import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';

typedef RegistryRecord = ({
  String name,
  String description,
  List<RegistryCommand>? commands,
  RegistryVariadic? variadic,
  List<RegistryPositional>? positionals,
  List<RegistryFlag>? flags,
  List<RegistryFlag>? persistentFlags,
  List<RegistryOption>? options,
  List<RegistryOption>? persistentOptions,
  List<RegistryOptionGroup>? optionGroups,
  List<RegistryAccessor>? accessors,
});
typedef RegistryFlag = ({
  String name,
  String? short,
  bool? defaultValue,
  bool? negatable,
  bool hidden,
  String? description,
});
typedef RegistryOption = ({
  String name,
  String? short,
  bool required,
  bool hidden,
  String? description,
  String valueType,
  bool? repeatable,
  bool? unique,
  List<String>? choices,
  String? defaultValue,
  String? pattern,
  num? min,
  num? max,
  num? step,
  List<String>? pairedOptions,
});
typedef RegistryPositional = ({
  String name,
  bool required,
  String? description,
  List<String>? choices,
  String? defaultValue,
  bool? repeatable,
  int? times,
  String? pattern,
});
typedef RegistryVariadic = ({
  String? description,
  List<String>? choices,
  String? defaultValue,
  String? pattern,
});

typedef RegistryOptionGroup = ({bool required, List<String> members});

final class RegistryCommand {
  RegistryCommand({
    required this.name,
    required this.description,
    this.aliases,
    this.commands,
    this.variadic,
    this.positionals,
    this.flags,
    this.persistentFlags,
    this.options,
    this.persistentOptions,
    this.optionGroups,
    this.accessors,
  });
  final String name;
  final String description;
  final List<String>? aliases;
  final List<RegistryCommand>? commands;
  final RegistryVariadic? variadic;
  final List<RegistryPositional>? positionals;
  final List<RegistryFlag>? flags;
  final List<RegistryFlag>? persistentFlags;
  final List<RegistryOption>? options;
  final List<RegistryOption>? persistentOptions;
  final List<RegistryOptionGroup>? optionGroups;
  final List<RegistryAccessor>? accessors;
}

final class RegistryAccessor {
  RegistryAccessor.group({
    required this.name,
    required this.hidden,
    this.description,
    required List<RegistryAccessor> options,
  }) : kind = 'group',
       valueType = null,
       choices = null,
       defaultValue = null,
       pattern = null,
       options = List.unmodifiable(options);
  RegistryAccessor.value({
    required this.name,
    required this.valueType,
    this.description,
    this.choices,
    this.defaultValue,
    this.pattern,
  }) : kind = 'value',
       hidden = null,
       options = null;
  final String name;
  final String kind;
  final bool? hidden;
  final String? description;
  final String? valueType;
  final List<String>? choices;
  final String? defaultValue;
  final String? pattern;
  final List<RegistryAccessor>? options;
}

final class CommandResolution {
  const CommandResolution({
    required this.registry,
    required this.path,
    required this.tokenIndices,
  });

  final CommandRegistry registry;
  final List<String> path;
  final Set<int> tokenIndices;
}

final class MambaCommandNotFoundException extends MambaException {
  MambaCommandNotFoundException(
    String name,
    List<String> parentPath,
    List<String> available,
  ) : super(
        'Command $name was not found under ${parentPath.join(' ')}. ${available.isEmpty ? 'This command has no subcommands.' : 'Available commands: ${available.join(', ')}'}',
      );
}

