/// An unrecoverable error in a Mamba command-definition invariant.
class MambaRegistryError extends ArgumentError {
  new([super.message]);
  new value(super.value, [super.name, super.message]) : super.value();
  @override
  String toString() => 'MambaRegistryError: ${super.toString()}';
}

/// A recoverable failure that can be rendered to a user.
class MambaException implements Exception {
  new(this.message, {this.exitCode = 1}) {
    if (exitCode < 1 || exitCode > 255) {
      throw ArgumentError.value(
        exitCode,
        'exitCode',
        'must be between 1 and 255',
      );
    }
  }

  final String message;
  final int exitCode;

  @override
  String toString() => message;
}

class MambaIntegrationException extends MambaException {
  new(super.message, {super.exitCode});
}
