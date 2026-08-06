void main(List<String> args) {
  // print(Filter.values.);
}

class MambaParser {
  final String name;

  final String? shortDescription;
  final String? longDescription;

  final List<Command> commands;

  final List<Flag>? flags;

  final List<Option>? options;

  MambaParser(
    this.name,
    this.commands, {
    this.shortDescription,
    this.longDescription,
    this.flags,
    this.options,
  });

  void run(List<String> args) {}
}

class Command {
  final String name;
  final String shortDescription;
  final String? longDescription;

  final PositionalSchema? positionalSchema;

  final List<Flag>? flags;

  final List<Option>? options;

  final List<Command>? commands;

  Command(
    this.name,
    this.shortDescription, {
    this.longDescription,
    this.positionalSchema,
    this.commands,
    this.flags,
    this.options,
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

  const NamedInput({required this.name, this.description});

  // Must be overridden using the first letter of the name
  String get short;
}

sealed class Flag<T> extends NamedInput {
  final bool negatable;

  final String? _short;

  const Flag({
    this._short,
    required super.name,
    required super.description,
    this.negatable = false,
  });

  @override
  String get short => _short ?? super.name[0];
}

final class BooleanFlag extends Flag<bool> {
  final bool defaultValue;

  BooleanFlag({
    required super.name,

    super.description,
    this.defaultValue = false,
  });
}

final class CountFlag extends Flag<int> {
  const CountFlag({required super.name, super.short, super.description});
}

sealed class Option<T> extends NamedInput {
  final String? _short;
  final bool required;
  final bool repeatable;

  const Option({
    required super.name,
    required super.description,
    this._short,
    this.required = false,
    this.repeatable = false,
  });

  @override
  String get short => _short ?? super.name[0];

  T parse(String value);
}

final class StringOption extends Option {
  StringOption({
    required super.name,
    required this.regex,
    super.description,
    super.required,
    super.repeatable,
  });

  final RegExp regex;

  @override
  MambaException? parse(String value) {
    if (!regex.hasMatch(value)) {
      return MambaException('Invalid value: $value');
    }
    return null;
  }
}

final class IntOption extends Option {
  IntOption({
    required super.name,

    super.description,
    super.required,
    super.repeatable,
  });

  @override
  MambaException? parse(String value) {
    if (int.tryParse(value) == null) {
      return MambaException("Value $value isn't an integer");
    }
    return null;
  }
}

final class DoubleOption extends Option {
  DoubleOption({
    required super.name,

    super.description,
    super.required,
    super.repeatable,
  });

  @override
  MambaException? parse(String value) {
    if (double.tryParse(value) == null) {
      return MambaException("Value $value isn't a double");
    }
    return null;
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