final class CommandRegistry {
  CommandRegistry._({
    required this.name,
    required this.shortDescription,
    this.longDescription,
    this.commandAliases,
    this.parent,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptionsDefinition>? pairedOptions,
    List<SelectedOptions>? selectedOptionses,
    Map<String, List<String>>? conflicts,
    List<MandatoryPositional>? mandatoryPositionals,
    List<DiscretionaryPositional>? discretionaryPositionals,
    this.variadic,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<Flag>? publishedFlags,
    List<Option>? publishedOptions,
  }) : flags = List.unmodifiable(flags ?? const []),
       options = List.unmodifiable(options ?? const []),
       pairedOptionGroups = List.unmodifiable(pairedOptions ?? const []),
       selectedOptionses = List.unmodifiable(selectedOptionses ?? const []),
       conflicts = Map<String, List<String>>.unmodifiable({
         for (final entry
             in (conflicts ?? const <String, List<String>>{}).entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       mandatoryPositionals = List.unmodifiable(
         mandatoryPositionals ?? const [],
       ),
       discretionaryPositionals = List.unmodifiable(
         discretionaryPositionals ?? const [],
       ),
       accessors = List.unmodifiable(accessors ?? const []),
       publishedFlags = List.unmodifiable(publishedFlags ?? const []),
       publishedOptions = List.unmodifiable(publishedOptions ?? const []),
       commands = List.unmodifiable(commands ?? const []);
  final String name;
  final String shortDescription;
  final String? longDescription;
  final List<String>? commandAliases;
  final CommandRegistry? parent;
  final List<Flag> flags;
  final List<Option> options;
  final List<PairedOptionsDefinition> pairedOptionGroups;
  final List<SelectedOptions> selectedOptionses;
  final Map<String, List<String>> conflicts;
  final List<MandatoryPositional> mandatoryPositionals;
  final List<DiscretionaryPositional> discretionaryPositionals;
  final Variadic? variadic;
  final List<AccessorListOption> accessors;
  final List<Flag> publishedFlags;
  final List<Option> publishedOptions;
  final List<Command> commands;
  late final List<CommandRegistry> commandRegistries = [
    for (final command in commands) _fromCommand(command, this),
  ];
  BooleanFlag get helpFlag => MambaBuiltInFlags.help;
  List<String> get fullPath => [...?parent?.fullPath, name];
  List<Flag> get applicableFlags {
    final resolved = <String, Flag>{
      for (final flag in [...?parent?._publishedFlagsToHere, ...flags])
        flag.name: flag,
    };
    if (parent == null) {
      resolved[MambaBuiltInFlags.help.name] = MambaBuiltInFlags.help;
    }
    return List.unmodifiable(resolved.values);
  }

  List<Flag> get _publishedFlagsToHere => [
    ...?parent?._publishedFlagsToHere,
    ...publishedFlags,
  ];
  List<Option> get applicableOptions => List.unmodifiable(
    {
      for (final option in [...?parent?._publishedOptionsToHere, ...options])
        option.name: option,
    }.values,
  );
  List<Option> get _publishedOptionsToHere => [
    ...?parent?._publishedOptionsToHere,
    ...publishedOptions,
  ];
  factory CommandRegistry.create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<MandatoryPositional>? mandatoryPositionals,
    List<DiscretionaryPositional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptionsDefinition>? pairedOptions,
    List<SelectedOptions>? selectedOptionses,
    Map<String, List<String>>? conflicts,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
  }) {
    _validate(
      name,
      shortDescription,
      flags: [...?flags, MambaBuiltInFlags.help],
      options: options,
      paired: pairedOptions,
      selected: selectedOptionses,
      conflicts: conflicts,
      accessors: accessors,
      mandatory: mandatoryPositionals,
      discretionary: discretionaryPositionals,
      commands: commands,
    );
    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      longDescription: longDescription,
      flags: flags,
      options: options,
      pairedOptions: pairedOptions,
      selectedOptionses: selectedOptionses,
      conflicts: conflicts,
      mandatoryPositionals: mandatoryPositionals,
      discretionaryPositionals: discretionaryPositionals,
      variadic: variadic,
      accessors: accessors,
      commands: commands,
      publishedFlags: flags,
      publishedOptions: options,
    );
  }
  static CommandRegistry _fromCommand(Command command, CommandRegistry parent) {
    final group = command is GroupCommand ? command : null;
    _validate(
      command.name,
      command.shortDescription,
      flags: command.flags,
      options: command.options,
      paired: command.pairedOptions,
      selected: command.selectedOptionses,
      conflicts: command.conflicts,
      accessors: command.accessors,
      mandatory: command.mandatoryPositionals,
      discretionary: command.discretionaryPositionals,
      commands: group?.commands,
    );
    return CommandRegistry._(
      name: command.name,
      shortDescription: command.shortDescription,
      longDescription: command.longDescription,
      commandAliases: command.aliases,
      parent: parent,
      flags: command.flags,
      options: command.options,
      pairedOptions: command.pairedOptions,
      selectedOptionses: command.selectedOptionses,
      conflicts: command.conflicts,
      mandatoryPositionals: command.mandatoryPositionals,
      discretionaryPositionals: command.discretionaryPositionals,
      variadic: command.variadic,
      accessors: command.accessors,
      commands: group?.commands,
      publishedFlags: group?.inheritedFlags,
      publishedOptions: group?.inheritedOptions,
    );
  }

