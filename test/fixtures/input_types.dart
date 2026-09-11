import 'package:mamba/mamba.dart';

enum Format { text, json }

void verifyInputOutputTypes(ParsedInputs inputs) {
  final optionalName = StringOption('name');
  final requiredName = StringOption.required('name');
  final format = ChoiceOption.withDefault(
    'format',
    choices: Format.values,
    defaultValue: Format.text,
  );
  final source = NormalPositional('source');
  final destination = NormalPositional.optional('destination');

  final String? optionalNameValue = inputs.valueOf(optionalName);
  final String requiredNameValue = inputs.valueOf(requiredName);
  final Format formatValue = inputs.valueOf(format);
  final String sourceValue = inputs.valueOf(source);
  final String? destinationValue = inputs.valueOf(destination);

  Object.hash(
    optionalNameValue,
    requiredNameValue,
    formatValue,
    sourceValue,
    destinationValue,
  );
}
