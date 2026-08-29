
# Mamba Framework Inconsistencies

This report is based exclusively on `lib/` and `test/`. It focuses on places
where the framework's public model, runtime behavior, error handling, help
output, tests, or serialized integration model disagree with one another.

## Severity guide

- **High**: can produce incorrect behavior, bypass the advertised failure
  boundary, or lose framework semantics.
- **Medium**: produces surprising or inconsistent public behavior that callers
  must work around.
- **Low**: primarily affects clarity, diagnostics, or maintainability.

## Summary

The most important inconsistencies are:

- The executor catches `Exception`, while registry failures use `Error` and
  post-hook failures occur outside the catch boundary.
- Several input classes expose defaults that the parser never applies.
- Accessor numeric declarations do not match the numeric parser used at
  runtime.
- Paired-option and accessor semantics were previously lost during registry
  export; INC-028 and INC-029 document the implemented resolution.
- Carapace numeric completions advertise a much narrower range than the parser
  accepts.
- Similar parse failures use different exception classes and substantially
  different message styles.

## Error model inconsistencies

### INC-001: Registry failures are outside the normal execution contract

**Severity: High**

`MambaRegistryError` extends `Error`, while recoverable framework failures
implement `Exception`. The executor catches only `Exception`.

Registry construction also happens in the private executor constructor, before
`execute()` begins. Therefore both `MambaRegistryError` and ordinary definition
exceptions can be thrown by `fake()` or `create()` instead of becoming a
`MambaFailureResult` or console failure.

This conflicts with the apparent abstraction that fake execution returns one
of the two `MambaExecutionResult` variants.

**Recommendation:** represent all definition failures with one documented
exception family, or make executor creation return an explicit result. If
registry errors are intentionally programmer errors, document that
`fake()`/`create()` may throw before execution.

### INC-002: Post-hook failures bypass executor failure handling

**Severity: High**

The main execution body is wrapped in `try`/`catch`, but ordinary and persistent
post-hooks run in `finally`. An exception from `postRun()` or
`postPersistentRun()` therefore escapes instead of being passed to `writeErr()`.

This means an exception from `run()` becomes `MambaFailureResult`, while an
exception from cleanup can reject the returned future directly.

**Recommendation:** place post-hook execution inside a dedicated error boundary
and define how command and cleanup failures are combined or prioritized.

### INC-003: Similar positional failures use different exception types

**Severity: Medium**

Invalid or missing mandatory positionals throw `MambaParseException`. An
invalid discretionary positional throws raw `ArgumentError`. Excess
positionals return to `MambaParseException` again.

Direct parser consumers must consequently catch multiple exception categories
for the same class of invalid invocation. Through the executor, the
`ArgumentError` is generically converted to `MambaException`, losing the
specific parse type.

**Recommendation:** make every invocation-shape failure a
`MambaParseException`.

### INC-004: Unknown commands do not consistently use the command-not-found
exception

**Severity: Medium**

`MambaCommandNotFoundException` is used by registry traversal, particularly
while resolving help. Normal parser execution can stop command discovery and
treat the unknown token as a positional instead. The resulting message may be
`This term isn't a registered command positional` rather than a command-not-
found message listing available commands.

**Recommendation:** let command discovery identify tokens that occur where only
a child command is valid and consistently throw `MambaCommandNotFoundException`.

### INC-005: `MambaRegistryError` has weaker formatting than exceptions

**Severity: Low**

`MambaException` overrides `toString()` to include its runtime type and message.
`MambaRegistryError` stores a message but does not override `toString()`.

**Recommendation:** give every public error type consistent string formatting.

## Command inconsistencies

### INC-006: Command and input naming rules disagree

**Severity: Medium**

Command names reject every digit, but named flags, options, positionals, and
accessors allow digits after the first letter. Commands also permit internal
underscores, while named inputs reject underscores and otherwise encourage
hyphenated names.

As a result, `release2` is a valid input name but not a valid command name, and
`release_build` can be a command but not an input.

**Recommendation:** define one token grammar for commands and long input names,
preferably letter-led kebab-case, unless the difference is intentional and
documented.

