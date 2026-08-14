import 'errors.dart';

final class CommandRegistry {
  final String name;

  final String shortDescription;

  final String? longDescription;

  final PositionalSchema? positionalSchema;
  final FlagSchema? flagSchema;
  final OptionSchema? optionSchema;
  final AccessorOptionSchema? accessorSchema;

  final Map<String, CountFlag>? countFlags;
  final Map<String, BooleanFlag>? boolFlags;

  final Map<String, SingleOption>? singleOptions;
  final Map<String, RepeatableOption>? repeatedOptions;

  final Map<String, Positional>? mandatoryPositionals;
  final Map<String, Positional>? discretionaryPositionals;
  final Variadic? variadic;

  final Map<String, AccessorOption>? accessors;

  final List<CommandRegistry>? commandRegistries;

  factory CommandRegistry.create(
    String name,
    String shortDescription, {
    String? longDescription,
    PositionalSchema? positionalSchema,
    FlagSchema? flagSchema,
    OptionSchema? optionSchema,
    AccessorOptionSchema? accessorSchema,
    List<Command>? commands,
  }) {
    final flags = flagSchema?.schema;
    final options = optionSchema?.schema;
    final accessors = accessorSchema?.schema;
    final mandatoryPositionals = positionalSchema?.mandatory;
    final discretionaryPositionals = positionalSchema?.discretionary;

    _validateDefinition(
      name,
      shortDescription,
      positionalSchema,
      flags,
      options,
      accessors,
      commands,
    );

    return CommandRegistry(
      name: name,
      shortDescription: shortDescription,
      longDescription: longDescription,
      positionalSchema: positionalSchema,
      flagSchema: flagSchema,
      optionSchema: optionSchema,
      accessorSchema: accessorSchema,
      boolFlags: _indexByName<BooleanFlag>(flags?.whereType<BooleanFlag>()),
      countFlags: _indexByName<CountFlag>(flags?.whereType<CountFlag>()),
      singleOptions: _indexByName<SingleOption>(
        options?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        options?.whereType<RepeatableOption>(),
      ),
      mandatoryPositionals: _indexByName<Positional>(mandatoryPositionals),
      discretionaryPositionals: _indexByName<Positional>(
        discretionaryPositionals,
      ),
      variadic: positionalSchema?.variadic,
      accessors: _indexByName<AccessorOption>(accessors),
      commands: commands,
    );
  }

  CommandRegistry({
    required this.name,
    required this.shortDescription,
    this.longDescription,
    this.positionalSchema,
    this.flagSchema,
    this.optionSchema,
    this.accessorSchema,
    this.boolFlags,
    this.countFlags,
    this.singleOptions,
    this.repeatedOptions,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.accessors,
    List<Command>? commands,
  }) : commandRegistries = commands
           ?.map(
             (command) => CommandRegistry.create(
               command.name,
               command.shortDescription,
               longDescription: command.longDescription,
               positionalSchema: command.positionalSchema,
               accessorSchema: command.accessorSchema,
               flagSchema: command.flagSchema,
               optionSchema: command.optionSchema,
               commands: command.commands,
             ),
           )
           .toList();

  static final RegExp _keyboardSymbol = RegExp(r'[^A-Za-z0-9_-]');
  static final RegExp _number = RegExp(r'\d');

  static Map<String, T>? _indexByName<T extends NamedInput>(
    Iterable<T>? inputs,
  ) {
    if (inputs == null) return null;
    return {for (final input in inputs) input.name: input};
  }

