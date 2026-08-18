import 'package:arg_parser/context.dart';
import 'package:test/test.dart';

void main() {
  group('MambaContext', () {
    test('stores typed values under independent keys', () {
      final context = MambaContext();
      final firstName = MambaContextKey<String>();
      final lastName = MambaContextKey<String>();

      context.set(firstName, 'Ada');
      context.set(lastName, 'Lovelace');

      expect(context.get(firstName), 'Ada');
      expect(context.get(lastName), 'Lovelace');
      expect(context.get(MambaContextKey<String>()), isNull);
    });

    test('replaces a value stored under the same key', () {
      final context = MambaContext();
      final count = MambaContextKey<int>();

      context.set(count, 1);
      context.set(count, 2);

      expect(context.get(count), 2);
    });
  });

  group('MambaReadContext', () {
    test('reads current values from its mutable context', () {
      final context = MambaContext();
      final key = MambaContextKey<String>();
      final readContext = MambaReadContext(context);

      context.set(key, 'before');
      expect(readContext.get(key), 'before');

      context.set(key, 'after');
      expect(readContext.get(key), 'after');
    });
  });
}
