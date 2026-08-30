# Mamba Framework Inconsistencies

This report is based exclusively on the current implementation in `lib/` and
the behavior specified in `test/`. It replaces the pre-0.3 historical report
with a fresh assessment of the changed framework.

Current verification:

- `dart test`: 473 tests passed.
- `dart analyze lib test`: no issues found.

Passing tests do not invalidate the findings below. Most occur where two
individually tested features interact, or where the live registry and its
serialized form enforce different rules.

## Severity guide

- **High**: can reject a valid definition, resurrect shadowed behavior, make a
  declared spelling unreachable, or lose failure diagnostics.
- **Medium**: produces surprising public behavior or a material completion/help
  mismatch.
- **Low**: primarily affects diagnostics, portability, documentation, or
  maintainability.

## Summary

The most important current inconsistencies are:

- `RegistryMap` rejects some definitions accepted by `CommandRegistry`.
- An option override that changes single/repeatable cardinality can expose both
  the old and new definitions.
- Synthesized `--no-*` names are not included in collision validation.
- A paired option may claim the reserved `-h` alias even though parsing always
  treats it as help.
- `MambaExecutionError` promises cleanup-order preservation but drops and
  reorders multiple non-`Exception` cleanup failures.
- Group defaults are inserted before help resolution, so `group --help` can
  display the default descendant instead of the named group.
- Required Carapace variant groups still lose their at-least-one constraint.

## Registry and serialization inconsistencies

### INC-001: RegistryMap rejects live-valid cross-category names

**Severity: High**

The live registry intentionally distinguishes positional names from named
input names. `_validateDuplicates()` prevents collisions among flags/options,
among positionals, and between positionals and child commands, but it permits a
positional to share a name with a flag, option, or accessor because their token
syntax is unambiguous.

`RegistryMap._validateCommandSemantics()` instead inserts flags, options,
positionals, and accessors into one `localNames` set. It rejects the same name
across any of those collections.

Consequently, this sequence is possible:

```text
CommandRegistry.create(...) succeeds
CommandRegistry.toMap() succeeds
RegistryMap(registry.toMap()) throws MambaIntegrationException
Executor.fake() or Executor.create() fails during setup
```

The executor always constructs a `RegistryMap`, so serialization has become a
stricter second definition validator even for applications that never invoke a
completion command.

**Recommendation:** share one collision policy between the live registry and
map validator. If positional/named collisions are intended to be illegal,
reject them in `CommandRegistry`; otherwise keep separate name sets in
`RegistryMap`.

### INC-002: Type-changing option overrides can resurrect the shadowed option

**Severity: High**

Options are allowed to override same-named inherited options. The inheritance
chain is correctly ordered root-to-leaf, but `applicableSingleOptions` and
`applicableRepeatedOptions` filter the chain by subtype before de-duplicating
by name.

If a root publishes `RepeatableStringOption('profile')` and a nearer group
publishes `StringOption('profile')`, the selected descendant receives:

- The nearer `profile` in `singleOptions`
- The shadowed root `profile` in `repeatedOptions`

The parser chooses the single option first, yet the repeated map still exists.
If the shadowed repeated option was required, required validation can make the
invocation impossible because the same token can never populate its repeated
map.

The inverse single-to-repeatable override has the corresponding stale single
shape. Same-category overrides work because map construction replaces the
earlier value.

**Recommendation:** resolve name overrides across the complete option list
before splitting it into single and repeatable maps. Add root/group/local tests
for both cardinality transitions and required shadowed options.

### INC-003: RegistryMap does not enforce all live reserved-name rules

**Severity: Medium**

The map validator now checks names, aliases, short-alias collisions, defaults,
command keys, option groups, and repetition metadata. It still does not mirror
several live rules:

- `help` is not reserved for flags, options, or accessors.
- `h` is not reserved as a short alias.
- Short-description emptiness and the 150-character boundary are not checked.
- The live/map collision policies differ as described in INC-001.

