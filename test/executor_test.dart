import 'package:arg_parser/command.dart';
import 'package:arg_parser/context.dart';
import 'package:arg_parser/executor.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestHookRunner extends Mock implements Command, HookRunner {
  @override
  final String name;

  @override
  final String shortDescription;
  TestHookRunner(this.name, this.shortDescription);
}

class _FakeGitCommand extends Mock implements Command {
  @override
  final String name;

  @override
  final String shortDescription;

  _FakeGitCommand(this.name) : shortDescription = 'Run git $name.';
}

void main() {
  setUpAll(() {
    registerFallbackValue(MambaContext());
    registerFallbackValue(MambaReadContext(MambaContext()));
    final ParsedNamedInputs emptyInputs = (
      accessors: null,
      boolFlags: null,
      countFlags: null,
      doubleOptions: null,
      intOptions: null,
      repeatedDoubleOptions: null,
      repeatedIntOptions: null,
      repeatedStringOptions: null,
      stringOptions: null,
    );
    registerFallbackValue(emptyInputs);
    const ParsedSingleOptions emptyOptions = (
      doubleOptions: null,
      intOptions: null,
      stringOptions: null,
    );
    registerFallbackValue(emptyOptions);
  });

  group('Executor', () {
    test("executes hooks when a command is a HookRunner", () async {
      final testHookRunner = TestHookRunner('add', "Add a new item.");

      when(() => testHookRunner.run(any(), any(), any())).thenAnswer((_) => '');
      when(
        () => testHookRunner.preRun(any(), any(), any(), any()),
      ).thenReturn(null);
      when(() => testHookRunner.postRun(any())).thenReturn(null);

      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [testHookRunner],
      );

      await executor.execute(['add']);

      verify(() => testHookRunner.preRun(any(), any(), any(), any())).called(1);
      verify(() => testHookRunner.run(any(), any(), any())).called(1);
      verify(() => testHookRunner.postRun(any())).called(1);
    });

    test(
      'passes null input to pre-run hooks when stdin is not piped',
      () async {
        final command = TestHookRunner('add', 'Add a new item.');
        when(() => command.run(any(), any(), any())).thenAnswer((_) => '');
        when(() => command.preRun(any(), any(), any(), any())).thenReturn(null);
        when(() => command.postRun(any())).thenReturn(null);
        final executor = Executor(
          'workspace',
          'Manage a workspace.',
          commands: [command],
        );

        await executor.execute(['add']);

        verify(
          () => command.preRun(any(that: isNull), any(), any(), any()),
        ).called(1);
      },
    );

    test('provides constructor context to command hooks', () async {
      final deploymentKey = MambaContextKey<String>();
      final context = MambaContext()..set(deploymentKey, 'production');
      final command = TestHookRunner('add', 'Add a new item.');
      String? deployment;
      when(() => command.run(any(), any(), any())).thenAnswer((_) => '');
      when(() => command.preRun(any(), any(), any(), any())).thenReturn(null);
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

    test(
      'runs the executor default subcommand when no command is selected',
      () async {
        final status = _RecordingCommand('status', 'Show the status.');
        final executor = Executor(
          'git',
          'Version control.',
          defaultSubCommandPath: ['status'],
          commands: [status],
        );

        await executor.execute([]);
        await executor.execute(['--verbose', 'git']);

        expect(status.calls, 2);
      },
    );

    test('rejects empty and parent-qualified executor paths', () {
      expect(
        () => Executor('git', 'Version control.', defaultSubCommandPath: []),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Executor(
          'git',
          'Version control.',
          defaultSubCommandPath: ['git', 'status'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('does not run commands when help is requested', () async {
      final build = _RecordingCommand('build', 'Build the workspace.');
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [build],
      );

      await executor.execute([]);
      await executor.execute(['build', '--help']);

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
      expect(build.inputs!.boolFlags, {'dry-run': false, 'verbose': true});
    });

    test(
      'runs persistent hooks for every command on the selected path',
      () async {
        final add = TestHookRunner('add', 'Add an item.');
        final remote = TestHookRunner('remote', 'Manage remotes.');
        when(() => remote.commands).thenReturn([add]);
        for (final command in [remote, add]) {
          when(() => command.run(any(), any(), any())).thenAnswer((_) => '');
          when(
            () => command.prePersistentRun(any(), any(), any()),
          ).thenReturn(null);
          when(
            () => command.postPersistentRun(any(), any(), any()),
          ).thenReturn(null);
          when(
            () => command.preRun(any(), any(), any(), any()),
          ).thenReturn(null);
          when(() => command.postRun(any())).thenReturn(null);
        }
        final executor = Executor(
          'git',
          'Version control.',
          commands: [remote],
        );

        await executor.execute(['remote', 'add', '--dry-run', '-vv']);

        verify(() => remote.prePersistentRun(any(), any(), any())).called(1);
        verify(() => add.prePersistentRun(any(), any(), any())).called(1);
        verify(() => add.preRun(any(), any(), any(), any())).called(1);
        final invocation =
            verify(() => add.run(any(), captureAny(), any())).captured.single
                as ParsedNamedInputs;
        expect(invocation.boolFlags?['dry-run'], isTrue);
        expect(invocation.countFlags?['verbose'], 2);
        verify(() => add.postRun(any())).called(1);
        verify(() => add.postPersistentRun(any(), any(), any())).called(1);
        verify(() => remote.postPersistentRun(any(), any(), any())).called(1);
        verifyNever(() => remote.preRun(any(), any(), any(), any()));
        verifyNever(() => remote.run(any(), any(), any()));
      },
    );

    test('provides executor flags to every selected command', () async {
      final build = _RecordingCommand('build', 'Build the workspace.');
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        flags: [BooleanFlag(name: 'color')],
        commands: [build],
      );

      await executor.execute(['build', '--dry-run', '--color', '-vv']);
      await executor.execute(['--dry-run', '-vv', '--color', 'build']);

      expect(build.calls, 2);
      expect(build.inputs!.boolFlags, {'dry-run': true, 'color': true});
      expect(build.inputs!.countFlags, {'verbose': 2});
    });

    test('passes arguments after -- to commands', () async {
      final build = _RecordingCommand('build', 'Build the workspace.');
      final executor = Executor(
        'workspace',
        'Manage a workspace.',
        commands: [build],
      );

      await executor.execute(['build', '--', '--help', 'value']);

      expect(build.trailingArguments, ['--help', 'value']);
    });

    test('executes git config with nested accessor flags', () async {
      final config = _FakeGitCommand('config');
      when(() => config.accessors).thenReturn([
        // These paths mirror names from `git help --config`.
        AccessorListOption(
          name: 'user',
          options: [AccessorStringOption(name: 'name')],
        ),
        AccessorListOption(
          name: 'branch',
          options: [
            AccessorListOption(
              name: 'main',
              options: [AccessorStringOption(name: 'remote')],
            ),
          ],
        ),
        AccessorListOption(
          name: 'remote',
          options: [
            AccessorListOption(
              name: 'origin',
              options: [
                AccessorStringOption(name: 'url'),
                AccessorListOption(
                  name: 'fetch',
                  options: [AccessorStringOption(name: 'refspec')],
                ),
              ],
            ),
          ],
        ),
      ]);
      ParsedNamedInputs? configInputs;
      when(() => config.run(any(), any(), any())).thenAnswer((invocation) {
        configInputs = invocation.positionalArguments[1] as ParsedNamedInputs;
        return 'config ran';
      });
      final executor = Executor(
        'git',
        'The stupid content tracker.',
        commands: [config],
      );

      await executor.execute([
        'git',
        'config',
        '--user.name=Ada',
        '--branch.main.remote',
        'origin',
        '--remote.origin.url',
        'https://example.com/repository.git',
        '--remote.origin.fetch.refspec',
        '+refs/heads/*:refs/remotes/origin/*',
      ]);

      verify(() => config.run(any(), any(), any())).called(1);
      expect(configInputs!.accessors, {
        'user': {'name': 'Ada'},
        'branch': {
          'main': {'remote': 'origin'},
        },
        'remote': {
          'origin': {
            'url': 'https://example.com/repository.git',
            'fetch': {'refspec': '+refs/heads/*:refs/remotes/origin/*'},
          },
        },
      });
    });

    test(
      'executes a mock git command tree and renders every command in help',
      () async {
        final commandNames = [
          'add',
          'am',
          'archive',
          'bisect',
          'branch',
          'bundle',
          'checkout',
          'cherry-pick',
          'clean',
          'clone',
          'commit',
          'config',
          'describe',
          'diff',
          'fetch',
          'format-patch',
          'gc',
          'grep',
          'init',
          'log',
          'merge',
          'mv',
          'notes',
          'pull',
          'push',
          'rebase',
          'reset',
          'restore',
          'revert',
          'rm',
          'show',
          'stash',
          'status',
          'switch',
          'tag',
          'worktree',
        ];
        final commands = commandNames.map(_FakeGitCommand.new).toList();
        ParsedNamedInputs? statusInputs;
        for (final command in commands) {
          when(() => command.run(any(), any(), any())).thenAnswer((invocation) {
            final inputs =
                invocation.positionalArguments[1] as ParsedNamedInputs;
            if (command.name == 'status') statusInputs = inputs;
            return inputs.boolFlags?['dry-run'] == true
                ? '${command.name} would run'
                : '${command.name} ran';
          });
        }
        final executor = Executor(
          'git',
          'The stupid content tracker.',
          commands: commands,
        );

        await executor.execute(['--dry-run', '-vv', 'git', 'status']);
        await executor.execute(['--verbose', 'git', '--help']);
        await executor.execute(['--verbose', 'git', 'status', '--help']);

        verify(
          () =>
              commands[commandNames.indexOf('status')].run(any(), any(), any()),
        ).called(1);
        expect(statusInputs!.boolFlags?['dry-run'], isTrue);
        expect(statusInputs!.countFlags?['verbose'], 2);
        verifyNever(
          () =>
              commands[commandNames.indexOf('merge')].run(any(), any(), any()),
        );
        verifyNever(
          () =>
              commands[commandNames.indexOf('rebase')].run(any(), any(), any()),
        );
      },
    );
  });
}

final class _RecordingCommand extends Command {
  @override
  final String name;
  @override
  final String shortDescription;

  _RecordingCommand(
    this.name,
    this.shortDescription, {
    super.flags,
    super.mandatoryPositionals,
  });

  int calls = 0;
  Map<String, String>? positionals;
  ParsedNamedInputs? inputs;
  List<String>? trailingArguments;
  @override
  String run(
    Map<String, String>? receivedPositionals,
    ParsedNamedInputs input,
    List<String> receivedTrailingArguments,
  ) {
    calls++;
    positionals = receivedPositionals;
    inputs = input;
    trailingArguments = receivedTrailingArguments;
    return '';
  }
}
