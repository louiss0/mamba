import 'package:mamba/mamba.dart';

enum OutputFormat { text, json }

sealed class OutputSelection {
  const OutputSelection();
}

final class JsonOutput extends OutputSelection {
  const JsonOutput(this.path);
  final String path;
}

final class TextOutput extends OutputSelection {
  const TextOutput(this.path);
  final String path;
}

final class ExportCommand extends Command {
  ExportCommand()
    : super(
        mandatoryPositionals: [source],
        options: [format],
        selectedOptions: [output],
      );
  static final source = NormalPositional('source');
  static final format = ChoiceOption<OutputFormat>(
    'format',
    choices: OutputFormat.values,
    defaultValue: OutputFormat.text,
  );
  static final json = PairStringOption('json');
  static final text = PairStringOption('text');
  static final output = SelectedOptions<OutputSelection>([
    SelectableOption(json, JsonOutput.new),
    SelectableOption(text, TextOutput.new),
  ]);
  @override
  String get name => 'export';
  @override
  String get shortDescription => 'Exports a source.';
  @override
  String run(CommandInvocation invocation, List<String> args) {
    final sourceValue = invocation.inputs.require(source);
    final formatValue = invocation.inputs.require(format);
    final selection = invocation.inputs.valueOf(output);
    final suffix = switch (selection) {
      JsonOutput(:final path) => path,
      TextOutput(:final path) => path,
      null => formatValue.name,
    };
    return 'Exporting $sourceValue as $suffix';
  }
}

Future<void> main(List<String> args) => Executor(
  'example',
  'Typed Mamba example.',
  '1.0.0',
  [ExportCommand()],
).create().execute(args);