### INC-007: Direct group execution does not resolve aliases

**Severity: Medium**

The parser and registry resolve aliases to canonical command names.
`GroupCommand.runChildCommand()`, however, searches children only by
`candidate.name`. A path that works through the executor can therefore fail
when passed directly to the group API using an alias.

**Recommendation:** either resolve aliases in `runChildCommand()` or explicitly
state that its path must contain canonical names.

### INC-008: Description validation and its message describe different units

**Severity: Low**

The registry rejects a short description whose character length is at least
150, but the error says the description cannot exceed “150 lines of code.”

**Recommendation:** say that the description must contain fewer than 150
characters, or revise the validation to match the intended unit.

## Flag inconsistencies

### INC-009: Unknown options are reported as unknown flags

**Severity: Medium**

After failing to locate a long option or flag, the parser throws
`This isn't a registered flag`. An invocation such as `--missing value` cannot
tell the user whether an option or flag was expected.

The short-form error combines both concepts—`registered short flag or option`—
which is more accurate than the long-form message.

**Recommendation:** use “named input” for the shared failure or report the
specific token as an unknown option/flag.

### INC-010: Count flags and boolean flags have different omitted-value shapes

**Severity: Low**

Every registered boolean flag is placed in the parsed map using its default,
normally `false`. An unused count flag has no `0` entry and is absent from the
count map.

The distinction may be intentional, but it makes equivalent lookups asymmetric
for command authors.

**Recommendation:** document the asymmetry or populate count defaults with
zero.

## Option inconsistencies

### INC-011: Choice defaults are declared more broadly than they are applied

**Severity: High**

The following entities expose `defaultValue`:

- `ChoiceOption`
- `PairChoiceOption`
- `ChoicePositional`
- `RepeatedChoicePositional`
- `ChoiceVariadic`
- `AccessorChoiceOption`

The parser applies defaults only to ordinary `ChoiceOption` and nested
`AccessorChoiceOption`. Pair choices, positionals, repeated positionals, and
variadics serialize their defaults but do not use them during parsing.

This makes the same property name mean different things depending on the input
subtype.

**Recommendation:** either apply defaults consistently or remove
`defaultValue` from entities where omission should remain omission.

### INC-012: Accessor numeric declarations do not control runtime validation

**Severity: High**

`AccessorIntOption.regex` describes unsigned digits. `AccessorDoubleOption.regex`
describes an unsigned decimal containing a decimal point. Runtime parsing does
not use either getter: it dispatches to the general integer and double parsers.

Consequently, accessor parsing accepts signed integers, signed doubles, and
integer-shaped double values that the accessor's own regex does not describe.

**Recommendation:** use the accessor regex during parsing or remove the getters
and document that accessor numerics share ordinary option syntax.

### INC-013: Required-option messages vary by value type

**Severity: Low**

A missing required `StringOption` reports `The <name> is required`. Other
required option types report `Option --<name> is required`.

**Recommendation:** use one message template for every required option type.

### INC-014: Dash-prefixed string values depend on syntax form

**Severity: Medium**

When an option value is in the following token, any dash-prefixed value is
treated as another input unless it looks like a negative number. The same
string can be accepted with inline syntax:

```text
--pattern=-value
```

but rejected with separate syntax:

```text
--pattern -value
```

This is especially surprising for string options whose regex explicitly
accepts a leading dash.

**Recommendation:** support an escaping rule, use `--name=-value`, or let the
registered option type determine whether the next token can be consumed.

### INC-015: Regex failure messages omit the input name and rejected value

**Severity: Low**

Every regex-backed option failure reports only
`This value doesn't satify the requirement`. Besides the spelling error, the
message does not identify the option, value, or expected pattern.

**Recommendation:** include the option name and rejected value while avoiding
exposing an unreadable raw expression unless verbose diagnostics are enabled.

## Argument inconsistencies

### INC-016: `times` represents additional values rather than total values

**Severity: Medium**

