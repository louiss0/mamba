import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

/// Metadata used by the parser, registry, help, and completion integrations.
abstract interface class InputDefinition {
  String get name;
  String? get description;
}

abstract interface class ParsedValue<T>;

/// An identity-based, typed handle for a parsed command value.
sealed class Input<T> implements InputDefinition, ParsedValue<T> {
  const Input();
}

abstract interface class RequiredInput<T> implements Input<T>;

abstract interface class OptionalInput<T> implements Input<T?>;

abstract interface class DefaultedInput<T> implements Input<T>;

mixin RegExpValidated {
  RegExp get regex;
  static final RegExp anyToken = RegExp(r'\S+');
}

mixin ChoiceValidated<T extends Enum> {
  List<T> get choices;
}

mixin NumericRangeValidated<T extends num> {
  T? get min;
  T? get max;
}

mixin NumericStepValidated {
  double? get step;
}

abstract interface class DefaultValue<T> {
  T get defaultValue;
}

List<T>? _copyList<T>(List<T>? items) =>
    items == null ? null : List.unmodifiable(items);

void _validateRepeatedTimes(int times) {
  if (times < 0) {
    throw MambaRegistryError.value(times, 'times', 'must not be negative');
  }
}

sealed class Positional<T> extends Input<T> with RegExpValidated {
  Positional(this.name, {this.description, RegExp? regex})
    : _regex = regex ?? RegExpValidated.anyToken;
  @override
  final String name;
  @override
  final String? description;
  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

sealed class MandatoryPositional<T> extends Positional<T>
    implements RequiredInput<T> {
  MandatoryPositional(super.name, {super.description, super.regex});
}

sealed class DiscretionaryPositional<T> extends Positional<T> {
  DiscretionaryPositional(super.name, {super.description, super.regex});
}

sealed class OptionalPositional<T> extends DiscretionaryPositional<T?>
    implements OptionalInput<T> {
  OptionalPositional(super.name, {super.description, super.regex});
}

sealed class DefaultedPositional<T> extends DiscretionaryPositional<T>
    implements DefaultedInput<T> {
  DefaultedPositional(super.name, {super.description, super.regex});
}

final class NormalPositional extends MandatoryPositional<String> {
  NormalPositional(super.name, {super.description, RegExp? regExp})
    : super(regex: regExp);

  static OptionalPositional<String> optional(
    String name, {
    String? description,
    RegExp? regExp,
  }) =>
      _OptionalNormalPositional(name, description: description, regex: regExp);
}

final class _OptionalNormalPositional extends OptionalPositional<String> {
  _OptionalNormalPositional(super.name, {super.description, super.regex});
}

final class ChoicePositional<T extends Enum> extends MandatoryPositional<T>
    with ChoiceValidated<T> {
  ChoicePositional(super.name, {super.description, required List<T> choices})
    : choices = List.unmodifiable(choices);

  static OptionalPositional<T> optional<T extends Enum>(
    String name, {
    String? description,
    required List<T> choices,
  }) => _OptionalChoicePositional(
    name,
    description: description,
    choices: choices,
  );

  static DefaultedPositional<T> withDefault<T extends Enum>(
    String name, {
    String? description,
    required List<T> choices,
    required T defaultValue,
  }) => _DefaultedChoicePositional(
    name,
    description: description,
    choices: choices,
    defaultValue: defaultValue,
  );

  @override
  final List<T> choices;
}

final class _OptionalChoicePositional<T extends Enum>
    extends OptionalPositional<T>
    with ChoiceValidated<T> {
  _OptionalChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
}

final class _DefaultedChoicePositional<T extends Enum>
    extends DefaultedPositional<T>
    with ChoiceValidated<T>
    implements DefaultValue<T> {
  _DefaultedChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    required this.defaultValue,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
  @override
  final T defaultValue;
}

abstract interface class RepeatedPositionalDefinition
    implements InputDefinition {
  int get times;
  Object freezeValues(List<Object> values);
}

sealed class RepeatedPositional<T> extends MandatoryPositional<List<T>>
    implements RepeatedPositionalDefinition {
  RepeatedPositional(
    super.name, {
    super.description,
    super.regex,
    this.times = 1,
  }) {
    _validateRepeatedTimes(times);
  }
  final int times;
  @override
  List<T> freezeValues(List<Object> values) =>
      List.unmodifiable(values.cast<T>());
}

final class RepeatedStringPositional extends RepeatedPositional<String> {
  RepeatedStringPositional(
    super.name, {
    super.description,
    RegExp? regExp,
    super.times = 1,
  }) : super(regex: regExp);

