# Mamba Framework Inconsistencies

This report is based exclusively on `lib/` and `test/`. It described the
pre-0.3.0 project. All findings INC-001 through INC-018 below are resolved in
0.3.0 and retained here as the historical change record; earlier findings that
were fixed before this report remain listed separately near the end.

The pre-0.3.0 suite passed 478 tests. The findings below were therefore
mostly untested interactions between individually tested features, metadata
contracts that are weaker than their documentation, or behavior that is
internally consistent but conflicts with the project's stated coding rules.

## Severity guide

- **High**: can produce a parsed state that violates the declaration, select
  the wrong value, or make an integration advertise materially incorrect
  syntax.
- **Medium**: creates surprising public behavior or requires a caller-specific
  workaround.
- **Low**: primarily affects diagnostics, discoverability, documentation, or
  maintainability.

## Historical high-priority findings (resolved in 0.3.0)

The most important current issues are:

- Required choice inputs can become optional when they declare defaults.
- An optional variant pair can return two members after one explicit member
  and one default are combined.
- A root input can override a same-named group-published input even though the
  inheritance code and documentation say the nearer group should win.
- Option names and short aliases are accepted with the wrong dash prefix.
- `RegistryMap` is only shallowly immutable and does not validate several
  semantic relationships.
- Carapace loses the at-least-one rule for required variant groups.

## Error and execution inconsistencies

### INC-001: Definition failures bypass the fake-executor result contract

**Severity: Medium**

`MambaRegistryError` extends `ArgumentError`, and registry construction occurs
inside `fake()` or `create()`, before `execute()` is called. An invalid command
surface therefore throws while the executor is being created instead of
returning `MambaFailureResult`.

This is defensible because the class documentation calls registry failures
unrecoverable definition errors. It still means the apparent fake-executor
contract—success or failure as a result value—begins only after construction,
and callers need a separate error boundary around setup.

**Recommendation:** document the construction boundary prominently, or expose
a validating factory that returns a setup result before producing an executor.

### INC-002: Non-Exception failures discard secondary diagnostics

**Severity: Medium**

The executor correctly attempts cleanup after `Error` values and arbitrary
thrown objects. It then rethrows the first primary `Error`/object, or the first
cleanup `Error`/object. Any ordinary exceptions collected from the other phase
are no longer observable through `MambaExecutionException`.

For example, a command `Exception` followed by a cleanup `StateError` rethrows
the `StateError`; the original command failure is lost to the caller. The
reverse situation similarly hides cleanup exceptions behind a primary
`Error`.

**Recommendation:** attach all secondary failures to a common diagnostic
object before rethrowing, or provide a logging callback that receives every
captured failure.

## Registry and inheritance inconsistencies

### INC-003: Group-published inputs lose to root inputs with the same name

**Severity: High**

Registry construction uses `_mergeByName(inherited, ownPublished)`, where the
nearer group's declaration replaces the inherited root declaration. The public
documentation also says inherited inputs are ordered from the root downward
and local or nearer declarations win.

At parse/help time, `_inheritableFlags` and `_inheritableOptions` actually walk
from the current registry toward the root. When those lists become maps, the
later root entry overwrites the earlier group entry. Consequently:

```text
root --profile (definition A)
  group publishes --profile (definition B)
    leaf sees definition A
```

This can change type, short alias, requiredness, default, and description. The
Carapace export retains the group-published declaration separately, so runtime
and generated completion can also disagree.

**Recommendation:** reverse the ancestor traversal or build an explicit
root-to-leaf chain before applying `_combineWithInherited`. Add paired flag and
option tests where root, group, and leaf reuse one name.

### INC-004: Name-validation messages do not describe the accepted grammar

**Severity: Low**

The actual grammar is:

```text
^[A-Za-z]+(?:[-_][A-Za-z]+)*$
```

It accepts letter-only words separated by hyphens or underscores and rejects
all digits. Input and positional errors instead say names may use “letters,
numbers, or hyphens,” omitting underscores and claiming numbers are valid.

**Recommendation:** centralize the grammar description and use the same text
for commands, flags, options, accessors, positionals, and variadics.

### INC-005: Empty choice sets are valid definitions but unusable inputs

**Severity: Medium**

