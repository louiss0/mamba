import 'errors.dart';

typedef BoolFlagMap = Map<String, BooleanFlag>;

typedef CountFlagMap = Map<String, CountFlag>;

typedef OptionMap = Map<String, Option>;

typedef AccessorMap = Map<String, AccessorInput>;

typedef Aliases = List<String>;

final class CommandRegistry {
  final String name;

  final String shortDescription;

  final String? longDescription;

  final BoolFlagMap? boolFlags;

  final CountFlagMap? countFlags;

  final OptionMap? options;

  final Map<String, Positional>? positionals;

  final Variadic? variadic;

  final AccessorMap? accessors;

  final List<CommandRegistry>? commandRegistries;

  final Aliases? aliases;

  factory CommandRegistry.create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<String>? aliases,
    Map<String, AccessorInput>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    PositionalSchema? positionalSchema,
    List<Command>? commands,
  }) {
    _validateDefinition(
      name: name,
      shortDescription: shortDescription,
      accessors: accessors,
      flags: flags,
      options: options,
      positionalSchema: positionalSchema,
      commands: commands,
    );

    return CommandRegistry(
      name: name,
      shortDescription: shortDescription,
      longDescription: longDescription,
      aliases: aliases,
      accessors: accessors,
      flags: flags,
      options: options,
      positionalSchema: positionalSchema,
      commands: commands,
    );
  }

  CommandRegistry({
    required this.name,
    required this.shortDescription,
    this.longDescription,
    this.aliases,
    this.accessors,
    List<Flag>? flags,
    List<Option>? options,
    PositionalSchema? positionalSchema,
    List<Command>? commands,
  }) : boolFlags = flags?.fold(
         {},
         (map, flag) => flag is BooleanFlag ? {...?map, flag.name: flag} : map,
       ),
       countFlags = flags?.fold(
         {},
         (map, flag) => flag is CountFlag ? {...?map, flag.name: flag} : map,
       ),
       options = options?.fold(
         {},
         (map, option) => {...?map, option.name: option},
       ),
       positionals = positionalSchema?.positionals.fold(
         {},
         (map, positional) => {...?map, positional.name: positional},
       ),
       variadic = positionalSchema?.variadic,
       commandRegistries = commands
           ?.map(
             (command) => CommandRegistry(
               name: command.name,
               shortDescription: command.shortDescription,
               longDescription: command.longDescription,
               aliases: command.aliases,
               flags: command.flags,
               options: command.options,
               accessors: command.accessorFlagSchema,
               positionalSchema: command.positionalSchema,
               commands: command.commands,
             ),
           )
           .toList();

  static final RegExp _keyboardSymbol = RegExp(r'[^A-Za-z0-9_-]');
  static final RegExp _number = RegExp(r'\d');

  static void _validateDefinition({
    required String name,
    required String shortDescription,
    required AccessorMap? accessors,
    required List<Flag>? flags,
    required List<Option>? options,
    required PositionalSchema? positionalSchema,
    required List<Command>? commands,
  }) {
    _validateCommandName(name);
    _validateShortDescription(shortDescription);
    _validateNamedInputs(options, 'Option');
    _validateNamedInputs(flags, 'Flag');
    _validateAccessors(accessors);
    _validatePositionals(positionalSchema);
    _validateDuplicates(accessors, flags, options, positionalSchema, commands);
  }

  static void _validateCommandName(String name) {
    if (name.isEmpty) {
      throw const MambaException('Command name is empty,');
    }
    if (name.contains(' ')) {
      throw const MambaException(
        'There should no spaces in between letters for command names',
      );
    }
    if (_number.hasMatch(name)) {
      throw const MambaException('Command name should have no numbers');
    }
    if (name == '_') {
      throw const MambaException("Command name can't be an underscore");
    }
    if (name == '-') {
      throw const MambaException("Command name can't be a dash");
    }
    if (_keyboardSymbol.hasMatch(name)) {
      throw MambaRegistryError(
        "Command names can't use keyboard symbols other than _ or -",
      );
    }
  }

  static void _validateShortDescription(String shortDescription) {
    if (shortDescription.isEmpty) {
      throw const MambaException("Short description can't be empty");
    }
    if (shortDescription.length >= 150) {
      throw const MambaException(
        "Short description can't go over 150 lines of code",
      );
    }
  }

  static void _validateNamedInputs(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) {
      return;
    }
    for (final input in inputs) {
      if (_keyboardSymbol.hasMatch(input.name)) {
        throw MambaRegistryError(
          "$inputKind names can't use keyboard symbols other than _ or -",
        );
      }
    }
  }

  static void _validateAccessors(AccessorMap? accessors) {
    if (accessors == null) {
      return;
    }
    for (final entry in accessors.entries) {
      _validatePositionalName(entry.key);
      switch (entry.value) {
        case AccessorNamedInput(:final input):
          _validatePositionalName(input.name);
        case AccessorInputGroup(:final inputs):
          for (final input in inputs.values) {
            _validatePositionalName(input.name);
          }
      }
    }
  }

  static void _validatePositionals(PositionalSchema? positionalSchema) {
    if (positionalSchema == null) {
      return;
    }
    for (final positional in positionalSchema.positionals) {
      _validatePositionalName(positional.name);
    }
    final variadic = positionalSchema.variadic;
    if (variadic != null) {
      _validatePositionalName(variadic.name);
    }
  }

  static void _validatePositionalName(String name) {
    if (_keyboardSymbol.hasMatch(name)) {
      throw MambaRegistryError(
        "Positional names can't use keyboard symbols other than _ or -",
      );
    }
  }

  static void _validateDuplicates(
    AccessorMap? accessors,
    List<Flag>? flags,
    List<Option>? options,
    PositionalSchema? positionalSchema,
    List<Command>? commands,
  ) {
    _validateDuplicateNames(options, 'option');
    _validateDuplicateNames(flags, 'flag');

    if (accessors != null) {
      for (final entry in accessors.entries) {
        final flagIndex =
            flags?.indexWhere((flag) => flag.name == entry.key) ?? -1;
        if (flagIndex >= 0) {
          throw MambaException(
            'This accessor ${entry.key} has the same name as a flag at index $flagIndex',
          );
        }
        final optionIndex =
            options?.indexWhere((option) => option.name == entry.key) ?? -1;
        if (optionIndex >= 0) {
          throw MambaException(
            'This accessor ${entry.key} has the same name as an option at index $optionIndex',
          );
        }
      }
    }

    final positionals = positionalSchema?.positionals;
    if (positionals != null) {
      final names = <String>{};
      for (final positional in positionals) {
        if (!names.add(positional.name)) {
          throw const MambaException(
            "A positional can't have the same name as another positional",
          );
        }
      }

      final commandNames = commands?.map((command) => command.name).toList();
      for (final positional in positionals) {
        final commandIndex = commandNames?.indexOf(positional.name) ?? -1;
        if (commandIndex >= 0) {
          throw MambaException(
            'This positional mesaage has the same name as a command at index $commandIndex',
          );
        }
      }

      final variadic = positionalSchema?.variadic;
      if (variadic != null && names.contains(variadic.name)) {
        throw const MambaException(
          "A positional and variadic can't have the same name you can pluralize the variadic",
        );
      }
    }
  }

  static void _validateDuplicateNames(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) {
      return;
    }
    final names = <String, int>{};
    for (final (index, input) in inputs.indexed) {
      final duplicateIndex = names[input.name];
      if (duplicateIndex != null) {
        throw MambaException(
          'There are duplicate $inputKind names at index $duplicateIndex and $index',
        );
      }
      names[input.name] = index;
    }
  }
}