  static OptionalPositional<List<String>> optional(
    String name, {
    String? description,
    RegExp? regExp,
    int times = 1,
  }) => _OptionalRepeatedStringPositional(
    name,
    description: description,
    regex: regExp,
    times: times,
  );
}

final class _OptionalRepeatedStringPositional
    extends OptionalPositional<List<String>>
    implements RepeatedPositionalDefinition {
  _OptionalRepeatedStringPositional(
    super.name, {
    super.description,
    super.regex,
    this.times = 1,
  }) {
    _validateRepeatedTimes(times);
  }

  @override
  final int times;
  @override
  List<String> freezeValues(List<Object> values) =>
      List.unmodifiable(values.cast<String>());
}

final class RepeatedChoicePositional<T extends Enum>
    extends RepeatedPositional<T>
    with ChoiceValidated<T> {
  RepeatedChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    super.times = 1,
  }) : choices = List.unmodifiable(choices);

  static OptionalPositional<List<T>> optional<T extends Enum>(
    String name, {
    String? description,
    required List<T> choices,
    int times = 1,
  }) => _OptionalRepeatedChoicePositional(
    name,
    description: description,
    choices: choices,
    times: times,
  );

  static DefaultedPositional<List<T>> withDefault<T extends Enum>(
    String name, {
    String? description,
    required List<T> choices,
    required List<T> defaultValue,
    int times = 1,
  }) => _DefaultedRepeatedChoicePositional(
    name,
    description: description,
    choices: choices,
    defaultValue: defaultValue,
    times: times,
  );

  @override
  final List<T> choices;
}

final class _OptionalRepeatedChoicePositional<T extends Enum>
    extends OptionalPositional<List<T>>
    with ChoiceValidated<T>
    implements RepeatedPositionalDefinition {
  _OptionalRepeatedChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    this.times = 1,
  }) : choices = List.unmodifiable(choices) {
    _validateRepeatedTimes(times);
  }

  @override
  final List<T> choices;
  @override
  final int times;
  @override
  List<T> freezeValues(List<Object> values) =>
      List.unmodifiable(values.cast<T>());
}

final class _DefaultedRepeatedChoicePositional<T extends Enum>
    extends DefaultedPositional<List<T>>
    with ChoiceValidated<T>
    implements DefaultValue<List<T>>, RepeatedPositionalDefinition {
  _DefaultedRepeatedChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    required List<T> defaultValue,
    this.times = 1,
  }) : choices = List.unmodifiable(choices),
       defaultValue = List.unmodifiable(defaultValue) {
    _validateRepeatedTimes(times);
  }

  @override
  final List<T> choices;
  @override
  final List<T> defaultValue;
  @override
  final int times;
  @override
  List<T> freezeValues(List<Object> values) =>
      List.unmodifiable(values.cast<T>());
}

sealed class Variadic {
  const Variadic({this.description});
  final String? description;
}

final class NormalVariadic extends Variadic with RegExpValidated {
  NormalVariadic({super.description, RegExp? regExp})
    : regex = regExp ?? RegExpValidated.anyToken;
  final RegExp regex;
}

