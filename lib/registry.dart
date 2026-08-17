import 'dart:async';

import 'errors.dart';

/// Parsed command inputs grouped by their concrete value type.
typedef Inputs = ({
  Map<String, bool>? boolFlags,
  Map<String, int>? countFlags,
  Map<String, String>? stringOptions,
  Map<String, int>? intOptions,
  Map<String, double>? doubleOptions,
  Map<String, List<String>>? repeatedStringOptions,
  Map<String, List<int>>? repeatedIntOptions,
  Map<String, List<double>>? repeatedDoubleOptions,
  Map<String, dynamic>? accessors,
});

final class CommandRegistry {
  CommandRegistry._({
    required this.name,
    required this.shortDescription,
    this.longDescription,
    this.boolFlags,
    this.countFlags,
    this.singleOptions,
    this.repeatedOptions,
    this.pairedOptions,
    this.pairOptions,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.accessors,
    this.commandRegistries,
  });

  final String name;
  final String shortDescription;
  final String? longDescription;
  final Map<String, CountFlag>? countFlags;
  final Map<String, BooleanFlag>? boolFlags;
  final Map<String, SingleOption>? singleOptions;
  final Map<String, RepeatableOption>? repeatedOptions;
  final Map<String, PairedOption>? pairedOptions;
  final Map<String, PairOption>? pairOptions;
  final Map<String, Positional>? mandatoryPositionals;
  final Map<String, Positional>? discretionaryPositionals;
  final Variadic? variadic;
  final Map<String, AccessorOption>? accessors;
  final List<CommandRegistry>? commandRegistries;

