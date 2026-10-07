// Verifies that the packages Mamba re-exports are reachable through
// `package:mamba/mamba.dart` alone, which is how an application imports it.
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('re-exports the terminal UI toolkit applications prompt with', () {
    expect(ClixInput(prompt: 'Name'), isA<Prompt<String>>());
    expect(Confirm(prompt: 'Continue?'), isA<Prompt<bool>>());
    expect(SpinnerType.dots, isNotNull);
    expect(BooleanFlag('verbose'), isA<Input<bool>>());
  });

  test('re-exports the styling and serialization packages', () {
    expect(chalk, isA<Chalk>());
    expect(YamlWriter, isNotNull);
  });
}
