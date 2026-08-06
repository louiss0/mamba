void main(List<String> args) {
  // print(Filter.values.);
}

class MambaParser {
  final String name;

  final List<Command> commands;

  final List<Flag>? flags;

  final List<Option>? options;

  MambaParser(this.name, this.commands, {this.flags, this.options});

  void run(List<String> args) {}
}

class Command {
  final String name;

  final List<PositionalSchema>? positionalSchemas;

  final List<Flag>? flags;

  final List<Option>? options;

  final List<Command>? commands;

  Command(
    this.name, {
    this.positionalSchemas,
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
  const Positional(this.name, {this.required = false, this.description});

  final String name;
  final bool required;
  final String? description;
}

class Variadic extends Positional {
  Variadic(super.name, {super.description}) : super(required: false);
}

sealed class Flag<T> {
  const Flag({required this.name, this.short, this.description});

  final String name;
  final String? short;
  final String? description;
}

final class BooleanFlag extends Flag<bool> {
  const BooleanFlag({
    required super.name,
    super.short,
    super.description,
    this.defaultValue = false,
    this.negatable = false,
  });

  final bool defaultValue;
  final bool negatable;
}

final class CountFlag extends Flag<int> {
  const CountFlag({required super.name, super.short, super.description});
}

sealed class Option {
  const Option({
    required this.name,
    this.short,
    this.description,
    this.required = false,
    this.repeatable = false,
  });

  final String name;
  final String? short;
  final String? description;
  final bool required;
  final bool repeatable;
  MambaException? parser(String value);
}

final class StringOption extends Option {
  StringOption({required super.name, required this.regex});

  final RegExp regex;

  @override
  MambaException? parser(String value) {
    if (!regex.hasMatch(value)) {
      return MambaException('Invalid value: $value');
    }
    return null;
  }
}

final class IntOption extends Option {
  IntOption({required super.name});

  @override
  MambaException? parser(String value) {
    if (int.tryParse(value) == null) {
      return MambaException("Value $value isn't an integer");
    }
    return null;
  }
}

final class DoubleOption extends Option {
  DoubleOption({required super.name});

  @override
  MambaException? parser(String value) {
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

class ChoiceOption<T extends Enum> extends Option {
  ChoiceOption({
    required super.name,
    super.short,
    super.description,
    super.required,
    super.repeatable,
    this.defaultValue,
    required this.choices,
  }) : super();

  final T? defaultValue;
  final List<T> choices;

  @override
  MambaException? parser(String value) {
    final choiceValues = choices.whereType<ValueGetter<Object>>();

    switch (choiceValues) {
      case Iterable<IntGetter>():
        var choices = choiceValues.map((e) => e.value);
        var parse = int.parse(value);
        if (!choices.contains(parse)) {
          return MambaInvalidChoiceException(choices, parse);
        }
        return null;

      case Iterable<DoubleGetter>():
        var choices = choiceValues.map((e) => e.value);
        var parsedDouble = double.parse(value);
        if (!choices.contains(parsedDouble)) {
          return MambaInvalidChoiceException(choices, parsedDouble);
        }
        return null;

      case Iterable<NumberGetter>():
        var choices = choiceValues.map((e) => e.value);
        var parsedNum = num.parse(value);
        if (!choices.contains(parsedNum)) {
          return MambaInvalidChoiceException(choices, parsedNum);
        }
        return null;

      case Iterable<StringGetter>():
        var choices = choiceValues.map((e) => e.value);
        if (!choices.contains(value)) {
          return MambaInvalidChoiceException(choices, value);
        }
        return null;
    }

    var choiceNames = choices.map((e) => e.name);

    if (!choiceNames.contains(value)) {
      return MambaException("Invalid choice: $value");
    }

    return null;
  }
}

enum Filter { all, complete, incomplete }

interface class ValueGetter<T> {
  final T value;
  ValueGetter(this.value);
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
