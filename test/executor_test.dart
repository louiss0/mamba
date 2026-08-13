import 'package:arg_parser/errors.dart';
import 'package:arg_parser/executor.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

void main() {
  group('Executor help routing', () {
    test('writes root help instead of running the root command', () {
      final calls = <String>[];
      final output = <String>[];
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        writeHelp: output.add,
        commands: [_RecordingCommand('build', 'Build the workspace.', calls)],
      );

      executor.execute(['--help']);

      expect(calls, isEmpty);
      expect(output, hasLength(1));
      expect(output.single, HelpFormatter().formatHelp(_rootRegistry()));
    });

    test('writes selected command help without running its handler', () {
      final calls = <String>[];
      final output = <String>[];
      final build = _RecordingCommand('build', 'Build the workspace.', calls);
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        writeHelp: output.add,
        commands: [build],
      );

      executor.execute(['build', '--help']);

      expect(calls, isEmpty);
      expect(output, [HelpFormatter().formatHelp(build.registry)]);
    });

    test('supports the short help flag after a nested command', () {
      final calls = <String>[];
      final output = <String>[];
      final deploy = _RecordingCommand(
        'deploy',
        'Deploy the workspace.',
        calls,
      );
      final release = _RecordingCommand(
        'release',
        'Manage releases.',
        calls,
        commands: [deploy],
      );
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        writeHelp: output.add,
        commands: [release],
      );

      executor.execute(['release', 'deploy', '-h']);

      expect(calls, isEmpty);
      expect(output, [HelpFormatter().formatHelp(deploy.registry)]);
    });

    test('rejects an unknown command even when help is requested', () {
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [_RecordingCommand('build', 'Build the workspace.', [])],
      );

      expect(
        () => executor.execute(['unknown', '--help']),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('Command unknown was not found under workspace.'),
          ),
        ),
      );
    });

    test('runs the selected command when help is absent', () {
      final calls = <String>[];
      final build = _RecordingCommand('build', 'Build the workspace.', calls);
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [build],
      );

      executor.execute(['build']);

      expect(calls, ['build']);
    });
  });
}

CommandRegistry _rootRegistry() => CommandRegistry.create(
  'workspace',
  'Manage a workspace.',
  flags: [
    BooleanFlag(
      name: 'help',
      short: 'h',
      description: 'Display help for commands',
    ),
    CountFlag(name: 'verbose', short: 'v', description: 'Decide log level'),
  ],
  commands: [_RecordingCommand('build', 'Build the workspace.', [])],
);

final class _RecordingCommand extends Command {
  _RecordingCommand(
    super.name,
    super.shortDescription,
    this.calls, {
    super.commands,
  }) : super(
         positionalSchema: null,
         accessorFlagSchema: null,
         flags: null,
         singleOptions: null,
         repeatedOptions: null,
       );

  final List<String> calls;

  @override
  void run(Inputs input) => calls.add(name);
}
