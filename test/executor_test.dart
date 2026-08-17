import 'package:arg_parser/command.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/executor.dart';
import 'package:arg_parser/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestHookRunner extends Mock implements Command, HookRunner {
  @override
  final String name;

  @override
  final String shortDescription;
  TestHookRunner(this.name, this.shortDescription);
}

void main() {
  setUpAll(() {
    registerFallbackValue(MambaContext());
    registerFallbackValue(MambaReadContext(MambaContext()));
    final Inputs emptyInputs = (
      accessors: null,
      boolFlags: null,
      countFlags: null,
      doubleOptions: null,
      intOptions: null,
      positionalOptions: null,
      repeatedDoubleOptions: null,
      repeatedIntOptions: null,
      repeatedStringOptions: null,
      stringOptions: null,
    );
    registerFallbackValue(emptyInputs);
  });

  group('Executor', () {
    test("executes hooks when a command is a HookRunner", () async {
      final testHookRunner = TestHookRunner('add', "Add a new item.");

      when(() => testHookRunner.run(any(), any(), any())).thenAnswer((_) => '');
      when(() => testHookRunner.preRun(any())).thenReturn(null);
      when(() => testHookRunner.postRun(any())).thenReturn(null);

      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [testHookRunner],
      );

      await executor.execute(['add']);

      verify(() => testHookRunner.preRun(any())).called(1);
      verify(() => testHookRunner.run(any(), any(), any())).called(1);
      verify(() => testHookRunner.postRun(any())).called(1);
    });

    test('provides constructor context to command hooks', () async {
      final deploymentKey = MambaContextKey<String>();
      final context = MambaContext()..set(deploymentKey, 'production');
      final command = TestHookRunner('add', 'Add a new item.');
      String? deployment;
      when(() => command.run(any(), any(), any())).thenAnswer((_) {});
      when(() => command.preRun(any())).thenReturn(null);
      when(() => command.postRun(any())).thenAnswer((invocation) {
        final context =
            invocation.positionalArguments.single as MambaReadContext;
        deployment = context.get(deploymentKey);
      });
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        context: context,
        commands: [command],
      );

      await executor.execute(['add']);

      expect(deployment, 'production');
    });

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

    test('passes positionals and parsed maps to commands', () async {
      final build = _RecordingCommand(
        'build',
        'Build the workspace.',
        mandatoryPositionals: [Positional('target')],
        flags: [BooleanFlag(name: 'verbose')],
      );
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [build],
      );

      await executor.execute(['build', 'release', '--verbose']);

      expect(build.calls, 1);
      expect(build.positionals, {'target': 'release'});
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
  _RecordingCommand(
    super.name,
    super.shortDescription, {
    super.flags,
    super.mandatoryPositionals,
  });

  int calls = 0;
  Map<String, String>? positionals;
  Inputs? inputs;
  @override
  void run(
    Map<String, String>? receivedPositionals,
    Inputs input,
    List<String> variadic,
  ) {
    calls++;
    positionals = receivedPositionals;
    inputs = input;
  }
}
