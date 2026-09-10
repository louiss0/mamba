import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import '../fixtures/rig/rig.dart';

enum Mode { json, text }

void main() {
  test('completion converters consume uniqueness metadata', () {
    final record = CommandRegistry.create(
      'tool',
      'Tool.',
      options: [
        RepeatableChoiceOption<Mode>('format', Mode.values, unique: true),
      ],
    ).toMap();
    expect(
      ToFishCompletionConverter(record).convert(),
      contains('__mamba_unique_choices format _ json text'),
    );
    expect(CarapaceSpecConverter(record).convert(), contains('format'));
  });

  test('Carapace preserves selected option exclusivity', () {
    final record = CommandRegistry.create(
      'tool',
      'Tool.',
      selectedOptions: [
        SelectedOptions<String>([
          SelectableOption(PairStringOption('json'), (value) => value),
          SelectableOption(PairStringOption('text'), (value) => value),
        ]),
      ],
    ).toMap();
    final completion = CarapaceSpecConverter(record).convert();
    expect(completion, contains('exclusiveflags:'));
    expect(completion, contains('- - "json"'));
    expect(completion, contains('- "text"'));
  });

  test('checked-in rig completions match generated artifacts', () {
    final record = CommandRegistry.create(
      'rig',
      'Completion fixture.',
      options: [RigCommand.format],
    ).toMap();
    final completions = <String, String>{
      'rig.bash': ToBashCompletionConverter(record).convert(),
      '_rig': ToZshCompletionConverter(record).convert(),
      'rig.fish': ToFishCompletionConverter(record).convert(),
      'rig.ps1': ToPowerShellCompletionConverter(record).convert(),
      'rig.yaml': CarapaceSpecConverter(record).convert(),
    };
    for (final entry in completions.entries) {
      expect(
        File('fixtures/rig/completions/${entry.key}').readAsStringSync(),
        entry.value,
        reason: 'Regenerate fixtures/rig/completions/${entry.key}.',
      );
    }
  });
}
