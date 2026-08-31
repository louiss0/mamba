# Mamba CLI Framework Architecture Report

This report is based exclusively on the implementation in `lib/` and the
behavior specified in `test/`. The README, package metadata, executables, and
other project folders were not used to infer framework behavior.

The current verification baseline is:

- `dart test`: 494 tests passed.
- `dart analyze lib test`: no issues found.

## Executive summary

Mamba is a declarative Dart CLI framework with a clear definition-to-execution
pipeline:

```text
Command objects
    -> CommandRegistry validation and indexing
    -> optional RegistryMap serialization
    -> Parser token classification and typed values
    -> Executor command selection and hook lifecycle
    -> output, help, or a typed failure result
```

Its central architectural boundary is `CommandRegistry`. Command objects are
the authoring model, while a registry is the validated and indexed runtime
model. The parser consumes a selected registry and returns one typed record
containing the canonical command path, parsed values, trailing arguments, and
a named `help` state. The executor uses that state to choose help formatting or
command dispatch.
Help and Carapace completion output are also derived from registry metadata.

The current version uses a typed parser record, deep-frozen registry maps,
strict long/short option lookup, immutable definition collections, bounded
numeric options, and separate execution aggregates for recoverable exceptions
and non-recoverable errors. Pre-hooks are asynchronous, cleanup is attempted
for every successfully entered hook, and output is delayed until cleanup
completes.

## Architecture

### Public API and module boundaries

[`lib/mamba.dart`](lib/mamba.dart) is the package barrel. It exports the
definition model, context, errors, executor, help formatter, integrations,
parser, and registry.

The implementation is organized by responsibility:

| File | Architectural role |
| --- | --- |
| `lib/command.dart` | Command and input definitions, parsed record types, `RegistryMap`, completion commands, stdin wrappers, and hook contracts |
| `lib/registry.dart` | Definition validation, name indexing, inheritance, command discovery helpers, and registry serialization |
| `lib/parser.dart` | Token classification, typed conversion, defaults, requiredness, pairs, positionals, accessors, and variadics |
| `lib/executor.dart` | Composition root, defaults, help routing, command lookup, hooks, output, and failure normalization |
| `lib/help_formatter.dart` | Styled help grammar and the default ANSI formatter |
| `lib/context.dart` | Typed executor-scoped mutable context and its read-only view |
| `lib/errors.dart` | Registry, execution, integration, and general framework failures |
| `lib/integrations.dart` | `RegistryMap` converters and Carapace spec writing |

### Definition model

[`lib/command.dart`](lib/command.dart) is the framework vocabulary. Its sealed
input hierarchies make invalid runtime type combinations difficult to express:

- `Flag` divides into `BooleanFlag` and `CountFlag`.
- `Option` divides into single and repeatable typed options.
- `PairOption` models values owned by a `PairedOptions` group.
- `AccessorOption` divides into nested lists and primitive leaves.
- `Positional` includes normal, choice, and bounded repeated forms.
- `Variadic` owns values following `--`.

Regex-backed definitions expose `RegExpValidated`; enum-backed definitions
expose `ChoiceValidated<T>`. Parsing stores enum choices by their `.name`, not
as enum instances. Integer and double option definitions expose optional
inclusive bounds through `NumericRangeValidated<T>`. Choice values and fully
bounded numeric ranges are the completion domains exported to integrations;
regex patterns remain runtime validation rules rather than inferred
completion domains.

Definitions are mostly passive values. Public authoring collections are copied
into unmodifiable lists at command, group, executor, pair, accessor, and choice
boundaries. Validation is intentionally deferred to registry construction,
except for a few local invariants such as a negative
repeated-positional count or an invalid default-command path.

### Registry construction and validation

[`lib/registry.dart`](lib/registry.dart) converts the root surface and every
child `Command` into `CommandRegistry` nodes. A node stores local declarations
in name-indexed maps and links to its parent and children.

Registry construction validates:

- Command, alias, input, positional, variadic, and accessor names
- Short aliases
- Empty and overlong descriptions
- Reserved `help` and `-h` declarations
- Duplicate commands, aliases, input names, and short aliases
- Flag/option/accessor collisions
- Positional collisions and positional/command collisions
- Empty paired groups and duplicate pair members
- Empty choice sets and defaults that are not registered enum choices
- Required choice inputs that declare defaults
- Numeric ranges whose minimum exceeds their maximum
- Descendant attempts to override published global flags
- Collisions with synthesized `--no-*` flag spellings
- Nested accessor definitions recursively

