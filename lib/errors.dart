class MambaRegistryError extends Error {
  final String message;

  MambaRegistryError(this.message);
}

class MambaException implements Exception {
  const MambaException(this.message);

  final String message;

  @override
  String toString() => "$runtimeType $message";
}

final class MambaInvalidChoiceException<T> extends MambaException {
  MambaInvalidChoiceException(Iterable<T> choices, T invalidChoice)
    : super(
        "Invalid choice '$invalidChoice'. "
        "Expected one of: ${choices.join(', ')}.",
      );
}