  CommandRegistry withInheritedInputs() => this;

  /// Resolves command tokens while skipping values owned by applicable inputs.
  CommandResolution resolveCommandPath(List<String> args) {
    var registry = this;
    final path = <CommandRegistry>[];
    final indices = <int>{};
    for (var index = 0; index < args.length; index++) {
      final token = args[index];
      if (token == '--') break;
      final ownedLength = registry.registeredInputTokenLength(token);
      if (ownedLength != null) {
        index += ownedLength - 1;
        continue;
      }
      if (path.isEmpty && token == name) {
        indices.add(index);
        continue;
      }
      final child = registry.commandRegistries
          .where(
            (candidate) =>
                candidate.name == token ||
                candidate.commandAliases?.contains(token) == true,
          )
          .firstOrNull;
      if (child != null) {
        registry = child;
        path.add(child);
        indices.add(index);
      }
    }
    return CommandResolution(
      registry: registry,
      path: List.unmodifiable([name, ...path.map((item) => item.name)]),
      tokenIndices: Set.unmodifiable(indices),
    );
  }

  CommandRegistry registryForArguments(List<String> args) =>
      resolveCommandPath(args).registry;

  List<String> canonicalCommandPath(List<String> path) {
    if (path.isEmpty) {
      throw MambaRegistryError('defaultCommandPath must not be empty.');
    }
    var registry = this;
    final canonical = <String>[];
    for (final segment in path) {
      final child = registry.commandRegistries
          .where(
            (candidate) =>
                candidate.name == segment ||
                candidate.commandAliases?.contains(segment) == true,
          )
          .firstOrNull;
      if (child == null) {
        throw MambaRegistryError(
          'Unknown default command segment $segment under ${registry.fullPath.join(' ')}.',
        );
      }
      canonical.add(child.name);
      registry = child;
    }
    if (registry.commandRegistries.isNotEmpty) {
      throw MambaRegistryError(
        'defaultCommandPath must end at an executable command.',
      );
    }
    return List.unmodifiable(canonical);
  }

  int? registeredInputTokenLength(String token) {
    if (token.startsWith('--')) {
      final name = token.substring(2).split('=').first;
      if (_allValueInputs.any((input) => input.name == name) ||
          _accessorFor(name) != null)
        return token.contains('=') ? 1 : 2;
      if (applicableFlags.any(
        (flag) =>
            flag.name == name ||
            (flag is BooleanFlag &&
                flag.negatable &&
                name == 'no-${flag.name}'),
      ))
        return 1;
    }
    if (token.startsWith('-') && token.length > 1) {
      final short = token.substring(1);
      if (_allValueInputs.any((input) => _shortOf(input) == short)) return 2;
      if (short
          .split('')
          .every(
            (letter) => applicableFlags.any((flag) => _shortOf(flag) == letter),
          ))
        return 1;
    }
    return null;
  }

  Iterable<InputDefinition> get _allValueInputs sync* {
    yield* applicableOptions;
    for (final group in pairedOptionGroups) yield* group.options;
    for (final group in selectedOptionses) yield* group.options;
  }

  AccessorPrimitiveOption? _accessorFor(String path) {
    AccessorOption? current = accessors
        .where((root) => root.name == path.split('.').first)
        .firstOrNull;
    for (final part in path.split('.').skip(1)) {
      if (current is! AccessorListOption) return null;
      current = current.options
          .where((child) => child.name == part)
          .firstOrNull;
    }
    return current is AccessorPrimitiveOption ? current : null;
  }

  InputDefinition? conflictInput(String name) =>
      applicableFlags.where((input) => input.name == name).firstOrNull ??
      _allValueInputs.where((input) => input.name == name).firstOrNull ??
      _accessorFor(name);