The shared long-name grammar is letter-led words separated by hyphens or
underscores. Digits are rejected.

The registry keeps locally declared inputs separate from published inputs:

- Root flags and options are published globally.
- A `GroupCommand` may publish `inheritedFlags` and `inheritedOptions` to its
  descendants.
- Positionals, variadics, accessors, paired groups, and ordinary group-local
  inputs are not inherited.
- `withInheritedInputs()` materializes inherited flags and options into a copy
  used by parsing and help formatting.

Local options override same-named inherited options. Published flags are
immutable at descendant levels: a group or leaf may not redeclare a published
global flag name; short-alias collisions are rejected as well.

### Serialized registry boundary

`CommandRegistry.toMap()` exports a command tree containing:

- Names, combined descriptions, aliases, and descendants
- Boolean/count flags and local/persistent distinction
- Typed ordinary and repeatable options
- Paired group mode, requiredness, and members
- Required/discretionary and repeated positional metadata
- Variadic metadata
- Recursive typed accessors
- Choices, defaults, hidden state, short aliases, and regex patterns where
  applicable
- The built-in help flag

`RegistryMap` validates this structure recursively. Invalid map data throws
`MambaIntegrationException` with a dotted property path such as
`commands.publish.options.format.valueType` and includes the rejected value.

The map is the integration boundary: converters do not need to retain live
command instances. Construction recursively copies and freezes every nested
map and list. It validates names, descriptions, aliases, reserved help names,
negated flag spellings, collisions, defaults, option groups, and repetition
metadata. It also synthesizes canonical built-in help metadata when a manual
map omits it and rejects attempts to redefine that behavior.

### Parsing pipeline

[`lib/parser.dart`](lib/parser.dart) performs these stages:

1. Discover the canonical command path, resolving aliases and continuing past
   a registered help flag so help can target a later command.
2. Determine the raw token indexes occupied by command names.
3. Select the deepest command registry and materialize inherited inputs.
4. Parse long inputs, short inputs, flags, options, accessors, and ordinary
   positional tokens.
5. Stop ordinary parsing at `--` and preserve every later token.
6. Stop token parsing once the global help flag is observed.
7. Add boolean and count defaults.
8. For non-help invocations, add choice defaults, validate paired and required
   options, allocate positionals, and validate the registered variadic.
9. Remove the internal help flag from user-visible boolean inputs and return
   its state in the record's named `help` field.

`Parser.parse()` returns `ParsedArguments`:

```dart
(
  List<String> command,
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
  {bool help},
)
```

Help is the registry's built-in global boolean flag, so `--help`, `-h`, and
valid short bundles containing `h` set `help: true`. Tokens after help are not
parsed as inputs, but command discovery continues so `--help deploy` can select
`deploy`. Direct parsing of an empty list returns `help: false`; the executor
formats root help when parsing selects no command. The executor applies
configured default commands before invoking the parser.

The command path always uses canonical command names. Named inputs are split
into maps by concrete value shape: booleans, counts, strings, integers,
doubles, repeated typed lists, and nested accessor values. Positionals are
split into single, repeated, and variadic maps.

### Execution pipeline

[`lib/executor.dart`](lib/executor.dart) is the application composition root.
`Executor` owns root metadata, root inputs, commands, an optional context,
default command path, and help formatter.

Creating a concrete executor builds and validates the registry, creates one
validated `RegistryMap`, and assigns that complete root map recursively to all
`CompletionCommand` instances.

Two environments share the same private orchestration:

- `fake()` returns `MambaSuccessResult` or `MambaFailureResult` and is intended
  for tests.
- `create()` writes successful output to stdout, failures to stderr, and sets
  process exit code `1`.

Execution preserves the explicitly named path when help is present; otherwise
it applies root and nested group default command paths before parsing. A true
`help` field or an absent selected command formats the selected registry;
otherwise the command runs hooks and `run()`, performs cleanup, and only then
emits the final result.

The executor automatically adds:

