/// An unrecoverable error in a Mamba command-definition invariant.
class MambaRegistryError extends ArgumentError {
  MambaRegistryError([super.message]);

  MambaRegistryError.value(Object? value, [String? name, String? message])
    : super.value(value, name, message);

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