  static String? _shortOf(InputDefinition input) => switch (input) {
    Flag(:final short) ||
    Option(:final short) ||
    PairOption(:final short) => short,
    _ => null,
  };
  RegistryRecord toMap() => _record(this);
  static RegistryRecord _record(CommandRegistry registry) {
    final options = [
      ...registry.applicableOptions,
      for (final group in registry.pairedOptionGroups) ...group.options,
      for (final group in registry.selectedOptionses) ...group.options,
    ];
    return (
      name: registry.name,
      description: registry.longDescription == null
          ? registry.shortDescription
          : '${registry.shortDescription}\n\n${registry.longDescription}',
      commands: registry.commandRegistries.isEmpty
          ? null
          : List.unmodifiable([
              for (final child in registry.commandRegistries)
                _commandRecord(child),
            ]),
      variadic: registry.variadic == null
          ? null
          : _variadicRecord(registry.variadic!),
      positionals: registry.parent == null
          ? null
          : List.unmodifiable([
              for (final input in registry.mandatoryPositionals)
                _positionalRecord(input, true),
              for (final input in registry.discretionaryPositionals)
                _positionalRecord(input, false),
            ]),
      flags: List.unmodifiable([
        for (final flag in registry.applicableFlags) _flagRecord(flag),
      ]),
      persistentFlags: null,
      options: options.isEmpty
          ? null
          : List.unmodifiable([
              for (final option in options) _optionRecord(option, registry),
            ]),
      persistentOptions: null,
      optionGroups: [
        ...registry.pairedOptionGroups.map(
          (group) => (
            required: group.required,
            members: List.unmodifiable(group.options.map((item) => item.name)),
          ),
        ),
      ],
      accessors: registry.accessors.isEmpty
          ? null
          : List.unmodifiable([
              for (final accessor in registry.accessors)
                _accessorRecord(accessor),
            ]),
    );
  }

  static RegistryCommand _commandRecord(CommandRegistry registry) {
    final record = _record(registry);
    return RegistryCommand(
      name: record.name,
      description: record.description,
      aliases: registry.commandAliases,
      commands: record.commands,
      variadic: record.variadic,
      positionals: record.positionals,
      flags: record.flags,
      options: record.options,
      optionGroups: record.optionGroups,
      accessors: record.accessors,
    );
  }

  static RegistryFlag _flagRecord(Flag flag) => (
    name: flag.name,
    short: flag.short,
    defaultValue: flag is BooleanFlag ? flag.defaultValue : null,
    negatable: flag is BooleanFlag ? flag.negatable : null,
    hidden: flag.hidden,
    description: flag.description,
  );
  static RegistryOption _optionRecord(
    InputDefinition input,
    CommandRegistry registry,
  ) {
    final choice = input is ChoiceValidated
        ? (input as ChoiceValidated).choices.cast<Enum>()
        : null;
    final range = input is NumericRangeValidated
        ? input as NumericRangeValidated
        : null;
    return (
      name: input.name,
      short: _shortOf(input),
      required: input is Option ? input.isRequired : false,
      hidden: input is Option ? input.hidden : false,
      description: input.description,
      valueType: input is NumericRangeValidated<int>
          ? 'int'
          : input is NumericRangeValidated<double>
          ? 'double'
          : input is RegExpValidated
          ? 'string'
          : 'choice',
      repeatable:
          input is RepeatableOptionDefinition || input is RepeatablePairOption
          ? true
          : null,
      unique: input is RepeatableOptionDefinition && input.unique ? true : null,
      choices: choice == null
          ? null
          : List.unmodifiable(choice.map((item) => item.name)),
      defaultValue: switch (input) {
        DefaultValue(:final defaultValue) => _defaultText(defaultValue),
        _ => null,
      },
      pattern: input is RegExpValidated
          ? (input as RegExpValidated).regex.pattern
          : null,
      min: range?.min,
      max: range?.max,
      step: input is NumericStepValidated
          ? (input as NumericStepValidated).step
          : null,
      pairedOptions: input is PairOption
          ? List.unmodifiable([
              for (final group in registry.pairedOptionGroups)
                if (group.options.contains(input))
                  ...group.options.map((item) => item.name),
            ])
          : null,
    );
  }

  static String _defaultText(Object value) => switch (value) {
    Enum value => value.name,
    List values =>
      values.map((value) => _defaultText(value as Object)).join(','),
    _ => value.toString(),
  };

