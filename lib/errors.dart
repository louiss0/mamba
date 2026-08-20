/// An unrecoverable error in a Mamba command-definition invariant.
class MambaRegistryError extends Error {
  final String message;

  MambaRegistryError(this.message);
}

/// A recoverable Mamba failure reported by parsing or command selection.
class MambaException implements Exception {
  const MambaException(this.message);

  final String message;

  @override
  String toString() => "$runtimeType $message";
}
