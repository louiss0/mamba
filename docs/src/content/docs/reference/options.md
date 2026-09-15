---
title: Options
description: Define typed named inputs in Mamba
---

Options are named inputs that take values. Register ordinary options in
`Command.options`, `Executor.options`, or `GroupCommand.propagatedOptions`.
Register paired and selected groups in their corresponding command lists.
Accessor options are registered as trees.

Long options accept `--name value` and `--name=value`. A one-letter `short`
alias accepts `-n value`.

## Output availability

An option declaration determines the exact type returned by `valueOf`.
Ordinary options are optional by default:

```dart
final label = StringOption('label');
final String? labelValue = invocation.valueOf(label);
```

Use `.required` when the user must provide the option:

```dart
final output = StringOption.required('output');
final String outputValue = invocation.valueOf(output);
```

Choice options use `.withDefault` when omission supplies a fallback:

```dart
final format = ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
final OutputFormat formatValue = invocation.valueOf(format);
```

The ordinary constructors no longer accept `required` or `defaultValue`
modifiers because runtime booleans cannot change a declaration's static output
type.

## Single-value options

### `StringOption`

Parses a complete `String` matching `regex`. The default `\S+` pattern accepts
one non-whitespace token.

```dart
StringOption('label', short: 'l')
StringOption.required('output', short: 'o')
```

### `IntOption`

Parses a signed decimal `int`. `min` and `max` define inclusive bounds.

```dart
IntOption('retries', min: 0, max: 5)
IntOption.required('port', min: 1, max: 65535)
```

### `DoubleOption`

Parses a signed decimal `double`. `min` and `max` define inclusive bounds. A
`step` requires finite bounds and restricts accepted values to increments from
`min`.

```dart
DoubleOption('ratio', min: 0, max: 1, step: 0.25)
DoubleOption.required('amount', min: 0)
```

### `ChoiceOption<T>`

Accepts the name of a registered enum member and returns that enum member.

```dart
ChoiceOption<OutputFormat>('format', choices: OutputFormat.values)
ChoiceOption.required('format', choices: OutputFormat.values)
ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
)
```

Generic factories infer their type from `choices` and `defaultValue`.

## Repeatable options

Repeatable options append every occurrence to an ordered list:

```console
mamba build --tag stable --tag public
```

```dart
RepeatableStringOption('tag')             // List<String>?
RepeatableStringOption.required('tag')    // List<String>
RepeatableIntOption('port')               // List<int>?
RepeatableIntOption.required('port')      // List<int>
RepeatableDoubleOption('ratio')           // List<double>?
RepeatableDoubleOption.required('ratio')  // List<double>
```

`RepeatableChoiceOption<T>` returns enum members. With `unique: true`, a
repeated member is rejected rather than silently deduplicated.

```dart
RepeatableChoiceOption<OutputFormat>(
  'format',
  OutputFormat.values,
  unique: true,
)
```

## Paired options

`PairedOptions<T>` requires all members together when any member is supplied
and maps the complete set into an immutable `Map<String, T>`:

```dart
final host = PairStringOption('host');
final password = PairStringOption('password');
final credentials = PairedOptions<String>([host, password]);

final values = inputs.valueOf(credentials);
// --host db.internal --password mamba produces
// {'host': 'db.internal', 'password': 'mamba'}
```

The ordinary group is omittable and produces an empty `Map<String, T>`.
`PairedOptions<T>.required` requires the complete group.

## Selected options

`SelectedOptions<T>` maps every supplied pair option into an immutable
`Map<String, T>`. The pair option name is the map key:

```dart
final json = PairStringOption('json');
final text = PairStringOption('text');
final output = SelectedOptions<String>([json, text]);

final values = inputs.valueOf(output);
// --json tasks.json produces {'json': 'tasks.json'}
```

Use `SelectedOptions<T>.required(...)` when at least one member must be
supplied. Use `SelectedOptions<T>.single(...)` when exactly zero or one member
may be supplied. Without an explicit type argument, Dart infers the common
pair-value type; mixed pair types infer `Object`.

## Accessor options

Accessor lists group dotted paths such as `--server.host`:

```dart
final host = AccessorStringOption('host');
final format = AccessorChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
final server = AccessorListOption('server', [host, format]);
```

Accessor leaves remain omittable. Ordinary leaves are omitted from the map;
defaulted leaves are always present. `AccessorListOption` is the typed,
value-producing handle for its complete accessor tree. Read it from
`ParsedInputs` using the top-level declaration:

```dart
final values = inputs.valueOf(server);
final String? hostValue = values['host'] as String?;
final OutputFormat formatValue = values['format'] as OutputFormat;
```

Nested accessor lists produce nested immutable maps, so an option such as
`--server.auth.token secret` is available below `inputs.valueOf(server)`.

## Conflicting inputs

`Command.conflicts` rejects incompatible named inputs before the command runs.
Each map key conflicts with every name in its list. Keys and list entries must
name a flag, ordinary option, paired or selected option member, or an accessor
leaf. Accessor leaves use their dotted spelling.

```dart
final class DeployCommand extends Command {
  DeployCommand()
      : super(
          conflicts: {
            'replace': ['output', 'server.auth.token'],
          },
        );

  // Command members omitted.
}
```

The conflict map belongs to the command that declares the inputs; it is not an
`Executor` configuration option.

## Shared metadata

`description` supplies help text. `hidden: true` keeps ordinary options
parseable while omitting them from help. Registry records retain required,
default, range, repetition, and group metadata for help and completion
converters.
