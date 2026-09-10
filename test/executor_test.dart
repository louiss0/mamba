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
  void preRun(ProcessedStandardInput? input, CommandInvocation invocation) {
    events.add('pre');
    expect(invocation.inputs.valueOf(enabled), isA<bool>());
  }

  @override
  String run(CommandInvocation invocation, List<String> args) {
    events.add('run');
    if (failRun) throw MambaException('run failed', exitCode: 7);
    return 'output';
  }

  @override
  void postRun(CommandInvocation invocation) {
    events.add('post');
    if (failPost) throw MambaException('post failed', exitCode: 9);
  }
}

final class Persistent extends GroupCommand with PersistentHookRunner {
  Persistent(this.events, super.commands, {this.failPost = false}) : super();
  final List<String> events;
  final bool failPost;
  @override
  String get name => 'group';
  @override
  String get shortDescription => 'Group.';
  @override
  void prePersistentRun(CommandInvocation invocation) =>
      events.add('pre-group');
  @override
  void postPersistentRun(CommandInvocation invocation) {
    events.add('post-group');
    if (failPost) throw MambaException('persistent failed', exitCode: 8);
  }
}

void main() {
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
  test('validates failure result invariants and exception codes', () {
    expect(() => MambaException('bad', exitCode: 0), throwsArgumentError);
    expect(
      () => MambaFailureResult(exitCode: 0, errors: []),
      throwsArgumentError,
    );
  });
}
