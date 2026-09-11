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

`PairedOptions<R>` requires all members together when any member is supplied
and maps the complete set into one output:

```dart
final host = PairStringOption('host');
final port = PairIntOption('port');
final server = PairedOptions(
  [host, port],
  (values) => Server(
    values.valueOf(host),
    values.valueOf(port),
  ),
);
```

The ordinary group is omittable and produces `Server?`.
`PairedOptions.required` requires the complete group and produces `Server`.
Pair members are available only inside the mapper.

## Selected options

`SelectedOptions<R>` accepts at most one member and maps it to one output:

```dart
final output = SelectedOptions<OutputSelection>([
  SelectableOption(json, JsonOutput.new),
  SelectableOption(text, TextOutput.new),
]);
```

The ordinary group produces `OutputSelection?`.
`SelectedOptions.required` requires exactly one member and produces
`OutputSelection`. Selected members are not exposed separately.

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

Accessor leaves remain omittable. Ordinary leaves return nullable values;
defaulted choice leaves return non-null enum values. `AccessorListOption` is a
registration node and is not itself a value-producing handle.

## Shared metadata

`description` supplies help text. `hidden: true` keeps ordinary options
parseable while omitting them from help. Registry records retain required,
default, range, repetition, and group metadata for help and completion
converters.