The registry checks that a declared default belongs to its choice list, but it
does not require the list itself to contain a member. Empty choices can be
registered for ordinary options, paired options, positionals, variadics, and
accessor choices.

A required empty-choice input can never parse successfully. An optional one is
dead public surface and produces empty completion metadata.

**Recommendation:** reject empty choice lists with `MambaRegistryError` and
reject empty `choices` arrays in `RegistryMap` whenever the value type is
choice-based.

## Command inconsistencies

### INC-006: Command-not-found text joins sentences without whitespace

**Severity: Low**

`MambaCommandNotFoundException` concatenates:

```text
Command x was not found under parent.This command has no subcommands.
```

or:

```text
Command x was not found under parent.Available commands: ...
```

The first string ends with a period and the next starts immediately.

**Recommendation:** insert one space between the sentence fragments and add
exact-message tests for empty and non-empty child lists.

## Flag inconsistencies

### INC-007: The registry recognizes bundled help but the executor/parser do not

**Severity: Medium**

`CommandRegistry.isRegisteredFlagToken()` treats the built-in `-h` as a valid
member of a short bundle. A token such as `-hv` can therefore be classified as
a registered flag token during command discovery.

`requestsHelp()` recognizes only exact `-h` and `--help`. The parser's short
flag maps do not contain the built-in help flag, so parsing the same `-hv`
eventually throws `This isn't a registered short flag or option`.

Direct `Parser` use also rejects exact `-h`; only the executor intercepts it.

**Recommendation:** either reserve help as an exact, non-bundleable executor
token and make the registry helper agree, or let parser/executor detect `h`
inside valid bundles.

## Option inconsistencies

### INC-008: Short aliases and long option names cross dash forms

**Severity: High**

The parser uses `_findOption()` for both long and short syntax. That function
looks up both the full option name and every short alias regardless of which
syntax called it. As a result, an option declared as `output` with short alias
`o` accepts all of these forms:

```text
--output value   # documented long form
-o value         # documented short form
--o value         # undocumented short alias with two dashes
-output value     # undocumented long name with one dash
```

Flags do not have this behavior. Registry token-length discovery also checks
only real short aliases for one-dash tokens, so `-output` can behave differently
depending on whether command discovery must skip it before reaching a child.
Help and Carapace advertise only the two documented forms.

**Recommendation:** split lookup into `_findLongOption(name)` and
`_findShortOption(alias)` and add rejection tests for the crossed forms.

### INC-009: Required choice inputs can be omitted when they have defaults

**Severity: High**

Ordinary choice defaults are inserted before `_validateRequiredOptions()`. A
`ChoiceOption(required: true, defaultValue: ...)` therefore passes requiredness
without an explicit token. Registry metadata, help grammar, and Carapace still
mark it mandatory.

The same conceptual conflict exists for positional registration. A
`ChoicePositional` or `RepeatedChoicePositional` placed in
`mandatoryPositionals` accepts omission when it has a default, even though help
uses required angle brackets and serialized metadata says `required: true`.

Paired required choices behave differently: pair requiredness is checked
before defaults, and tests explicitly require user input there.

**Recommendation:** choose one contract:

- Treat a default as satisfying omission and serialize/render the input as
  optional, or
- Treat `required` as requiring explicit user input and apply defaults only to
  optional inputs.

Rejecting `required + default` during registry construction would be the least
ambiguous API.

### INC-010: Variant pair defaults can violate variant exclusivity

**Severity: High**

Pair validation runs before pair choice defaults are inserted. Consider an
optional variant group with one defaulted member and another explicit member:

```text
variant: [--json (default auto), --text]
invocation: --text plain
```

Validation sees one explicit member and succeeds. `_addChoiceDefaults()` then
adds the omitted `json` default. The returned string option map contains both
variant members, even though the group promises at most one.

The same ordering gives all-of defaults uneven behavior: a completely omitted
optional all-of group receives every default, while a partially explicit group
fails before a missing default can complete it.

**Recommendation:** build effective values and validate the final group once,
or apply group-aware defaults that suppress a variant default whenever another
member was explicit. Add an explicit-member-plus-default regression test.

### INC-011: Regex-approved dash values can consume real input tokens

**Severity: Medium**

To support values such as `-pattern`, `_takeOptionValue()` accepts a
dash-prefixed following token when a string option's regex matches it. With a
broad regex such as `\S+`, this also accepts registered-looking tokens:

