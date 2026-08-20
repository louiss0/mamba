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
}
