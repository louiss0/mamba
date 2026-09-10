import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('context is keyed by identity', () {
    final key = MambaContextKey<String>();
    final context = MambaContext()..set(key, 'value');
    expect(context.get(key), 'value');
  });
}