A manually supplied `RegistryMap` can therefore represent a command surface
that cannot be constructed through `CommandRegistry`, despite documentation
describing the map as the canonical serialized form.

**Recommendation:** extract shared definition validators or define one schema
model used by both live registration and deserialization.

### INC-004: Live definition collections remain externally mutable

**Severity: High**

`RegistryMap` is deeply frozen, and `PairedOptions`, `AccessorListOption`, and
default command paths defensively copy their lists. Most other authoring lists
are retained directly: command aliases and input collections, group/executor
command lists, and every choice input's `choices` list.

Registry construction snapshots some structures into maps while retaining
references to other objects. The executor separately retains the original
command list. Mutating caller-owned lists after executor creation can therefore
split the framework into different views:

- The parser registry can know a command that `_commandsForPath()` no longer
  finds, or vice versa.
- Alias lookup can retain a pre-mutation index while exported alias metadata
  observes a changed list.
- A mutated choice list can change runtime parsing while the already frozen
  completion `RegistryMap` retains the old choices.

**Recommendation:** defensively copy all definition collections at their
ownership boundary, including aliases, commands, input lists, and choice lists.
Document executor definitions as immutable after construction even with those
copies.

## Command and help inconsistencies

### INC-005: Group defaults redirect explicit group help

**Severity: High**

The executor applies root and group default paths before calling the parser.
Help selection now belongs to the parser. For a group whose default child is
`serve`:

```text
tool group --help
```

is rewritten to:

```text
tool group serve --help
```

The parser then returns help for `serve`, even though the user explicitly
named `group`. Root help avoids this because root default insertion stops when
the first token is `--help`; group insertion has no equivalent help guard.

**Recommendation:** resolve exact help tokens before inserting group defaults,
or make group-default insertion stop at help and retain the explicitly selected
registry.

### INC-006: Help detection ignores option-token ownership

**Severity: Medium**

`_findCommand()` correctly skips a registered option and its following value.
`_requestsHelp()` then independently scans every raw token before `--`. Thus:

```text
--pattern --help
```

returns `ParsedHelp` even when `--help` is a regex-approved value for
`--pattern`. The same parser deliberately accepts other dash-prefixed values in
that position. Inline `--pattern=--help` does not trigger help, so equivalent
values behave differently by syntax form.

**Recommendation:** identify help while walking token ownership, not through a
second raw scan. Treat a token consumed by a value-taking option as data.

### INC-007: Deep command-not-found errors omit the full parent path

**Severity: Low**

`MambaCommandNotFoundException` accepts a `List<String> parentPath`, but parser
and registry callers pass only `[registry.name]`. At depth three, the message
reports the immediate group rather than `root parent group`.

**Recommendation:** derive the full path from registry parents so diagnostics
identify the exact location of the failed lookup.

## Flag inconsistencies

### INC-008: Negatable spellings are absent from collision validation

**Severity: High**

A negatable `BooleanFlag('color')` synthesizes `--no-color`, but the registry
reserves only the declared name `color`. It permits another flag, option, or
pair member named `no-color`.

The parser checks long options before flags and direct flag names before
synthesized negation. Depending on the colliding entity, `--no-color` may:

- Parse the explicitly declared `no-color` flag
- Require a value for an option named `no-color`
- Never reach the negation of `color`

Help and Carapace can advertise both meanings for the same spelling.

**Recommendation:** treat every synthesized `no-<name>` as part of the command
token namespace and reject collisions at registry and `RegistryMap` validation
time.

### INC-009: Pair options can claim the reserved `-h` alias

**Severity: High**

`_validateNamedInputs()` reserves short `h` only when the input is `Flag` or
`Option`. `PairOption` is a separate hierarchy, so a pair member with
`short: 'h'` passes registry validation.

The parser recognizes exact `-h` as help before option parsing. The paired
option's short form is therefore unreachable, even though help and Carapace
render it.

