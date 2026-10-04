# Code Review: `mamba` (v0.15.0)

> **Status: acted on.** Every finding below is marked **Fixed**, **Fixed (doc)**,
> **Won't fix**, or **Corrected**. The fixes landed as `0.16.0`; see
> `CHANGELOG.md`. Baseline before the work: `dart analyze` → **No issues found**,
> `dart test` → **369 tests, all passing**. Baseline after: **373 tests, all
> passing**, analyzer clean. All findings were reproduced with throwaway probe
> scripts (since removed).

Reviewer scope: robustness assessment, bugs, redundant tests, and strange/dead
helpers.

---

## 1. Is Mamba a robust CLI framework?

**Short answer: yes, structurally — with two genuine robustness gaps.**

### What is genuinely strong

| Area | Evidence |
|---|---|
| Layering | `Command → CommandRegistry → Parser → _Execution`. No cycles, no god object. `lib/mamba.dart` is a clean barrel. |
| Type safety | `sealed class Input<T>` makes optional/required/defaulted/nullable a **compile-time** property (`OptionalInput<T> : Input<T?>`, `MandatoryPositional<T> : Positional<T>`). Enforced by 4 custom lints (`no_dynamic_casts`, `no_raw_types`, `strict_top_level_inference`, `strict-inference`). Zero analyzer findings. |
| Immutability | Every list/map field is wrapped at declaration (`_copyList`, `_copyStringLists`, `List.unmodifiable`, `Map.unmodifiable`). No mutable escape hatch. |
| Declaration validation | `CommandRegistry._validate` (registry.dart:769–860) checks name shape, duplicate names, duplicate shorts, conflict keys vs. required inputs, choices-vs-defaults, range-vs-default, step-vs-default, and accessor leaf reuse — all at *build* time, not parse time. |
| Failure model | `MambaFailureResult` aggregates per-phase errors; cleanup hooks still run after a failure (`executor_test.dart:404,427`); exit codes validated 1–255 (`errors.dart`). |
| Suggestion engine | `lib/src/suggestion.dart` (90 lines) is genuinely well isolated — one function, one policy, fully documented, 20+ focused tests. |
| Executable's own test suite | `mamba_cli_test.dart:987` asserts generated sources are already `dart format` clean. That is a nice touch. |

### Robustness gaps — two of these are now closed

**R-a. The error taxonomy leaks.** A command author can receive a raw `StateError`
from `ParsedInputs.valueOf` for a *perfectly legal* declaration. Two independent
paths, both reproduced:

- Nested accessor leaf (§2, B3)
- Clustered short containing `h` (§2, B4)

`StateError` is a programmer bug in Dart. Mamba's own type system is what makes the
declaration legal, so Mamba should be the one reporting it — as a `MambaException`.
**Fixed (B3, B4).**

**R-b. Four independent short-token scanners, already out of sync.**

| Scanner | Location |
|---|---|
| Parser letter loop | `parser.dart:130–152` |
| Command-path skipping | `registry.dart:_registeredInputTokenLength` |
| Help/version pre-scan | `executor.dart:_requestsControlFlag` — uses a raw `contains('h') \|\| contains('V')` heuristic |
| Suggestion inventory | `parser.dart:_shorts` |

B4 was a concrete divergence between the first two. **Partly fixed (B4);** the other
three scanners are still separate.

**R-c. Group default-command resolution is implemented twice** and has diverged
(§2, B9/B10). **Error model fixed (B9);** the duplication remains.

**R-d. `package:mamba/mamba.dart` transitively imports `dart:io`**
(`mamba.dart` → `integrations.dart:1`, and → `command.dart` →
`completion_command.dart:1`). A Flutter-web or `dart2js` consumer cannot import the
package at all. The `dart:io`-free 90% of the framework is unreachable because it
shares a barrel with `CarapaceSpecWriter`. Splitting `integrations.dart` (or making
the spec writer a separate entrypoint) would fix this.

