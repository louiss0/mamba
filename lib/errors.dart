/// An unrecoverable error in a Mamba command-definition invariant.
class MambaRegistryError extends ArgumentError {
  new([super.message]);

  new value(super.value, [super.name, super.message]) : super.value();

  @override
  String toString() => 'MambaRegistryError: ${super.toString()}';
}

/// A recoverable Mamba failure reported by parsing or command selection.
class const MambaException(final String message) implements Exception {
  @override
  String toString() => "$runtimeType $message";
}

/// A failure while validating or producing an external integration artifact.
class const MambaIntegrationException(super.message) extends MambaException;
