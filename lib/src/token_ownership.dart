import 'package:mamba/command.dart';

/// Separate-form supply is syntax, never a content-validator decision.
bool ownsSeparateValue(InputDefinition input, String token) {
  if (token == '--') return false;
  if (!token.startsWith('-') || token == '-') return true;
  final numeric =
      input is NumericRangeValidated ||
      input is AccessorIntOption ||
      input is AccessorDoubleOption;
  return numeric && RegExp(r'^-[0-9]').hasMatch(token);
}
