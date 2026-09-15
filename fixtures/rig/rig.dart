import 'package:mamba/mamba.dart';

/// Small completion fixture demonstrating typed input handles.
enum Output { text, json }

final class RigCommand extends Command {
  new() : super(options: [format]);
  static final format = ChoiceOption.required('format', choices: Output.values);
  @override
  String get name => 'rig';
  @override
  String get shortDescription => 'Completion fixture.';
  @override
  String run(ParsedInputs inputs, List<String> args) =>
      inputs.valueOf(format).name;
}
