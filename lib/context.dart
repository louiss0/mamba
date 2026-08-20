/// A typed identity token for a value stored in [MambaContext].
///
/// Create and share the same key instance between the code that writes a value
/// and the code that reads it.
class MambaContextKey<T> {}

/// Mutable global state shared by persistent hooks during an execution.
class MambaContext {
  final Map<MambaContextKey<dynamic>, dynamic> _values = {};

  /// Associates [value] with its typed [key].
  void set<T>(MambaContextKey<T> key, T value) {
    _values[key] = value;
  }

  /// Returns the value associated with [key], if one has been set.
  T? get<T>(MambaContextKey<T> key) {
    return _values[key] as T?;
  }
}

/// A read-only view of a [MambaContext] supplied to ordinary command hooks.
class MambaReadContext {
  MambaReadContext(this._context);

  final MambaContext _context;

  /// Returns the value associated with [key], if one has been set.
  T? get<T>(MambaContextKey<T> key) {
    return _context.get(key);
  }
}
