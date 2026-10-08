import 'package:mamba/mamba.dart';

final class InputCommand extends Command with HookRunner {
  String? _input;

  @override
  String get name => 'input';

  @override
  String get shortDescription => 'Read standard input.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    _input = input?.utf8Text;
  }

  @override
  String run(ValueOf valueOf, List<String> args) => _input ?? 'no input';

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    _input = null;
  }
}

final class FailureCommand extends Command {
  @override
  String get name => 'fail';

  @override
  String get shortDescription => 'Fail execution.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    throw MambaException('process failed', exitCode: 7);
  }
}

final class SilentCommand extends Command {
  @override
  String get name => 'silent';

  @override
  String get shortDescription => 'Produce no output.';

  @override
  String? run(ValueOf valueOf, List<String> args) => null;
}

final class EchoCommand extends Command {
  @override
  String get name => 'echo';

  @override
  String get shortDescription => 'Return two lines without a trailing newline.';

  @override
  String run(ValueOf valueOf, List<String> args) => 'line one\nline two';
}

final class ErrorTextCommand extends Command {
  @override
  String get name => 'error-text';

  @override
  String get shortDescription => 'Fail with error text.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    throw MambaException('error text', exitCode: 9);
  }
}

final class UnicodeCommand extends Command {
  @override
  String get name => 'unicode';

  @override
  String get shortDescription => 'Return non-ASCII text.';

  @override
  String run(ValueOf valueOf, List<String> args) => 'héllo — ünïcode ☃';
}

final class TwiceFailingCommand extends Command with HookRunner {
  @override
  String get name => 'fails-twice';

  @override
  String get shortDescription => 'Fail in run and in the post hook.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    throw MambaException('cleanup failed', exitCode: 5);
  }

  @override
  String run(ValueOf valueOf, List<String> args) {
    throw MambaException('run failed', exitCode: 7);
  }
}

Future<void> main(List<String> args) =>
    Executor('process-cli', 'Exercise process execution.', '1.0.0', [
      InputCommand(),
      FailureCommand(),
      SilentCommand(),
      EchoCommand(),
      ErrorTextCommand(),
      UnicodeCommand(),
      TwiceFailingCommand(),
    ]).create().execute(args);