- `--dry-run`, a boolean flag defaulting to `false`
- `--verbose` / `-v`, a count flag defaulting to `0`

The registry adds `--help` / `-h` separately.

### Help formatting

[`lib/help_formatter.dart`](lib/help_formatter.dart) defines the customization
boundary through `HelpFormatter` and provides `MambaHelpFormatter` as the
default ANSI-styled implementation.

The default formatter renders:

- A command usage line and short description
- An optional long-description block
- Flags
- Accessor flags
- Options, including paired expressions
- Child commands

Empty sections are omitted. Hidden flags, options, and accessor subtrees remain
parseable but do not appear. Mandatory expressions use angle brackets,
optional expressions use square brackets, pairs use `&`, variants use `|`,
and repeated positionals render a bounded `{1,n}` range.

The formatted-string wrappers reject unstyled strings and invalid delimiter
content with `FormatException`. These are formatter-programming failures, not
invocation failures.

### Context and standard input

[`lib/context.dart`](lib/context.dart) uses identity-based
`MambaContextKey<T>` objects. Two keys with the same generic type are still
independent.

- `MambaContext` permits typed `set()` and `get()` operations.
- `MambaReadContext` exposes only `get()`.
- Context is executor-scoped and intentionally survives multiple `execute()`
  calls on the same executor.

`ProcessedStandardInput` stores raw bytes and exposes character-code text,
UTF-8 text, and decoded JSON. Malformed JSON propagates `FormatException`.
Standard input is read only when the selected command uses `HookRunner` and
stdin is a pipe. Closed inherited pipes are recognized through common POSIX
and Windows error codes and known closed/broken-pipe messages; other stdin
filesystem failures propagate into the execution error boundary.

### Error boundary

The error hierarchy has six principal roles:

- `MambaRegistryError extends ArgumentError` reports invalid definitions.
- `MambaException implements Exception` is the recoverable framework base.
- `MambaParseException` and `MambaCommandNotFoundException` report invalid
  invocations and command selection.
- `MambaIntegrationException` reports invalid or unwritable integration
  artifacts.
- `MambaExecutionException` combines ordinary execution and cleanup
  exceptions.
- `MambaExecutionError extends Error` reports execution paths containing an
  `Error` or arbitrary thrown object.

Registry construction occurs while `fake()` or `create()` builds the private
executor, so definition errors are thrown before `execute()` can return a
failure result.

During execution, ordinary `Exception` values become failure output. Existing
`MambaException` values are preserved; other exceptions are wrapped in
`MambaException`. Dart `Error` values and arbitrary thrown objects remain
outside the recoverable result contract. After cleanup, they are rethrown as
`MambaExecutionError`, which contains the primary failure and every cleanup
failure in callback order.

## Commands

### Command types and behavior

`Command` is the executable leaf abstraction. A subclass supplies `name`,
`shortDescription`, optional metadata and inputs, and:

```dart
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
)
```

A `null` result suppresses output.

`GroupCommand` owns child commands, inherited inputs, and an optional relative
default path. Its `runChildCommand()` accepts canonical names or aliases and
can descend through nested groups. Calling a group without a default returns
an empty string.

`CompletionCommand` is a command specialization whose `registryMap` is filled
by the executor before invocation. Nested completion commands receive the same
complete root map as top-level completion commands.

### Discovery, aliases, and defaults

Aliases are scoped to siblings, validated for collisions, and canonicalized by
the parser. Unknown child tokens become `MambaCommandNotFoundException` when
the current command has children but no positional declaration that could
legitimately consume the token.

The executor supports a root-relative `defaultCommandPath`; each group supports
a relative `defaultSubCommandPath`. Default segments are inserted around
registered value-taking inputs so an option value is not mistaken for a
command. Group defaults are applied repeatedly down the selected group path,
with a set preventing the same group default from being inserted twice.
Explicit help suppresses default insertion and therefore targets the root or
group path named by the user.

### Command errors

Definition and construction failures include:

- `MambaRegistryError` for an invalid name, alias, short description, duplicate
  sibling, collision, reserved help name, or invalid default path
- `MambaRegistryError.value` for empty, parent-qualified, or empty-segment
  default paths

Direct group execution can throw:

- `ArgumentError` when the runtime path is empty
- `ArgumentError.value` when the path contains the current group name instead
  of being relative
