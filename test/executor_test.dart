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
    final factory = Executor(
      'mamba',
      'A command-line application.',
      '1.0.0',
      [],
    );

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
    test('receive the complete root record when nested', () async {
      final completion = _CompletionCommand();
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _DefaultGroup([completion], defaultSubCommandPath: ['completion']),
        ],
      ).fake();

      final result = await executor.execute(['group']);

      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, 'mamba');
      final commands = completion.registryRecord.commands!;
      final group = commands.singleWhere((command) => command.name == 'group');
      expect(
        group.commands!.any((command) => command.name == 'completion'),
        isTrue,
      );
    });
  });

  group('global inputs', () {
    test('leaves -n available for application inputs', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        options: [StringOption('name', short: 'n')],
        [_InputCommand('run')],
      ).fake();

      final result = await executor.execute(['run', '-n', 'demo']);

      expect(result, isA<MambaSuccessResult>());
    });

    test('parses built-in and custom root inputs for a command', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
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
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _InputCommand(
            'run',
            onRun: (inputs) => received.addAll(inputs.boolFlags ?? {}),
          ),
        ],
      ).fake();

      final result = await executor.execute(['run']);

      expect(result, isA<MambaSuccessResult>());
      expect(received, isNot(contains('help')));
    });

    test('ignores options after help once the command is known', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [_InputCommand('run')],
      ).fake();

      final result = await executor.execute(['run', '--help', '--unknown']);

      expect(result, isA<MambaSuccessResult>());
      expect(
        _withoutAnsi((result as MambaSuccessResult).output!),
        startsWith('mamba run'),
      );
    });

    test('resolves command help after a value-taking option', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _InputCommand(
            'run',
            options: [StringOption('config', regex: RegExp(r'\S+'))],
          ),
        ],
      ).fake();

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

  group('version reporting', () {
    group('valid Semantic Version 2.0.0 values', () {
      for (final version in [
        '0.0.0',
        '1.2.3',
        '1.2.3-rc.1',
        '1.2.3-alpha-1.9',
        '1.2.3-0+001',
        '1.2.3+build.42',
        '1.2.3-rc.1+build.42',
      ]) {
        test('accepts $version', () {
          expect(
            () => Executor('mamba', 'A command-line application.', version, []),
            returnsNormally,
          );
        });
      }
    });

    group('invalid versions', () {
      for (final version in [
        '',
        'v1.2.3',
        '1.2',
        '01.2.3',
        '1.02.3',
        '1.2.03',
        '1.2.3-',
        '1.2.3-01',
        '1.2.3-alpha..1',
        '1.2.3+build..42',
        '1.2.3+build_42',
      ]) {
        test('rejects $version', () {
          expect(
            () => Executor('mamba', 'A command-line application.', version, []),
            throwsA(
              isA<MambaRegistryError>().having(
                (error) => error.message,
                'message',
                contains('Semantic Version 2.0.0'),
              ),
            ),
          );
        });
      }
    });

    test(
      'prints the configured version without running the selected command',
      () async {
        var ran = false;
        final executor = Executor(
          'mamba',
          'A command-line application.',
          '1.2.3-rc.1+build.42',
          [_InputCommand('run', onRun: (_) => ran = true)],
        ).fake();

        final result = await executor.execute(['run', '--version']);

        expect(result, isA<MambaSuccessResult>());
        expect(
          (result as MambaSuccessResult).output,
          'mamba 1.2.3-rc.1+build.42',
        );
        expect(ran, isFalse);
      },
    );

    test('accepts version before or after a command before --', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [_InputCommand('run')],
      ).fake();

      for (final arguments in [
        ['--version', 'run'],
        ['run', '--version'],
      ]) {
        final result = await executor.execute(arguments);

        expect(
          result,
          isA<MambaSuccessResult>().having(
            (value) => value.output,
            'output',
            'mamba 1.2.3',
          ),
        );
      }
    });

    test('does not treat --version after -- as a framework flag', () async {
      var receivedVersion = true;
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [
          _InputCommand(
            'run',
            onRun: (inputs) =>
                receivedVersion = inputs.boolFlags?['version'] == true,
          ),
        ],
      ).fake();

      final result = await executor.execute(['run', '--', '--version']);

      expect(result, isA<MambaSuccessResult>());
      expect(receivedVersion, isFalse);
    });

    test('exposes version false to ordinary command runs', () async {
      bool? receivedVersion;
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [
          _InputCommand(
            'run',
            onRun: (inputs) => receivedVersion = inputs.boolFlags?['version'],
          ),
        ],
      ).fake();

      await executor.execute(['run']);

      expect(receivedVersion, isFalse);
    });

    test('prints version before selected help in either flag order', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [_InputCommand('run')],
      ).fake();

      for (final arguments in [
        ['--version', 'run', '--help'],
        ['run', '--help', '--version'],
      ]) {
        final result = await executor.execute(arguments);
        final output = _withoutAnsi((result as MambaSuccessResult).output!);

        expect(output, startsWith('mamba 1.2.3\n\nmamba run'));
      }
    });

    test('ignores tokens after version but rejects tokens before it', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [_InputCommand('run')],
      ).fake();

      expect(
        await executor.execute(['--version', '--unknown']),
        isA<MambaSuccessResult>(),
      );
      expect(
        await executor.execute(['--unknown', '--version']),
        isA<MambaFailureResult>(),
      );
    });

    test('lists version in help and completion records', () async {
      final completion = _CompletionCommand();
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.2.3',
        [completion],
      ).fake();

      final result = await executor.execute(['--help']);

      expect((result as MambaSuccessResult).output, contains('--version'));
      expect(
        completion.registryRecord.flags!.any((flag) => flag.name == 'version'),
        isTrue,
      );
    });

    test('rejects application-defined version flags', () {
      expect(
        () => Executor(
          'mamba',
          'A command-line application.',
          '1.2.3',
          [],
          flags: [BooleanFlag('version')],
        ).fake(),
        throwsA(isA<MambaRegistryError>()),
      );
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
          '1.0.0',
          commands,
        );
        commands.add(_Command('later'));

        final result = await factory.fake().execute(['later']);

        expect(result, isA<MambaFailureResult>());
      },
    );

    test('rejects an empty root default path as a registry error', () {
      expect(
        () => Executor('mamba', 'A command-line application.', '1.0.0', [
          _Command('run'),
        ], defaultCommandPath: []),
        throwsA(isA<MambaRegistryError>()),
      );
    });
    test('applies a root default after a value-taking option', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
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
        final executor = Executor(
          'mamba',
          'A command-line application.',
          '1.0.0',
          [
            _DefaultGroup(
              [_Command('serve')],
              defaultSubCommandPath: ['serve'],
            ),
          ],
        ).fake();

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
        '1.0.0',
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
        final executor = Executor(
          'mamba',
          'A command-line application.',
          '1.0.0',
          [
            _DefaultGroup(
              [_HookCommand('serve', events)],
              defaultSubCommandPath: ['serve'],
            ),
          ],
        ).fake();

        final result = await executor.execute(['group']);

        expect(result, isA<MambaSuccessResult>());
        expect(events, ['pre:serve', 'run:serve']);
      },
    );

    test('returns a failure for an unknown group default path', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _DefaultGroup(
            [_Command('serve')],
            defaultSubCommandPath: ['missing'],
          ),
        ],
      ).fake();

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
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _PersistentGroup(events, [_StringThrowingCommand()]),
        ],
      ).fake();

      await expectLater(
        executor.execute(['group', 'throwing']),
        throwsA('run failed'),
      );
      expect(events, ['pre:group']);
    });

    test('does not run post-hooks that throw Errors', () async {
      final events = <String>[];
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _PersistentGroup(events, [
            _FailingPostHookCommand(throwsError: true),
          ]),
        ],
      ).fake();

      expect(
        await executor.execute(['group', 'failing']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:group']);
    });

    test('does not run post-hooks', () async {
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [_FailingPostHookCommand()],
      ).fake();

      expect(await executor.execute(['failing']), isA<MambaSuccessResult>());
    });
  });

  group('persistent hooks', () {
    test('does not run persistent post-hooks that throw Errors', () async {
      final events = <String>[];
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _PersistentGroup(events, [
            _PersistentGroup(
              events,
              [_Command('serve')],
              errorPost: true,
              name: 'inner',
            ),
          ], name: 'outer'),
        ],
      ).fake();

      expect(
        await executor.execute(['outer', 'inner', 'serve']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:outer', 'pre:inner']);
    });

    test('does not run persistent post-hooks', () async {
      final events = <String>[];
      final executor = Executor(
        'mamba',
        'A command-line application.',
        '1.0.0',
        [
          _PersistentGroup(events, [
            _PersistentGroup(
              events,
              [_Command('serve')],
              failPost: true,
              name: 'inner',
            ),
          ], name: 'outer'),
        ],
      ).fake();

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
        final executor = Executor(
          'mamba',
          'A command-line application.',
          '1.0.0',
          [group],
        ).fake();

        await executor.execute(['group', 'serve']);

        expect(events, ['pre:group']);
      },
    );
  });
}

final class _Command extends Command {
  new(this.name);

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
  ) => registryRecord.name;
}

final class _InputCommand extends Command {
  new(this.name, {super.options, this.onRun});

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
  new(super.commands, {required super.defaultSubCommandPath});

  @override
  final String name = 'group';

  @override
  String get shortDescription => 'A default command group.';
}

final class _HookCommand extends Command with HookRunner {
  new(this.name, this.events);

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
  new({this.throwsError = false});

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
  new(
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