  static void _validateDefinition(
    String name,
    String shortDescription,
    PositionalSchema? positionalSchema,
    List<Flag>? flags,
    List<Option>? options,
    List<AccessorOption>? accessors,
    List<Command>? commands,
  ) {
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

  static void _validateAccessors(List<AccessorOption>? accessors) {
    if (accessors == null) return;
    _validateAccessorLevel(accessors, 'accessor');
  }

  static void _validateAccessorLevel(
    List<AccessorOption> accessors,
    String inputKind,
  ) {
    _validateDuplicateNames(accessors, inputKind);
    for (final accessor in accessors) {
      _validatePositionalName(accessor.name);
      if (accessor case AccessorListOption(options: final options)) {
        _validateAccessorLevel(options, 'accessor option');
      }
    }
  }

  static void _validatePositionals(PositionalSchema? positionalSchema) {
    if (positionalSchema == null) {
      return;
    }
    for (final positional in [
      ...positionalSchema.mandatory,
      ...?positionalSchema.discretionary,
    ]) {
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
    List<AccessorOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    PositionalSchema? positionalSchema,
    List<Command>? commands,
  ) {
    _validateDuplicateNames(options, 'option');
    _validateDuplicateNames(flags, 'flag');

    if (accessors != null) {
      for (final accessor in accessors) {
        final name = accessor.name;
        final flagIndex = flags?.indexWhere((flag) => flag.name == name) ?? -1;
        if (flagIndex >= 0) {
          throw MambaException(
            'This accessor $name has the same name as a flag at index $flagIndex',
          );
        }
        final optionIndex =
            options?.indexWhere((option) => option.name == name) ?? -1;
        if (optionIndex >= 0) {
          throw MambaException(
            'This accessor $name has the same name as an option at index $optionIndex',
          );
        }
      }
    }

    if (positionalSchema != null) {
      final names = <String>{};
      final positionals = [
        ...positionalSchema.mandatory,
        ...?positionalSchema.discretionary,
      ];

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

      final variadic = positionalSchema.variadic;
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

abstract interface class MapToRecord<T extends Record> {
  T toRecord(Map<String, dynamic> args);
}

abstract class Schema<T extends Record, U extends NamedInput>
    implements MapToRecord<T> {
  List<U> get schema;
}

abstract class FlagSchema<T extends Record> extends Schema<T, Flag> {}

abstract class OptionSchema<T extends Record> extends Schema<T, Option> {}

abstract class AccessorOptionSchema<T extends Record>
    extends Schema<T, AccessorOption> {}

abstract class PositionalSchema<T extends Record> implements MapToRecord<T> {
  List<Positional> mandatory;
  List<Positional>? discretionary;
  Variadic? variadic;

  PositionalSchema(this.mandatory, {this.discretionary, this.variadic});
}

typedef Inputs<
  FlagRecord extends Record,
  OptionRecord extends Record,
  AccessorRecord extends Record,
  PositionalRecord extends Record
> = ({
  FlagRecord? flags,
  OptionRecord? options,
  PositionalRecord? positionals,
  AccessorRecord? acessors,
  List<String> variadic,
});

abstract class Command<
  FlagRecord extends Record,
  OptionRecord extends Record,
  AccessorRecord extends Record,
  PositionalRecord extends Record
> {
  final String name;
  final String shortDescription;
  final String? longDescription;

  final PositionalSchema<PositionalRecord>? positionalSchema;
  final AccessorOptionSchema<AccessorRecord>? accessorSchema;
  final FlagSchema<FlagRecord>? flagSchema;
  final OptionSchema<OptionRecord>? optionSchema;

  final List<Command>? commands;

  Command(
    this.name,
    this.shortDescription, {
    this.longDescription,
    this.positionalSchema,
    this.accessorSchema,
    this.flagSchema,
    this.optionSchema,
    this.commands,
  });

  void run(
    Inputs<FlagRecord, OptionRecord, AccessorRecord, PositionalRecord> inputs,
    List<String> variadic,
  );
}

abstract class GroupCommand<
  FlagRecord extends Record,
  OptionRecord extends Record,
  AccessorRecord extends Record,
  PositionalRecord extends Record
>
    extends
        Command<FlagRecord, OptionRecord, AccessorRecord, PositionalRecord> {
  final List<String>? defaultSubCommandPath;

  GroupCommand(
    super.name,
    super.shortDescription, {
    required this.defaultSubCommandPath,
    required super.longDescription,
    required super.positionalSchema,
    required super.accessorSchema,
    required super.flagSchema,
    required super.optionSchema,
    required super.commands,
  });

  @override
  void run(
    Inputs<FlagRecord, OptionRecord, AccessorRecord, PositionalRecord> input,
    List<String> variadic,
  ) {}
}

class Positional extends NamedInput {
  final RegExp? regex;
  Positional(String name, {super.description, RegExp? regex})
    : regex = regex ?? RegExp(r'\S+'),
      super(name: name);
}

class Variadic extends Positional {
  Variadic(super.name, {super.description, super.regex});
}

sealed class NamedInput {
  final String name;
  final String? description;

  const NamedInput({required this.name, required this.description});
}

sealed class Flag extends NamedInput {
  final String? short;

  const Flag({
    required this.short,
    required super.name,
    required super.description,
  });
}

final class BooleanFlag extends Flag {
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

final class CountFlag extends Flag {
  const CountFlag({super.short, required super.name, super.description});
}

sealed class Option extends NamedInput {
  final String? short;
  final bool required;

  const Option({
    required this.short,
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

sealed class SingleOption extends Option {
  const SingleOption({
    required super.short,
    required super.name,
    required super.description,
    super.required,
  });
}

final class StringOption extends SingleOption {
  StringOption({
    required super.name,
    required this.regex,
    super.short,
    super.description,
    super.required,
  });

  final RegExp regex;
}

final class IntOption extends SingleOption {
  IntOption({
    required super.name,
    super.short,
    super.required,
    super.description,
  });
}

final class DoubleOption extends SingleOption {
  DoubleOption({
    required super.name,
    super.short,
    super.required,
    super.description,
  });
}

final class ChoiceOption<T extends Enum> extends SingleOption {
  final List<T> choices;

  ChoiceOption({
    this.defaultValue,
    required this.choices,
    required super.name,
    super.short,
    super.description,
    super.required,
  });

  final T? defaultValue;
}

sealed class RepeatableOption extends Option {
  const RepeatableOption({
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

  RepeatableStringOption({
    required super.name,
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');
}

final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
  });
}

final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
  });
}

sealed class AccessorOption extends NamedInput {
  const AccessorOption({required super.name, super.description});
}

sealed class AccessorPrimitiveOption extends AccessorOption {
  const AccessorPrimitiveOption({required super.name, super.description});
}

final class AccessorListOption extends AccessorOption {
  final List<AccessorOption> options;

  AccessorListOption({
    required super.name,
    super.description,
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options);
}

final class AccessorStringOption extends AccessorPrimitiveOption {
  final RegExp _regExp;
  AccessorStringOption({required super.name, super.description, RegExp? regex})
    : _regExp = regex ?? RegExp(r'\S+');

  RegExp get regex => _regExp;
}

final class AccessorIntOption extends AccessorPrimitiveOption {
  AccessorIntOption({required super.name, super.description});

  RegExp get regex => RegExp(r'\d+');
}

final class AccessorDoubleOption extends AccessorPrimitiveOption {
  AccessorDoubleOption({required super.name, super.description});

  RegExp get regex => RegExp(r'\d+\.\d+');
}

final class AccessorChoiceOption<T extends Enum>
    extends AccessorPrimitiveOption {
  final List<T> choices;
  final T? defaultValue;

  AccessorChoiceOption({
    required super.name,
    super.description,
    required this.choices,
    this.defaultValue,
  });
}