**R-e. `MambaContext` cannot carry domain objects** — deliberately sealed to four
scalars (`context.dart:55–60`). Hooks cannot pass a parsed `ParsedInputs`, an open
file handle, or a client object. Documented and defensible, but it is a real ceiling
on what hooks can do.

**R-f. `FormattedString`'s constructor throws `FormatException` on unstyled input**
(`help_formatter.dart:20–28`). A custom `HelpFormatter` that returns a plain `String`
fails at *runtime*, not compile time. The base class already styles via `string.red`,
so this only bites custom formatters — but it is a hostile failure mode for exactly
the extension point the class is designed for.

---

## 2. Bugs

### B1 — `CompletionCommand` silently discards the generated completion script when a caller supplies `createFile` ⚠️ *data loss* — **Fixed (breaking)**

`lib/completion_command.dart:40–55`

```dart
if (_usesDefaultGenerator) {
  File(path).writeAsStringSync(_completionFor(shell));   // line 50
} else {
  createFile(path);                                      // line 52 — content never computed
}
```

`_completionFor(shell)` is only reachable in the default branch. A caller-provided
`createFile` receives the path and nothing else. Probe:

```
A result=MambaSuccessResult      ← reports success
A file exists=true contents=     ← empty file
```

The framework reports `Created completion bash in /tmp/.../rig.bash` and leaves a
zero-byte file. This was the worst bug in the codebase: silent, and the success
message actively misleads.

**Fix.** `createFile` is now `void Function(String path, String contents)`
(`CompletionFileWriter`). The document is built before the destination is
touched, and `_usesDefaultGenerator` is gone. The default writer rejects an
omitted path instead of failing on an empty filename. Verified:

```
B1 […/rig.bash|3668 chars]
B2 bare -> MambaFailureResult A destination path is required to write fish completions.
```

### B2 — `CompletionCommand()` (bare constructor) is unusable ⚠️ — **Fixed**

`lib/completion_command.dart:18–26`. The bare constructor registers no positionals;
only `.preset` (line 27) wires `shellInput`/`pathInput`. But `run` (line 41) reads
both. Probe:

```
H bare CompletionCommand -> MambaFailureResult
  "bash" isn't a registered subcommand, alias, or argument.
```

`_usesDefaultGenerator` is also only meaningful to the bare constructor, which is the
constructor that cannot work. Make the bare constructor private, or make it a valid
minimal form.

**Fix.** The command's inputs are intrinsic, so the constructor declares them
itself and no longer accepts `mandatoryPositionals`/`discretionaryPositionals`/
`options`. `.preset` now only supplies aliases and a description.

### B3 — Nested accessor leaves are unreachable by identity ⚠️ — **Fixed**

`lib/parser.dart:172` (`_addAccessorMaps`) removes each leaf from `values`;
`_knownInputs` yields only **root** accessors. A user who holds the leaf declaration —
the exact object they passed to `AccessorListOption` — cannot read it:

```
C map={dsn: postgres://x}
C valueOf(leaf) THREW StateError: Bad state: Unknown parsed input declaration.
C contains(leaf)=false
```

`registry_test.dart` even tests this at the registry level (`publishes inherited
inputs on descendant records`), which makes the parse-level gap more surprising. Fix:
add every leaf to `_known` in `_knownInputs`, and/or leave the leaf entry in `values`
alongside the built map.

**Fix.** `_addAccessorMaps` no longer removes leaves, and `_knownInputs` registers
every leaf recursively. Verified: `B3 map={dsn: postgres://x} leaf=postgres://x`.

### B4 — `-xh` reports help but leaves the handle unset — **Fixed**

`lib/parser.dart:135` sets `help = true` without `values[MambaBuiltInFlags.help] =
true`, unlike the early branch at line 58 which handles both `--help` and `-h`:

```
B -h  -> help=true, valueOf(help)=true
I -xh -> help=true,  valueOf(help) THREW StateError: Parser omitted a non-null input value.
```

Same flag, two spellings, two behaviours. Line 58 already solves this — delete the
duplicated special case at 135.

