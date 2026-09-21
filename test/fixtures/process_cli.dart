import 'package:mamba/mamba.dart';

final class InputCommand extends Command with HookRunner {
  String? _input;

  @override
  String get name => 'input';

  @override
  String get shortDescription => 'Read standard input.';

  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    _input = input?.utf8Text;
  }

  @override
  String run(ParsedInputs inputs, List<String> args) => _input ?? 'no input';

  @override
  void postRun(ParsedInputs inputs, MambaReadContext context) {
    _input = null;
  }
}

final class FailureCommand extends Command {
  @override
  String get name => 'fail';

  @override
  String get shortDescription => 'Fail execution.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    throw MambaException('process failed', exitCode: 7);
  }
}

final class SilentCommand extends Command {
  @override
  String get name => 'silent';

  @override
  String get shortDescription => 'Produce no output.';

  @override
  String? run(ParsedInputs inputs, List<String> args) => null;
}

Future<void> main(List<String> args) => Executor(
  'process-cli',
  'Exercise process execution.',
  '1.0.0',
  [InputCommand(), FailureCommand(), SilentCommand()],
).create().execute(args);