A repeated positional with `times: 1` accepts two values: the original plus one
repetition. The property name can reasonably be read as either total
occurrences or repetitions, while help renders the computed total range.

**Recommendation:** rename it to `additionalValues`, replace it with
`maxValues`, or make the public documentation especially explicit.

### INC-017: Repeated positional parsing is greedy without backtracking

**Severity: Medium**

Repeated positionals consume as many matching values as allowed before later
positionals are considered. They do not reserve tokens for later mandatory
positionals and do not backtrack after a later failure.

The declared positional sequence can therefore be syntactically ambiguous even
when one allocation of the supplied tokens would satisfy all definitions.

**Recommendation:** reject ambiguous layouts during registry validation,
reserve the minimum number of tokens needed by later mandatory positionals, or
document strict greedy behavior.

### INC-018: Empty argument tokens are silently ignored

**Severity: Medium**

The parser skips `""` before positional collection. An explicitly supplied
empty argument is therefore indistinguishable from no argument for mandatory
positionals and cannot be accepted by a regex that permits an empty string.

**Recommendation:** treat empty strings as real positional values or reject them
with a targeted validation error.

### INC-019: Variadic defaults are serialized but omission returns `null`

**Severity: Medium**

`ChoiceVariadic.defaultValue` is exported in the registry map, but an invocation
without trailing arguments produces no variadic map. This is a specific example
of the broader choice-default inconsistency and can mislead integrations that
observe a default in metadata.

**Recommendation:** align serialized metadata with parser behavior.

## Hook and context inconsistencies

### INC-020: Post-hooks may run when their corresponding pre-hook did not
complete

**Severity: High**

The executor selects all persistent runners before calling any pre-hook. Its
`finally` block then calls every selected post-hook in reverse order. If an
outer persistent pre-hook throws, post-hooks for inner groups that were never
entered are still scheduled. An ordinary post-hook also runs if its own
`preRun()` throws.

This differs from conventional enter/exit or acquire/release lifecycle
semantics.

**Recommendation:** record each successfully entered hook and unwind only that
stack.

### INC-021: One post-hook failure prevents remaining cleanup

**Severity: High**

Persistent post-hooks are awaited sequentially. If an inner post-hook throws,
the remaining outer hooks do not run.

**Recommendation:** attempt every cleanup hook, collect failures, and report an
aggregate or primary-plus-suppressed error.

### INC-022: Output is emitted before cleanup completes

**Severity: Medium**

`writeOut()` or `writeErr()` is evaluated before entering `finally`. Production
stdout/stderr can therefore announce success or failure before post-hooks have
completed. A subsequent post-hook failure can make an already printed success
incorrect.

**Recommendation:** complete cleanup before emitting the final observable
result, or explicitly define post-hooks as non-transactional notifications.

### INC-023: Pre-hooks cannot be asynchronous, but post-hooks can

**Severity: Medium**

Both `preRun()` and `prePersistentRun()` return `void`. Their post-hook
counterparts return `FutureOr<void>` and are awaited. Async setup must therefore
be forced elsewhere even though async cleanup is supported.

**Recommendation:** make pre-hooks return `FutureOr<void>` and await them.

### INC-024: Context lifetime is broader than its documentation suggests

**Severity: Medium**

`MambaContext` is described as mutable global state shared during an execution,
but `_Executor` creates it once and reuses it across every call to `execute()`.
State can leak between invocations of the same fake or production executor.

**Recommendation:** clarify that the context is executor-scoped, or create a new
context per invocation while allowing an explicit application-scoped store.

## Help and documentation inconsistencies

### INC-025: Several public error messages contain spelling or wording defects

**Severity: Low**

Examples in parser and registry output include:

- `acessor`
- `satify`
- `postionals`
- `mesaage`
- `There should no spaces`
- `never have spaces in between numbers`

These are observable CLI messages rather than internal-only comments.

**Recommendation:** centralize message templates and add exact-message tests.

### INC-026: Public documentation overstates `RegistryMap` fidelity

**Severity: Medium**