**Fix.** The clustered branch now records the handle alongside `help = true`.
The branch has to stay: a group does not publish the built-in help flag to its
descendants, so the lookup would not find it. Verified: `B4 -xh help=true value=true`.

### B5 — Repeated positionals swallow the real validation error — **Fixed**

`lib/parser.dart:487`:

```dart
} on MambaParseException {
  break;
}
```

Any genuine value failure (regex, choice) is caught and turned into "stop
collecting". Probe with `RepeatedStringPositional('files', regExp:
RegExp(r'\d+'))` and `['1','oops','2']`:

```
F THREW MambaParseException: "oops" isn't a registered command, alias, or argument.
```

`oops` **is** a registered argument — it is a value. The user is told to look for a
command typo. Narrow the `catch` to the specific "not my value" condition and
rethrow genuine violations.

**Fix.** The loop asks `_accepts(positional, token)` before parsing, so parsing
cannot fail and nothing is swallowed. The leftover term is then attributed:

```
B5 MambaParseException: 'oops' is not an accepted value for files.
```

### B6 — `--help` makes validation order-dependent — **Documented**

`lib/parser.dart:68` — `if (help || version) continue;`

```
G parse(['--bogus-flag','--help']) -> rejected: Unknown flag or option --bogus-flag.
G parse(['--help','--bogus-flag']) -> accepted
```

Documented behaviour would be better than order-sensitive behaviour. At minimum,
document it on `Parser.parse`.

**Fix.** The order-sensitivity is deliberate — an invocation that only asks for
help is answered, not corrected — so it is now documented on `Parser.parse`
rather than changed.

### B7 — Digits rejected in names, accepted in shorts; error message conflates three failures — **Fixed (breaking)**

`lib/registry.dart:766` — `_name = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$')`, while
the short check at line 826 allows `^[A-Za-z0-9]$`:

```
J command name with digit  REJECTED: MambaRegistryError: Invalid command definition
J option name with digit  REJECTED: MambaRegistryError: Duplicate or invalid input max-workers2
```

`rig2` and `--max-workers2` are ordinary CLI names. Also: "Invalid command definition"
names neither the command nor the reason, and "Duplicate **or** invalid input"
conflates duplicate-name with bad-shape. Three distinct failures, two messages.

**Fix.** The name pattern is now `^[A-Za-z][A-Za-z0-9]*(?:[-_][A-Za-z][A-Za-z0-9]*)*$`,
and each failure reports itself:

```
B7 digit names accepted
B7 "2fast" rejected: Input name "2fast" must be letter-led words of letters and digits separated by a single hyphen or underscore.
```

### B8 — Help output: no blank line between `Options` and `Commands` — **Fixed**

`lib/help_formatter.dart:220–229`. Every other section is followed by
`buffer.writeln()`; the `Options` section is not. Actual output:

```
Options[ --name NAME ]
________________
Commandsgroup A group.
```

The `Commands` heading collides with the last option's underline. One missing
`buffer.writeln();`.

**Fix.** Added. Verified: `B8 contains "Options\nCommands"? false`.

### B9 — Group default resolution: two implementations, three error types — **Fixed (error model)**

`GroupCommand.run`/`runChildCommand` (`command.dart:1619–1652`) vs.
`_Execution._effectivePath` (`executor.dart`).

`runChildCommand` is **never reached through the executor** — `_effectivePath`
pre-expands group defaults, so `GroupCommand.run`'s default branch only fires on
direct calls (which is how `command_test.dart:454` tests it, while
`executor_test.dart:756` tests the *other* implementation). The two can drift freely,
and have:

- `runChildCommand` throws raw `ArgumentError` for a **legal** child name
  (`path.contains(name)` at line 1622):

  ```
  K runChildCommand(['same']) THREW ArgumentError: Invalid argument (path): Instance(length:1) of '_GrowableList'
  ```

  A group whose child shares its name is legal (the registry permits it), passes
  executor construction-time validation, and is rejected by `runChildCommand`.

