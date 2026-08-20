import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/executor.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutorFactory', () {
    final factory = Executor('mamba', 'A command-line application.');

    test('creates a fake executor that returns a success result', () async {
      final MambaExecutor<MambaExecutionResult> executor = factory.fake();

      final result = await executor.execute([]);
      final success = result as MambaSuccessResult;

      expect(result, isA<MambaSuccessResult>());
      expect(success.output, contains('mamba'));
      expect(success.output, contains('help'));
    });

    test('creates a console executor', () {
      final MambaExecutor<void> executor = factory.create();

      expect(executor, isA<MambaExecutor<void>>());
    });

    test('returns a failure result when execution fails', () async {
      final result = await factory.fake().execute(['missing']);

      expect(result, isA<MambaFailureResult>());
    });
  });

  group('persistent hooks', () {
    test(
      'run around descendant commands without ordinary command hooks',
      () async {
        final events = <String>[];
        final group = _PersistentGroup(events, [_Command('serve')]);
        final executor = Executor(
          'mamba',
          'A command-line application.',
          commands: [group],
        ).fake();

        await executor.execute(['group', 'serve']);

        expect(events, ['pre:group', 'post:group']);
      },
    );
  });
}

final class _Command extends Command {
  _Command(this.name);

  @override
  final String name;

  @override
  String get shortDescription => 'A test command.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => '';
}

final class _PersistentGroup extends GroupCommand with PersistentHookRunner {
  _PersistentGroup(this.events, super.commands);

  final List<String> events;

  @override
  final String name = 'group';

  @override
  String get shortDescription => 'A test group command.';

  @override
  void prePersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {
    events.add('pre:$name');
  }

  @override
  Future<void> postPersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) async {
    await Future<void>.delayed(Duration.zero);
    events.add('post:$name');
  }
}
