/// An unrecoverable error in a Mamba command-definition invariant.
class MambaRegistryError extends ArgumentError {
  MambaRegistryError([super.message]);

  MambaRegistryError.value(super.value, [super.name, super.message])
    : super.value();

  @override
  String toString() => 'MambaRegistryError: ${super.toString()}';
}

/// A recoverable Mamba failure reported by parsing or command selection.
class MambaException implements Exception {
  const MambaException(this.message);

  final String message;

  @override
  String toString() => "$runtimeType $message";
}

/// A command failure accompanied by one or more failures while unwinding hooks.
///
/// [primaryFailure] is the failure from setup or command execution, when one
/// occurred. [cleanupFailures] preserves every exception raised by entered
/// hooks, in the order in which cleanup was attempted.
final class MambaExecutionException extends MambaException {
  MambaExecutionException({
    this.primaryFailure,
    required Iterable<Exception> cleanupFailures,
  }) : cleanupFailures = List.unmodifiable(cleanupFailures),
       super(_message(primaryFailure, cleanupFailures));

  final Exception? primaryFailure;
  final List<Exception> cleanupFailures;

  static String _message(
    Exception? primaryFailure,
    Iterable<Exception> cleanupFailures,
  ) {
    final failures = cleanupFailures.toList();
    return [
      if (primaryFailure != null) 'Execution failed: $primaryFailure.',
      'Cleanup failed ${failures.length} time${failures.length == 1 ? '' : 's'}: '
          '${failures.join('; ')}',
    ].join(' ');
  }
}

/// A non-recoverable execution failure that preserves every phase failure.
///
/// The original non-Exception primary failure, when present, remains available
/// through [primaryFailure]. Cleanup failures are retained in cleanup order.
final class MambaExecutionError extends Error {
  MambaExecutionError({
    this.primaryFailure,
    required Iterable<Object> cleanupFailures,
  }) : cleanupFailures = List.unmodifiable(cleanupFailures);

  final Object? primaryFailure;
  final List<Object> cleanupFailures;

  @override
  String toString() {
    final failures = [
      if (primaryFailure != null) 'Execution failed: $primaryFailure.',
      if (cleanupFailures.isNotEmpty)
        'Cleanup failed ${cleanupFailures.length} time${cleanupFailures.length == 1 ? '' : 's'}: ${cleanupFailures.join('; ')}',
    ];
    return 'MambaExecutionError: ${failures.join(' ')}';
  }
}

/// A failure while validating or producing an external integration artifact.
class MambaIntegrationException extends MambaException {
  const MambaIntegrationException(super.message);
}