  factory CommandRegistry.create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<AccessorOption>? accessors,
    List<Command>? commands,
  }) {
    _validateDefinition(
      name,
      shortDescription,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      flags,
      options,
      pairedOptions,
      accessors,
      commands,
    );

    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      longDescription: longDescription,
      boolFlags: _indexByName<BooleanFlag>(flags?.whereType<BooleanFlag>()),
      countFlags: _indexByName<CountFlag>(flags?.whereType<CountFlag>()),
      singleOptions: _indexByName<SingleOption>(
        options?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        options?.whereType<RepeatableOption>(),
      ),
      pairedOptions: _indexByName<PairedOption>(pairedOptions),
      pairOptions: _indexByName<PairOption>(
        pairedOptions?.expand((pairedOption) => pairedOption.options),
      ),
      mandatoryPositionals: _indexByName<Positional>(mandatoryPositionals),
      discretionaryPositionals: _indexByName<Positional>(
        discretionaryPositionals,
      ),
      variadic: variadic,
      accessors: _indexByName<AccessorOption>(accessors),
      commandRegistries: commands
          ?.map(
            (command) => CommandRegistry.create(
              command.name,
              command.shortDescription,
              longDescription: command.longDescription,
              mandatoryPositionals: command.mandatoryPositionals,
              discretionaryPositionals: command.discretionaryPositionals,
              variadic: command.variadic,
              flags: command.flags,
              options: command.options,
              pairedOptions: command.pairedOptions,
              accessors: command.accessors,
              commands: command.commands,
            ),
          )
          .toList(),
    );
  }

  static final RegExp _keyboardSymbol = RegExp(r'[^A-Za-z0-9_-]');
  static final RegExp _number = RegExp(r'\d');

  static Map<String, T>? _indexByName<T extends NamedInput>(
    Iterable<T>? inputs,
  ) => inputs == null ? null : {for (final input in inputs) input.name: input};

  static void _validateDefinition(
    String name,
    String shortDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<AccessorOption>? accessors,
    List<Command>? commands,
  ) {
    _validateCommandName(name);
    _validateShortDescription(shortDescription);
    _validateNamedInputs(options, 'Option');
    _validatePairedOptions(pairedOptions);
    _validateNamedInputs(flags, 'Flag');
    _validateAccessors(accessors);
    _validatePositionals(
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
    );
    _validateDuplicates(
      accessors,
      flags,
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      commands,
    );
  }

  static void _validateCommandName(String name) {
    if (name.isEmpty) throw const MambaException('Command name is empty,');
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
    if (inputs == null) return;
    for (final input in inputs) {
      if (_keyboardSymbol.hasMatch(input.name)) {
        throw MambaRegistryError(
          "$inputKind names can't use keyboard symbols other than _ or -",
        );
      }
    }
  }

  static void _validatePairedOptions(List<PairedOption>? pairedOptions) {
    _validateDuplicateNames(pairedOptions, 'paired option');
    _validateNamedInputs(pairedOptions, 'Paired option');
    for (final pairedOption in pairedOptions ?? const <PairedOption>[]) {
      if (pairedOption.options.isEmpty) {
        throw const MambaException(
          'A paired option must contain at least one pair option',
        );
      }
    }
    _validateNamedInputs(
      pairedOptions?.expand((pairedOption) => pairedOption.options),
      'Pair option',
    );
  }

  static void _validateAccessors(List<AccessorOption>? accessors) {
    if (accessors != null) _validateAccessorLevel(accessors, 'accessor');
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

  static void _validatePositionals(
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    Variadic? variadic,
  ) {
    for (final positional in [...?mandatory, ...?discretionary]) {
      _validatePositionalName(positional.name);
    }
    if (variadic != null) _validatePositionalName(variadic.name);
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
    List<PairedOption>? pairedOptions,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    Variadic? variadic,
    List<Command>? commands,
  ) {
    final registeredOptions = [
      ...?options,
      ...?pairedOptions,
      ...?pairedOptions?.expand((pairedOption) => pairedOption.options),
    ];
    _validateDuplicateNames(registeredOptions, 'option');
    _validateDuplicateNames(flags, 'flag');

    for (final accessor in accessors ?? const <AccessorOption>[]) {
      final flagIndex =
          flags?.indexWhere((flag) => flag.name == accessor.name) ?? -1;
      if (flagIndex >= 0) {
        throw MambaException(
          'This accessor ${accessor.name} has the same name as a flag at index $flagIndex',
        );
      }
      final optionIndex = registeredOptions.indexWhere(
        (option) => option.name == accessor.name,
      );
      if (optionIndex >= 0) {
        throw MambaException(
          'This accessor ${accessor.name} has the same name as an option at index $optionIndex',
        );
      }
    }

    final positionals = [...?mandatory, ...?discretionary];
    final names = <String>{};
    for (final positional in positionals) {
      if (!names.add(positional.name)) {
        throw const MambaException(
          "A positional can't have the same name as another positional",
        );
      }
    }
    if (variadic != null && names.contains(variadic.name)) {
      throw const MambaException(
        "A positional and variadic can't have the same name you can pluralize the variadic",
      );
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
  }

  static void _validateDuplicateNames(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) return;
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

abstract class Command {
  Command(
    this.name,
    this.shortDescription, {
    this.longDescription,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.flags,
    this.options,
    this.pairedOptions,
    this.accessors,
    this.commands,
  });

  final String name;
  final String shortDescription;
  final String? longDescription;
  final List<Positional>? mandatoryPositionals;
  final List<Positional>? discretionaryPositionals;
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOption>? pairedOptions;
  final List<AccessorOption>? accessors;
  final List<Command>? commands;

  FutureOr<void> run(
    Map<String, String>? positionals,
    Inputs inputs,
    List<String> variadic,
  );
}

class Positional extends NamedInput {
  Positional(String name, {super.description, RegExp? regex})
    : regex = regex ?? RegExp(r'\S+'),
      super(name: name);

  final RegExp regex;
}

class Variadic extends Positional {
  Variadic(super.name, {super.description, super.regex});
}

sealed class NamedInput {
  const NamedInput({required this.name, required this.description});

  final String name;
  final String? description;
}

sealed class Flag extends NamedInput {
  const Flag({
    required this.short,
    required super.name,
    required super.description,
  });

  final String? short;
}

final class BooleanFlag extends Flag {
  BooleanFlag({
    super.short,
    required super.name,
    super.description,
    this.defaultValue = false,
    this.negatable = false,
  });

  final bool defaultValue;
  final bool negatable;
}

final class CountFlag extends Flag {
  const CountFlag({super.short, required super.name, super.description});
}

sealed class Option extends NamedInput {
  const Option({
    required this.short,
    required super.name,
    required super.description,
    this.required = false,
  });

  final String? short;
  final bool required;

  static StringOption stringOption(
    String name,
    RegExp regex, {
    String? short,
    String? description,
    bool required = false,
  }) => StringOption(
    name: name,
    regex: regex,
    short: short,
    description: description,
    required: required,
  );

  static IntOption intOption(
    String name, {
    String? short,
    String? description,
    bool required = false,
  }) => IntOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static DoubleOption doubleOption(
    String name, {
    String? short,
    String? description,
    bool required = false,
  }) => DoubleOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static ChoiceOption<T> choiceOption<T extends Enum>(
    String name,
    List<T> choices, {
    String? short,
    String? description,
    bool required = false,
  }) => ChoiceOption(
    name: name,
    choices: choices,
    short: short,
    description: description,
    required: required,
  );
}

/// An option with members that form either a required-together group or variant.
sealed class PairedOption extends Option {
  PairedOption({
    required List<PairOption> options,
    required super.short,
    required super.name,
    required super.description,
    super.required,
    this.variant = false,
  }) : options = List.unmodifiable(options);

  final List<PairOption> options;
  final bool variant;
}

final class PairedStringOption extends PairedOption {
  PairedStringOption({
    required super.name,
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairedIntOption extends PairedOption {
  PairedIntOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedDoubleOption extends PairedOption {
  PairedDoubleOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedChoiceOption<T extends Enum> extends PairedOption {
  PairedChoiceOption({
    required this.choices,
    required super.options,
    this.defaultValue,
    required super.name,
    super.short,
    super.description,
    super.required,
    super.variant,
  });

  final List<T> choices;
  final T? defaultValue;
}

final class PairedRepeatableStringOption extends PairedOption {
  PairedRepeatableStringOption({
    required super.name,
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairedRepeatableIntOption extends PairedOption {
  PairedRepeatableIntOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedRepeatableDoubleOption extends PairedOption {
  PairedRepeatableDoubleOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// A member of a [PairedOption] group or variant.
///
/// Pair members always inherit their requiredness from their primary option and
/// therefore do not expose a `required` constructor parameter.
sealed class PairOption extends Option {
  const PairOption({
    required super.short,
    required super.name,
    required super.description,
  }) : super(required: false);
}

final class PairStringOption extends PairOption {
  PairStringOption({
    required super.name,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairIntOption extends PairOption {
  const PairIntOption({required super.name, super.short, super.description});
}

final class PairDoubleOption extends PairOption {
  const PairDoubleOption({required super.name, super.short, super.description});
}

final class PairChoiceOption<T extends Enum> extends PairOption {
  PairChoiceOption({
    required this.choices,
    this.defaultValue,
    required super.name,
    super.short,
    super.description,
  });

  final List<T> choices;
  final T? defaultValue;
}

final class PairRepeatableStringOption extends PairOption {
  PairRepeatableStringOption({
    required super.name,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairRepeatableIntOption extends PairOption {
  const PairRepeatableIntOption({
    required super.name,
    super.short,
    super.description,
  });
}

final class PairRepeatableDoubleOption extends PairOption {
  const PairRepeatableDoubleOption({
    required super.name,
    super.short,
    super.description,
  });
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
  ChoiceOption({
    this.defaultValue,
    required this.choices,
    required super.name,
    super.short,
    super.description,
    super.required,
  });

  final List<T> choices;
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
  }) => RepeatableIntOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static RepeatableDoubleOption doubleOption({
    required String name,
    String? short,
    String? description,
    bool required = false,
  }) => RepeatableDoubleOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static RepeatableStringOption stringOption({
    required String name,
    required RegExp regex,
    String? short,
    String? description,
    bool required = false,
  }) => RepeatableStringOption(
    name: name,
    short: short,
    description: description,
    required: required,
    regex: regex,
  );
}

final class RepeatableStringOption extends RepeatableOption {
  RepeatableStringOption({
    required super.name,
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
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
  AccessorListOption({
    required super.name,
    super.description,
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options);

  final List<AccessorOption> options;
}

final class AccessorStringOption extends AccessorPrimitiveOption {
  AccessorStringOption({required super.name, super.description, RegExp? regex})
    : _regExp = regex ?? RegExp(r'\S+');

  final RegExp _regExp;
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
  AccessorChoiceOption({
    required this.choices,
    this.defaultValue,
    required super.name,
    super.description,
  });

  final List<T> choices;
  final T? defaultValue;
}