- `MambaException` when a named descendant cannot be found

Normal parsing can throw `MambaCommandNotFoundException`, whose message includes
the complete parent path and available children. An exception from `run()`
becomes a failure result; a non-Exception failure is rethrown as
`MambaExecutionError` after cleanup with all diagnostics preserved.

## Flags

### Boolean flags

`BooleanFlag` supports long syntax, a one-letter short alias, short bundles,
hidden help state, a boolean default, and optional negation:

```text
--color
-c
-abc
--no-color
```

Every user-defined boolean flag appears in the parsed boolean map, even when it
is omitted. The stored value is its declared default, normally `false`. The
built-in help flag is removed before `ParsedNamedInputs` is returned.

### Count flags

`CountFlag` increments for each occurrence, including bundled short forms:

```text
-vv
--verbose --verbose
```

Every registered count flag also appears when omitted, with value `0`.

### Built-in help and scope

`--help` and `-h` belong to a built-in global `BooleanFlag`. The short form is
valid in bundles such as `-hv`. Help after `--` is a trailing value. Once help
is parsed, later named inputs are ignored, requiredness and positional
validation are skipped, and the flag is removed from `ParsedNamedInputs`.

Root flags are global and group `inheritedFlags` apply to descendants. Neither
may be redeclared by descendants; ordinary group and leaf flags are otherwise
local. Help receives a registry copy with inherited inputs materialized.

### Flag errors

Definition-time failures use `MambaRegistryError` for:

- A long name outside the shared letter-led word grammar
- A non-letter or multi-character short alias
- Redeclaring `help` or `-h`
- Duplicate names or short aliases
- Collisions with options or top-level accessors

Parse-time failures use `MambaParseException`:

- `Flag --name does not accept a value` for `--flag=value`
- `Unknown flag or option --name.` for an unknown long input
- `This isn't a registered flag` for invalid negation
- `This isn't a registered short flag or option` for an unknown short bundle
  member

A direct `Parser` consumer checks the returned record's named `help` field. The
parser itself does not format help.

## Options

### Ordinary and repeatable options

Mamba defines:

- `StringOption`, with a full-token regex
- `IntOption`, accepting signed decimal integers and optional inclusive bounds
- `DoubleOption`, accepting signed integer or fixed-point decimal text and
  optional inclusive bounds
- `ChoiceOption<T>`, accepting an enum member name
- Repeatable string, integer, and double options

Accepted advertised syntax is:

```text
--name value
--name=value
-n value
```

Repeatable options append values to typed lists. Supplying a single option more
than once replaces its prior value. Choice values are stored in the string map.

Signed numeric values are accepted as separate tokens. Doubles require digits
on both sides of a decimal point when a point is present; `.5`, `1.`, and
scientific notation are rejected. Registry construction rejects an inverted
numeric range.

Regex-backed string options may consume a dash-prefixed following token when
their regex accepts it, but an exact registered input token retains its input
meaning. Inline syntax is required when a value intentionally looks like a
registered flag or option.

### Paired options

`PairedOptions` owns one or more `PairOption` members. Pair members can be
string, integer, double, choice, or repeatable typed values.

An all-of group behaves as a unit:

- An optional group with no effective values may be entirely absent.
- Once one explicit member is supplied, all members must be supplied.
- A required group requires every member explicitly.

A variant group represents alternatives:

- An optional group accepts zero or one explicit member.
- A required group requires exactly one explicit member.

Pair members do not support defaults. Consequently, an omitted optional pair
group stays absent, a partially supplied all-of group fails, and required
all-of or variant groups always require explicit user input.

### Accessor options

Accessor lists model nested long-only paths:

```text
--server.tls.certificate cert.pem
```

Leaves can be string, integer, double, or enum choice values. Repeated writes
merge into nested maps, and a later write replaces only the matching leaf.
Choice defaults are recursively merged without replacing explicit sibling
values. Hiding an accessor list hides its complete subtree from help and
Carapace display while preserving parseability.

### Defaults and requiredness

The parser applies defaults for:

- Boolean and count flags
- Ordinary choice options
- Single and repeated choice positionals
- Choice variadics
- Nested accessor choices

