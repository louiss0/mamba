import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('registry uses typed selection metadata', () {
    final selected = SelectedOptions<String>([
      SelectableOption(PairStringOption('json'), (String value) => value),
    ]);
    final record = CommandRegistry.create(
      'tool',
      'Tool.',
      selectedOptions: [selected],
    ).toMap();
    expect(record.optionGroups!.single.mode, RegistryOptionGroupMode.oneOf);
  });
}
