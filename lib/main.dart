void main(List<String> args) {}

class MambaParser {
  final String name;

  final String? shortDescription;
  final String? longDescription;

  final List<Command> commands;

  final List<Flag<Object>>? flags;

  final List<PureOption<Object>>? options;

  final Map<String, AccessorInput>? accessorFlagSchema;

  MambaParser(
    this.name,
    List<Command> commands, {
    this.shortDescription,
    this.longDescription,
    List<Flag<Object>>? flags,
    List<PureOption<Object>>? options,
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

  final List<PureOption<Object>>? options;

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
    List<PureOption<Object>>? options,
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

sealed class PureOption<Output> extends NamedInput {
  const PureOption({
    required super.name,
    required super.description,
    required super.short,
    required this.required,
  });

  final bool required;

  Output parseTokens(List<String> values);
}

sealed class Option<Output> extends PureOption<Output> {
  const Option({
    required super.name,
    required super.description,
    required super.short,
    required super.required,
  });

  Output parseValue(String value);

  @override
  Output parseTokens(List<String> values) {
    if (values.length != 1) {
      throw MambaException("Option '$name' expects exactly one value.");
    }

    return parseValue(values.single);
  }

  static StringOption stringOption(
    String name,
    RegExp regex, {
    String? short,
    String? description,
    bool required = true,
  }) {
    return StringOption(
      name: name,
      regex: regex,
      short: short,
      description: description,
      required: required,
    );
  }

  static IntOption intOption(
    String name, {
    String? short,
    String? description,
    bool required = true,
  }) {
    return IntOption(
      name: name,
      short: short,
      description: description,
      required: required,
    );
  }

  static DoubleOption doubleOption(
    String name, {
    String? short,
    String? description,
    bool required = true,
  }) {
    return DoubleOption(
      name: name,
      short: short,
      description: description,
      required: required,
    );
  }

  static ChoiceOption<T> choiceOption<T extends Enum>(
    String name,
    List<T> choices, {
    String Function(T choice)? valueOf,
    String? short,
    String? description,
    bool required = true,
  }) {
    return ChoiceOption(
      name: name,
      choices: choices,
      valueOf: valueOf,
      short: short,
      description: description,
      required: required,
    );
  }
}

final class StringOption extends Option<String> {
  StringOption({
    required super.name,
    required this.regex,
    required super.short,
    super.description,
    required super.required,
  });

  final RegExp regex;

  @override
  String parseValue(String value) {
    final match = regex.matchAsPrefix(value);

    if (match == null || match.end != value.length) {
      throw MambaException("Invalid value: '$value' ");
    }

    return value;
  }
}

final class IntOption extends Option<int> {
  IntOption({
    required super.name,
    required super.short,
    required super.required,
    super.description,
  });

  @override
  int parseValue(String value) {
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
    required super.required,
    super.description,
  });

  @override
  double parseValue(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw MambaException("Value $value isn't a double");
    }
    return parsed;
  }
}

final class ChoiceOption<T extends Enum> extends Option<T> {
  ChoiceOption({
    required super.name,
    required List<T> choices,
    String Function(T choice)? valueOf,

    required super.short,
    super.description,
    super.required = false,

    this.defaultValue,
  }) : choices = List.unmodifiable(choices),
       valueOf = valueOf ?? ((choice) => choice.name);

  final List<T> choices;
  final T? defaultValue;
  final String Function(T choice) valueOf;

  @override
  T parseValue(String raw) {
    for (final choice in choices) {
      if (valueOf(choice) == raw) {
        return choice;
      }
    }

    throw MambaInvalidChoiceException(choices.map(valueOf), raw);
  }
}

sealed class RepeatableOption<T> extends PureOption<List<T>> {
  const RepeatableOption({
    required super.name,
    required super.required,
    super.short,
    super.description,
  });

  T parseValue(int index, String value);

  @override
  List<T> parseTokens(List<String> values) {
    return [
      for (final (index, value) in values.indexed) parseValue(index, value),
    ];
  }

  static RepeatableIntOption intOption({
    required String name,
    String? short,
    String? description,
    bool required = false,
  }) {
    return RepeatableIntOption(
      name: name,
      short: short,
      description: description,
      required: required,
    );
  }

  static RepeatableDoubleOption doubleOption({
    required String name,
    String? short,
    String? description,
    bool required = false,
  }) {
    return RepeatableDoubleOption(
      name: name,
      short: short,
      description: description,
      required: required,
    );
  }

  static RepeatableStringOption stringOption({
    required String name,
    required RegExp regex,
    String? short,
    String? description,
    bool required = false,
  }) {
    return RepeatableStringOption(
      name: name,
      short: short,
      description: description,
      required: required,
      regex: regex,
    );
  }
}

final class RepeatableStringOption extends RepeatableOption<String> {
  final RegExp regex;

  const RepeatableStringOption({
    required super.name,
    required super.required,
    required this.regex,
    super.short,
    super.description,
  });

  @override
  String parseValue(int index, String value) {
    final match = regex.matchAsPrefix(value);

    if (match == null || match.end != value.length) {
      throw MambaException("Invalid value: '$value' at index $index");
    }

    return value;
  }
}

final class RepeatableIntOption extends RepeatableOption<int> {
  const RepeatableIntOption({
    required super.name,
    required super.required,
    super.short,
    super.description,
  });

  @override
  int parseValue(int index, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw MambaException(
        "Invalid value: '$value' at place $index isn't an int",
      );
    }
    return parsed;
  }
}

final class RepeatableDoubleOption extends RepeatableOption<double> {
  const RepeatableDoubleOption({
    required super.name,
    required super.required,
    super.short,
    super.description,
  });

  @override
  double parseValue(int index, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw MambaException(
        "Invalid value: '$value' at place $index isn't a double",
      );
    }
    return parsed;
  }
}

class MambaException implements Exception {
  const MambaException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class MambaInvalidChoiceException<T> extends MambaException {
  MambaInvalidChoiceException(Iterable<T> choices, T invalidChoice)
    : super(
        "Invalid choice '$invalidChoice'. "
        "Expected one of: ${choices.join(', ')}.",
      );
}

abstract interface class ValueGetter<T> {
  T get value;
}

typedef NumberGetter = ValueGetter<num>;

typedef IntGetter = ValueGetter<int>;

typedef StringGetter = ValueGetter<String>;

typedef DoubleGetter = ValueGetter<double>;

sealed class AccessorInput {
  const AccessorInput();

  factory AccessorInput.group(Map<String, NamedInput> inputs) {
    return AccessorInputGroup(inputs);
  }

  factory AccessorInput.named(NamedInput input) {
    return AccessorNamedInput(input);
  }
}

final class AccessorNamedInput extends AccessorInput {
  const AccessorNamedInput(this.input);

  final NamedInput input;
}

final class AccessorInputGroup extends AccessorInput {
  AccessorInputGroup(Map<String, NamedInput> inputs)
    : inputs = Map.unmodifiable(inputs);

  final Map<String, NamedInput> inputs;
}