Required choice options and mandatory choice positionals cannot declare
defaults, so `required` consistently means explicit user input. Supported
optional ordinary, positional, variadic, and accessor choices receive their
configured defaults before final validation.

### Option errors

Option syntax and conversion failures are `MambaParseException`:

- Missing value: `Option --name requires a value`
- Regex rejection: `Option --name does not accept 'value'.`
- Invalid choice: `value is not a valid choice for name` plus available names
- Invalid integer: `Invalid int value: value must be a signed decimal integer`
- Invalid double: `Invalid double value: value must be a signed decimal number`
- Out-of-range number:
  `Option --name must be at least min and at most max (received value).`
- Required omission: `Option --name is required.`
- Unknown dotted path: `This isn't a registered accessor`

Pair failures are:

- `Required paired options are missing: ...`
- `Paired options ... must be passed together`
- `One variant option is required: ...`
- `Variant options ... accept only one option`

Definition-time option failures are `MambaRegistryError` and cover invalid
names/aliases, duplicates, empty choice or pair groups, required choices with
defaults, reserved help spellings, synthesized negation collisions, and other
name or short-alias collisions. Pair choices expose no default API.

## Arguments

### Mandatory and discretionary positionals

Positionals are registered in ordered mandatory and discretionary lists.
Mandatory values are allocated first; discretionary values follow. A normal
positional validates its complete token with a regex, while a choice positional
accepts enum member names.

Optional choice positionals can declare defaults. Mandatory choice positionals
must be supplied explicitly and cannot declare defaults.

### Repeated positionals

`RepeatedStringPositional` and `RepeatedChoicePositional` collect bounded lists.
The `times` property means additional repetitions, so `times: 1` accepts one or
two total values. Negative counts fail immediately with
`MambaRegistryError.value`.

Allocation is registration-ordered and greedy, but a repeated mandatory
positional reserves enough values for later mandatory positionals. It does not
reserve values for later discretionary entries, which may legitimately remain
absent.

### Trailing arguments and variadics

`--` terminates ordinary parsing. Every later token is returned unchanged in
`trailingArguments`. If a variadic is registered, the same values are also
validated and stored under its name in `positionals.variadic`.

`NormalVariadic` uses a regex. `ChoiceVariadic` accepts one enum-named
trailing value, while `RepeatedChoiceVariadic` accepts every enum-named
trailing value. A choice variadic default produces one parsed variadic value
when no trailing values are supplied.

Trailing values are legal without a variadic; they simply remain unnamed.

### Argument errors

Positional and variadic invocation failures are `MambaParseException`:

- Missing mandatory positional, or an invalid first value for a mandatory
  repeated positional:
  `The name is required at index after this command`
- Invalid ordinary mandatory or discretionary positional:
  `Invalid value for positional name at index after the command`
- Excess ordinary positional:
  `This term isn't a registered command positional`
- Invalid variadic value:
  `The term at index N isn't accepted by the name variadic`
- More than one value for a single-valued `ChoiceVariadic`:
  `The name variadic accepts only one value.`

An explicitly supplied empty token is treated as a real value and validated;
it is no longer silently discarded.

## Hooks

Mamba provides two independent hook contracts.

`HookRunner` wraps only the final selected command:

- `preRun()` may be synchronous or asynchronous.
- It receives piped stdin, a read-only context, parsed positionals, and the
  single-valued string/integer/double option maps.
- `postRun()` receives the same read-only context.

`PersistentHookRunner` is mixed into groups:

- Persistent pre-hooks run from the outermost selected group inward.
- They receive mutable executor context, parsed positionals, and the same
  single-valued option slice.
- Persistent post-hooks run in reverse order for every group whose pre-hook
  completed successfully.

The hook option slice includes single-valued paired members because those share
the ordinary string/integer/double maps. It excludes boolean flags, count
flags, repeatable options, and accessors. `Command.run()` receives the complete
parsed input record.