  static RegistryPositional _positionalRecord(Positional input, bool required) {
    final choices = input is ChoiceValidated
        ? (input as ChoiceValidated).choices.cast<Enum>()
        : null;
    return (
      name: input.name,
      required: required,
      description: input.description,
      choices: choices == null
          ? null
          : List.unmodifiable(choices.map((choice) => choice.name)),
      defaultValue: switch (input) {
        DefaultValue(:final defaultValue) when defaultValue is List<Enum> =>
          defaultValue.map((choice) => choice.name).join(','),
        DefaultValue(:final defaultValue) => (defaultValue as Enum).name,
        _ => null,
      },
      repeatable: input is RepeatedPositionalDefinition ? true : null,
      times: input is RepeatedPositionalDefinition
          ? (input as RepeatedPositionalDefinition).times
          : null,
      pattern: input.regex.pattern,
    );
  }

  static RegistryVariadic _variadicRecord(Variadic input) {
    final choices = input is ChoiceVariadic ? input.choices : null;
    return (
      description: input.description,
      choices: choices == null
          ? null
          : List.unmodifiable(choices.map((choice) => choice.name)),
      defaultValue: input is ChoiceVariadic ? input.defaultValue?.name : null,

      pattern: input is NormalVariadic ? input.regex.pattern : null,
    );
  }

