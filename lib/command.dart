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

/// An identity-based, typed handle for a parsed command value.
sealed class Input<T> implements InputDefinition {
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

final class RepeatedChoiceVariadic<T extends Enum> extends ChoiceVariadic<T> {
  RepeatedChoiceVariadic({
    super.description,
    required super.choices,
    super.defaultValue,
  });
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

  final RegExp _regex;
  @override
  RegExp get regex => _regex;
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

final class PairValues {
  PairValues(Map<PairOption, Object?> values)
    : _values = Map.unmodifiable(values);

  final Map<PairOption, Object?> _values;

  T valueOf<T>(PairOption<T> option) => _values[option] as T;
}

abstract interface class PairedOptionsDefinition implements InputDefinition {
  List<PairOption> get options;
  String? get description;
  bool get isRequired;
  Object map(PairValues values);
}

/// A group whose members must either all be supplied or all be omitted.
final class PairedOptions<Result extends Object> extends Input<Result?>
    implements OptionalInput<Result>, PairedOptionsDefinition {
  PairedOptions(List<PairOption> options, this.toResult, {this.description})
    : options = List.unmodifiable(options);

  static RequiredPairedOptions<Result> required<Result extends Object>(
    List<PairOption> options,
    Result Function(PairValues values) toResult, {
    String? description,
  }) => _RequiredPairedOptions(options, toResult, description: description);

  @override
  final List<PairOption> options;
  final Result Function(PairValues values) toResult;
  @override
  final String? description;
  @override
  bool get isRequired => false;
  @override
  String get name => options.map((option) => option.name).join('&');
  @override
  Result map(PairValues values) => toResult(values);
}

sealed class RequiredPairedOptions<Result extends Object> extends Input<Result>
    implements RequiredInput<Result>, PairedOptionsDefinition;

final class _RequiredPairedOptions<Result extends Object>
    extends RequiredPairedOptions<Result> {
  _RequiredPairedOptions(
    List<PairOption> options,
    this.toResult, {
    this.description,
  }) : options = List.unmodifiable(options);

  @override
  final List<PairOption> options;
  final Result Function(PairValues values) toResult;
  @override
  final String? description;
  @override
  bool get isRequired => true;
  @override
  String get name => options.map((option) => option.name).join('&');
  @override
  Result map(PairValues values) => toResult(values);
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

abstract interface class SelectionMember<Result extends Object> {
  PairOption get option;
  Result map(Object? value);
}

final class SelectableOption<Value, Result extends Object>
    implements SelectionMember<Result> {
  const SelectableOption(this.option, this.toResult);
  @override
  final PairOption<Value> option;
  final Result Function(Value value) toResult;
  @override
  Result map(Object? value) => toResult(value as Value);
}

abstract interface class SelectedOptionsDefinition implements InputDefinition {
  List<SelectionMember<Object>> get options;
  String? get description;
  bool get isRequired;
  Object map(Object? value, SelectionMember<Object> member);
}

final class SelectedOptions<Result extends Object> extends Input<Result?>
    implements OptionalInput<Result>, SelectedOptionsDefinition {
  SelectedOptions(List<SelectionMember<Result>> options, {this.description})
    : _options = List.unmodifiable(options);

  static RequiredSelectedOptions<Result> required<Result extends Object>(
    List<SelectionMember<Result>> options, {
    String? description,
  }) => _RequiredSelectedOptions(options, description: description);

  final List<SelectionMember<Result>> _options;
  @override
  List<SelectionMember<Object>> get options => _options;
  @override
  final String? description;
  @override
  bool get isRequired => false;
  @override
  String get name => options.map((option) => option.option.name).join('|');
  @override
  Result map(Object? value, SelectionMember<Object> member) =>
      member.map(value) as Result;
}

sealed class RequiredSelectedOptions<Result extends Object>
    extends Input<Result>
    implements RequiredInput<Result>, SelectedOptionsDefinition;

final class _RequiredSelectedOptions<Result extends Object>
    extends RequiredSelectedOptions<Result> {
  _RequiredSelectedOptions(
    List<SelectionMember<Result>> options, {
    this.description,
  }) : _options = List.unmodifiable(options);

  final List<SelectionMember<Result>> _options;
  @override
  List<SelectionMember<Object>> get options => _options;
  @override
  final String? description;
  @override
  bool get isRequired => true;
  @override
  String get name => options.map((option) => option.option.name).join('|');
  @override
  Result map(Object? value, SelectionMember<Object> member) =>
      member.map(value) as Result;
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

final class AccessorListOption extends AccessorOption {
  AccessorListOption(
    super.name,
    List<AccessorOption> options, {
    super.description,
    this.hidden = false,
  }) : options = List.unmodifiable(options);
  final bool hidden;
  final List<AccessorOption> options;
}

final class AccessorStringOption extends AccessorPrimitiveOption<String?>
    with RegExpValidated
    implements OptionalInput<String> {
  AccessorStringOption(super.name, {super.description, RegExp? regex})
    : _regex = regex ?? RegExpValidated.anyToken;
  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class AccessorIntOption extends AccessorPrimitiveOption<int?>
    implements OptionalInput<int> {
  const AccessorIntOption(super.name, {super.description});
  RegExp get regex => RegExp(r'[+-]?\d+');
}

final class AccessorDoubleOption extends AccessorPrimitiveOption<double?>
    implements OptionalInput<double> {
  const AccessorDoubleOption(super.name, {super.description});
  RegExp get regex => RegExp(r'[+-]?(?:\d+\.\d+|\d+)');
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
  ParsedInputs(Map<InputDefinition, Object?> values)
    : _values = Map.unmodifiable(values);
  final Map<InputDefinition, Object?> _values;
  T valueOf<T>(Input<T> input) {
    if (!_values.containsKey(input) && null is! T) {
      throw StateError('Parser omitted non-null input --${input.name}.');
    }
    return _values[input] as T;
  }

  bool contains(InputDefinition input) => _values.containsKey(input);
}

final class CommandInvocation {
  const CommandInvocation(this._inputs);
  final ParsedInputs _inputs;

  T valueOf<T>(Input<T> input) => _inputs.valueOf(input);
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
  final List<SelectedOptionsDefinition>? selectedOptions;
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
    List<SelectedOptionsDefinition>? selectedOptions,
    List<AccessorListOption>? accessors,
  }) : aliases = _copyList(aliases),
       mandatoryPositionals = _copyList(mandatoryPositionals),
       discretionaryPositionals = _copyList(discretionaryPositionals),
       flags = _copyList(flags),
       options = _copyList(options),
       pairedOptions = _copyList(pairedOptions),
       selectedOptions = _copyList(selectedOptions),
       accessors = _copyList(accessors);
  String get name;
  String get shortDescription;
  FutureOr<String?> run(CommandInvocation invocation, List<String> args);
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
    super.selectedOptions,
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
    CommandInvocation invocation,
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
    return current!.run(invocation, args);
  }

  @override
  FutureOr<String?> run(CommandInvocation invocation, List<String> args) {
    final path = defaultSubCommandPath;
    return path == null ? '' : runChildCommand(path, invocation, args);
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
  String? run(CommandInvocation invocation, List<String> args) {
    final shell = invocation.valueOf(shellInput);
    final path = invocation.valueOf(pathInput) ?? '';
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
    CommandInvocation invocation,
    MambaReadContext context,
    ProcessedStandardInput? input,
  );
  FutureOr<void> postRun(
    CommandInvocation invocation,
    MambaReadContext context,
  ) {}
}

mixin PersistentHookRunner on GroupCommand {
  FutureOr<void> prePersistentRun(
    CommandInvocation invocation,
    MambaContext context,
  );
  FutureOr<void> postPersistentRun(
    CommandInvocation invocation,
    MambaContext context,
  ) {}
}
