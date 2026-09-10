import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('mamba exceptions use a portable default exit code', () {
    expect(MambaException('failure').exitCode, 1);
  });
}
