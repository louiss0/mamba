void main(List<String> args) {
  // print(Filter.values.);
}

class MambaParser {
  final String name;

  final String? shortDescription;
  final String? longDescription;

  final List<Command> commands;

  final List<Flag<Object>>? flags;

  final List<Option<Object>>? options;

  final Map<String, AccessorFlagValue>? accessorflagSchema;

  MambaParser(
    this.name,
    this.commands, {
    this.shortDescription,
    this.longDescription,
    this.flags,
    this.options,
    this.accessorflagSchema,
  });

  void run(List<String> args) {}
}

class Command {
  final String name;
  final String shortDescription;
  final String? longDescription;

  final PositionalSchema? positionalSchema;
  final Map<String, AccessorFlagValue>? accessorflagSchema;

  final List<Flag<Object>>? flags;

  final List<Option<Object>>? options;

  final List<Command>? commands;

  final List<String>? aliases;

  Command(
    this.name,
    this.shortDescription, {
    this.longDescription,
    this.positionalSchema,
    this.accessorflagSchema,
    this.commands,
    this.flags,
    this.options,
    this.aliases,
  });

  void run(List<String> args) {}
}

class PositionalSchema {
  final List<Positional> positionals;
  final Variadic? variadic;

  PositionalSchema(this.positionals, {this.variadic});
}

class Positional {
  const Positional(this.name, {this.required = true, this.description});

  final String name;
  final bool required;
  final String? description;
}

class Variadic extends Positional {
  Variadic(super.name, {super.description}) : super(required: false);
}

sealed class NamedInput {
  final String name;
  final String? description;
  final String? short;

  const NamedInput({required this.name, this.description, this.short});
}

sealed class Flag<T> extends NamedInput {
  final bool negatable;

  const Flag({
    required super.short,
    required super.name,
    required super.description,
    required this.negatable,
  });
}

final class BooleanFlag extends Flag<bool> {
  final bool defaultValue;

  BooleanFlag({
    super.short,
    required super.name,
    super.description,
    this.defaultValue = false,
    super.negatable = false,
  });
}

final class CountFlag extends Flag<int> {
  const CountFlag({
    required super.name,
    super.short,
    super.description,
    super.negatable = false,
  });
}

sealed class Option<T> extends NamedInput {
  final bool required;
  final bool repeatable;

  const Option({
    required super.name,
    required super.description,
    super.short,
    this.required = false,
    this.repeatable = false,
  });

  T parse(String value);
}

final class StringOption extends Option<String> {
  StringOption({
    required super.name,
    required this.regex,
    super.description,
    super.required,
    super.repeatable,
  });

  final RegExp regex;

  @override
  String parse(String value) {
    if (!regex.hasMatch(value)) {
      throw MambaException('Invalid value: $value');
    }
    return value;
  }
}

final class IntOption extends Option<int> {
  IntOption({
    required super.name,

    super.description,
    super.required,
    super.repeatable,
  });

  @override
  int parse(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw MambaException("Value $value isn't an integer");
    }
    return parsed;
  }
}

final class DoubleOption extends Option<double> {
  DoubleOption({
    required super.name,
    super.description,
    super.required,
    super.repeatable,
  });

  @override
  double parse(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw MambaException("Value $value isn't a double");
    }
    return parsed;
  }
}

class MambaException implements Exception {
  final String message;

  MambaException(this.message);
}

class MambaInvalidChoiceException<T> implements MambaException {
  final Iterable<T> choices;

  MambaInvalidChoiceException(this.choices, this.invalidChoice);

  final T invalidChoice;

  @override
  get message =>
      "Invalid choice $invalidChoice it's one of ${choices.join(' , ')}";
}

final class ChoiceOption<T extends Enum> extends Option<T> {
  ChoiceOption({
    required super.name,
    required List<T> choices,
    String Function(T choice)? valueOf,

    super.description,
    super.required,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices),
       valueOf = valueOf ?? ((choice) => choice.name);

  final List<T> choices;
  final T? defaultValue;
  final String Function(T choice) valueOf;

  @override
  T parse(String raw) {
    for (final choice in choices) {
      if (valueOf(choice) == raw) {
        return choice;
      }
    }

    throw MambaInvalidChoiceException(choices.map(valueOf), raw);
  }
}

enum Filter { all, complete, incomplete }

abstract interface class ValueGetter<T> {
  T get value;
}

typedef NumberGetter = ValueGetter<num>;

typedef IntGetter = ValueGetter<int>;

typedef StringGetter = ValueGetter<String>;

typedef DoubleGetter = ValueGetter<double>;

enum Numbers implements NumberGetter {
  one(1),
  two(2),
  threePointEight(3.8);

  const Numbers(this._number);

  final num _number;

  @override
  num get value => _number;
}

sealed class AccessorFlagValue<T extends Map<String, Object>> {
  final T value;

  const AccessorFlagValue(this.value);

  static AccessorFlagValue<Map<String, String>> stringMap(
    Map<String, String> value,
  ) => StringMapAccessorFlagValue(value);

  static AccessorFlagValue<Map<String, Map<String, String>>> stringMapLv2(
    Map<String, Map<String, String>> value,
  ) => StringMapLv2AccessorFlagValue(value);
}

final class StringMapAccessorFlagValue
    extends AccessorFlagValue<Map<String, String>> {
  const StringMapAccessorFlagValue(super.value);
}

final class StringMapLv2AccessorFlagValue
    extends AccessorFlagValue<Map<String, Map<String, String>>> {
  const StringMapLv2AccessorFlagValue(super.value);
}