```text
--pattern --verbose
```

`--verbose` becomes the pattern value instead of a flag. This is especially
surprising because numeric options use a narrower special case while string
options delegate the decision to arbitrary regexes.

**Recommendation:** prioritize exact registered input tokens over regex-based
consumption and require inline syntax (`--pattern=--verbose`) when the intended
value looks like another input.

## Argument inconsistencies

### INC-012: `RepeatedChoiceVariadic` changes completion, not parsing or help

**Severity: Medium**

`ChoiceVariadic` and `RepeatedChoiceVariadic` both parse every token after `--`
into an unbounded list, and help renders both with `*`. The subtype exists only
to switch Carapace from one `dash` completion slot to `dashany`.

Thus a non-repeated `ChoiceVariadic` accepts many runtime values even though
completion suggests only the first, while the class names imply a runtime
cardinality distinction that does not exist.

**Recommendation:** either make ordinary `ChoiceVariadic` accept one trailing
value, or rename the subtype around completion behavior and document why the
runtime cardinality is deliberately identical.

## RegistryMap inconsistencies

### INC-013: `RegistryMap` is shallowly, not deeply, immutable

**Severity: High**

`RegistryMap._parse()` wraps only the root map with
`Map.unmodifiable`. Nested maps and lists are the same mutable objects supplied
by the caller. After validation, caller code can mutate an option property,
remove a required nested field, change a choice to a non-string, or alter an
option-group member.

The converter then receives data that no longer satisfies the validation that
supposedly guards its casts. This can produce invalid YAML or raw type errors.

**Recommendation:** recursively copy and freeze maps and lists during parsing.
The validated copy, rather than the caller's source graph, should become
`registryMap.map`.

### INC-014: RegistryMap structural validation is stronger than semantic validation

**Severity: High**

The map validator has good recursive property/type checking and validates
option-group references. Several cross-property constraints remain unchecked:

- A command collection key need not equal the nested command's `name`.
- Ordinary `valueType: choice` options do not have to declare `choices`.
- Ordinary option, positional, and variadic defaults need not belong to their
  choices.
- Choice arrays may be empty.
- `times` can appear without meaningful repeated semantics, and repeated
  metadata can omit a coherent bound.
- Names, aliases, and short aliases are type-checked but do not receive the
  live registry's grammar and collision validation.

This matters because `CarapaceSpecConverter` explicitly supports maps that did
not originate from `CommandRegistry.toMap()`.

**Recommendation:** make `RegistryMap` validate the same semantic invariants as
the live registry, ideally by sharing validation helpers or by defining a
single serializable schema model.

## Hook and context inconsistencies

The earlier hook lifecycle findings are now resolved: pre-hooks are awaitable,
only successfully entered hooks unwind, every entered cleanup is attempted,
cleanup exceptions become failures, and output is delayed until cleanup
finishes.

One documentation risk remains: `ParsedSingleOptions` is described as ordinary
non-repeated options, but its maps also contain single-valued paired members
because paired values share the same parser maps. Hook authors can observe pair
members even though the typedef description does not mention them.

**Severity: Low**

**Recommendation:** describe the hook record as “all parsed single-valued
string, integer, and double option members,” explicitly including pairs and
choices.

## Integration inconsistencies

### INC-015: Carapace omits negated boolean flag forms

**Severity: Medium**

Registry export preserves a boolean flag's `negatable` property, but
`CarapaceSpecConverter` never reads it when building flag keys. A runtime flag
that accepts both `--color` and `--no-color` advertises only `--color` in the
generated spec.

**Recommendation:** emit the negated spelling as a second completion entry or
use the relevant Carapace-native negation representation.

### INC-016: Required variant groups lose their at-least-one constraint

**Severity: High**

The converter reads an option group's `required` value, but applies it only
when `mode == all`. Both required and optional `oneOf` groups emit optional
member keys plus the same `exclusiveflags` list.

The resulting specs preserve “at most one” but not “exactly one.” Carapace
therefore advertises the required variant group as omittable even though the
Mamba parser rejects omission.

**Recommendation:** map required variants to a Carapace construct that enforces
one member, or document the completion limitation and avoid claiming complete
semantic reproduction.

### INC-017: Numeric completion ranges are unrelated to parser bounds