The map and integration documentation imply that the serialized form carries
the input semantics needed to reproduce the command surface. Paired groups and
typed accessors are now retained, but regex constraints remain omitted.

**Recommendation:** either serialize the missing semantics or describe
`RegistryMap` as a completion-oriented approximation.

### INC-027: Duplicate and misleading comments reduce API clarity

**Severity: Low**

The `PairStringOption` documentation comment is duplicated. Some documentation
also describes parser failures uniformly as `MambaParseException` even though
the discretionary positional path throws `ArgumentError`.

**Recommendation:** remove the duplicate comment and make API documentation
match actual exception behavior.

## Test coverage inconsistencies

The existing tests are broad, especially around registry mapping, positional
layouts, inheritance, help output, and Carapace generation. The following
behavioral boundaries are not comparably covered:

- Nested persistent hook order beyond one group
- Pre-hook, command, and post-hook failure combinations
- Whether unentered hooks should receive post callbacks
- Context reuse across separate `execute()` calls
- Application of every declared choice default subtype
- Direct alias use through `GroupCommand.runChildCommand()`
- Accessor numeric regex behavior versus parser behavior
- Dash-prefixed separate string option values
- Presence or absence of built-in help in generated completion metadata

These gaps are important because several of the inconsistencies above occur
exactly at those untested boundaries.

## Integration inconsistencies

### INC-028: Paired-option relationships are lost during registry export

**Severity: High**

**Status: Resolved**

`CommandRegistry.toMap()` now emits first-class `optionGroups` records with
`mode`, `required`, and `members`. `RegistryMap` validates their shape,
membership, and uniqueness. The Carapace converter renders required all-member
groups and emits every variant member before adding `exclusiveflags`.

Live registry-to-converter round-trip tests cover required and variant groups.

### INC-029: Accessor value types and choices are lost during registry export

**Severity: High**

**Status: Resolved**

Accessor serialization now uses a uniform recursive group/value schema with
`valueType`, `choices`, `default`, descriptions, and hidden state. Carapace
flattens this tree into dotted flags and type-aware completion entries while
supporting legacy description-only accessor maps as string-valued inputs.

### INC-030: Carapace numeric completions disagree with parser ranges

**Severity: Medium**

The parser accepts signed integers and signed decimal values without a
`0..1000` bound. Carapace completion advertises only non-negative values from
`0` through `1000`. Double completion additionally formats values to two
decimal places, while the parser accepts integers and arbitrary decimal
precision.

**Recommendation:** either describe these as example completions rather than
constraints or generate completions that reflect the parser's actual numeric
domain.

### INC-031: String completion assumes filesystem semantics

**Severity: Medium**

Ordinary string options and non-choice positionals are exported as `$files`
completions regardless of their name or regex. A username, URL, query, token,
or other non-path string therefore receives file suggestions.

**Recommendation:** add explicit completion metadata to string inputs and omit
completions when no semantic source is declared.

### INC-032: Paired option completions are intentionally skipped

**Severity: Medium**

The converter deliberately avoids value completions for paired members. Even if
pair relationships are supplied manually, choice and type information for
those members does not result in the same completion behavior as ordinary
options.

**Recommendation:** generate member-specific completion entries after pair
metadata is preserved reliably.

### INC-033: Built-in help is absent from the exported registry map

**Severity: Low**

The help flag is stored separately from registered boolean and count flags.
`toMap()` exports the registered collections but not the built-in help flag.
Help output displays `--help`, while a map-derived integration does not receive
that declaration from Mamba.

**Recommendation:** include built-in inputs in the serialized command surface
or explicitly delegate help completion to the target integration.

### INC-034: Integration failures do not use the Mamba error hierarchy

**Severity: Medium**

`RegistryMap` validation throws `ArgumentError`, missing platform configuration
throws `StateError`, and filesystem operations can throw
`FileSystemException`. These failures are not translated into
`MambaException`, and completion generation commonly happens while the executor
is being constructed or from command code with different catch behavior.

**Recommendation:** define an integration-specific Mamba exception with clear
path and platform diagnostics, then consistently return or translate failures
at the integration boundary.
