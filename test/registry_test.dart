import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

enum Mode { json, text }

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

  test('registry validates selected member definitions', () {
    final selected = SelectedOptions<String>([
      SelectableOption(
        PairChoiceOption<Mode>('format', choices: const []),
        (Mode value) => value.name,
      ),
    ]);
    expect(
      () =>
          CommandRegistry.create('tool', 'Tool.', selectedOptions: [selected]),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test('registry rejects empty option groups', () {
    expect(
      () => CommandRegistry.create(
        'tool',
        'Tool.',
        pairedOptions: [PairedOptions([])],
      ),
      throwsA(isA<MambaRegistryError>()),
    );
    expect(
      () => CommandRegistry.create(
        'tool',
        'Tool.',
        selectedOptions: [SelectedOptions<String>([])],
      ),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test('registry validates choices in accessor branches', () {
    expect(
      () => CommandRegistry.create(
        'tool',
        'Tool.',
        accessors: [
          AccessorListOption('server', [
            AccessorChoiceOption<Mode>('format', choices: const []),
          ]),
        ],
      ),
      throwsA(isA<MambaRegistryError>()),
    );
  });
}
