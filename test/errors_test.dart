import 'package:mamba/errors.dart';
import 'package:mamba/parser.dart';
import 'package:test/test.dart';

void main() {
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
