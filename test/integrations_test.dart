import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

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
      contains('not __mamba_seen_format'),
    );
    expect(CarapaceSpecConverter(record).convert(), contains('format'));
  });
}
