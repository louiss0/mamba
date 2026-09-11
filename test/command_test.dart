import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

enum Format { text, json }

void main() {
  test('input declarations retain identity', () {
    final one = StringOption('one');
    final two = StringOption('two');
    expect(identical(one, two), isFalse);
  });

  test('input declarations expose output availability in their types', () {
    final optional = StringOption('optional');
    final required = StringOption.required('required');
    final defaulted = ChoiceOption.withDefault(
      'format',
      choices: Format.values,
      defaultValue: Format.text,
    );

    expect(optional, isA<OptionalInput<String>>());
    expect(required, isA<RequiredInput<String>>());
    expect(defaulted, isA<DefaultedInput<Format>>());
  });

  test('positionals expose presence constraints in their types', () {
    final mandatory = NormalPositional('source');
    final discretionary = NormalPositional.optional('destination');

    expect(mandatory, isA<MandatoryPositional<String>>());
    expect(discretionary, isA<DiscretionaryPositional<String?>>());
  });
}