**Recommendation:** include `PairOption` in the reserved-short check and mirror
the rule in `RegistryMap`.

## Option and argument inconsistencies

### INC-010: A default can make an optional all-of pair mandatory

**Severity: Medium**

Pair choice defaults are inserted before all-of validation. Consider an
optional group containing one defaulted choice member and one non-defaulted
string member. With no user input, the default creates one effective member;
all-of validation then rejects the missing string member.

The group is declared `required: false`, but it can no longer be omitted. Tests
cover all members defaulted and explicit members completed by defaults, not
this mixed-default empty invocation.

**Recommendation:** for an optional all-of group with no explicit member,
either suppress all group defaults or require every member to have a default
before activating the group.

### INC-011: Broad string regexes can consume registered input tokens

**Severity: Medium**

To support values beginning with a dash, `_takeOptionValue()` accepts the next
dash-prefixed token whenever a string regex matches it. A broad regex such as
`\S+` therefore makes this invocation consume `--verbose` as data:

```text
--pattern --verbose
```

The registered flag is silently bypassed. Inline syntax is unambiguous, but
the parser does not require it.

**Recommendation:** prioritize exact registered input tokens and require
`--pattern=--verbose` when the intended value looks like another input.

### INC-012: Numeric errors describe only spaces, not the actual grammar

**Severity: Low**

Integer and double failures say the value “must not contain spaces,” but the
same message is used for letters, `.5`, `1.`, exponent notation, or other
grammar violations. Mandatory positional validation likewise reports a value
as “required” even when a value was supplied but failed validation.

**Recommendation:** distinguish missing input from invalid input and describe
the accepted numeric form rather than one possible invalid feature.

## Hook and execution inconsistencies

### INC-013: MambaExecutionError drops and reorders cleanup failures

**Severity: High**

`MambaExecutionError` documents that cleanup failures are retained in cleanup
order. The executor stores:

- Every cleanup `Exception` in a list
- Only the first cleanup `Error`
- Only the first arbitrary cleanup object

It then builds `cleanupFailures` as all exceptions, followed by the stored
`Error`, followed by the stored arbitrary object. This loses later
non-`Exception` failures and changes order whenever categories are interleaved.

For example, cleanup outcomes `StateError`, `Exception`, `StateError` become
`Exception, first StateError`; the second `StateError` disappears.

**Recommendation:** collect every cleanup failure immediately into one
`List<Object>` in callback order. Decide recoverability after the complete
ordered list has been built.

### INC-014: Closed-stdin handling depends on one message string

**Severity: Medium**

`_readStandardInput()` treats `FileSystemException` as an absent pipe only when
`error.message == 'Socket is closed'`. Message text can vary by platform,
runtime version, wrapping, or localization. Equivalent closed-pipe failures
with different text become execution failures.

There is no test for this branch in `test/`.

**Recommendation:** use an error code or structural condition when available,
or isolate the platform-specific predicate and cover accepted closed-pipe
variants with tests.

## Integration inconsistencies

### INC-015: Required variants remain optional in Carapace

**Severity: Medium**

Mamba requires exactly one member of a required variant pair. The converter
emits optional member flags plus `exclusiveflags`, which preserves only “at
most one.” The source comment explicitly acknowledges that Carapace cannot
express the at-least-one constraint.

This is now documented rather than accidental, but generated completion still
describes a weaker command surface than the parser enforces.

**Recommendation:** expose this as converter capability metadata or emit a
clear generated-spec comment/description so integration consumers know that
runtime validation remains authoritative.

### INC-016: Numeric completion ranges are arbitrary suggestions

**Severity: Low**

The parser accepts signed, unbounded integer and fixed-point values. Carapace
suggests only `-10..10`, and double suggestions use two decimal places. These
are explicitly described in code as illustrative, but the declaration model
contains no range or precision metadata supporting those choices.