  static RegistryAccessor _accessorRecord(AccessorOption input) =>
      switch (input) {
        AccessorListOption(:final hidden, :final options) =>
          RegistryAccessor.group(
            name: input.name,
            hidden: hidden,
            description: input.description,
            options: [for (final child in options) _accessorRecord(child)],
          ),
        AccessorPrimitiveOption() => RegistryAccessor.value(
          name: input.name,
          valueType: input is AccessorStringOption
              ? 'string'
              : input is AccessorIntOption
              ? 'int'
              : input is AccessorDoubleOption
              ? 'double'
              : 'choice',
          description: input.description,
          choices: input is ChoiceValidated
              ? List.unmodifiable(
                  (input as ChoiceValidated).choices.cast<Enum>().map(
                    (choice) => choice.name,
                  ),
                )
              : null,
          defaultValue: input is DefaultValue
              ? _defaultText((input as DefaultValue).defaultValue)
              : null,
          pattern: input is RegExpValidated
              ? (input as RegExpValidated).regex.pattern
              : null,
        ),
      };
  static final _name = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$');
  static void _validate(
    String name,
    String description, {
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptionsDefinition>? paired,
    List<SelectedOptions>? selected,
    Map<String, List<String>>? conflicts,
    List<AccessorListOption>? accessors,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    List<Command>? commands,
  }) {
    if (!_name.hasMatch(name) || description.isEmpty)
      throw MambaRegistryError('Invalid command definition');
    if ((paired ?? const <PairedOptionsDefinition>[]).any(
          (group) => group.options.isEmpty,
        ) ||
        (selected ?? const <SelectedOptions>[]).any(
          (group) => group.options.isEmpty,
        )) {
      throw MambaRegistryError(
        'Option groups must contain at least one member.',
      );
    }
    final inputs = [
      ...?flags,
      ...?options,
      for (final group in paired ?? const <PairedOptionsDefinition>[])
        ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        ...group.options,
    ];
    final registeredNames = {for (final input in inputs) input.name};
    void registerAccessorPaths(AccessorOption accessor, String path) {
      if (accessor is AccessorPrimitiveOption) registeredNames.add(path);
      if (accessor is AccessorListOption) {
        for (final child in accessor.options) {
          registerAccessorPaths(child, '$path.${child.name}');
        }
      }
    }

    for (final accessor in accessors ?? const <AccessorListOption>[]) {
      registerAccessorPaths(accessor, accessor.name);
    }
    for (final entry in (conflicts ?? const <String, List<String>>{}).entries) {
      if (!registeredNames.contains(entry.key)) {
        throw MambaRegistryError(
          'Conflict key ${entry.key} is not a registered input.',
        );
      }
      for (final (index, member) in entry.value.indexed) {
        if (!registeredNames.contains(member)) {
          throw MambaRegistryError(
            'Conflict member at index $index for ${entry.key} is not a registered input: $member.',
          );
        }
      }
    }
    final names = <String>{};
    final shorts = <String, InputDefinition>{};
    for (final input in inputs) {
      if (!_name.hasMatch(input.name) || !names.add(input.name)) {
        throw MambaRegistryError('Duplicate or invalid input ${input.name}');
      }
      final short = _shortOf(input);
      if (short == null) continue;
      if (!RegExp(r'^[A-Za-z0-9]$').hasMatch(short)) {
        throw MambaRegistryError(
          'Short alias $short for ${input.name} must be one ASCII letter or digit without a dash.',
        );
      }
      final previous = shorts[short];
      if (previous != null) {
        throw MambaRegistryError(
          'Short alias -$short is used by both ${previous.name} and ${input.name}.',
        );
      }
      shorts[short] = input;
    }
    final commandNames = <String>{};
    for (final command in commands ?? const <Command>[]) {
      if (!_name.hasMatch(command.name) || !commandNames.add(command.name)) {
        throw MambaRegistryError(
          'Duplicate or invalid command ${command.name}.',
        );
      }
      for (final alias in command.aliases ?? const <String>[]) {
        if (!_name.hasMatch(alias) || !commandNames.add(alias)) {
          throw MambaRegistryError(
            'Duplicate or invalid command alias $alias for ${command.name}.',
          );
        }
      }
    }
    final leaves = <AccessorPrimitiveOption>{};
    void visit(AccessorOption input) {
      if (input is AccessorPrimitiveOption && !leaves.add(input))
        throw MambaRegistryError(
          'Accessor leaf ${input.name} is reused in multiple paths.',
        );
      if (input is AccessorListOption) {
        final level = <String>{};
        for (final child in input.options) {
          if (!level.add(child.name))
            throw MambaRegistryError('Duplicate accessor ${child.name}');
          visit(child);
        }
      }
    }

    final accessorNames = <String>{};
    for (final accessor in accessors ?? const <AccessorListOption>[]) {
      if (!accessorNames.add(accessor.name)) {
        throw MambaRegistryError('Duplicate accessor ${accessor.name}');
      }
      visit(accessor);
    }
    void validateChoices(InputDefinition input) {
      if (input is ChoiceValidated) {
        final choices = (input as ChoiceValidated).choices.cast<Enum>();
        if (choices.isEmpty)
          throw MambaRegistryError(
            'Choices for ${input.name} must not be empty.',
          );
        final defaultValue = switch (input) {
          DefaultValue(:final defaultValue) => defaultValue,
          _ => null,
        };
        final defaultsAreRegistered = switch (defaultValue) {
          null => true,
          List<Enum> values => values.every(choices.contains),
          Enum value => choices.contains(value),
          _ => false,
        };
        if (!defaultsAreRegistered) {
          throw MambaRegistryError(
            'Every default must be a registered choice for ${input.name}.',
          );
        }
      }
      if (input is AccessorListOption)
        for (final child in input.options) validateChoices(child);
    }

    for (final input in [
      ...?options,
      ...?mandatory,
      ...?discretionary,
      ...?accessors,
      for (final group in paired ?? const <PairedOptionsDefinition>[])
        ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        ...group.options,
    ]) {
      validateChoices(input);
    }
    void validateNumeric(InputDefinition input) {
      if (input is NumericRangeValidated) {
        final range = input as NumericRangeValidated;
        if (range.min != null && range.max != null && range.min! > range.max!) {
          throw MambaRegistryError(
            'Minimum must not exceed maximum for ${input.name}.',
          );
        }
      }
      if (input is NumericStepValidated) {
        final stepped = input as NumericStepValidated;
        if (stepped.step != null && stepped.step! <= 0) {
          throw MambaRegistryError('Step must be positive for ${input.name}.');
        }
      }
      if (input is DefaultValue) {
        final defaulted = input as DefaultValue;
        final defaults = defaulted.defaultValue is List
            ? defaulted.defaultValue as List
            : [defaulted.defaultValue];
        for (final value in defaults) {
          if (input is RegExpValidated &&
              (value is! String ||
                  !(input as RegExpValidated).regex.hasMatch(value))) {
            throw MambaRegistryError(
              'Default value is invalid for ${input.name}.',
            );
          }
          if (input is NumericRangeValidated && value is num) {
            final range = input as NumericRangeValidated;
            final min = range.min;
            final max = range.max;
            if ((min != null && value < min) || (max != null && value > max)) {
              throw MambaRegistryError(
                'Default value is outside the range for ${input.name}.',
              );
            }
          }
        }
      }
      if (input is AccessorListOption) {
        for (final child in input.options) validateNumeric(child);
      }
    }

    for (final input in [
      ...?options,
      ...?accessors,
      for (final group in paired ?? const <PairedOptionsDefinition>[])
        ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        ...group.options,
    ]) {
      validateNumeric(input);
    }
  }
}
