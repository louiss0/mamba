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

  final Map<String, AccessorInput>? accessorFlagSchema;

  MambaParser(
    this.name,
    List<Command> commands, {
    this.shortDescription,
    this.longDescription,
    List<Flag<Object>>? flags,
    List<Option<Object>>? options,
    Map<String, AccessorInput>? accessorFlagSchema,
  }) : flags = flags != null ? List.unmodifiable(flags) : null,
       commands = List.unmodifiable(commands),
       options = options != null ? List.unmodifiable(options) : null,
       accessorFlagSchema = accessorFlagSchema != null
           ? Map.unmodifiable(accessorFlagSchema)
           : null;

  void run(List<String> args) {}
}

class Command {
  final String name;
  final String shortDescription;
  final String? longDescription;

  final PositionalSchema? positionalSchema;
  final Map<String, AccessorInput>? accessorFlagSchema;

  final List<Flag<Object>>? flags;

  final List<Option<Object>>? options;

  final List<Command>? commands;

  final List<String>? aliases;

  Command(
    this.name,
    this.shortDescription, {
    List<Command>? commands,
    this.longDescription,
    this.positionalSchema,
    List<Flag<Object>>? flags,
    Map<String, AccessorInput>? accessorFlagSchema,
    List<Option<Object>>? options,
    List<String>? aliases,
  }) : flags = flags != null ? List.unmodifiable(flags) : null,
       options = options != null ? List.unmodifiable(options) : null,
       commands = commands != null ? List.unmodifiable(commands) : null,
       accessorFlagSchema = accessorFlagSchema != null
           ? Map.unmodifiable(accessorFlagSchema)
           : null,
       aliases = aliases != null ? List.unmodifiable(aliases) : null;

  void run(List<String> args) {}
}

class PositionalSchema {
  final List<Positional> positionals;
  final Variadic? variadic;

  PositionalSchema(List<Positional> positionals, {this.variadic})
    : positionals = List.unmodifiable(positionals);
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
  const Flag({
    required super.short,
    required super.name,
    required super.description,
  });
}

final class BooleanFlag extends Flag<bool> {
  final bool defaultValue;
  final bool negatable;

  BooleanFlag({
    super.short,
    required super.name,
    super.description,
    this.defaultValue = false,
    this.negatable = false,
  });
}

final class CountFlag extends Flag<int> {
  const CountFlag({required super.name, super.short, super.description});
}

sealed class Option<T> extends NamedInput {
  final bool required;
  final bool repeatable;

  const Option({
    required super.name,
    required super.description,
    required super.short,
    this.required = false,
    this.repeatable = false,
  });

  T parse(String value);
}

final class StringOption extends Option<String> {
  StringOption({
    required super.name,
    required this.regex,
    required super.short,
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
    required super.short,
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
    required super.short,
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

    required super.short,
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

sealed class AccessorInput<T extends Object> {
  final T value;

  const AccessorInput(this.value);

  static AccessorNamedInput namedInput(NamedInput value) {
    return AccessorNamedInput(value);
  }

  static AccessorMapNamedInput namedInputMap(Map<String, NamedInput> value) {
    return AccessorMapNamedInput(value);
  }
}

class AccessorNamedInput extends AccessorInput<NamedInput> {
  const AccessorNamedInput(super.value);
}

class AccessorMapNamedInput extends AccessorInput<Map<String, NamedInput>> {
  const AccessorMapNamedInput(super.value);
}
