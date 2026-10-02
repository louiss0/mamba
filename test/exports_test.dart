// Verifies that the packages Mamba re-exports are reachable through
// `package:mamba/mamba.dart` alone, which is how an application imports it.
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('re-exports the terminal UI toolkit applications prompt with', () {
    expect(terminice, isA<Terminice>());
    expect(terminice.confirm, isA<Function>());
  });

  test('re-exports the styling and serialization packages', () {
    expect(chalk, isA<Chalk>());
    expect(YamlWriter, isNotNull);
  });
}
