import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('stores and retrieves supported scalar values', () {
    final stringKey = MambaContextKey<String>();
    final boolKey = MambaContextKey<bool>();
    final intKey = MambaContextKey<int>();
    final doubleKey = MambaContextKey<double>();
    final context = MambaContext();

    context.set(stringKey, const MambaContextString(''));
    context.set(boolKey, const MambaContextBool(true));
    context.set(intKey, const MambaContextInt(-12));
    context.set(doubleKey, const MambaContextDouble(3.5));

    expect(context.get(stringKey), '');
    context.set(stringKey, const MambaContextString('workspace'));
    expect(context.get(stringKey), 'workspace');
    expect(context.get(boolKey), isTrue);
    expect(context.get(intKey), -12);
    expect(context.get(doubleKey), 3.5);
  });

  test('supports false, zero, and non-finite doubles', () {
    final boolKey = MambaContextKey<bool>();
    final intKey = MambaContextKey<int>();
    final doubleKey = MambaContextKey<double>();
    final context = MambaContext();

    context.set(boolKey, const MambaContextBool(false));
    context.set(intKey, const MambaContextInt(0));
    context.set(doubleKey, const MambaContextDouble(double.nan));
    expect(context.get(boolKey), isFalse);
    expect(context.get(intKey), 0);
    expect(context.get(doubleKey)!.isNaN, isTrue);

    context.set(intKey, const MambaContextInt(42));
    expect(context.get(intKey), 42);
    context.set(doubleKey, const MambaContextDouble(double.infinity));
    expect(context.get(doubleKey), double.infinity);
    context.set(doubleKey, const MambaContextDouble(double.negativeInfinity));
    expect(context.get(doubleKey), double.negativeInfinity);
  });

  test('replaces values and keeps same-typed keys separate by identity', () {
    final firstKey = MambaContextKey<String>();
    final secondKey = MambaContextKey<String>();
    final context = MambaContext();

    context.set(firstKey, const MambaContextString('first'));
    context.set(secondKey, const MambaContextString('second'));
    context.set(firstKey, const MambaContextString('replaced'));

    expect(context.get(firstKey), 'replaced');
    expect(context.get(secondKey), 'second');
    expect(context.get(MambaContextKey<String>()), isNull);
  });

  test('returns null for an unset supported key', () {
    expect(MambaContext().get(MambaContextKey<String>()), isNull);
  });

  test('rejects unsupported dynamic writes without mutating state', () {
    final key = MambaContextKey<String>();
    final context = MambaContext();
    context.set(key, const MambaContextString('before'));
    final dynamic dynamicContext = context;

    expect(() => dynamicContext.set(key, Object()), throwsA(isA<TypeError>()));
    expect(context.get(key), 'before');
  });

  test('rejects mismatched wrappers supplied with a dynamic raw key', () {
    final key = MambaContextKey<String>();
    final context = MambaContext();
    context.set(key, const MambaContextString('before'));
    final dynamic dynamicContext = context;
    final dynamic rawKey = key;

    expect(
      () => dynamicContext.set(rawKey, const MambaContextBool(true)),
      throwsArgumentError,
    );
    expect(context.get(key), 'before');
  });
}
