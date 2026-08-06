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

  const Option({
    required super.name,
    required super.description,
    required super.short,
    this.required = false,
  });

  T parse(String value);

  StringOption stringOption(
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

  IntOption intOption(
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

  DoubleOption doubleOption(
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
}

final class StringOption extends Option<String> {
  StringOption({
    required super.name,
    required this.regex,
    required super.short,
    super.description,
    super.required,
  });

  final RegExp regex;

  @override
  String parse(String value) {
    final match = regex.matchAsPrefix(value);

    if (match == null || match.end != value.length) {
      throw MambaException(
        "Invalid value: '$value' TIP: Anchoring is generally a good idea",
      );
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

sealed class RepeatableOption<T> extends NamedInput {
  final bool required;

  const RepeatableOption({
    required super.name,
    super.short,
    super.description,
    this.required = false,
  });

  List<T> parseItems(List<String> values);

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

  RepeatableStringOption({
    required super.name,
    super.short,
    super.description,
    super.required,
    required this.regex,
  });

  @override
  List<String> parseItems(List<String> values) {
    return values.map((value) {
      final match = regex.matchAsPrefix(value);

      if (match == null || match.end != value.length) {
        throw MambaException(
          "Invalid value: '$value' TIP: Anchoring is generally a good idea",
        );
      }

      return value;
    }).toList();
  }
}

final class RepeatableIntOption extends RepeatableOption<int> {
  RepeatableIntOption({
    required super.name,
    super.short,
    super.description,
    super.required,
  });

  @override
  List<int> parseItems(List<String> values) {
    return values.map((v) {
      final value = int.tryParse(v);
      if (value == null) {
        throw MambaException("Invalid value: '$v' isn't an int");
      }
      return value;
    }).toList();
  }
}

final class RepeatableDoubleOption extends RepeatableOption<double> {
  RepeatableDoubleOption({
    required super.name,
    super.short,
    super.description,
    super.required,
  });

  @override
  List<double> parseItems(List<String> values) {
    return values.map((v) {
      final value = double.tryParse(v);
      if (value == null) {
        throw MambaException("Invalid value: '$v' isn't a double");
      }
      return value;
    }).toList();
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

final class AccessorNamedInput extends AccessorInput<NamedInput> {
  const AccessorNamedInput(super.value);
}

final class AccessorMapNamedInput
    extends AccessorInput<Map<String, NamedInput>> {
  AccessorMapNamedInput(Map<String, NamedInput> value)
    : super(Map.unmodifiable(value));
}
