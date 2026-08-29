import 'package:mamba/errors.dart';
import 'package:mamba/parser.dart';
import 'package:test/test.dart';

void main() {
  group('MambaRegistryError', () {
    test('preserves ArgumentError diagnostics', () {
      final error = MambaRegistryError.value('bad', 'name', 'is invalid');

      expect(error, isA<ArgumentError>());
      expect(error.invalidValue, 'bad');
      expect(error.name, 'name');
    });
  });

  group('MambaException', () {
    test('formats its runtime type and message', () {
      expect(MambaException('failed').toString(), 'MambaException failed');
      expect(
        MambaParseException('invalid').toString(),
        'MambaParseException invalid',
      );
    });
  });
}
