# Command API

Use this reference when declaring commands or choosing an input type from
`package:mamba/command.dart`. It covers the public API; types whose names begin
with `_` are implementation details and must not be referenced.

## Parsed values

Keep each input declaration in a stable variable and pass that same instance
to the command constructor and to `ParsedInputs.valueOf`. Declarations are
identity-based typed keys.

```dart
static final output = StringOption.required('output');

@override
String run(ParsedInputs inputs, List<String> args) {
  final path = inputs.valueOf(output);
  return path;
}
```

- `ParsedInputs.valueOf<T>(ParsedValue<T>)` returns the typed parsed value.
- `ParsedInputs.contains(Object)` reports whether the invocation supplied or
  defaulted a value.
- `ParsedValue<T>` marks anything that can be used with `valueOf`.
- `InputDefinition` exposes the common `name` and `description` metadata.

## Flags

| API | Behavior |
| --- | --- |
| `BooleanFlag` | Boolean switch. Supports `defaultValue` and `negatable`. |
| `CountFlag` | Integer count incremented for each occurrence. |
| `MambaBuiltInFlags` | Declarations for `help`, `dryRun`, `verbose`, and `version`. |

Both flag types accept `name`, `short`, `description`, and `hidden`.

## Single options

Single options are optional by default. Every concrete type provides
`.required(...)` and `.withDefault(...)` factories.

| API | Value and validation |
| --- | --- |
| `StringOption` | `String`; optional full-token `regex`. |
| `IntOption` | `int`; optional `min` and `max`. |
| `DoubleOption` | `double`; optional `min`, `max`, and positive `step`. |
| `ChoiceOption<T extends Enum>` | One member of `choices`. |

All single options accept `name`, `short`, `description`, and `hidden`.
`DoubleOption.step` is enforced relative to `min`, so provide `min` when using
a step.

## Repeatable options

Repeatable options collect occurrences into immutable lists and are optional
by default. Every concrete type provides `.required(...)` and
`.withDefault(...)` factories.

| API | Value and validation |
| --- | --- |
| `RepeatableStringOption` | `List<String>`; optional full-token `regex`. |
| `RepeatableIntOption` | `List<int>`; optional `min` and `max`. |
| `RepeatableDoubleOption` | `List<double>`; optional `min`, `max`, and positive `step`. |
| `RepeatableChoiceOption<T extends Enum>` | `List<T>`; accepts `unique` to discard duplicate values. |

The choice list is the second positional constructor argument for
`RepeatableChoiceOption`; it is a named `choices` argument for
`ChoiceOption`.

## Positionals

Register required declarations in `mandatoryPositionals` and optional or
defaulted declarations in `discretionaryPositionals`.

| API | Direct constructor | Other factories |
| --- | --- | --- |
| `NormalPositional` | Required `String` | `.optional(...)` |
| `ChoicePositional<T extends Enum>` | Required enum choice | `.optional(...)`, `.withDefault(...)` |
| `RepeatedStringPositional` | Required `List<String>` | `.optional(...)` |
| `RepeatedChoicePositional<T extends Enum>` | Required `List<T>` | `.optional(...)`, `.withDefault(...)` |

String positionals accept `regExp`; choice positionals accept `choices`.
Repeated positionals accept from one value through the `times` maximum when
required, or from zero through `times` when optional. A defaulted repeated
choice uses its default list only when no value is supplied.

The public positional hierarchy—`Positional`, `MandatoryPositional`,
`DiscretionaryPositional`, `OptionalPositional`, `DefaultedPositional`, and
`RepeatedPositional`—and `RepeatedPositionalDefinition` are primarily useful
for command field types, capability checks, and factory return values.
Instantiate the concrete types above.

## Values after `--`

Set one declaration on `Command.variadic`:

- `NormalVariadic` accepts any number of values matching `regExp`.
- `ChoiceVariadic<T extends Enum>` accepts at most one supplied enum choice.
  Its optional `defaultValue` is exported through registry integrations; it is
  not inserted into the raw `args` passed to `run`.

The parser validates values after `--`, then passes their original strings to
`Command.run` as `args`. They are not stored in `ParsedInputs`.

## Paired options

`PairedOptions<T>` groups members that must be supplied together. The default
constructor allows all members to be omitted; `PairedOptions<T>.required`
requires all members. The parsed value is an immutable `Map<String, T>` keyed
by member name.

Choose members from:

- `PairStringOption`, with optional `regex`;
- `PairIntOption`, with optional `min` and `max`;
- `PairDoubleOption`, with optional `min`, `max`, and `step`;
- `PairChoiceOption<T extends Enum>`, with `choices`;
- `RepeatablePairStringOption`;
- `RepeatablePairIntOption`; and
- `RepeatablePairDoubleOption`.

Pair members accept `name`, `short`, and `description`. Register the group in
`Command.pairedOptions`, retain the `PairedOptions` instance, and read the map
with `inputs.valueOf(group)`.

