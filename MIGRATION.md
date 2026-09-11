# Migrating to availability-typed command inputs

This release makes input availability part of each declaration's output type.
It is a breaking change: runtime `required` and `defaultValue` modes have been
replaced by factories whose types express whether a value may be absent.

## Reading values

Read retained declaration handles directly from `CommandInvocation`:

```dart
final class ExportCommand extends Command {
  ExportCommand() : super(mandatoryPositionals: [source], options: [format]);

  static final source = NormalPositional('source');
  static final format = ChoiceOption.withDefault(
    'format',
    choices: OutputFormat.values,
    defaultValue: OutputFormat.text,
  );

  @override
  String get name => 'export';

  @override
  String get shortDescription => 'Export data.';

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final sourceValue = invocation.valueOf(source); // String
    final formatValue = invocation.valueOf(format); // OutputFormat
    return 'Exporting $sourceValue as ${formatValue.name}';
  }
}
```

`ParsedInputs.require()` and `CommandInvocation.inputs` have been removed.
`valueOf()` returns exactly the declaration's output type. An absent non-null
output is a parser invariant failure.

## Required, optional, and defaulted options

Options remain optional by default. Use `.required` when the user must provide
a value and `.withDefault` when omission should produce a configured fallback:

```dart
final label = StringOption('label'); // String?
final output = StringOption.required('output'); // String
final format = ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
); // OutputFormat
```

The same required factory is available for numeric and repeatable options.
Choice defaults must use `.withDefault`; `defaultValue` is no longer accepted
by the ordinary choice constructor.

## Positionals

Positionals remain mandatory by default. Their declaration type now agrees
with the registration list:

```dart
final source = NormalPositional('source');
final destination = NormalPositional.optional('destination');

Command(
  mandatoryPositionals: [source],
  discretionaryPositionals: [destination],
);
```

`mandatoryPositionals` accepts only `MandatoryPositional` declarations and
`discretionaryPositionals` accepts only `DiscretionaryPositional`
declarations. Choice and repeated positionals provide corresponding
`.optional` and `.withDefault` factories.

Accessor leaves remain omittable. Ordinary leaves produce nullable outputs;
`AccessorChoiceOption.withDefault` produces a non-null enum output.

## Option groups

Paired groups now map all members into one cohesive output. Members are
available only to the mapper:

```dart
final host = PairStringOption('host');
final port = PairIntOption('port');
final server = PairedOptions.required(
  [host, port],
  (values) => Server(
    values.valueOf(host),
    values.valueOf(port),
  ),
);
```

Optional `PairedOptions` produce `R?`; `PairedOptions.required` produces `R`.

Selected groups follow the same availability convention:

```dart
final output = SelectedOptions.required([
  SelectableOption(json, JsonOutput.new),
  SelectableOption(text, TextOutput.new),
]);
```

Optional `SelectedOptions` produce `R?`; `SelectedOptions.required` produces
`R`. Individual selected members are not exposed in parsed inputs.

## Validated trailing arguments

Values after `--` remain separate from typed inputs. Mamba validates them using
the registered `Variadic` and passes them as the immutable `args` list.

## Execution results

`Executor.fake()` returns `MambaExecutionResult`. Successful results have exit
code `0`; failures expose `exitCode`, retained `output`, and phase-tagged
`errors`. Production executors render retained output to stdout, every error to
stderr, and use the reported exit code.
