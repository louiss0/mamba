import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

final class ResultCommand extends Command with HookRunner {
  ResultCommand(this.events, {this.failRun = false, this.failPost = false})
    : super(flags: [enabled]);
  static final enabled = BooleanFlag('enabled');
  final List<String> events;
  final bool failRun;
  final bool failPost;
  @override
  String get name => 'run';
  @override
  String get shortDescription => 'Runs.';
  @override
  void preRun(
    CommandInvocation invocation,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    events.add('pre');
    expect(invocation.valueOf(enabled), isA<bool>());
  }

  @override
  String run(CommandInvocation invocation, List<String> args) {
    events.add('run');
    if (failRun) throw MambaException('run failed', exitCode: 7);
    return 'output';
  }

  @override
  void postRun(CommandInvocation invocation, MambaReadContext context) {
    events.add('post');
    if (failPost) throw MambaException('post failed', exitCode: 9);
  }
}

final class Persistent extends GroupCommand with PersistentHookRunner {
  Persistent(
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
  void prePersistentRun(CommandInvocation invocation, MambaContext context) {
    events.add('pre-group');
    if (failPre) throw MambaException('persistent pre failed', exitCode: 6);
  }

  @override
  void postPersistentRun(CommandInvocation invocation, MambaContext context) {
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
    CommandInvocation invocation,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  void postRun(CommandInvocation invocation, MambaReadContext context) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  String? run(CommandInvocation invocation, List<String> args) => null;
}

final class ContextWriter extends GroupCommand with PersistentHookRunner {
  ContextWriter(super.commands) : super();
  @override
  String get name => 'context';
  @override
  String get shortDescription => 'Writes hook context.';

  @override
  void prePersistentRun(CommandInvocation invocation, MambaContext context) {
    context.set(_contextValue, const MambaContextString('available'));
  }

  @override
  void postPersistentRun(CommandInvocation invocation, MambaContext context) {
    expect(context.get(_contextValue), 'available');
    context.set(_contextValue, const MambaContextString('replaced'));
  }
}

final class RetainingContextWriter extends GroupCommand
    with PersistentHookRunner {
  RetainingContextWriter(super.commands) : super();
  @override
  String get name => 'retaining';
  @override
  String get shortDescription => 'Retains hook context.';

  @override
  void prePersistentRun(CommandInvocation invocation, MambaContext context) {
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
    CommandInvocation invocation,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  String run(CommandInvocation invocation, List<String> args) => 'complete';
}

final class InvalidContextWriter extends GroupCommand
    with PersistentHookRunner {
  InvalidContextWriter() : super([ResultCommand(<String>[])]);
  @override
  String get name => 'invalid';
  @override
  String get shortDescription => 'Writes invalid hook context.';

  @override
  void prePersistentRun(CommandInvocation invocation, MambaContext context) {
    final dynamic rawKey = _contextValue;
    context.set(rawKey, const MambaContextBool(true));
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

      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, 'complete');
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
      ]).fake().execute(['run']) as MambaFailureResult;
      expect(result.output, 'output');
      expect(result.exitCode, 9);
      expect(result.errors.single.phase, MambaExecutionPhase.postRun);
    },
  );
  test('preserves first command exit code while completing cleanup', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        ResultCommand(events, failRun: true, failPost: true),
      ], failPost: true),
    ]).fake().execute(['group', 'run']) as MambaFailureResult;
    expect(result.exitCode, 7);
    expect(result.errors.map((error) => error.phase), [
      MambaExecutionPhase.run,
      MambaExecutionPhase.postRun,
      MambaExecutionPhase.postPersistentRun,
    ]);
    expect(events, ['pre-group', 'pre', 'run', 'post', 'post-group']);
  });
  test('only cleans up persistent hooks whose pre-hook completed', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        Persistent(events, [ResultCommand(events)], failPre: true),
      ]),
    ]).fake().execute(['group', 'group', 'run']) as MambaFailureResult;
    expect(result.exitCode, 6);
    expect(result.errors.map((error) => error.phase), [
      MambaExecutionPhase.prePersistentRun,
    ]);
    expect(events, ['pre-group', 'pre-group', 'post-group']);
  });

  test('validates failure result invariants and exception codes', () {
    expect(() => MambaException('bad', exitCode: 0), throwsArgumentError);
    expect(
      () => MambaFailureResult(exitCode: 0, errors: []),
      throwsArgumentError,
    );
  });

  test('renders the application version without running a command', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.2.3', [
      ResultCommand(events),
    ]).fake().execute(['--version']);
    expect(result, isA<MambaSuccessResult>());
    expect((result as MambaSuccessResult).output, 'tool 1.2.3');
    expect(events, isEmpty);
  });

  test('reports the resolved command path for parse failures', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(<String>[], [ResultCommand(<String>[])]),
    ]).fake().execute(['group', 'run', '--unknown']) as MambaFailureResult;
    expect(result.errors.single.phase, MambaExecutionPhase.parse);
    expect(result.errors.single.commandPath, ['tool', 'group', 'run']);
    expect(
      () => result.errors.single.commandPath.add('other'),
      throwsUnsupportedError,
    );
  });
}
