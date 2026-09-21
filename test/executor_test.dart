import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

String _withoutAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

final class ResultCommand extends Command with HookRunner {
  new(
    this.events, {
    this.failPre = false,
    this.failRun = false,
    this.failPost = false,
  }) : super(flags: [enabled]);
  static final enabled = BooleanFlag('enabled');
  final List<String> events;
  final bool failPre;
  final bool failRun;
  final bool failPost;
  @override
  String get name => 'run';
  @override
  String get shortDescription => 'Runs.';
  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    events.add('pre');
    if (failPre) throw Exception('pre failed');
    expect(inputs.valueOf(enabled), isA<bool>());
  }

  @override
  String run(ParsedInputs inputs, List<String> args) {
    events.add('run');
    if (failRun) throw MambaException('run failed', exitCode: 7);
    return 'output';
  }

  @override
  void postRun(ParsedInputs inputs, MambaReadContext context) {
    events.add('post');
    if (failPost) throw MambaException('post failed', exitCode: 9);
  }
}

final class Persistent extends GroupCommand with PersistentHookRunner {
  new(
    this.events,
    super.commands, {
    this.failPre = false,
    this.failPost = false,
  }) : super();
  final List<String> events;
  final bool failPre;
  final bool failPost;
  @override
  String get name => 'group';
  @override
  String get shortDescription => 'Group.';
  @override
  void prePersistentRun(ParsedInputs inputs, MambaContext context) {
    events.add('pre-group');
    if (failPre) throw MambaException('persistent pre failed', exitCode: 6);
  }

  @override
  void postPersistentRun(ParsedInputs inputs, MambaContext context) {
    events.add('post-group');
    if (failPost) throw MambaException('persistent failed', exitCode: 8);
  }
}

final _contextValue = MambaContextKey<String>();

final class ContextReader extends Command with HookRunner {
  @override
  String get name => 'read';
  @override
  String get shortDescription => 'Reads hook context.';

  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  void postRun(ParsedInputs inputs, MambaReadContext context) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  String? run(ParsedInputs inputs, List<String> args) => null;
}

final class ContextWriter extends GroupCommand with PersistentHookRunner {
  new(super.commands) : super();
  @override
  String get name => 'context';
  @override
  String get shortDescription => 'Writes hook context.';

  @override
  void prePersistentRun(ParsedInputs inputs, MambaContext context) {
    context.set(_contextValue, const MambaContextString('available'));
  }

  @override
  void postPersistentRun(ParsedInputs inputs, MambaContext context) {
    expect(context.get(_contextValue), 'available');
    context.set(_contextValue, const MambaContextString('replaced'));
  }
}

final class RetainingContextWriter extends GroupCommand
    with PersistentHookRunner {
  new(super.commands) : super();
  @override
  String get name => 'retaining';
  @override
  String get shortDescription => 'Retains hook context.';

  @override
  void prePersistentRun(ParsedInputs inputs, MambaContext context) {
    if (context.get(_contextValue) == null) {
      context.set(_contextValue, const MambaContextString('available'));
    }
  }
}

final class DefaultPostHookCommand extends Command with HookRunner {
  @override
  String get name => 'default-post';

  @override
  String get shortDescription => 'Uses the default post-run hook.';

  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  String run(ParsedInputs inputs, List<String> args) => 'complete';
}

final class NoOutputCommand extends Command {
  @override
  String get name => 'silent';

  @override
  String get shortDescription => 'Produces no output.';

  @override
  String? run(ParsedInputs inputs, List<String> args) => null;
}

final class DefaultCommand extends Command {
  new(this.events);
  final List<String> events;
  @override
  String get name => 'default';

  @override
  String get shortDescription => 'Runs by default.';

  @override
  List<String> get aliases => ['d'];

  @override
  String run(ParsedInputs inputs, List<String> args) {
    events.add('run');
    return 'default output';
  }
}

final class InputCommand extends Command with HookRunner {
  new(this.input);
  final ProcessedStandardInput input;
  @override
  String get name => 'input';

  @override
  String get shortDescription => 'Reads standard input.';

  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    expect(input?.utf8Text, this.input.utf8Text);
  }

  @override
  String? run(ParsedInputs inputs, List<String> args) => null;
}

final class RecordingProcess implements MambaProcess {
  new({this.input});
  final ProcessedStandardInput? input;
  final output = <String>[];
  final errors = <String>[];
  int? exitCode;

  @override
  Future<ProcessedStandardInput?> readStandardInput() async => input;

  @override
  void writeError(String message) => errors.add(message);

  @override
  void writeOutput(String message) => output.add(message);