- `runChildCommand` throws `MambaException` for an unknown child (line 1637), while
  the executor throws `MambaRegistryError` for the same situation.

`ArgumentError` is an `Error`, not an `Exception`, so `_Execution.execute`'s `on
Exception catch` would **not** catch it — it would escape `execute()` uncaught, past
the exit-code machinery.

**Fix.** `runChildCommand` no longer throws `ArgumentError`: an empty path is a
`MambaException`, an unknown child is a `MambaCommandNotFoundException` (which
nothing threw before — see S3), and the `path.contains(name)` guard is gone so a
child that shares its group's name resolves. Verified: `B9 runChildCommand -> leaf ran`.

The two resolution implementations are still both present, and
`GroupCommand.run`'s default branch is still unreachable through the executor.
That duplication remains; see S12.

### B10 — Root defaults fire on an empty command line; group defaults do not — **Corrected / documented**

`Executor.defaultCommandPath` is applied when `selected == null`. A
`GroupCommand.defaultSubCommandPath` is only consulted when the group token was
*explicitly typed*. Probe — a root containing one group with
`defaultSubCommandPath: ['same']`, invoked with no arguments:

```
K result = root help output      ← leaf never ran
```

Both mechanisms are called "default command" in `CONTEXT.md:11–13`:

> **Default command**: A command selected when an invocation does not name a child
> command at a scope that has a configured default. **It is selected implicitly
> rather than by a command token.**

The group case violates its own definition unless you type the group.
`executor_test.dart:594` only tests the group case with an explicit `['git']`, so
the gap is untested.

**Corrected.** On re-reading `_effectivePath`, the behaviour is right: each *scope*
resolves its own default, and the root is the scope you are in when you type
nothing. A group becomes the relevant scope only once its own token is named.
Firing a child's default from its parent with no argument at all would make the
root's `defaultCommandPath` redundant. The defect was the *definition*, not the
code, so `CONTEXT.md` now states the per-scope rule explicitly and adds a test for
the root-without-default case.

### B11 — `--` trailing arguments are silently accepted with no variadic — **Won't fix**

`lib/parser.dart:643` — `_validateVariadic` returns early when `variadic == null`:

```
D parse(['--','anything','-x']) -> trailing=[anything, -x]
```

Any mistyped subcommand placed after `--` is accepted and forwarded to
`run(inputs, args)` as free-form data. Defensible, but undocumented and asymmetric
with the strict treatment of everything before `--`.

**Won't fix.** `--` is the conventional escape hatch and a command that receives
`args` is entitled to do whatever it wants with them. Rejecting them would break the
ordinary `mytool -- file1 file2` idiom. Documented on `Command.run` instead.

---

## 3. Redundant & weak tests

### R1 — 40× repeated setup boilerplate — **Fixed**

`test/mamba_cli_test.dart`: **40** × `createTempSync('mamba_')`, **40** ×
`addTearDown`, **31** × `sourceFormatter: _sourceFormatter`. There is no harness. A
single `late TempProject scaffold;` / `withProject((p) { ... })` helper would remove
~200 lines and the copy-paste drift risk.

**Fix.** `test/fixtures.dart` gained `tempDirectory()` (creates and registers the
teardown itself) and `realScaffolding(parent, processRunner:)`. All 40 sites collapsed.

### R2 — The golden-file completion test covers almost nothing — **Fixed**

`test/integrations_test.dart:471–496`. The record is built as:

```dart
CommandRegistry.create('rig', 'Completion fixture.', options: [RigCommand.format]).toMap()
```

Root only. **One** option. No subcommands, no positionals, no variadic, no
accessors, no paired/selected groups, no persistent inputs. It then string-compares
five large generated artifacts. Meanwhile `integrations_test.dart:313` (`render rich
command metadata for every shell`) already covers the rich case inline.

The five checked-in files in `fixtures/rig/completions/` cost a "Regenerate
fixtures/…" ritual and detect regressions the inline tests already catch. Either drop
them or promote the rig to a real tree (which is what the name implies it should be).

**Fix.** Promoted the rig rather than dropping the fixtures — they are the only
regression net on the converters. `fixtures/rig/rig.dart` is now a real tree: a
group with `propagatedFlags`, `deploy` (long description, alias, mandatory and
discretionary positionals, variadic, boolean/count/negatable flags, plain/required/
repeatable/choice options, a required paired group, a selected group, a nested
accessor) and `status` (repeated positional with `times`). The generated artifacts
grew from ~1 KB to 7.6/2.7/12.2/16.7/1.9 KB, and the test asserts the record's
shapes before comparing. `tool/regenerate_fixtures.dart` does the rewrite.

### R3 — The suggestion-ordering test is duplicated verbatim — **Partly fixed**

`parser_test.dart:1412` and `parser_test.dart:1483` are both literally:

```dart
test('leads with the shorter name when a prefix matches twice', () { ... });
```

Two near-identical blocks for one function (`prefixMatches`'s sort). One ordering
test is sufficient; the second should assert the *other* thing that actually differs
(flag-vs-option kind rank).

**Partly fixed.** Re-reading them, the two assertions are *not* identical — they use
different registries and check different candidate sets, so both earn their place.
What was actually wrong was that two differently-scoped tests shared one title, which
made the output ambiguous. They are now `'leads with the shorter command name …'` and
`'leads with the shorter input name …'`. A kind-rank test is still worth adding; it
was not added here.

### R4 — Two ad-hoc analyzer harnesses — **Fixed**

- `command_test.dart:858–893` — "Input definition analyzer": writes
  `test/invalid_input_types_temp.dart`, shells out to `dart analyze`.
- `context_test.dart:99–136` — "Analyzer contracts": same technique.

Two hand-rolled temp-file-plus-`Process.run` harnesses for the same job. Extract one
`expectAnalyzerErrors(source, [...diagnostics])` helper.

**Fix.** `fixtures.dart` exposes `expectAnalysis(source, {expectedDiagnostics,
fileName})`, which writes, analyzes, asserts, and cleans up. Both suites use it.

### R5 — 12 near-identical "format" enums across the test suite — **Fixed**

```
command_test.dart:41          enum OutputFormat { yaml, json }
help_formatter_test.dart:276  enum _OutputFormat { json, yaml }
help_formatter_test.dart:278  enum _Tag { release, preview }
help_formatter_test.dart:280  enum _Mode { auto, always }
context_test.dart:141         enum Mode { local }
integrations_test.dart:9      enum Mode { json, text }
parser_test.dart:4            enum Format { text, json }
fixtures/input_types.dart:3   enum Format { text, json }
registry_test.dart:15         enum _Format { json, yaml }
registry_test.dart:17         enum DeploymentFormat { yaml, json }
registry_test.dart:13         enum VariantChoice { one }   ← referenced zero times
```

`{json, yaml}` / `{yaml, json}` / `{text, json}` are the same enum three times over.
`VariantChoice` is declared once and never used — dead.

**Fix.** Deleted `VariantChoice`, deleted `test/fixtures/input_types.dart` (which held
a fourth `Format`), and collapsed `registry_test`'s `_Format` into `DeploymentFormat`.
`OutputFormat`, `_OutputFormat`, `Format`, and `Mode` remain: they live in separate
suites with different member names that assertions depend on, and merging them would
couple four files for no gain.

### R6 — `_withoutAnsi` duplicated five times — **Fixed**

The regex `\x1B\[[0-9;]*m` is re-declared in:

- `lib/help_formatter.dart:22`
- `test/command_test.dart:68`
- `test/executor_test.dart:6`
- `test/help_formatter_test.dart:7`
- `test/registry_test.dart:10`
- `test/mamba_cli_test.dart:1091`

It already exists as `FormattedString._ansiColorRegex`. `test/fixtures.dart` is the
obvious home for a public `stripAnsi` — it is currently imported by **one** file out
of nine.

**Fix.** `stripAnsi` now lives in `fixtures.dart` and is imported by every suite
that asserts on help. It is documented as the test-side twin of
`FormattedString._ansiColorRegex`.

### R7 — `InputCommand` defined twice — **Fixed**

`test/executor_test.dart:222` and `test/fixtures/process_cli.dart:3` — same class
name, same `HookRunner` shape, same `_input = null` in `postRun`. One should live in
`test/fixtures.dart`.

**Fix.** The shared one moved to `fixtures.dart` and `executor_test.dart` uses it.
`process_cli.dart` keeps its own copy *deliberately*: it is a standalone program run
in a separate process by `system_process_test.dart`, and importing `fixtures.dart`
would drag `package:test` into it. That is now stated in a comment on the file.

### R8 — `registry_test.dart` is 2838 lines with a ~250-line hand-rolled matcher DSL — **Won't fix**

Lines 20–254 define `FlagExpectation`, `OptionExpectation`, `PositionalExpectation`,
`AccessorExpectation`, `CommandExpectation`, and `matchRegistry`, which restates
`isA<RegistryFlag>().having(…)` six times per field, per category. 81 tests over one
class. The DSL is arguably justified, but it is a second type system living in the
test directory — and it is why three parallel enums were needed.

**Won't fix.** The DSL buys readable, compile-checked expectations across 80+ tests;
hand-rolling `having` chains at each site would be longer and less safe. The dead
enums it forced were removed under R5.

### R9 — Duplicated group names across files — **Won't fix**

- `group('Variadic')` → `command_test.dart:895` **and** `registry_test.dart:1865`
- `group('Paired options')` → `command_test.dart:786` **and** `parser_test.dart:512`

Same subject, two files, overlapping assertions.

**Won't fix.** `command_test` asserts what a `Command` *declares*; `parser_test` and
`registry_test` assert what a *parse* and a *record* produce. Same heading, different
layer. Renaming headings to disambiguate would be churn.

---

## 4. Strange / dead helpers

### S1 — `CommandRegistry.withInheritedInputs() => this` — **Fixed**

`lib/registry.dart:406`. A no-op that returns `this`. Probe:
`E withInheritedInputs()===self: true`. Its only reference was an identity assertion
in `registry_test.dart`. **Fixed.** Deleted.

### S2 — `CommandRegistry.helpFlag` — **Fixed**

`lib/registry.dart:283`. An **instance** getter that ignores the instance and always
returns the same global constant. `MambaBuiltInFlags.help` is already public. Only
referenced by `registry_test.dart:1858`. **Fixed.** Deleted; the test reads
`MambaBuiltInFlags.help.short` directly.

### S3 — `MambaCommandNotFoundException` — **Fixed**

`lib/registry.dart:215`. Declared, exported, **never thrown anywhere in `lib/`**. The
registry throws `MambaRegistryError`; the parser throws `MambaParseException`;
`GroupCommand.runChildCommand` threw a bare `MambaException`. The only reference was
`registry_test.dart:2374`, which constructed it purely to assert its message string.

**Fixed.** Rather than deleted, it is now thrown — by `GroupCommand.runChildCommand`
for an unknown child, the one place that genuinely knows which commands were on offer.
The two message-only tests were repointed at the live path.

### S4 — `RegistryRecord.persistentFlags` / `persistentOptions` are hardcoded `null` — **Corrected**

`lib/registry.dart:596` — literally `persistentFlags: null, persistentOptions: null`.
Meanwhile five completion converters carry `_withoutLocalOverrides(command.persistentFlags, …)`,
`_mergeFlags([...inheritedFlags, ...persistentFlags, ...])`, and related branches.
The review called those branches dead.

**Corrected.** They are reachable. `docs/.../completions.md:148` and
`skills/.../completion-commands.md:101` both document that `toMap()` leaves them null
*so that a manually built record is the only way to state them*, and
`integrations_test.dart` builds exactly such records with them populated. No change
made.

The genuine gap found next door: `_record` emits `optionGroups` for **paired** groups
only, so a `SelectedOptions` group reaches a converter as loose options with no record
of the grouping. Recorded as S14 rather than silently changed, because fixing it
alters every generated artifact.

### S5 — `ChoiceVariadic.defaultValue` is declared, exported, and never read — **Fixed (breaking)**

`lib/command.dart:318–323` declares it; `registry.dart:732` serialised it into the
completion record; **the parser never read it**. `ParsedInputs` has no variadic
handle at all — variadic values reach a command only through the untyped `List<String>
args`. **Fixed.** The field and `RegistryVariadic.defaultValue` are both gone.

### S6 — `publishedAccessors` has no group-level counterpart

`lib/registry.dart:367` sets `publishedAccessors: accessors` for a root registry, but
`_fromCommand` never sets it, and `GroupCommand` exposes `propagatedFlags` /
`propagatedOptions` with **no** `propagatedAccessors`. A group can therefore never
publish an accessor to its descendants, while it can publish every other input kind.
Asymmetry, not a bug — but it reads as an oversight and `_publishedAccessorsToHere`
(`registry.dart:319`) therefore only ever contributes root accessors.

**Won't fix.** Accessors read like configuration rather than per-command inputs, and
root-only publication is a coherent rule. Adding `propagatedAccessors` would be a
feature, not a fix.

### S7 — Two pairs of byte-identical helpers — **Fixed**

```dart
// parser.dart:454 and :461
void _addPairedValuesFor(PairedOptionsDefinition group, Map<Object,Object?> values) =>
    values[group] = group.valuesFrom(values);
void _addSelectedValuesFor(SelectedOptions group, Map<Object,Object?> values) =>
    values[group] = group.valuesFrom(values);
```

and `PairedOptions.valuesFrom` (`command.dart:1142`) vs `SelectedOptions.valuesFrom`
(`command.dart:1258`) — identical bodies. The two classes differ only by
`SelectedOptions.single`. Collapse to one implementation.

**Fixed.** `SelectedOptions` now implements `PairedOptionsDefinition`, both delegate
to one private `_valuesFrom`, and the parser has one `_addGroupValuesFor` instead of
two.

### S8 — The five completion converters share no base helpers — **Deferred**

`lib/integrations.dart` (2416 lines). Duplicated **five times**: `_accessorLeaves`.
Duplicated 2–4×: `_pathIdentifier`, `_identifier`, `_quote`, `_description`. `_quote`
alone has **three different escaping strategies** across bash (`'"'"'`), zsh
(`'\''` via `_escape`), and fish (`\'`) — correct per shell, but copied rather than
parameterised. `RegistryRecordConverter._root` (line 72) additionally re-wraps a
`RegistryRecord` into a structurally identical `RegistryCommand`, so two parallel
record types flow through the whole file.

**Deferred.** This is a ~2400-line refactor with no behaviour change, and it would
land in the same release as three breaking API changes. It is worth doing, but as its
own change with its own diff review, not folded in here.

### S9 — Accessor numeric options fake interface conformance — **Partly fixed**

```dart
// command.dart:1360ish
final class _RequiredAccessorIntOption extends RequiredAccessorOption<int>
    with NumericRangeValidated<int> {
  @override int? get min => null;
  @override int? get max => null;
}
```

and the same for `_DefaultedAccessorIntOption`, `_RequiredAccessorDoubleOption`,
`_DefaultedAccessorDoubleOption`. These mixins exist only to satisfy `Parser._range`
and `Parser._allowsDash`. Meanwhile `AccessorIntOption.regex` /
`AccessorDoubleOption.regex` allocate a **new `RegExp` on every access** and are not
part of `RegExpValidated`. Both should be `static final` fields on the type.

**Partly fixed.** The allocation is gone: `AccessorIntOption.syntax` and
`AccessorDoubleOption.syntax` are `static final RegExp` fields, and `Parser` matches
against those. The always-null `NumericRangeValidated` / `NumericStepValidated`
mixins were left alone — removing them changes what a caller can cast to, and the
mixins are the honest way to say "constrained, and the constraint is unbounded".

### S10 — `ProcessedStandardInput.text` has Latin-1 semantics — **Fixed**

`lib/processed_standard_input.dart:8` — `String.fromCharCodes(bytes)` decodes each byte
as a code unit. For a field named `bytes` on a UTF-8 CLI, `utf8Text` is the correct
accessor and `text` is a trap. (`command_test.dart:941` "exposes character, UTF-8, and
JSON representations" enshrined the behaviour with `'hé'.codeUnits`.)

**Fixed.** `text` now delegates to `utf8Text`. The test was updated to use real UTF-8
bytes.

### S11 — `test/fixtures/input_types.dart` is orphaned — **Fixed**

No file in the repo imports it. `verifyInputOutputTypes` never executes.
`test/fixtures.dart` is imported by exactly one test file.

**Fixed.** Deleted, and `fixtures.dart` is now imported by six test files.

### S12 — Two parallel documentation trees — **Won't fix**

`docs/src/content/docs/reference/{arguments,flags,options,commands,hooks,executor,architecture}.md`
and `skills/mamba-framework/references/{arguments,flags,options,completion-commands,hook-runners,testing}.md`
cover the same API. Nothing enforces that they agree.

**Won't fix.** They have different audiences: `docs/` is the rendered site, `skills/`
is what an agent is handed. Deduplicating them would need a build step, which is a
larger change than the problem.

### S13 — Thin `CONTEXT.md` — **Fixed**

Four terms for a ~5000-line framework, and two of them (the "default command" and
"repeated positional" definitions) are **contradicted by current behaviour** — see B10
and B5.

**Fixed.** Added the per-scope default-command rule (B10), the repeated-positional
stop rule (B5), and a new **Command name** term pinning the name shape (B7).

### S14 — Selected option groups never reach `optionGroups` — **Found while fixing, not fixed**

`_record` builds `optionGroups` from `pairedOptionGroups` alone. A
`SelectedOptions` group's members are exported as ordinary options, so a converter
cannot tell that `--log` and `--report` were declared as one choice. Fixing it
changes every generated artifact, so it is recorded as a known limitation rather than
changed alongside the correctness fixes. The fixture test now asserts the behaviour
instead of hiding it.

---

## Priority

| # | Item | Why first | Status |
|---|---|---|---|
| 1 | **B1** | Silent data loss with a success message. | Fixed (breaking) |
| 2 | **B2** | A public constructor that cannot work. | Fixed |
| 3 | **B3, B4** | `StateError` escaping a legal program. | Fixed |
| 4 | **B5** | Actively misdirecting error message. | Fixed |
| 5 | **B7** | Blocks legitimate CLI names (`--max-workers2`). | Fixed (breaking) |
| 6 | **B9, B10** | Divergent default-command semantics; an `ArgumentError` that escapes `execute()`. | Fixed / corrected |
| 7 | **R4, R5, R6, R7** | Test-suite hygiene — mechanical, low risk, high readability payoff. | Fixed |
| 8 | **S1, S2, S3, S5** | Delete-only cleanups with zero behavioural risk. | Fixed |
| 9 | **S4, S7, S8** | Structural dedup in `integrations.dart` / `command.dart`. | S7 fixed; S4 corrected; S8 deferred |
| 10 | **B6, B8, B11, S10** | Document-or-fix decisions; small. | Documented / fixed / declined |

### New findings raised while fixing

- **N1** (not in the original review): the public API spelled the `RegExp`
  parameter `regex` on options and accessors but `regExp` on `NormalPositional`,
  `RepeatedStringPositional`, and `NormalVariadic`. **Fixed (breaking).** Every
  `RegExp` parameter is now `regex`, which let the two positional constructors
  become plain super-parameter forwarding instead of re-naming the argument.
- **S14**: selected option groups never reach `toMap()`'s `optionGroups`.