```mermaid
flowchart TD
    A["Executor receives arguments"] --> B["Apply root and group defaults"]
    B --> C{"Parsed record requests help or has no command?"}
    C -- Yes --> D["Format selected registry"]
    C -- No --> E["Run outer persistent pre-hook"]
    E --> F["Record successfully entered group"]
    F --> H["Run inner persistent pre-hooks in order"]
    H --> I{"Selected command uses HookRunner?"}
    I -- Yes --> J["Read piped stdin"]
    J --> K["Await command preRun"]
    K --> L["Record successfully entered command hook"]
    I -- No --> M["Run selected command"]
    L --> M
    M --> N["Capture output or primary failure"]
    D --> N
    N --> O{"Command hook entered?"}
    O -- Yes --> P["Attempt command postRun"]
    O -- No --> Q["Unwind entered persistent hooks"]
    P --> Q
    Q --> R["Attempt every post-hook, inner to outer"]
    R --> S{"Non-Exception failure captured?"}
    S -- Yes --> T["Throw MambaExecutionError"]
    S -- No --> U{"Cleanup exceptions captured?"}
    U -- Yes --> V["Return MambaExecutionException failure"]
    U -- No --> W{"Primary exception captured?"}
    W -- Yes --> X["Return normalized failure"]
    W -- No --> Y["Emit successful output"]
```

Important lifecycle properties:

- A post-hook is scheduled only after its matching pre-hook completes.
- Failure in one cleanup hook does not prevent later cleanup attempts.
- Ordinary cleanup exceptions are collected in order.
- If execution and cleanup both throw `Exception`,
  `MambaExecutionException.primaryFailure` preserves the execution failure and
  `cleanupFailures` preserves the cleanup exceptions in cleanup order.
- `Error` and arbitrary thrown objects remain non-recoverable but do not skip
  cleanup. `MambaExecutionError` retains the primary failure and every cleanup
  failure in cleanup order.
- Output and failure writers run only after cleanup completes.
- Context mutations made by persistent hooks are visible to descendant hooks
  and commands and persist across executions of the same executor.

## Integrations

Integrations are intentionally last because they consume the framework model
rather than participate in parsing or execution.

### RegistryMap contract

`RegistryMapConverter` accepts a validated `RegistryMap` and returns an
integration-specific string artifact. This lets a completion command work from
serialized metadata without knowing the live command subclasses.

`RegistryMap` accepts only current canonical typed accessor data. It recursively
copies and freezes the validated map. Its failures use
`MambaIntegrationException` with full nested paths, and it validates structural
and semantic invariants including names, descriptions, aliases, help
reservations, negated spellings, collisions, choice defaults, option-group
membership, numeric ranges, local/persistent overrides, and repetition
metadata.

### Carapace conversion

`CarapaceSpecConverter` emits YAML for:

- Root and nested command names, descriptions, and aliases
- Local and persistent flags
- Boolean defaults and repeatable count flags
- Required, optional, repeatable, and hidden value-taking options
- Paired all-of and exclusive variant groups
- Positionals and bounded repeated positional slots
- Ordinary and repeated dash completions
- Typed dotted accessors
- Enum-choice and bounded numeric completion suggestions
- Built-in help

Root inputs become Carapace `persistentflags`. A group's published inputs are
emitted once at that group. Local declarations are removed from inherited
entries with the same name.

Choice completions use enum names. Regex-backed inputs do not imply filesystem
or domain completion. Numeric options emit a Carapace range only when both
inclusive bounds are present; unbounded and one-sided numeric inputs do not
invent limits. A normal choice variadic fills the first `dash` slot, while a
`RepeatedChoiceVariadic` uses `dashany` for every subsequent slot.

### Carapace writing and errors

`CarapaceSpecWriter` creates missing parent directories and writes
`<command>.yaml` below:

- Development: the system temporary directory
- Windows production: `%APPDATA%/carapace/specs`
- macOS production: `$HOME/Library/Application Support/carapace/specs`
- Other production platforms: `$XDG_CONFIG_HOME/carapace/specs`, falling back
  to `$HOME/.config/carapace/specs`
- An explicit `outputPath`, when supplied

Failure to locate a production configuration directory throws
`MambaIntegrationException`. Directory and file-write failures are caught and
translated into `MambaIntegrationException` containing the target path and the
filesystem message.

Carapace emits both spellings of a negatable boolean flag. It cannot express
the at-least-one constraint of a required variant group, so those members are
emitted as optional exclusive flags. Each member description states the exact
runtime requirement, and the CLI remains responsible for enforcement. Regex
patterns remain validation metadata rather than completion constraints.