`PairOption`, `RepeatablePairOption`, and `PairedOptionsDefinition` are the
public base types used by these declarations.

## Selected options

`SelectedOptions<T>` maps whichever pair-style members were supplied to an
immutable `Map<String, T>`:

- `SelectedOptions<T>(members)` permits zero or more selections.
- `SelectedOptions<T>.required(members)` requires at least one selection.
- `SelectedOptions<T>.single(members)` permits zero or one selection.

Use the same `Pair*Option` and `RepeatablePair*Option` members supported by
`PairedOptions`. Register the group in `Command.selectedOptionses` and read it
using the retained group instance.

## Nested accessor options

`AccessorListOption` groups nested dotted options into an immutable map. It
may contain other `AccessorListOption` groups or these leaf declarations:

| API | Value |
| --- | --- |
| `AccessorStringOption` | Optional `String`; accepts `regex`. |
| `AccessorIntOption` | Optional `int`. |
| `AccessorDoubleOption` | Optional `double`. |
| `AccessorChoiceOption<T extends Enum>` | Optional enum member from `choices`. |

Every leaf type provides `.required(...)` and `.withDefault(...)`. Accessor
leaves accept `name` and `description`; they do not have short aliases.
`AccessorListOption` also accepts `hidden`. Integer and double accessor leaves
do not expose range or step constructor arguments.

```dart
static final server = AccessorListOption('server', [
  AccessorStringOption.required('host'),
  AccessorIntOption.withDefault('port', defaultValue: 443),
]);

// Parses --server.host example.com --server.port 8443.
final values = inputs.valueOf(server);
```

Register root groups in `Command.accessors`. `AccessorOption`,
`AccessorPrimitiveOption`, `RequiredAccessorOption`, and
`DefaultedAccessorOption` are base or factory-return types; instantiate the
concrete groups and leaves above.

## Command declarations

Extend `Command`, provide `name` and `shortDescription`, and implement
`FutureOr<String?> run(ParsedInputs inputs, List<String> args)`.

The constructor accepts:

- `longDescription` and `aliases`;
- `mandatoryPositionals` and `discretionaryPositionals`;
- one `variadic` declaration;
- `flags` and ordinary `options`;
- `pairedOptions`, `selectedOptionses`, and root `accessors`; and
- `conflicts`, mapping an input name to incompatible input names.

`run` may return a string, `null`, or a future of either.

## Group commands

Extend `GroupCommand` for nested command paths. Pass child commands as the
first constructor argument. Its additional configuration includes:

- `defaultSubCommandPath` to run a descendant when no child is named;
- `propagatedFlags` to make flags available to descendants; and
- `propagatedOptions` to make ordinary options available to descendants.

Override `run` only when the group needs behavior other than its default child
dispatch. `runChildCommand(path, inputs, args)` dispatches a descendant by
name or alias.

## Completion commands

`CompletionCommand.preset(createFile)` constructs the standard `completion`
command for `ShellCompletion.bash`, `zsh`, `fish`, `powershell`, and
`carapace`. Pass `null` to write through the built-in generator, or pass a
callback to handle the requested path. Use the unnamed `CompletionCommand`
constructor only when customizing its declarations.

`CompletionCommand.shellInput` and `CompletionCommand.pathInput` expose the
preset command's retained positional declarations. The executor supplies its
`registryRecord`.

## Execution hooks and standard input

Mix `HookRunner` onto a `Command` to implement:

- `preRun(ParsedInputs, MambaReadContext, ProcessedStandardInput?)`; and
- optional `postRun(ParsedInputs, MambaReadContext)`.

Mix `PersistentHookRunner` onto a `GroupCommand` to implement hooks around a
descendant invocation:

- `prePersistentRun(ParsedInputs, MambaContext)`; and
- optional `postPersistentRun(ParsedInputs, MambaContext)`.

`ProcessedStandardInput` exposes raw `bytes`, direct `String.fromCharCodes`
`text`, UTF-8 `utf8Text`, and decoded `json`.

## Public supporting types

The following types describe capabilities and factory return values. Use them
for type checks or signatures, not as concrete declarations:

- `Input<T>`, `RequiredInput<T>`, `OptionalInput<T>`, and
  `DefaultedInput<T>`;
- `RegExpValidated`, `ChoiceValidated<T>`, `NumericRangeValidated<T>`, and
  `NumericStepValidated`;
- `DefaultValue<T>`;
- `Flag<T>`, `Option<T>`, `SingleOption<T>`, `RequiredOption<T>`, and
  `DefaultedOption<T>`; and
- `RepeatableOptionDefinition`, `RepeatableOption<T>`,
  `RequiredRepeatableOption<T>`, and `DefaultedRepeatableOption<T>`.

`RegExpValidated.anyToken` is the default full-token pattern used by string
inputs when no custom expression is supplied.