**Recommendation:** add author-supplied completion-range metadata or omit the
range when no domain is declared.

### INC-017: Regex metadata has no completion effect

**Severity: Low**

Registry export preserves regex patterns for strings, positionals, variadics,
and accessor strings. The Carapace converter does not use them. This avoids
guessing incorrectly, but it means the serialized constraint cannot guide
completion.

**Recommendation:** add explicit completion providers instead of trying to
infer semantic values from arbitrary regexes.

### INC-018: Legacy accessor conversion branches are unreachable

**Severity: Low**

`RegistryMap` now rejects legacy description-only accessor maps, and every
`CarapaceSpecConverter` must receive a `RegistryMap`. `_accessorLeaves()` still
contains branches for primitive legacy leaves, legacy `options` maps, and
description-only values. Those paths cannot be reached through the public
converter contract.

**Recommendation:** remove the dead compatibility branches or move legacy
migration before canonical `RegistryMap` validation.

## Documentation and guideline warnings

The project-specific instructions require reviews to call out code that does
not follow the supplied guidelines.

- The guidelines prefer errors as explicit return values. Parsing, registry
  setup, formatting, integration writing, and non-recoverable execution still
  use thrown values. `ParseOutcome` and fake execution move part of the API
  toward explicit results, but the error model remains mixed.
- The guidelines say errors should be logged for monitoring/history. The
  framework has no logging callback, and INC-013 can discard failures entirely.
- `RegistryMapProps` documentation still says malformed nested data is
  preserved in an `ArgumentError`; the implementation throws
  `MambaIntegrationException`.
- `PairStringOption` still has the same documentation comment twice.
- The `PairOption` comment says members inherit behavior from a “primary
  option,” while the current API has a standalone group and no primary member.

Static analysis itself is clean: `dart analyze lib test` reports no issues.

## Current test-coverage gaps

The most consequential untested boundaries are:

- A positional sharing a name with a flag, option, or accessor through full
  executor construction
- Single-to-repeatable and repeatable-to-single option overrides
- Required shadowed options across cardinality changes
- `group --help` when the group has a default descendant
- An option consuming exact `--help` as its separate value
- Collisions with synthesized `--no-*` spellings
- A paired option using short alias `h`
- An omitted optional all-of pair with mixed defaulted/non-defaulted members
- Multiple cleanup `Error` values and mixed-category cleanup order
- Closed inherited stdin behavior
- Full parent paths in nested command-not-found messages
- Reserved help names in manually constructed `RegistryMap` values
- Mutation of command, alias, input, and choice lists after executor creation

## Resolved findings from the previous report

The current code fixes most findings from the earlier assessment:

- Construction-time registry failure is explicitly documented on `fake()` and
  `create()`.
- Root-to-leaf inherited ordering now lets nearer same-category options win.
- Descendants cannot override published global flag names or aliases.
- Name-validation messages match the implemented grammar.
- Empty choice sets are rejected.
- Required choice inputs cannot declare defaults.
- Variant defaults are suppressed when another variant member is explicit.
- Optional all-of defaults can complete explicit members.
- Command-not-found sentence spacing is fixed.
- Help is a parser-owned sealed outcome and is not valid in short bundles.
- Long and short option lookup no longer accepts crossed dash forms.
- `ChoiceVariadic` is single-valued; `RepeatedChoiceVariadic` is unbounded.
- `RegistryMap` recursively copies and freezes nested data.
- Registry-map validation now covers command keys, aliases, choice/default
  relationships, option-group membership, and repetition metadata.
- Hook option documentation includes single-valued paired members.
- Negatable boolean forms are emitted to Carapace.
- Legacy accessor maps are explicitly rejected.

Required Carapace variants, numeric suggestions, regex completion metadata,
dash-prefixed string ambiguity, and the duplicated pair comment remain active
and are therefore listed above rather than treated as resolved.
