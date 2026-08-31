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

/// A failure while validating or producing an external integration artifact.
class MambaIntegrationException extends MambaException {
  const MambaIntegrationException(super.message);
}