**Severity: Low**

The parser accepts signed, unbounded integer and fixed-point text. Carapace
suggests only `-10..10`; double suggestions additionally force two-decimal
formatting. The implementation now correctly comments that these are
illustrative suggestions, not validation bounds, but users still see a narrow
domain that has no basis in the input declaration.

**Recommendation:** add explicit completion-range metadata, or omit numeric
range suggestions when the command author did not declare a domain.

### INC-018: Serialized regex patterns are not used by Carapace

**Severity: Low**

`toMap()` now preserves regex patterns for string options, positionals,
variadics, and accessor strings. The Carapace converter does not use them to
choose or constrain completions. This is safer than the old unconditional
`$files` assumption, but it means pattern metadata currently has no integration
effect.

**Recommendation:** add author-supplied completion metadata rather than trying
to infer semantic completion from arbitrary regular expressions.

## Code-guideline warnings

The project-specific instructions ask reviews to warn when code conflicts with
the supplied guidelines. The following conflicts remain:

- The guideline requires errors to be explicit return values, while the
  framework deliberately uses thrown `Error`, `Exception`, and arbitrary
  throwable handling. Fake execution converts recoverable exceptions to
  values, but parsing, registry construction, formatting, and integrations
  still throw directly.
- The guideline says errors should be logged for monitoring or history. The
  framework has no logging callback; some secondary hook failures can become
  inaccessible when an `Error` takes precedence.
- Comments should stay synchronized with behavior. The inherited-input order
  comment says root-down while the implementation walks leaf-to-root, and the
  `ParsedSingleOptions` description omits paired members.
- `PairStringOption` still has a duplicated documentation comment.
- Static analysis reports two style infos: `MambaRegistryError.value` could use
  super parameters, and one executor-test helper could use an initializing
  formal.

The rest of the code generally follows the supplied guidance well: names are
mostly behavior-oriented, mutation is localized, stateful entities are
cohesive, formatting is automated, and the test suite emphasizes behavior.

## Current test-coverage gaps

The suite is broad and now covers defaults, positional allocation, aliases,
registry-map paths, integration output, and hook cleanup much more deeply.
These important boundaries still lack direct regression tests:

- Required ordinary choice option plus a default
- Mandatory choice positional help/metadata versus its omission behavior
- Variant pair with one explicit member and a different defaulted member
- Root and group publishing the same flag or option name
- `--o` and `-long-name` crossed option syntax
- Bundled built-in help such as `-hv`
- Empty choice collections
- Mutation of nested `RegistryMap` data after construction
- Registry-map command key/name mismatch and ordinary invalid choice defaults
- Negatable flags and required variants in generated Carapace YAML
- Primary execution failure combined with a cleanup `Error`
- A failing asynchronous pre-hook proving that its own post-hook is not called

## Findings resolved since the previous report

The following earlier inconsistencies no longer describe the current code:

- `MambaRegistryError` now has consistent string formatting and preserves
  `ArgumentError` diagnostics.
- Command and input names use one shared grammar, although two messages remain
  inaccurate.
- `GroupCommand.runChildCommand()` resolves aliases.
- Short-description validation and its 150-character message agree.
- Unknown long inputs identify both flags and options.
- Omitted count flags now receive `0`.
- Choice defaults are applied to ordinary options, pairs, positionals,
  variadics, and accessors.
- Accessor integer/double regex declarations match parser numeric syntax.
- Required ordinary options use one message.
- Regex failures identify the option and rejected value.
- Invalid discretionary positionals use `MambaParseException`.
- Empty positional tokens are validated rather than skipped.
- Repeated mandatory positionals reserve values for later mandatory entries.
- Pre-hooks support `FutureOr<void>`.
- Post-hooks run only for successfully entered hooks.
- One cleanup failure no longer prevents remaining cleanup.
- Cleanup exceptions become failure results and can be aggregated with a
  primary exception.
- Output is emitted only after cleanup succeeds.
- Executor-scoped context lifetime is explicitly documented and tested.
- Registry export retains option groups, accessor types, choices, defaults,
  regex patterns, and built-in help.
- Carapace emits typed completions for paired members and accessors.
- General string inputs no longer assume filesystem completion.
- Integration validation and writer failures use
  `MambaIntegrationException`.
