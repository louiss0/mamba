# Migrating to typed command inputs

This Mamba release replaces name-keyed parsed records with declaration handles. This is a
breaking change: commands register the same input instances that they later use
to read values.

## Command execution

Declare handles as `static final` fields (or otherwise retain the instances
passed to `super`), then read them from the invocation:

```dart
final class ExportCommand extends Command {
  ExportCommand() : super(mandatoryPositionals: [source], options: [format]);

  static final source = NormalPositional('source');
  static final format = ChoiceOption<OutputFormat>(
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
    final sourceValue = invocation.inputs.require(source);
    final formatValue = invocation.inputs.require(format);
    return 'Exporting $sourceValue as ${formatValue.name}';
  }
}
```

`valueOf` returns `null` for an omitted optional input. `require` is for inputs
which the parser has already guaranteed are present. Values after `--` are
validated by the registered `Variadic` and passed as the immutable `args` list;
they are not part of `CommandInvocation.inputs`.

Choice inputs now return their registered enum members rather than enum names.
Accessor leaves are read through their leaf handles, so commands no longer
receive dynamic path maps.

## Option groups

`PairedOptions` now always means every member must be supplied together. Replace
`PairedOptions(..., variant: true)` with a typed `SelectedOptions<R>`:

```dart
final output = SelectedOptions<OutputSelection>([
  SelectableOption(json, JsonOutput.new),
  SelectableOption(text, TextOutput.new),
], required: true);
```

The selected group's mapped result is available through `valueOf(output)` or
`require(output)`. The individual selected member is intentionally not exposed
in parsed inputs.

## Execution results

`Executor.fake()` returns `MambaExecutionResult`. Successful results have exit
code `0`; failures expose `exitCode`, retained `output`, and phase-tagged
`errors`. Production executors render retained output to stdout, every error to
stderr, and use the reported exit code.
