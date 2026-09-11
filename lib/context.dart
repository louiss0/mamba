/// A typed identity token for a scalar value stored in [MambaContext].
///
/// Create and share the same key instance between the code that writes a value
/// and the code that reads it. Keys are typed by the primitive returned from
/// [MambaContext.get].
class MambaContextKey<T extends Object> {
  const MambaContextKey();

  bool _accepts(MambaContextValue<Object> value) {
    if (T == String) return value is MambaContextString;
    if (T == bool) return value is MambaContextBool;
    if (T == int) return value is MambaContextInt;
    if (T == double) return value is MambaContextDouble;
    return false;
  }
}

/// A closed scalar value that can be stored in [MambaContext].
///
/// Applications cannot add context value variants. Use one of
/// [MambaContextString], [MambaContextBool], [MambaContextInt], or
/// [MambaContextDouble] to store hook state.
sealed class MambaContextValue<T extends Object> {
  const MambaContextValue(this.value);

  /// The scalar wrapped by this context value.
  final T value;
}

/// A [String] value stored in [MambaContext].
final class MambaContextString extends MambaContextValue<String> {
  const MambaContextString(super.value);
}

/// A [bool] value stored in [MambaContext].
final class MambaContextBool extends MambaContextValue<bool> {
  const MambaContextBool(super.value);
}

/// An [int] value stored in [MambaContext].
final class MambaContextInt extends MambaContextValue<int> {
  const MambaContextInt(super.value);
}

/// A [double] value stored in [MambaContext].
final class MambaContextDouble extends MambaContextValue<double> {
  const MambaContextDouble(super.value);
}

/// Mutable state scoped to an executor and shared by all of its executions.
///
/// Reusing an executor intentionally retains values between calls to
/// `execute`; create another executor when an isolated context is required.
/// Context is a scalar hook-state bag, not a dependency container. Environment
/// variables and configuration files remain application responsibilities.
class MambaContext {
  final Map<MambaContextKey<Object>, MambaContextValue<Object>> _values = {};

  /// Associates [value] with its typed [key].
  void set<T extends Object>(
    MambaContextKey<T> key,
    MambaContextValue<T> value,
  ) {
    if (!key._accepts(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'does not match the primitive type of the context key',
      );
    }
    _values[key] = value;
  }

  /// Returns the unwrapped primitive associated with [key], if one has been
  /// set. An unset key returns `null`; `null` cannot be stored.
  T? get<T extends Object>(MambaContextKey<T> key) {
    final value = _values[key];
    return value?.value as T?;
  }
}

/// A read-only view of a [MambaContext] supplied to ordinary command hooks.
class MambaReadContext(final MambaContext _context) {
  /// Returns the unwrapped primitive associated with [key], if one has been
  /// set.
  T? get<T extends Object>(MambaContextKey<T> key) {
    return _context.get(key);
  }
}