  @override
  set processExitCode(int value) => exitCode = value;
}

final class InvalidContextWriter extends GroupCommand
    with PersistentHookRunner {
  new() : super([ResultCommand(<String>[])]);
  @override
  String get name => 'invalid';
  @override
  String get shortDescription => 'Writes invalid hook context.';

  @override
  void prePersistentRun(ParsedInputs inputs, MambaContext context) {
    final dynamic rawKey = _contextValue;
    context.set(rawKey, const MambaContextBool(true));
  }
}

final class GlobalAccessorCommand extends Command {
  new(this.configuration);

  final AccessorListOption configuration;

  @override
  String get name => 'read-config';

  @override
  String get shortDescription => 'Reads global configuration.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final values = inputs.valueOf(configuration);
    return values['host'] as String;
  }
}

void main() {
  group('MambaException', () {
    test('uses a portable default exit code', () {
      expect(MambaException('failure').exitCode, 1);
    });
  });

  group('Command hooks', () {
    test('allows the default post-run hook', () async {
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        DefaultPostHookCommand(),
      ]).fake().execute(['default-post']);

      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          'complete',
        ),
      );
    });
  });

  test('persistent hooks provide read-only context to command hooks', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ContextWriter([ContextReader()]),
    ]).fake().execute(['context', 'read']);

    expect(result, isA<MambaSuccessResult>());
  });

  test('persistent post-hooks can replace supported context values', () async {
    final context = MambaContext();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ContextWriter([ContextReader()]),
    ], context: context).fake().execute(['context', 'read']);

    expect(result, isA<MambaSuccessResult>());
    expect(context.get(_contextValue), 'replaced');
  });

  test('reusing an executor retains supported context values', () async {
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      RetainingContextWriter([ContextReader()]),
    ]).fake();

    expect(
      await executor.execute(['retaining', 'read']),
      isA<MambaSuccessResult>(),
    );
    expect(
      await executor.execute(['retaining', 'read']),
      isA<MambaSuccessResult>(),
    );
  });

  test('developer errors escape execution', () async {
    final execution = Executor('tool', 'Tool.', '1.0.0', [
      InvalidContextWriter(),
    ]).fake().execute(['invalid', 'run']);

    await expectLater(execution, throwsArgumentError);
  });

  test('success has zero exit code and runs eligible hooks', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(events),
    ]).fake().execute(['run']);
    expect(result, isA<MambaSuccessResult>());
    expect(result.exitCode, 0);
    expect(events, ['pre', 'run', 'post']);
  });
  test(
    'retains output and collects cleanup failures after command success',
    () async {
      final events = <String>[];
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ResultCommand(events, failPost: true),
      ]).fake().execute(['run']);
      expect(
        result,
        isA<MambaFailureResult>()
            .having((value) => value.output, 'output', 'output')
            .having((value) => value.exitCode, 'exit code', 9)
            .having(
              (value) => value.errors.single.phase,
              'error phase',
              MambaExecutionPhase.postRun,
            ),
      );
    },
  );
  test('preserves first command exit code while completing cleanup', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        ResultCommand(events, failRun: true, failPost: true),
      ], failPost: true),
    ]).fake().execute(['group', 'run']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.exitCode, 'exit code', 7)
          .having(
            (value) => value.errors.map((error) => error.phase),
            'error phases',
            [
              MambaExecutionPhase.run,
              MambaExecutionPhase.postRun,
              MambaExecutionPhase.postPersistentRun,
            ],
          ),
    );
    expect(events, ['pre-group', 'pre', 'run', 'post', 'post-group']);
  });
  test('only cleans up persistent hooks whose pre-hook completed', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        Persistent(events, [ResultCommand(events)], failPre: true),
      ]),
    ]).fake().execute(['group', 'group', 'run']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.exitCode, 'exit code', 6)
          .having(
            (value) => value.errors.map((error) => error.phase),
            'error phases',
            [MambaExecutionPhase.prePersistentRun],
          ),
    );
    expect(events, ['pre-group', 'pre-group', 'post-group']);
  });

  test('validates failure result invariants and exception codes', () {
    expect(() => MambaException('bad', exitCode: 0), throwsArgumentError);
    expect(
      () => MambaFailureResult(exitCode: 0, errors: []),
      throwsArgumentError,
    );
    expect(
      () => MambaFailureResult(
        exitCode: 1,
        errors: const <MambaExecutionError>[],
      ),
      throwsArgumentError,
    );
  });

  test('renders the application version without running a command', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.2.3', [
      ResultCommand(events),
    ]).fake().execute(['--version']);
    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => value.output,
        'output',
        'tool 1.2.3',
      ),
    );
    expect(events, isEmpty);
  });

  test('renders application help with the version', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.2.3',
      const [],
    ).fake().execute(['--help', '--version']);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => _withoutAnsi(value.output!),
        'output',
        startsWith('tool 1.2.3\n\ntool'),
      ),
    );
  });

  test('reports the resolved command path for parse failures', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(<String>[], [ResultCommand(<String>[])]),
    ]).fake().execute(['group', 'run', '--unknown']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having(
            (value) => value.errors.single.phase,
            'error phase',
            MambaExecutionPhase.parse,
          )
          .having((value) => value.errors.single.commandPath, 'error path', [
            'tool',
            'group',
            'run',
          ]),
    );
  });

  test('rejects versions that are not semantic versions', () {
    expect(
      () => Executor('tool', 'Tool.', '1.2', const []),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test('uses its default command when no arguments are supplied', () async {
    final events = <String>[];
    final result = await Executor(
      'tool',
      'Tool.',
      '1.0.0',
      [DefaultCommand(events)],
      defaultCommandPath: ['default'],
    ).fake().execute([]);

    expect(result, isA<MambaSuccessResult>());
    expect(events, ['run']);
  });

  test('renders help when no command is selected', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.0.0',
      const [],
    ).fake().execute([]);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => _withoutAnsi(value.output!),
        'output',
        startsWith('tool'),
      ),
    );
  });

  test('records non-Mamba hook errors', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(<String>[], failPre: true),
    ]).fake().execute(['run']);

    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.message, 'message', 'Exception: pre failed')
          .having(
            (value) => value.errors.single.phase,
            'error phase',
            MambaExecutionPhase.preRun,
          ),
    );
  });

  test('runs commands selected by an alias', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      DefaultCommand(events),
    ]).fake().execute(['d']);

    expect(result, isA<MambaSuccessResult>());
    expect(events, ['run']);
  });

  test('makes executor accessors available to commands', () async {
    final configuration = AccessorListOption('config', [
      AccessorStringOption.required('host'),
    ]);
    final executor = Executor(
      'tool',
      'Tool.',
      '1.0.0',
      [GlobalAccessorCommand(configuration)],
      accessors: [configuration],
    ).fake();

    for (final arguments in [
      ['--config.host', 'localhost', 'read-config'],
      ['read-config', '--config.host', 'localhost'],
    ]) {
      final result = await executor.execute(arguments);

      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          'localhost',
        ),
      );
    }
  });

  test('assigns completion commands their root registry', () {
    final completion = CompletionCommand(createFile: (_) {});

    Executor('tool', 'Tool.', '1.0.0', [completion]).fake();

    expect(completion.registryRecord.name, 'tool');
  });

  test(
    'creates the system process adapter without accessing process streams',
    () {
      final executor = Executor('tool', 'Tool.', '1.0.0', const []).create();

      expect(executor, isA<MambaExecutor<void>>());
    },
  );

  test('delivers production results through an injected process', () async {
    final process = RecordingProcess();
    await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(<String>[]),
    ]).create(process: process).execute(['run']);

    expect(process.output, ['output']);
    expect(process.errors, isEmpty);
    expect(process.exitCode, isNull);
  });

  test('delivers production failures through an injected process', () async {
    final process = RecordingProcess();
    await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(<String>[], failPost: true),
    ]).create(process: process).execute(['run']);

    expect(process.output, ['output']);
    expect(process.errors, ['post failed']);
    expect(process.exitCode, 9);
  });

  test('delivers injected standard input to command hooks', () async {
    final process = RecordingProcess(
      input: const ProcessedStandardInput([104, 105]),
    );
    await Executor('tool', 'Tool.', '1.0.0', [
      InputCommand(const ProcessedStandardInput([104, 105])),
    ]).create(process: process).execute(['input']);

    expect(process.output, isEmpty);
    expect(process.errors, isEmpty);
  });

  test('identifies closed pipe errors without reading process streams', () {
    expect(
      isClosedPipeFileSystemException(
        FileSystemException('write', '', OSError('Broken pipe', 32)),
      ),
      isTrue,
    );
    expect(
      isClosedPipeFileSystemException(FileSystemException('write')),
      isFalse,
    );
  });

  test('does not write successful commands without output', () async {
    final process = RecordingProcess();
    await Executor('tool', 'Tool.', '1.0.0', [
      NoOutputCommand(),
    ]).create(process: process).execute(['silent']);

    expect(process.output, isEmpty);
    expect(process.errors, isEmpty);
  });
}
