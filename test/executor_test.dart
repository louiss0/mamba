import 'package:arg_parser/errors.dart';
import 'package:arg_parser/executor.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

void main() {
  group('Executor', () {
    test('writes help for the root and selected command', () {
      final output = <String>[];
      final build = _RecordingCommand('build', 'Build the workspace.');
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        writeHelp: output.add,
        commands: [build],
      );

      executor.execute([]);
      executor.execute(['build', '--help']);

      expect(output, hasLength(2));
      expect(output.first, contains('workspace'));
      expect(output.last, contains('build'));
      expect(build.calls, 0);
    });

    test('runs the selected list-defined command with parsed maps', () {
      final build = _RecordingCommand(
        'build',
        'Build the workspace.',
        flags: [BooleanFlag(name: 'verbose')],
      );
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [build],
      );

      executor.execute(['build', '--verbose']);

      expect(build.calls, 1);
      expect(build.inputs!.boolFlags, {'verbose': true});
    });

    test('rejects unknown commands even when help is requested', () {
      final executor = Executor('workspace', 'Manage a workspace.');

      expect(
        () => executor.execute(['unknown', '--help']),
        throwsA(isA<MambaException>()),
      );
    });
  });
}

final class _RecordingCommand extends Command {
  _RecordingCommand(super.name, super.shortDescription, {super.flags});

  int calls = 0;
  Inputs? inputs;

  @override
  void run(Inputs input, List<String> variadic) {
    calls++;
    inputs = input;
  }
}
