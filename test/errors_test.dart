import 'package:arg_parser/errors.dart';
import 'package:arg_parser/parser.dart';
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