class ChoiceVariadic<T extends Enum> extends Variadic with ChoiceValidated<T> {
  ChoiceVariadic({
    super.description,
    required List<T> choices,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  final T? defaultValue;
}

sealed class Flag<T> extends Input<T> {
  const Flag(
    this.name, {
    required this.short,
    this.description,
    this.hidden = false,
  });
  @override
  final String name;
  final String? short;
  @override
  final String? description;
  final bool hidden;
}

final class BooleanFlag extends Flag<bool> implements DefaultedInput<bool> {
  const BooleanFlag(
    super.name, {
    super.short,
    super.description,
    super.hidden,
    this.defaultValue = false,
    this.negatable = false,
  });
  final bool defaultValue;
  final bool negatable;
}

final class CountFlag extends Flag<int> implements DefaultedInput<int> {
  const CountFlag(super.name, {super.short, super.description, super.hidden});
}

sealed class Option<T> extends Input<T> {
  const Option(
    this.name, {
    required this.short,
    this.description,
    this.isRequired = false,
    this.hidden = false,
  });
  @override
  final String name;
  final String? short;
  @override
  final String? description;
  final bool isRequired;
  final bool hidden;
}

sealed class SingleOption<T> extends Option<T> {
  const SingleOption(
    super.name, {
    required super.short,
    required super.description,
    super.isRequired,
    super.hidden,
  });
}

final class StringOption extends SingleOption<String?>
    with RegExpValidated
    implements OptionalInput<String> {
  StringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : _regex = regex ?? RegExpValidated.anyToken;

  static RequiredOption<String> required(
    String name, {
    RegExp? regex,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredStringOption(
    name,
    regex: regex,
    short: short,
    description: description,
    hidden: hidden,
  );

  static DefaultedOption<String> withDefault(
    String name, {
    required String defaultValue,
    RegExp? regex,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedStringOption(
    name,
    defaultValue: defaultValue,
    regex: regex,
    short: short,
    description: description,
    hidden: hidden,
  );

  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class _DefaultedStringOption extends DefaultedOption<String>
    with RegExpValidated
    implements DefaultValue<String> {
  _DefaultedStringOption(
    super.name, {
    required this.defaultValue,
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final String defaultValue;
  @override
  final RegExp regex;
}

sealed class RequiredOption<T> extends SingleOption<T>
    implements RequiredInput<T> {
  const RequiredOption(
    super.name, {
    super.short,
    super.description,
    super.hidden,
  }) : super(isRequired: true);
}

final class _RequiredStringOption extends RequiredOption<String>
    with RegExpValidated {
  _RequiredStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : _regex = regex ?? RegExpValidated.anyToken;

  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class IntOption extends SingleOption<int?>
    with NumericRangeValidated<int>
    implements OptionalInput<int> {
  const IntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });

  static RequiredOption<int> required(
    String name, {
    int? min,
    int? max,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredIntOption(
    name,
    min: min,
    max: max,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final int? min;
  static DefaultedOption<int> withDefault(
    String name, {
    required int defaultValue,
    int? min,
    int? max,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedIntOption(
    name,
    defaultValue: defaultValue,
    min: min,
    max: max,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final int? max;
}

final class _DefaultedIntOption extends DefaultedOption<int>
    with NumericRangeValidated<int>
    implements DefaultValue<int> {
  const _DefaultedIntOption(
    super.name, {
    required this.defaultValue,
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final int defaultValue;
  @override
  final int? min;
  @override
  final int? max;
}

final class _RequiredIntOption extends RequiredOption<int>
    with NumericRangeValidated<int> {
  const _RequiredIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });

  @override
  final int? min;
  @override
  final int? max;
}

final class DoubleOption extends SingleOption<double?>
    with NumericRangeValidated<double>, NumericStepValidated
    implements OptionalInput<double> {
  const DoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });

  static RequiredOption<double> required(
    String name, {
    double? min,
    double? max,
    double? step,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredDoubleOption(
    name,
    min: min,
    max: max,
    step: step,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final double? min;
  @override
  final double? max;
  static DefaultedOption<double> withDefault(
    String name, {
    required double defaultValue,
    double? min,
    double? max,
    double? step,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedDoubleOption(
    name,
    defaultValue: defaultValue,
    min: min,
    max: max,
    step: step,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final double? step;
}

final class _DefaultedDoubleOption extends DefaultedOption<double>
    with NumericRangeValidated<double>, NumericStepValidated
    implements DefaultValue<double> {
  const _DefaultedDoubleOption(
    super.name, {
    required this.defaultValue,
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final double defaultValue;
  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

final class _RequiredDoubleOption extends RequiredOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const _RequiredDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });

  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

final class ChoiceOption<T extends Enum> extends SingleOption<T?>
    with ChoiceValidated<T>
    implements OptionalInput<T> {
  ChoiceOption(
    super.name, {
    required List<T> choices,
    super.short,
    super.description,
    super.hidden,
  }) : choices = List.unmodifiable(choices);

  static RequiredOption<T> required<T extends Enum>(
    String name, {
    required List<T> choices,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredChoiceOption(
    name,
    choices: choices,
    short: short,
    description: description,
    hidden: hidden,
  );

  static DefaultedOption<T> withDefault<T extends Enum>(
    String name, {
    required List<T> choices,
    required T defaultValue,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedChoiceOption(
    name,
    choices: choices,
    defaultValue: defaultValue,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final List<T> choices;
}

final class _RequiredChoiceOption<T extends Enum> extends RequiredOption<T>
    with ChoiceValidated<T> {
  _RequiredChoiceOption(
    super.name, {
    required List<T> choices,
    super.short,
    super.description,
    super.hidden,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
}

sealed class DefaultedOption<T> extends SingleOption<T>
    implements DefaultedInput<T> {
  const DefaultedOption(
    super.name, {
    super.short,
    super.description,
    super.hidden,
  });
}

final class _DefaultedChoiceOption<T extends Enum> extends DefaultedOption<T>
    with ChoiceValidated<T>
    implements DefaultValue<T> {
  _DefaultedChoiceOption(
    super.name, {
    required List<T> choices,
    required this.defaultValue,
    super.short,
    super.description,
    super.hidden,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
  @override
  final T defaultValue;
}

abstract interface class RepeatableOptionDefinition implements InputDefinition {
  bool get unique;
  Object appendValue(Object value, Object? existing);
}

sealed class RepeatableOption<T> extends Option<List<T>?>
    implements OptionalInput<List<T>>, RepeatableOptionDefinition {
  const RepeatableOption(
    super.name, {
    super.short,
    super.description,
    super.hidden,
  });

  @override
  bool get unique => false;
  @override
  List<T> appendValue(Object value, Object? existing) =>
      List.unmodifiable([...?existing as List<T>?, value as T]);
}

sealed class RequiredRepeatableOption<T> extends Option<List<T>>
    implements RequiredInput<List<T>>, RepeatableOptionDefinition {
  const RequiredRepeatableOption(
    super.name, {
    super.short,
    super.description,
    super.hidden,
  }) : super(isRequired: true);

  @override
  bool get unique => false;
  @override
  List<T> appendValue(Object value, Object? existing) =>
      List.unmodifiable([...?existing as List<T>?, value as T]);
}

sealed class DefaultedRepeatableOption<T> extends Option<List<T>>
    implements
        DefaultedInput<List<T>>,
        RepeatableOptionDefinition,
        DefaultValue<List<T>> {
  DefaultedRepeatableOption(
    super.name, {
    required List<T> defaultValue,
    super.short,
    super.description,
    super.hidden,
  }) : defaultValue = List.unmodifiable(defaultValue);

  @override
  final List<T> defaultValue;
  @override
  bool get unique => false;
  @override
  List<T> appendValue(Object value, Object? existing) =>
      List.unmodifiable([...?existing as List<T>?, value as T]);
}

final class RepeatableStringOption extends RepeatableOption<String>
    with RegExpValidated {
  RepeatableStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExpValidated.anyToken;

  static RequiredRepeatableOption<String> required(
    String name, {
    RegExp? regex,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredRepeatableStringOption(
    name,
    regex: regex,
    short: short,
    description: description,
    hidden: hidden,
  );

  static DefaultedRepeatableOption<String> withDefault(
    String name, {
    required List<String> defaultValue,
    RegExp? regex,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedRepeatableStringOption(
    name,
    defaultValue: defaultValue,
    regex: regex,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final RegExp regex;
}

final class _DefaultedRepeatableStringOption
    extends DefaultedRepeatableOption<String>
    with RegExpValidated {
  _DefaultedRepeatableStringOption(
    super.name, {
    required super.defaultValue,
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class _RequiredRepeatableStringOption
    extends RequiredRepeatableOption<String>
    with RegExpValidated {
  _RequiredRepeatableStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExpValidated.anyToken;

  @override
  final RegExp regex;
}

final class RepeatableIntOption extends RepeatableOption<int>
    with NumericRangeValidated<int> {
  const RepeatableIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });

  static RequiredRepeatableOption<int> required(
    String name, {
    int? min,
    int? max,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredRepeatableIntOption(
    name,
    min: min,
    max: max,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final int? min;
  static DefaultedRepeatableOption<int> withDefault(
    String name, {
    required List<int> defaultValue,
    int? min,
    int? max,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedRepeatableIntOption(
    name,
    defaultValue: defaultValue,
    min: min,
    max: max,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final int? max;
}

final class _DefaultedRepeatableIntOption extends DefaultedRepeatableOption<int>
    with NumericRangeValidated<int> {
  _DefaultedRepeatableIntOption(
    super.name, {
    required super.defaultValue,
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final int? min;
  @override
  final int? max;
}

final class _RequiredRepeatableIntOption extends RequiredRepeatableOption<int>
    with NumericRangeValidated<int> {
  const _RequiredRepeatableIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final int? min;
  @override
  final int? max;
}

final class RepeatableDoubleOption extends RepeatableOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const RepeatableDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });

  static RequiredRepeatableOption<double> required(
    String name, {
    double? min,
    double? max,
    double? step,
    String? short,
    String? description,
    bool hidden = false,
  }) => _RequiredRepeatableDoubleOption(
    name,
    min: min,
    max: max,
    step: step,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final double? min;
  @override
  final double? max;
  static DefaultedRepeatableOption<double> withDefault(
    String name, {
    required List<double> defaultValue,
    double? min,
    double? max,
    double? step,
    String? short,
    String? description,
    bool hidden = false,
  }) => _DefaultedRepeatableDoubleOption(
    name,
    defaultValue: defaultValue,
    min: min,
    max: max,
    step: step,
    short: short,
    description: description,
    hidden: hidden,
  );

  @override
  final double? step;
}

final class _DefaultedRepeatableDoubleOption
    extends DefaultedRepeatableOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  _DefaultedRepeatableDoubleOption(
    super.name, {
    required super.defaultValue,
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

final class _RequiredRepeatableDoubleOption
    extends RequiredRepeatableOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const _RequiredRepeatableDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
    super.hidden,
  });
  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

final class RepeatableChoiceOption<T extends Enum> extends RepeatableOption<T>
    with ChoiceValidated<T> {
  RepeatableChoiceOption(
    super.name,
    List<T> choices, {
    super.short,
    super.description,
    super.hidden,
    this.unique = false,
  }) : choices = List.unmodifiable(choices);

  static RequiredRepeatableOption<T> required<T extends Enum>(
    String name,
    List<T> choices, {
    String? short,
    String? description,
    bool hidden = false,
    bool unique = false,
  }) => _RequiredRepeatableChoiceOption(
    name,
    choices,
    short: short,
    description: description,
    hidden: hidden,
    unique: unique,
  );

  static DefaultedRepeatableOption<T> withDefault<T extends Enum>(
    String name,
    List<T> choices, {
    required List<T> defaultValue,
    String? short,
    String? description,
    bool hidden = false,
    bool unique = false,
  }) => _DefaultedRepeatableChoiceOption(
    name,
    choices,
    defaultValue: defaultValue,
    short: short,
    description: description,
    hidden: hidden,
    unique: unique,
  );

  @override
  final List<T> choices;
  @override
  final bool unique;
}

final class _DefaultedRepeatableChoiceOption<T extends Enum>
    extends DefaultedRepeatableOption<T>
    with ChoiceValidated<T> {
  _DefaultedRepeatableChoiceOption(
    super.name,
    List<T> choices, {
    required super.defaultValue,
    super.short,
    super.description,
    super.hidden,
    this.unique = false,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  @override
  final bool unique;
}

final class _RequiredRepeatableChoiceOption<T extends Enum>
    extends RequiredRepeatableOption<T>
    with ChoiceValidated<T> {
  _RequiredRepeatableChoiceOption(
    super.name,
    List<T> choices, {
    super.short,
    super.description,
    super.hidden,
    this.unique = false,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
  @override
  final bool unique;
}

abstract interface class PairedOptionsDefinition {
  List<PairOption> get options;
  String? get description;
  bool get isRequired;
}

/// A group whose members must either all be supplied or all be omitted.
final class PairedOptions<Result extends Object>
    implements PairedOptionsDefinition, ParsedValue<Map<String, Result>?> {
  PairedOptions(List<PairOption<Result>> options, {this.description})
    : options = List.unmodifiable(options);

  static RequiredPairedOptions<Result> required<Result extends Object>(
    List<PairOption<Result>> options, {
    String? description,
  }) => _RequiredPairedOptions(options, description: description);

  @override
  final List<PairOption<Result>> options;
  @override
  final String? description;
  @override
  bool get isRequired => false;
}

sealed class RequiredPairedOptions<Result extends Object>
    implements PairedOptionsDefinition, ParsedValue<Map<String, Result>>;

final class _RequiredPairedOptions<Result extends Object>
    extends RequiredPairedOptions<Result> {
  _RequiredPairedOptions(List<PairOption<Result>> options, {this.description})
    : options = List.unmodifiable(options);

  @override
  final List<PairOption<Result>> options;
  @override
  final String? description;
  @override
  bool get isRequired => true;
}

sealed class PairOption<T> implements InputDefinition {
  const PairOption(this.name, {required this.short, this.description});
  @override
  final String name;
  final String? short;
  @override
  final String? description;
}

final class PairStringOption extends PairOption<String> with RegExpValidated {
  PairStringOption(super.name, {RegExp? regex, super.short, super.description})
    : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class PairIntOption extends PairOption<int>
    with NumericRangeValidated<int> {
  const PairIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });
  @override
  final int? min;
  @override
  final int? max;
}

final class PairDoubleOption extends PairOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const PairDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
  });
  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

final class PairChoiceOption<T extends Enum> extends PairOption<T>
    with ChoiceValidated<T> {
  PairChoiceOption(
    super.name, {
    required List<T> choices,
    super.short,
    super.description,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
}

sealed class RepeatablePairOption<T> extends PairOption<List<T>> {
  const RepeatablePairOption(super.name, {super.short, super.description});
}

final class RepeatablePairStringOption extends RepeatablePairOption<String>
    with RegExpValidated {
  RepeatablePairStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class RepeatablePairIntOption extends RepeatablePairOption<int>
    with NumericRangeValidated<int> {
  const RepeatablePairIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });
  @override
  final int? min;
  @override
  final int? max;
}

final class RepeatablePairDoubleOption extends RepeatablePairOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const RepeatablePairDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
  });
  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

/// A named collection of pair options that resolves to a map of supplied values.
final class SelectedOptions<T extends Object>
    implements ParsedValue<Map<String, T>> {
  SelectedOptions(List<PairOption<T>> options, {this.description})
    : options = List.unmodifiable(options),
      required = false,
      single = false;

  SelectedOptions.required(List<PairOption<T>> options, {this.description})
    : options = List.unmodifiable(options),
      required = true,
      single = false;

  SelectedOptions.single(List<PairOption<T>> options, {this.description})
    : options = List.unmodifiable(options),
      required = false,
      single = true;

  final String? description;
  final bool single;
  final bool required;
  final List<PairOption<T>> options;
}

sealed class AccessorOption implements InputDefinition {
  const AccessorOption(this.name, {this.description});
  @override
  final String name;
  @override
  final String? description;
}

sealed class AccessorPrimitiveOption<T> extends Input<T>
    implements AccessorOption {
  const AccessorPrimitiveOption(this.name, {this.description});
  @override
  final String name;
  @override
  final String? description;
}

final class AccessorListOption extends Input<Map<String, Object?>>
    implements AccessorOption {
  AccessorListOption(
    this.name,
    List<AccessorOption> options, {
    this.description,
    this.hidden = false,
  }) : options = List.unmodifiable(options);

  @override
  final String name;
  @override
  final String? description;
  final bool hidden;
  final List<AccessorOption> options;
}

final class AccessorStringOption extends AccessorPrimitiveOption<String?>
    with RegExpValidated
    implements OptionalInput<String> {
  AccessorStringOption(super.name, {super.description, RegExp? regex})
    : _regex = regex ?? RegExpValidated.anyToken;
  static RequiredAccessorOption<String> required(
    String name, {
    RegExp? regex,
    String? description,
  }) => _RequiredAccessorStringOption(
    name,
    regex: regex,
    description: description,
  );

  static DefaultedAccessorOption<String> withDefault(
    String name, {
    required String defaultValue,
    RegExp? regex,
    String? description,
  }) => _DefaultedAccessorStringOption(
    name,
    defaultValue: defaultValue,
    regex: regex,
    description: description,
  );

  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

sealed class RequiredAccessorOption<T> extends AccessorPrimitiveOption<T>
    implements RequiredInput<T> {
  const RequiredAccessorOption(super.name, {super.description});
}

final class _RequiredAccessorStringOption extends RequiredAccessorOption<String>
    with RegExpValidated {
  _RequiredAccessorStringOption(super.name, {RegExp? regex, super.description})
    : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class _DefaultedAccessorStringOption
    extends DefaultedAccessorOption<String>
    with RegExpValidated
    implements DefaultValue<String> {
  _DefaultedAccessorStringOption(
    super.name, {
    required this.defaultValue,
    RegExp? regex,
    super.description,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final String defaultValue;
  @override
  final RegExp regex;
}

final class AccessorIntOption extends AccessorPrimitiveOption<int?>
    implements OptionalInput<int> {
  const AccessorIntOption(super.name, {super.description});
  static RequiredAccessorOption<int> required(
    String name, {
    String? description,
  }) => _RequiredAccessorIntOption(name, description: description);
  static DefaultedAccessorOption<int> withDefault(
    String name, {
    required int defaultValue,
    String? description,
  }) => _DefaultedAccessorIntOption(
    name,
    defaultValue: defaultValue,
    description: description,
  );
  RegExp get regex => RegExp(r'[+-]?\d+');
}

final class _RequiredAccessorIntOption extends RequiredAccessorOption<int>
    with NumericRangeValidated<int> {
  const _RequiredAccessorIntOption(super.name, {super.description});
  @override
  int? get min => null;
  @override
  int? get max => null;
}

final class _DefaultedAccessorIntOption extends DefaultedAccessorOption<int>
    with NumericRangeValidated<int>
    implements DefaultValue<int> {
  const _DefaultedAccessorIntOption(
    super.name, {
    required this.defaultValue,
    super.description,
  });
  @override
  final int defaultValue;
  @override
  int? get min => null;
  @override
  int? get max => null;
}

final class AccessorDoubleOption extends AccessorPrimitiveOption<double?>
    implements OptionalInput<double> {
  const AccessorDoubleOption(super.name, {super.description});
  static RequiredAccessorOption<double> required(
    String name, {
    String? description,
  }) => _RequiredAccessorDoubleOption(name, description: description);
  static DefaultedAccessorOption<double> withDefault(
    String name, {
    required double defaultValue,
    String? description,
  }) => _DefaultedAccessorDoubleOption(
    name,
    defaultValue: defaultValue,
    description: description,
  );
  RegExp get regex => RegExp(r'[+-]?(?:\d+\.\d+|\d+)');
}

final class _RequiredAccessorDoubleOption extends RequiredAccessorOption<double>
    with NumericRangeValidated<double>, NumericStepValidated {
  const _RequiredAccessorDoubleOption(super.name, {super.description});
  @override
  double? get min => null;
  @override
  double? get max => null;
  @override
  double? get step => null;
}

final class _DefaultedAccessorDoubleOption
    extends DefaultedAccessorOption<double>
    with NumericRangeValidated<double>, NumericStepValidated
    implements DefaultValue<double> {
  const _DefaultedAccessorDoubleOption(
    super.name, {
    required this.defaultValue,
    super.description,
  });
  @override
  final double defaultValue;
  @override
  double? get min => null;
  @override
  double? get max => null;
  @override
  double? get step => null;
}

sealed class DefaultedAccessorOption<T> extends AccessorPrimitiveOption<T>
    implements DefaultedInput<T> {
  const DefaultedAccessorOption(super.name, {super.description});
}

final class AccessorChoiceOption<T extends Enum>
    extends AccessorPrimitiveOption<T?>
    with ChoiceValidated<T>
    implements OptionalInput<T> {
  AccessorChoiceOption(
    super.name, {
    required List<T> choices,
    super.description,
  }) : choices = List.unmodifiable(choices);

  static RequiredAccessorOption<T> required<T extends Enum>(
    String name, {
    required List<T> choices,
    String? description,
  }) => _RequiredAccessorChoiceOption(
    name,
    choices: choices,
    description: description,
  );

  static DefaultedAccessorOption<T> withDefault<T extends Enum>(
    String name, {
    required List<T> choices,
    required T defaultValue,
    String? description,
  }) => _DefaultedAccessorChoiceOption(
    name,
    choices: choices,
    defaultValue: defaultValue,
    description: description,
  );

  @override
  final List<T> choices;
}

final class _RequiredAccessorChoiceOption<T extends Enum>
    extends RequiredAccessorOption<T>
    with ChoiceValidated<T> {
  _RequiredAccessorChoiceOption(
    super.name, {
    required List<T> choices,
    super.description,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
}

final class _DefaultedAccessorChoiceOption<T extends Enum>
    extends DefaultedAccessorOption<T>
    with ChoiceValidated<T>
    implements DefaultValue<T> {
  _DefaultedAccessorChoiceOption(
    super.name, {
    required List<T> choices,
    required this.defaultValue,
    super.description,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
  @override
  final T defaultValue;
}

final class ParsedInputs {
  ParsedInputs(Map<Object, Object?> values, Iterable<Object> known)
    : _values = Map.unmodifiable(values),
      _known = Set.unmodifiable(known);

  final Map<Object, Object?> _values;
  final Set<Object> _known;

  T valueOf<T>(ParsedValue<T> input) {
    if (!_known.contains(input)) {
      throw StateError('Unknown parsed input declaration.');
    }
    if (!_values.containsKey(input) && null is! T) {
      throw StateError('Parser omitted a non-null input value.');
    }
    return _values[input] as T;
  }

  bool contains(Object input) => _values.containsKey(input);
}

abstract class Command {
  final String? longDescription;
  final List<String>? aliases;
  final List<MandatoryPositional>? mandatoryPositionals;
  final List<DiscretionaryPositional>? discretionaryPositionals;
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOptionsDefinition>? pairedOptions;
  final List<SelectedOptions>? selectedOptionses;
  final List<AccessorListOption>? accessors;
  Command({
    this.longDescription,
    List<String>? aliases,
    List<MandatoryPositional>? mandatoryPositionals,
    List<DiscretionaryPositional>? discretionaryPositionals,
    this.variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptionsDefinition>? pairedOptions,
    List<SelectedOptions>? selectedOptionses,
    List<AccessorListOption>? accessors,
  }) : aliases = _copyList(aliases),
       mandatoryPositionals = _copyList(mandatoryPositionals),
       discretionaryPositionals = _copyList(discretionaryPositionals),
       flags = _copyList(flags),
       options = _copyList(options),
       pairedOptions = _copyList(pairedOptions),
       selectedOptionses = _copyList(selectedOptionses),
       accessors = _copyList(accessors);
  String get name;
  String get shortDescription;
  FutureOr<String?> run(ParsedInputs inputs, List<String> args);
}

abstract class GroupCommand extends Command {
  final List<String>? defaultSubCommandPath;
  final List<Flag>? inheritedFlags;
  final List<Option>? inheritedOptions;
  final List<Command> commands;
  GroupCommand(
    List<Command> commands, {
    List<String>? defaultSubCommandPath,
    super.aliases,
    List<Flag>? propagatedFlags,
    List<Option>? propagatedOptions,
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.selectedOptionses,
    super.accessors,
  }) : commands = List.unmodifiable(commands),
       inheritedFlags = _copyList(propagatedFlags),
       inheritedOptions = _copyList(propagatedOptions),
       defaultSubCommandPath = _copyPath(defaultSubCommandPath);
  static List<String>? _copyPath(List<String>? path) {
    if (path == null) return null;
    if (path.isEmpty || path.any((part) => part.isEmpty))
      throw MambaRegistryError(
        'defaultSubCommandPath must contain command names',
      );
    return List.unmodifiable(path);
  }

  FutureOr<String?> runChildCommand(
    List<String> path,
    ParsedInputs inputs,
    List<String> args,
  ) async {
    if (path.isEmpty || path.contains(name))
      throw ArgumentError.value(path, 'path');
    Command? current;
    List<Command>? children = commands;
    for (final part in path) {
      current = children
          ?.where(
            (candidate) =>
                candidate.name == part ||
                candidate.aliases?.contains(part) == true,
          )
          .firstOrNull;
      if (current == null)
        throw MambaException('command not found in $name ${path.join(' ')}');
      children = current is GroupCommand ? current.commands : null;
    }
    return current!.run(inputs, args);
  }

  @override
  FutureOr<String?> run(ParsedInputs inputs, List<String> args) {
    final path = defaultSubCommandPath;
    return path == null ? '' : runChildCommand(path, inputs, args);
  }
}

enum ShellCompletion { bash, zsh, fish, powershell, carapace }

class CompletionCommand extends Command {
  late RegistryRecord registryRecord;
  final void Function(String path) createFile;
  @override
  String get name => 'completion';
  @override
  String get shortDescription => 'Generate completion for various shells';
  CompletionCommand({
    void Function(String)? createFile,
    super.longDescription,
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.options,
  }) : createFile = createFile ?? _createFileSynchronously;
  CompletionCommand.preset(
    void Function(String path)? createFile, {
    String? longDescription,
  }) : this(
         createFile: createFile,
         longDescription:
             longDescription ??
             'Generate completions for Bash ZSH Fish or Powershell',
         aliases: ['cmp', 'cpt'],
         mandatoryPositionals: [shellInput],
         discretionaryPositionals: [pathInput],
       );
  @override
  String? run(ParsedInputs inputs, List<String> args) {
    final shell = inputs.valueOf(shellInput);
    final path = inputs.valueOf(pathInput) ?? '';
    final extension = _extensionFor(shell);
    if (path.isNotEmpty && !_isValidPath(path, extension))
      throw MambaException(
        'When shell is ${shell.name} the path must end in $extension and must have ${registryRecord.name} in the file name',
      );
    createFile(path);
    return 'Created completion ${shell.name} in $path';
  }

  static final ChoicePositional<ShellCompletion> shellInput = ChoicePositional(
    'shell',
    choices: ShellCompletion.values,
  );
  static final DiscretionaryPositional<String?> pathInput =
      NormalPositional.optional('path');
  String _extensionFor(ShellCompletion shell) => switch (shell) {
    ShellCompletion.bash => '.bash',
    ShellCompletion.zsh => '.zsh',
    ShellCompletion.fish => '.fish',
    ShellCompletion.powershell => '.ps1',
    ShellCompletion.carapace => '.yaml',
  };
  bool _isValidPath(String path, String extension) {
    if (!path.endsWith(extension)) return false;
    final name = path.split(RegExp(r'[/\\]')).last;
    return name
        .substring(0, name.length - extension.length)
        .contains(registryRecord.name);
  }

  static void _createFileSynchronously(String path) {
    File(path).createSync(exclusive: true);
  }
}

final class ProcessedStandardInput {
  const ProcessedStandardInput(this.bytes);
  final List<int> bytes;
  String get text => String.fromCharCodes(bytes);
  String get utf8Text => utf8.decode(bytes);
  dynamic get json => jsonDecode(utf8Text);
}

mixin HookRunner on Command {
  FutureOr<void> preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  );
  FutureOr<void> postRun(ParsedInputs inputs, MambaReadContext context) {}
}

mixin PersistentHookRunner on GroupCommand {
  FutureOr<void> prePersistentRun(ParsedInputs inputs, MambaContext context);
  FutureOr<void> postPersistentRun(ParsedInputs inputs, MambaContext context) {}
}
