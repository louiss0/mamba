import 'package:mamba/mamba.dart';

/// Small completion fixture demonstrating typed input handles.
enum Output { text, json }

final class RigCommand extends Command {
  RigCommand() : super(options: [format]);
  static final format = ChoiceOption.required('format', choices: Output.values);
  @override
  String get name => 'rig';
  @override
  String get shortDescription => 'Completion fixture.';
  @override
  String run(
    CommandInvocation invocation,
    List<String> args,
    ProcessedStandardInput? input,
  ) => invocation.valueOf(format).name;
}
