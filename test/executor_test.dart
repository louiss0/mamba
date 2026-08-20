import 'package:mamba/executor.dart';
import 'package:test/test.dart';

void main() {
  group('ExecutorFactory', () {
    final factory = ExecutorFactory('mamba', 'A command-line application.');

    test('creates a fake executor that returns a success result', () async {
      final Executor<ExecutionResult> executor = factory.fake();

      final result = await executor.execute([]);

      expect(result, isA<SuccessResult>());
      expect((result as SuccessResult).output, contains('mamba'));
    });

    test('creates a console executor', () {
      final Executor<void> executor = factory.create();

      expect(executor, isA<Executor<void>>());
    });

    test('returns a failure result when execution fails', () async {
      final result = await factory.fake().execute(['missing']);

      expect(result, isA<FailureResult>());
    });
  });
}
