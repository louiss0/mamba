void main(List<String> args) {}

class MambaParser {
  final String name;

  final String? shortDescription;
  final String? longDescription;

  final List<Command> commands;

  final List<Flag<Object>>? flags;

  final List<Option>? options;

  final Map<String, AccessorInput>? accessorFlagSchema;

  MambaParser(
    this.name,
    List<Command> commands, {
    this.shortDescription,
    this.longDescription,
    List<Flag<Object>>? flags,
    List<Option>? options,
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

  final List<Option>? options;

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
    List<Option>? options,
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

enum NamedInputType {
  string,
  int,
  bool,
  double,
  count,
  choice,
  repeatableString,
  repeatableInt,
  repeatableDouble,
}

sealed class NamedInput {
  final String name;
  final String? description;

  final NamedInputType type;

  const NamedInput({required this.name, this.description, required this.type});
}

sealed class Flag<T> extends NamedInput {
  final String? short;

  const Flag({
    required this.short,
    required super.name,
    required super.description,
    required super.type,
  });
}

final class BooleanFlag extends Flag<bool> {
  final bool defaultValue;
  final bool negatable;

  BooleanFlag({
    super.short,
    super.type = NamedInputType.bool,
    required super.name,
    super.description,
    this.defaultValue = false,
    this.negatable = false,
  });
}

final class CountFlag extends Flag<int> {
  const CountFlag({
    super.short,
    super.type = NamedInputType.count,
    required super.name,
    super.description,
  });
}

sealed class Option extends NamedInput {
  final String? short;
  final bool required;

  const Option({
    required this.short,
    required super.type,
    required super.name,
    required super.description,
    required this.required,
  });
  static StringOption stringOption(
    String name,
    RegExp regex, {
    String? short,
    String? description,
    bool required = false,
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
    bool required = false,
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
    bool required = false,
  }) {
    return DoubleOption(
      name: name,
      short: short,
      description: description,
      required: required,
    );
  }

  static ChoiceOption choiceOption<T extends Enum>(
    String name,
    List<T> choices, {
    String? short,
    String? description,
    bool required = false,
  }) {
    return ChoiceOption(
      name: name,
      choices: choices,
      short: short,
      description: description,
      required: required,
    );
  }
}

final class StringOption extends Option {
  StringOption({
    required super.name,
    super.type = NamedInputType.string,
    required this.regex,
    required super.short,
    super.description,
    required super.required,
  });

  final RegExp regex;
}

final class IntOption extends Option {
  IntOption({
    required super.name,
    super.type = NamedInputType.int,
    required super.short,
    required super.required,
    super.description,
  });
}

final class DoubleOption extends Option {
  DoubleOption({
    required super.name,
    super.type = NamedInputType.double,
    required super.short,
    required super.required,
    super.description,
  });
}

final class ChoiceOption<T extends Enum> extends Option {
  ChoiceOption({
    required super.name,
    super.type = NamedInputType.choice,
    required List<T> choices,
    required super.short,
    super.description,
    super.required = false,

    this.defaultValue,
  }) : choices = List.unmodifiable(choices);

  final List<T> choices;
  final T? defaultValue;
}

sealed class RepeatableOption<T> extends Option {
  const RepeatableOption({
    required super.type,
    required super.name,
    required super.required,
    super.short,
    super.description,
  });

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

final class RepeatableStringOption extends RepeatableOption {
  final RegExp regex;

  const RepeatableStringOption({
    required super.name,
    super.type = NamedInputType.repeatableString,
    required super.required,
    required this.regex,
    super.short,
    super.description,
  });
}

final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption({
    super.type = NamedInputType.repeatableInt,
    required super.name,
    required super.required,
    super.short,
    super.description,
  });
}

final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption({
    super.type = NamedInputType.repeatableDouble,
    required super.name,
    required super.required,
    super.short,
    super.description,
  });
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
