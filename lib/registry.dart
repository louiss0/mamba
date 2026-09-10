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
  bool? repeatable,
  String? pattern,
});

enum RegistryOptionGroupMode { all, oneOf }

typedef RegistryOptionGroup = ({
  RegistryOptionGroupMode mode,
  bool required,
  List<String> members,
});

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
  static final BooleanFlag _helpFlag = BooleanFlag(
    'help',
    short: 'h',
    description: 'Show this help message.',
  );
  CommandRegistry._({
    required this.name,
    required this.shortDescription,
    this.longDescription,
    this.commandAliases,
    this.parent,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<SelectedOptions>? selectedOptions,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    this.variadic,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<Flag>? publishedFlags,
    List<Option>? publishedOptions,
  }) : flags = List.unmodifiable(flags ?? const []),
       options = List.unmodifiable(options ?? const []),
       pairedOptionGroups = List.unmodifiable(pairedOptions ?? const []),
       selectedOptionGroups = List.unmodifiable(selectedOptions ?? const []),
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
  final List<PairedOptions> pairedOptionGroups;
  final List<SelectedOptions> selectedOptionGroups;
  final List<Positional> mandatoryPositionals;
  final List<Positional> discretionaryPositionals;
  final Variadic? variadic;
  final List<AccessorListOption> accessors;
  final List<Flag> publishedFlags;
  final List<Option> publishedOptions;
  final List<Command> commands;
  late final List<CommandRegistry> commandRegistries = [
    for (final command in commands) _fromCommand(command, this),
  ];
  BooleanFlag get helpFlag => _helpFlag;
  List<String> get fullPath => [...?parent?.fullPath, name];
  List<Flag> get applicableFlags {
    final resolved = <String, Flag>{
      for (final flag in [...?parent?._publishedFlagsToHere, ...flags])
        flag.name: flag,
    };
    if (parent == null) resolved[_helpFlag.name] = _helpFlag;
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
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<SelectedOptions>? selectedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
  }) {
    _validate(
      name,
      shortDescription,
      flags: flags,
      options: options,
      paired: pairedOptions,
      selected: selectedOptions,
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
      selectedOptions: selectedOptions,
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
      selected: command.selectedOptions,
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
      selectedOptions: command.selectedOptions,
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
  CommandRegistry registryForArguments(List<String> args) {
    var registry = this;
    for (var index = 0; index < args.length; index++) {
      final token = args[index];
      if (token == '--') break;
      final child = registry.commandRegistries
          .where(
            (candidate) =>
                candidate.name == token ||
                candidate.commandAliases?.contains(token) == true,
          )
          .firstOrNull;
      if (child != null) registry = child;
    }
    return registry;
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
    for (final group in selectedOptionGroups)
      for (final selected in group.options) yield selected.option;
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

  static String? _shortOf(InputDefinition input) => switch (input) {
    Flag(:final short) ||
    Option(:final short) ||
    PairOption(:final short) => short,
    _ => null,
  };
  RegistryRecord toMap() => _record(this);
  static RegistryRecord _record(CommandRegistry registry) {
    final options = [
      ...registry.options,
      for (final group in registry.pairedOptionGroups) ...group.options,
      for (final group in registry.selectedOptionGroups)
        for (final selected in group.options) selected.option,
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
            mode: RegistryOptionGroupMode.all,
            required: group.required,
            members: List.unmodifiable(group.options.map((item) => item.name)),
          ),
        ),
        ...registry.selectedOptionGroups.map(
          (group) => (
            mode: RegistryOptionGroupMode.oneOf,
            required: group.required,
            members: List.unmodifiable(
              group.options.map((item) => item.option.name),
            ),
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
      required: input is Option ? input.required : false,
      hidden: input is Option ? input.hidden : false,
      description: input.description,
      valueType:
          input is StringOption ||
              input is RepeatableStringOption ||
              input is PairStringOption ||
              input is RepeatablePairStringOption
          ? 'string'
          : input is IntOption ||
                input is RepeatableIntOption ||
                input is PairIntOption ||
                input is RepeatablePairIntOption
          ? 'int'
          : input is DoubleOption ||
                input is RepeatableDoubleOption ||
                input is PairDoubleOption ||
                input is RepeatablePairDoubleOption
          ? 'double'
          : 'choice',
      repeatable: input is RepeatableOption || input is RepeatablePairOption
          ? true
          : null,
      unique: input is RepeatableChoiceOption && input.unique ? true : null,
      choices: choice == null
          ? null
          : List.unmodifiable(choice.map((item) => item.name)),
      defaultValue: switch (input) {
        ChoiceOption(:final defaultValue?) => defaultValue.name,
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
              for (final group in registry.selectedOptionGroups)
                if (group.options.any((item) => identical(item.option, input)))
                  ...group.options.map((item) => item.option.name),
            ])
          : null,
    );
  }

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
        ChoicePositional(:final defaultValue?) => defaultValue.name,
        RepeatedChoicePositional(:final defaultValue?) => defaultValue.name,
        _ => null,
      },
      repeatable: input is RepeatedPositional ? true : null,
      times: input is RepeatedPositional ? input.times : null,
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
      repeatable: input is RepeatedChoiceVariadic ? true : null,
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
          defaultValue: input is AccessorChoiceOption
              ? input.defaultValue?.name
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
    List<PairedOptions>? paired,
    List<SelectedOptions>? selected,
    List<AccessorListOption>? accessors,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    List<Command>? commands,
  }) {
    if (!_name.hasMatch(name) || description.isEmpty)
      throw MambaRegistryError('Invalid command definition');
    if ((paired ?? const <PairedOptions>[]).any(
          (group) => group.options.isEmpty,
        ) ||
        (selected ?? const <SelectedOptions>[]).any(
          (group) => group.options.isEmpty,
        )) {
      throw MambaRegistryError(
        'Option groups must contain at least one member.',
      );
    }
    final names = <String>{};
    for (final input in [
      ...?flags,
      ...?options,
      for (final group in paired ?? const <PairedOptions>[]) ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        for (final member in group.options) member.option,
    ]) {
      if (!_name.hasMatch(input.name) || !names.add(input.name))
        throw MambaRegistryError('Duplicate or invalid input ${input.name}');
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
          ChoiceOption(:final defaultValue) => defaultValue,
          ChoicePositional(:final defaultValue) => defaultValue,
          RepeatedChoicePositional(:final defaultValue) => defaultValue,
          AccessorChoiceOption(:final defaultValue) => defaultValue,
          _ => null,
        };
        if (defaultValue != null && !choices.contains(defaultValue)) {
          throw MambaRegistryError(
            'Default ${defaultValue.name} is not a registered choice for ${input.name}.',
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
      for (final group in paired ?? const <PairedOptions>[]) ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        for (final member in group.options) member.option,
    ]) {
      validateChoices(input);
    }
    for (final input in [
      ...?options,
      for (final group in paired ?? const <PairedOptions>[]) ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        for (final member in group.options) member.option,
    ]) {
      if (input is NumericRangeValidated) {
        final range = input as NumericRangeValidated;
        if (range.min != null && range.max != null && range.min! > range.max!) {
          throw MambaRegistryError(
            'Minimum must not exceed maximum for ${input.name}.',
          );
        }
      }
    }
  }
}
