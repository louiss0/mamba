import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/executor.dart';
import 'package:test/test.dart';

String _withoutAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

void main() {
  group('ExecutorFactory', () {
    final factory = Executor('mamba', 'A command-line application.', []);

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

    test('returns root help when valid input selects no command', () async {
      final result = await factory.fake().execute(['--dry-run']);

      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, contains('mamba'));
    });
  });

  group('completion commands', () {
    test('receive the complete root map when nested', () async {
      final completion = _CompletionCommand();
      final executor = Executor('mamba', 'A command-line application.', [
        _DefaultGroup([completion], defaultSubCommandPath: ['completion']),
      ]).fake();

      final result = await executor.execute(['group']);

      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, 'mamba');
      final commands =
          completion.registryMap.map['commands'] as Map<String, dynamic>;
      final group = commands['group'] as Map<String, dynamic>;
      expect(
        (group['commands'] as Map<String, dynamic>).containsKey('completion'),
        isTrue,
      );
    });
  });

  group('global inputs', () {
    test('parses built-in and custom root inputs for a command', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        options: [StringOption('config', regex: RegExp(r'\S+'))],
        [_InputCommand('run')],
      ).fake();

      final result = await executor.execute([
        'run',
        '--dry-run',
        '-vv',
        '--config',
        'settings.json',
      ]);

      expect(result, isA<MambaSuccessResult>());
      expect(
        (result as MambaSuccessResult).output,
        'dry-run=true verbose=2 config=settings.json',
      );
    });

    test('does not pass the internal help flag to commands', () async {
      final received = <String, bool>{};
      final executor = Executor('mamba', 'A command-line application.', [
        _InputCommand(
          'run',
          onRun: (inputs) => received.addAll(inputs.boolFlags ?? {}),
        ),
      ]).fake();

      final result = await executor.execute(['run']);

      expect(result, isA<MambaSuccessResult>());
      expect(received, isNot(contains('help')));
    });

    test('ignores options after help once the command is known', () async {
      final executor = Executor('mamba', 'A command-line application.', [
        _InputCommand('run'),
      ]).fake();

      final result = await executor.execute(['run', '--help', '--unknown']);

      expect(result, isA<MambaSuccessResult>());
      expect(
        _withoutAnsi((result as MambaSuccessResult).output!),
        startsWith('mamba run'),
      );
    });

    test('resolves command help after a value-taking option', () async {
      final executor = Executor('mamba', 'A command-line application.', [
        _InputCommand(
          'run',
          options: [StringOption('config', regex: RegExp(r'\S+'))],
        ),
      ]).fake();

      final result = await executor.execute([
        'run',
        '--config',
        'settings.json',
        '--help',
      ]);

      expect(result, isA<MambaSuccessResult>());
      final output = (result as MambaSuccessResult).output;
      expect(output, isNotNull);
      expect(_withoutAnsi(output!), startsWith('mamba run'));
    });
  });

  group('default commands', () {
    test(
      'snapshots caller-owned command collections at factory creation',
      () async {
        final commands = <Command>[_Command('initial')];
        final factory = Executor(
          'mamba',
          'A command-line application.',
          commands,
        );
        commands.add(_Command('later'));

        final result = await factory.fake().execute(['later']);

        expect(result, isA<MambaFailureResult>());
      },
    );

    test('rejects an empty root default path as a registry error', () {
      expect(
        () => Executor('mamba', 'A command-line application.', [
          _Command('run'),
        ], defaultCommandPath: []),
        throwsA(isA<MambaRegistryError>()),
      );
    });
    test('applies a root default after a value-taking option', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        [_InputCommand('run')],
        options: [StringOption('config', regex: RegExp(r'\S+'))],
        defaultCommandPath: ['run'],
      ).fake();

      final result = await executor.execute(['--config', 'settings.json']);

      expect(result, isA<MambaSuccessResult>());
      expect(
        (result as MambaSuccessResult).output,
        contains('config=settings.json'),
      );
    });

    test(
      'help targets the explicitly named group before its default',
      () async {
        final executor = Executor('mamba', 'A command-line application.', [
          _DefaultGroup([_Command('serve')], defaultSubCommandPath: ['serve']),
        ]).fake();

        final result = await executor.execute(['group', '--help']);

        expect(result, isA<MambaSuccessResult>());
        expect(
          (result as MambaSuccessResult).output,
          contains('mamba group  \'A default command group.\''),
        );
      },
    );

    test('root help targets the root before its default', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        [_Command('run')],
        defaultCommandPath: ['run'],
      ).fake();

      final result = await executor.execute(['--help']);

      expect(result, isA<MambaSuccessResult>());
      expect(
        (result as MambaSuccessResult).output,
        contains('mamba  \'A command-line application.\''),
      );
    });

    test(
      'does not run child post-hooks when a group selects its default',
      () async {
        final events = <String>[];
        final executor = Executor('mamba', 'A command-line application.', [
          _DefaultGroup(
            [_HookCommand('serve', events)],
            defaultSubCommandPath: ['serve'],
          ),
        ]).fake();

        final result = await executor.execute(['group']);

        expect(result, isA<MambaSuccessResult>());
        expect(events, ['pre:serve', 'run:serve']);
      },
    );

    test('returns a failure for an unknown group default path', () async {
      final executor = Executor('mamba', 'A command-line application.', [
        _DefaultGroup([_Command('serve')], defaultSubCommandPath: ['missing']),
      ]).fake();

      final result = await executor
          .execute(['group'])
          .timeout(const Duration(seconds: 1));

      expect(result, isA<MambaFailureResult>());
    });
  });

  group('hook failures', () {
    test('recognizes platform variants of closed inherited pipes', () {
      expect(
        isClosedPipeFileSystemException(
          FileSystemException('Socket is closed'),
        ),
        isTrue,
      );
      expect(
        isClosedPipeFileSystemException(
          FileSystemException('pipe closed', '', OSError('pipe closed', 109)),
        ),
        isTrue,
      );
      expect(
        isClosedPipeFileSystemException(
          FileSystemException('permission denied'),
        ),
        isFalse,
      );
    });

    test('does not track non-Exception command failures', () async {
      final events = <String>[];
      final executor = Executor('mamba', 'A command-line application.', [
        _PersistentGroup(events, [_StringThrowingCommand()]),
      ]).fake();

      await expectLater(
        executor.execute(['group', 'throwing']),
        throwsA('run failed'),
      );
      expect(events, ['pre:group']);
    });

    test('does not run post-hooks that throw Errors', () async {
      final events = <String>[];
      final executor = Executor('mamba', 'A command-line application.', [
        _PersistentGroup(events, [_FailingPostHookCommand(throwsError: true)]),
      ]).fake();

      expect(
        await executor.execute(['group', 'failing']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:group']);
    });

    test('does not run post-hooks', () async {
      final executor = Executor('mamba', 'A command-line application.', [
        _FailingPostHookCommand(),
      ]).fake();

      expect(await executor.execute(['failing']), isA<MambaSuccessResult>());
    });
  });

  group('persistent hooks', () {
    test('does not run persistent post-hooks that throw Errors', () async {
      final events = <String>[];
      final executor = Executor('mamba', 'A command-line application.', [
        _PersistentGroup(events, [
          _PersistentGroup(
            events,
            [_Command('serve')],
            errorPost: true,
            name: 'inner',
          ),
        ], name: 'outer'),
      ]).fake();

      expect(
        await executor.execute(['outer', 'inner', 'serve']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:outer', 'pre:inner']);
    });

    test('does not run persistent post-hooks', () async {
      final events = <String>[];
      final executor = Executor('mamba', 'A command-line application.', [
        _PersistentGroup(events, [
          _PersistentGroup(
            events,
            [_Command('serve')],
            failPost: true,
            name: 'inner',
          ),
        ], name: 'outer'),
      ]).fake();

      expect(
        await executor.execute(['outer', 'inner', 'serve']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:outer', 'pre:inner']);
    });

    test(
      'runs around descendant commands without ordinary command hooks',
      () async {
        final events = <String>[];
        final group = _PersistentGroup(events, [_Command('serve')]);
        final executor = Executor('mamba', 'A command-line application.', [
          group,
        ]).fake();

        await executor.execute(['group', 'serve']);

        expect(events, ['pre:group']);
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

final class _CompletionCommand extends CompletionCommand {
  @override
  String get name => 'completion';

  @override
  String get shortDescription => 'A completion command.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => registryMap.map['name'] as String;
}

final class _InputCommand extends Command {
  _InputCommand(this.name, {super.options, this.onRun});

  final void Function(ParsedNamedInputs)? onRun;

  @override
  final String name;

  @override
  String get shortDescription => 'A test input command.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    onRun?.call(inputs);
    return 'dry-run=${inputs.boolFlags?['dry-run']} '
        'verbose=${inputs.countFlags?['verbose']} '
        'config=${inputs.stringOptions?['config']}';
  }
}

final class _DefaultGroup extends GroupCommand {
  _DefaultGroup(super.commands, {required super.defaultSubCommandPath});

  @override
  final String name = 'group';

  @override
  String get shortDescription => 'A default command group.';
}

final class _HookCommand extends Command with HookRunner {
  _HookCommand(this.name, this.events);

  @override
  final String name;

  final List<String> events;

  @override
  String get shortDescription => 'A command with hooks.';

  @override
  void preRun(
    ProcessedStandardInput? input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {
    events.add('pre:$name');
  }

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    events.add('run:$name');
    return '';
  }

  @override
  Future<void> postRun(MambaReadContext context) async {
    events.add('post:$name');
  }
}

final class _StringThrowingCommand extends Command {
  @override
  String get name => 'throwing';

  @override
  String get shortDescription => 'A command that throws a string.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => throw 'run failed';
}

final class _FailingPostHookCommand extends Command with HookRunner {
  _FailingPostHookCommand({this.throwsError = false});

  final bool throwsError;

  @override
  String get name => 'failing';

  @override
  String get shortDescription => 'A command with a failing post-hook.';

  @override
  void preRun(
    ProcessedStandardInput? input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {}

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => '';

  @override
  void postRun(MambaReadContext context) {
    if (throwsError) throw StateError('cleanup failed');
    throw Exception('cleanup failed');
  }
}

final class _PersistentGroup extends GroupCommand with PersistentHookRunner {
  _PersistentGroup(
    this.events,
    super.commands, {
    this.failPost = false,
    this.errorPost = false,
    this.name = 'group',
  });

  final List<String> events;
  final bool failPost;
  final bool errorPost;

  @override
  final String name;

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
    if (errorPost) throw StateError('persistent cleanup failed');
    if (failPost) throw Exception('persistent cleanup failed');
    events.add('post:$name');
  }
}
