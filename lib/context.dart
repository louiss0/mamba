class MambaContextKey<T> {}

class MambaContext {
  final Map<MambaContextKey<dynamic>, dynamic> _values = {};

  void set<T>(MambaContextKey<T> key, T value) {
    _values[key] = value;
  }

  T? get<T>(MambaContextKey<T> key) {
    return _values[key] as T?;
  }
}

class MambaReadContext {
  MambaReadContext(this._context);

  final MambaContext _context;

  T? get<T>(MambaContextKey<T> key) {
    return _context.get(key);
  }
}