typedef Inputs = ({
  Map<String, int>? countFlags,
  Map<String, bool>? boolFlags,
  Map<String, String>? options,
  Map<String, AccessorInput>? accessorMap,
  Map<String, String>? positionals,
  List<String>? variadic,
});

abstract class Command {
  final String name;
  final String shortDescription;
  final String? longDescription;

  // ignore: unused_field
  final CommandRegistry _registry;

  final PositionalSchema? positionalSchema;
  final Map<String, AccessorInput>? accessorFlagSchema;

  final List<Flag>? flags;
  final List<Option>? options;
  final List<Command>? commands;
  final List<String>? aliases;

  Command(
    String name,
    String shortDescription, {
    String? longDescription,

    PositionalSchema? positionalSchema,
    Map<String, AccessorInput>? accessorFlagSchema,

    List<Flag>? flags,

    List<Option>? options,

    List<Command>? commands,

    List<String>? aliases,
  }) : _registry = CommandRegistry.create(
         name,
         shortDescription,
         longDescription: longDescription,
         positionalSchema: positionalSchema,
         accessors: accessorFlagSchema,
         flags: flags,
         options: options,
         commands: commands,
         aliases: aliases,
       ),
       name = name,
       shortDescription = shortDescription,
       longDescription = longDescription,
       aliases = aliases != null ? List.unmodifiable(aliases) : null,
       positionalSchema = positionalSchema,
       accessorFlagSchema = accessorFlagSchema != null
           ? Map.unmodifiable(accessorFlagSchema)
           : null,
       flags = flags != null ? List.unmodifiable(flags) : null,
       options = options != null ? List.unmodifiable(options) : null,
       commands = commands != null ? List.unmodifiable(commands) : null;

  void run(Inputs input);
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
    this.required = false,
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
    super.short,
    super.description,
    super.required,
  });

  final RegExp regex;
}

final class IntOption extends Option {
  IntOption({
    required super.name,
    super.type = NamedInputType.int,
    super.short,
    super.required,
    super.description,
  });
}

final class DoubleOption extends Option {
  DoubleOption({
    required super.name,
    super.type = NamedInputType.double,
    super.short,
    super.required,
    super.description,
  });
}

final class ChoiceOption<T extends Enum> extends Option {
  ChoiceOption({
    required super.name,
    super.type = NamedInputType.choice,
    required List<T> choices,
    super.short,
    super.description,
    super.required,

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
