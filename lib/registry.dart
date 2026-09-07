import 'package:mamba/command.dart';

import 'errors.dart';

/// The typed registry description exported for completion integrations.
///
/// Commands and accessor groups use classes because Dart record typedefs cannot
/// refer to themselves recursively.
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
  bool? variant,
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

typedef RegistryOptionGroup = ({
  String mode,
  bool required,
  List<String> members,
});

final class RegistryCommand {
  new({
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
  new group({
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

  new value({
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
  new(String name, List<String> parentPath, List<String> availableCommands)
    : super(
        "Command $name was not found under ${parentPath.join(' ')}. "
        "${availableCommands.isEmpty ? 'This command has no subcommands.' : 'Available commands: ${availableCommands.join(', ')}'}",
      );
}

/// A validated, name-indexed view of one command and its descendants.
///
/// A registry separates each input kind into its own map so callers can look up
/// a definition by name while preserving its input semantics. Each registry
/// holds only its locally declared inputs; inputs inherited from the root and
/// enclosing groups stay at the declaring level through [publishedFlags] and
/// [publishedOptions], and consumers resolve them by walking the [parent]
/// chain from the root.
final class CommandRegistry {
  static final BooleanFlag _helpFlag = BooleanFlag(
    'help',
    short: 'h',
    description: 'Show this help message.',
  );

  new _({
    required this.name,
    required this.shortDescription,
    required this.helpFlag,
    this.longDescription,
    this.aliases,
    this.commandAliases,
    this.boolFlags,
    this.countFlags,
    this.singleOptions,
    this.repeatedOptions,
    this.pairedOptionGroups,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.accessors,
    this.parent,
    this.publishedFlags,
    this.publishedOptions,
    List<Command>? commands,
    List<CommandRegistry>? childRegistries,
    List<String> parentPath = const <String>[],
    List<Flag>? descendantFlags,
    List<Option>? descendantOptions,
  }) {
    // Children are built in the body so they can point back at this registry
    // while the inheritance chain is resolved from the root downward.
    commandRegistries =
        childRegistries ??
        commands
            ?.map(
              (command) => _fromCommand(
                command,
                parent: this,
                parentPath: parentPath,
                inheritedFlags: descendantFlags,
                inheritedOptions: descendantOptions,
              ),
            )
            .toList();
  }

  final String name;
  final String shortDescription;
  final BooleanFlag helpFlag;
  final String? longDescription;

  /// Maps each registered child alias to that child's canonical name.
  final Map<String, String>? aliases;

  /// Alternative names used to select this command among its siblings.
  final List<String>? commandAliases;
  final Map<String, CountFlag>? countFlags;
  final Map<String, BooleanFlag>? boolFlags;
  final Map<String, SingleOption>? singleOptions;
  final Map<String, RepeatableOption>? repeatedOptions;

  /// Pair groups registered directly on this level; pair groups are not
  /// inherited.
  final List<PairedOptions>? pairedOptionGroups;
  final Map<String, Positional>? mandatoryPositionals;
  final Map<String, Positional>? discretionaryPositionals;

  /// Input validating and naming values supplied after `--`.
  final Variadic? variadic;
  final Map<String, AccessorListOption>? accessors;
  late final List<CommandRegistry>? commandRegistries;

  /// The enclosing registry, or `null` on the root.
  final CommandRegistry? parent;

  /// Flags and options this level publishes to its descendants.
  ///
  /// The root publishes its own flags and options; a group publishes its
  /// declared inheritedFlags and inheritedOptions. They are not merged into
  /// descendant tables; the parser collects them by walking from the root.
  final List<Flag>? publishedFlags;
  final List<Option>? publishedOptions;

  /// Builds and validates a root registry from a list-defined command surface.
  ///
  /// The factory indexes inputs by name, supplies the built-in help flag, and
  /// creates child registries for [commands]. It rejects ambiguous names,
  /// aliases, positional definitions, and invalid input definitions.
  factory create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
  }) {
    _validateDefinition(
      name,
      shortDescription,
      null,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      flags,
      options,
      pairedOptions,
      accessors,
      commands,
      [name],
    );

    final copiedMandatoryPositionals = _copyList(mandatoryPositionals);
    final copiedDiscretionaryPositionals = _copyList(discretionaryPositionals);
    final copiedFlags = _copyList(flags);
    final copiedOptions = _copyList(options);
    final copiedPairedOptions = _copyList(pairedOptions);
    final copiedAccessors = _copyList(accessors);
    final copiedCommands = _copyList(commands);

    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      helpFlag: _helpFlag,
      longDescription: longDescription,
      aliases: _indexAliases(copiedCommands),
      boolFlags: _indexByName<BooleanFlag>(
        copiedFlags?.whereType<BooleanFlag>(),
      ),
      countFlags: _indexByName<CountFlag>(copiedFlags?.whereType<CountFlag>()),
      singleOptions: _indexByName<SingleOption>(
        copiedOptions?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        copiedOptions?.whereType<RepeatableOption>(),
      ),
      pairedOptionGroups: copiedPairedOptions,
      mandatoryPositionals: _indexByName<Positional>(
        copiedMandatoryPositionals,
      ),
      discretionaryPositionals: _indexByName<Positional>(
        copiedDiscretionaryPositionals,
      ),
      variadic: variadic,
      accessors: _indexByName<AccessorListOption>(copiedAccessors),
      parent: null,
      publishedFlags: copiedFlags,
      publishedOptions: copiedOptions,
      commands: copiedCommands,
      parentPath: [name],
      descendantFlags: copiedFlags,
      descendantOptions: copiedOptions,
    );
  }

  static CommandRegistry _fromCommand(
    Command command, {
    required CommandRegistry parent,
    List<String> parentPath = const <String>[],
    List<Flag>? inheritedFlags,
    List<Option>? inheritedOptions,
  }) {
    final group = command is GroupCommand ? command : null;
    final childCommands = group?.commands;
    // Inputs this level contributes to its descendants; they stay here and are
    // resolved by walking from the root rather than being merged downward.
    final ownPublishedFlags = group?.inheritedFlags;
    final ownPublishedOptions = group?.inheritedOptions;
    _validateGlobalFlagOverrides(inheritedFlags, ownPublishedFlags);
    _validateGlobalFlagOverrides(inheritedFlags, command.flags);
    _validateGlobalFlagOverrides(ownPublishedFlags, command.flags);
    final publishedFlags = _mergeByName(inheritedFlags, ownPublishedFlags);
    final publishedOptions = _mergeByName(
      inheritedOptions,
      ownPublishedOptions,
    );
    final localOptions = command.options;
    final standalonePairGroups = command.pairedOptions;
    // Inherited inputs join the validation surface so conflicts with local
    // declarations are still reported at the level that would collide.
    final registeredFlags = _mergeByName(publishedFlags, command.flags);
    final registeredOptions = _mergeByName(publishedOptions, localOptions);
    final registeredPairGroups = [...?standalonePairGroups];

    final commandPath = [...parentPath, command.name];
    _validateDefinition(
      command.name,
      command.shortDescription,
      command.aliases,
      command.mandatoryPositionals,
      command.discretionaryPositionals,
      command.variadic,
      registeredFlags,
      registeredOptions,
      registeredPairGroups,
      command.accessors,
      childCommands,
      commandPath,
      inheritedInputs: [...?publishedFlags, ...?publishedOptions],
    );

    return CommandRegistry._(
      name: command.name,
      shortDescription: command.shortDescription,
      helpFlag: _helpFlag,
      longDescription: command.longDescription,
      aliases: _indexAliases(childCommands),
      commandAliases: command.aliases,
      boolFlags: _indexByName<BooleanFlag>(
        command.flags?.whereType<BooleanFlag>(),
      ),
      countFlags: _indexByName<CountFlag>(
        command.flags?.whereType<CountFlag>(),
      ),
      singleOptions: _indexByName<SingleOption>(
        localOptions?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        localOptions?.whereType<RepeatableOption>(),
      ),
      pairedOptionGroups: standalonePairGroups,
      mandatoryPositionals: _indexByName<Positional>(
        command.mandatoryPositionals,
      ),
      discretionaryPositionals: _indexByName<Positional>(
        command.discretionaryPositionals,
      ),
      variadic: command.variadic,
      accessors: _indexByName<AccessorListOption>(command.accessors),
      parent: parent,
      publishedFlags: ownPublishedFlags,
      publishedOptions: ownPublishedOptions,
      commands: childCommands,
      parentPath: [...parentPath, command.name],
      descendantFlags: publishedFlags,
      descendantOptions: publishedOptions,
    );
  }

  /// Exports this registry as a typed record description.
  ///
  /// Constructs records directly, without an intermediate serialized map.
  RegistryRecord toMap() {
    final description = longDescription == null
        ? shortDescription
        : '$shortDescription\n\n$longDescription';

    final flags = _recordFlags([
      helpFlag,
      ...?(boolFlags?.values),
    ], countFlags?.values);

    final localOptions = <Option>[
      ...?(singleOptions?.values),
      ...?(repeatedOptions?.values),
    ];
    final hasOptions =
        localOptions.isNotEmpty ||
        singleOptions != null ||
        repeatedOptions != null ||
        pairedOptionGroups != null;
    final List<RegistryOption>? options = hasOptions
        ? _recordOptions([
            ...localOptions,
            ...?(pairedOptionGroups?.expand((g) => g.options)),
          ], pairedGroups: pairedOptionGroups)
        : null;

    // Mamba's executor root has no positional or variadic inputs. Keep these
    // fields on nested command records, where the command owns their parsing.
    RegistryVariadic? variadic;
    List<RegistryPositional>? positionals;
    if (parent != null) {
      final registeredMandatoryPositionals = mandatoryPositionals;
      final registeredDiscretionaryPositionals = discretionaryPositionals;
      if (registeredMandatoryPositionals != null ||
          registeredDiscretionaryPositionals != null) {
        positionals = List.unmodifiable([
          for (final positional
              in registeredMandatoryPositionals?.values ?? const <Positional>[])
            _recordPositional(positional, true),
          for (final positional
              in registeredDiscretionaryPositionals?.values ??
                  const <Positional>[])
            _recordPositional(positional, false),
        ]);
      }

      final registeredVariadic = this.variadic;
      if (registeredVariadic != null) {
        variadic = _recordVariadic(registeredVariadic);
      }
    }

    final registeredAccessors = accessors;
    final List<RegistryAccessor>? accessorsList = registeredAccessors == null
        ? null
        : List.unmodifiable([
            for (final entry in registeredAccessors.entries)
              _recordAccessorList(entry.value),
          ]);

    // Root inputs are already represented by flags and options. Only nested
    // commands need separate published collections to retain the distinction
    // between local and descendant-published inputs.
    List<RegistryFlag>? persistentFlags;
    List<RegistryOption>? persistentOptions;
    if (parent != null) {
      final inheritedFlags = publishedFlags;
      if (inheritedFlags != null) {
        persistentFlags = _recordFlags(
          inheritedFlags.whereType<BooleanFlag>(),
          inheritedFlags.whereType<CountFlag>(),
        );
      }
      final inheritedOptions = publishedOptions;
      if (inheritedOptions != null) {
        persistentOptions = _recordOptions(
          inheritedOptions,
          pairedGroups: pairedOptionGroups,
        );
      }
    }

    final registeredCommands = commandRegistries;
    final List<RegistryCommand>? commandsList = registeredCommands == null
        ? null
        : List.unmodifiable([
            for (final command in registeredCommands)
              command._toCommandRecord(),
          ]);

    return (
      name: name,
      description: description,
      commands: commandsList,
      variadic: variadic,
      positionals: positionals,
      flags: flags,
      persistentFlags: persistentFlags,
      options: options,
      persistentOptions: persistentOptions,
      optionGroups: pairedOptionGroups == null
          ? null
          : List.unmodifiable([
              for (final group in pairedOptionGroups!)
                (
                  mode: group.variant ? 'oneOf' : 'all',
                  required: group.required,
                  members: List<String>.unmodifiable(
                    group.options.map((option) => option.name),
                  ),
                ),
            ]),
      accessors: accessorsList,
    );
  }

  /// Wraps the canonical export with the aliases owned by this child command.
  RegistryCommand _toCommandRecord() {
    final record = toMap();
    return RegistryCommand(
      name: record.name,
      description: record.description,
      aliases: commandAliases == null
          ? null
          : List.unmodifiable(commandAliases!),
      commands: record.commands,
      variadic: record.variadic,
      positionals: record.positionals,
      flags: record.flags,
      persistentFlags: record.persistentFlags,
      options: record.options,
      persistentOptions: record.persistentOptions,
      optionGroups: record.optionGroups,
      accessors: record.accessors,
    );
  }

  static List<RegistryFlag> _recordFlags(
    Iterable<BooleanFlag>? booleanFlags,
    Iterable<CountFlag>? countFlags,
  ) => List.unmodifiable([
    for (final flag in booleanFlags ?? const <BooleanFlag>[])
      _recordBooleanFlag(flag),
    for (final flag in countFlags ?? const <CountFlag>[])
      _recordCountFlag(flag),
  ]);

  static RegistryFlag _recordBooleanFlag(BooleanFlag flag) => (
    name: flag.name,
    short: flag.short,
    defaultValue: flag.defaultValue,
    negatable: flag.negatable,
    hidden: flag.hidden,
    description: flag.description,
  );

  static RegistryFlag _recordCountFlag(CountFlag flag) => (
    name: flag.name,
    short: flag.short,
    defaultValue: null,
    negatable: null,
    hidden: flag.hidden,
    description: flag.description,
  );

  static List<RegistryOption> _recordOptions(
    Iterable<NamedInput> options, {
    List<PairedOptions>? pairedGroups,
  }) => List.unmodifiable([
    for (final option in options)
      _recordOption(option, pairedGroups: pairedGroups),
  ]);

  static RegistryOption _recordOption(
    NamedInput input, {
    List<PairedOptions>? pairedGroups,
  }) {
    final choiceData = _recordChoiceData(input);
    final (short, required, hidden, description, repeatable) = switch (input) {
      Option(
        short: final short,
        required: final required,
        hidden: final hidden,
        description: final description,
      ) =>
        (short, required, hidden, description, input is RepeatableOption),
      PairOption(short: final short, description: final description) => (
        short,
        false,
        false,
        description,
        input is RepeatablePairOption,
      ),
      _ => throw ArgumentError('Expected an option input'),
    };
    final num? minValue = switch (input) {
      NumericRangeValidated() => (input as NumericRangeValidated).min,
      _ => null,
    };
    final num? maxValue = switch (input) {
      NumericRangeValidated() => (input as NumericRangeValidated).max,
      _ => null,
    };
    final num? stepValue = switch (input) {
      NumericStepValidated() => (input as NumericStepValidated).step,
      _ => null,
    };
    return (
      name: input.name,
      short: short,
      required: required,
      hidden: hidden,
      description: description,
      valueType: _recordOptionValueType(input),
      repeatable: repeatable ? true : null,
      variant:
          input is PairOption &&
              pairedGroups?.any(
                    (group) => group.variant && group.options.contains(input),
                  ) ==
                  true
          ? true
          : null,
      choices: choiceData.choices,
      defaultValue: choiceData.defaultValue,
      pattern: input is RegExpValidated
          ? (input as RegExpValidated).regex.pattern
          : null,
      min: minValue,
      max: maxValue,
      step: stepValue,
      pairedOptions: input is PairOption
          ? _recordPairedOptions(input, pairedGroups)
          : null,
    );
  }

  static ({List<String>? choices, String? defaultValue}) _recordChoiceData(
    NamedInput input,
  ) => switch (input) {
    ChoiceOption(:final choices, :final defaultValue) ||
    ChoicePositional(:final choices, :final defaultValue) ||
    RepeatedChoicePositional(:final choices, :final defaultValue) => (
      choices: List.unmodifiable([for (final choice in choices) choice.name]),
      defaultValue: defaultValue?.name,
    ),
    PairChoiceOption(:final choices) => (
      choices: List.unmodifiable([for (final choice in choices) choice.name]),
      defaultValue: null,
    ),
    _ => (choices: null, defaultValue: null),
  };

  /// Resolves the paired options that share a [PairedOptions] group with
  /// [input]. Pair members always appear together in [pairedOptionGroups], so
  /// a registry-level lookup is safe.
  static List<String> _recordPairedOptions(
    PairOption input,
    List<PairedOptions>? pairedGroups,
  ) {
    final group = pairedGroups?.firstWhere(
      (group) => group.options.contains(input),
      orElse: () => throw ArgumentError(
        'Pair option ${input.name} is not in a paired group',
      ),
    );
    return List.unmodifiable([
      for (final member in group!.options) member.name,
    ]);
  }

  static String _recordOptionValueType(NamedInput input) => switch (input) {
    StringOption() ||
    RepeatableStringOption() ||
    PairStringOption() ||
    RepeatablePairStringOption() => 'string',
    IntOption() ||
    RepeatableIntOption() ||
    PairIntOption() ||
    RepeatablePairIntOption() => 'int',
    DoubleOption() ||
    RepeatableDoubleOption() ||
    PairDoubleOption() ||
    RepeatablePairDoubleOption() => 'double',
    ChoiceOption() || PairChoiceOption() => 'choice',
    _ => throw ArgumentError('Expected an option input'),
  };

  static RegistryPositional _recordPositional(
    Positional positional,
    bool required,
  ) {
    final choiceData = _recordChoiceData(positional);
    final isRepeated = positional is RepeatedPositional;
    return (
      name: positional.name,
      required: required,
      description: positional.description,
      choices: choiceData.choices,
      defaultValue: choiceData.defaultValue,
      repeatable: isRepeated ? true : null,
      times: isRepeated ? positional.times : null,
      pattern: positional.regex.pattern,
    );
  }

  static RegistryVariadic _recordVariadic(Variadic variadic) {
    return switch (variadic) {
      ChoiceVariadic(:final description, :final choices, :final defaultValue) =>
        (
          description: description,
          choices: List.unmodifiable([
            for (final choice in choices) choice.name,
          ]),
          defaultValue: defaultValue?.name,
          repeatable: variadic is RepeatedChoiceVariadic ? true : null,
          pattern: null,
        ),
      NormalVariadic(:final description, :final regex) => (
        description: description,
        choices: null,
        defaultValue: null,
        repeatable: null,
        pattern: regex.pattern,
      ),
    };
  }

  static RegistryAccessor _recordAccessorList(AccessorListOption accessor) =>
      _recordAccessor(accessor);

  static RegistryAccessor _recordAccessor(AccessorOption accessor) =>
      switch (accessor) {
        AccessorListOption(:final hidden, :final description, :final options) =>
          RegistryAccessor.group(
            name: accessor.name,
            hidden: hidden,
            description: description,
            options: List.unmodifiable([
              for (final option in options) _recordAccessor(option),
            ]),
          ),
        AccessorStringOption(:final description) => RegistryAccessor.value(
          name: accessor.name,
          valueType: 'string',
          description: description,
          choices: null,
          defaultValue: null,
          pattern: accessor.regex.pattern,
        ),
        AccessorIntOption(:final description) => RegistryAccessor.value(
          name: accessor.name,
          valueType: 'int',
          description: description,
          choices: null,
          defaultValue: null,
          pattern: accessor.regex.pattern,
        ),
        AccessorDoubleOption(:final description) => RegistryAccessor.value(
          name: accessor.name,
          valueType: 'double',
          description: description,
          choices: null,
          defaultValue: null,
          pattern: accessor.regex.pattern,
        ),
        AccessorChoiceOption(
          :final description,
          :final choices,
          :final defaultValue,
        ) =>
          RegistryAccessor.value(
            name: accessor.name,
            valueType: 'choice',
            description: description,
            choices: List.unmodifiable([
              for (final choice in choices) choice.name,
            ]),
            defaultValue: defaultValue?.name,
            pattern: null,
          ),
      };

  List<Flag> get _inheritableFlags => [
    for (final level in _ancestorChain) ...?level.publishedFlags,
  ];

  List<Option> get _inheritableOptions => [
    for (final level in _ancestorChain) ...?level.publishedOptions,
  ];

  Iterable<CommandRegistry> get _ancestorChain sync* {
    final chain = <CommandRegistry>[];
    for (CommandRegistry? level = this; level != null; level = level.parent) {
      chain.add(level);
    }
    yield* chain.reversed;
  }

  /// The registry names from the root down to this level, so command-not-found
  /// diagnostics can report the exact location of a failed lookup.
  List<String> get fullPath => [for (final level in _ancestorChain) level.name];

  static Map<String, T>? _combineWithInherited<T extends NamedInput>(
    Iterable<T> inherited,
    Map<String, T>? local,
  ) {
    if (local == null && inherited.isEmpty) return null;
    return {for (final input in inherited) input.name: input, ...?local};
  }

  /// Boolean flags available here: the built-in help flag plus inherited and
  /// local declarations, with local same-name definitions taking precedence.
  Map<String, BooleanFlag> get applicableBoolFlags => {
    helpFlag.name: helpFlag,
    ...?_combineWithInherited(
      _inheritableFlags.whereType<BooleanFlag>(),
      boolFlags,
    ),
  };

  /// Count flags available here, including inherited ones.
  Map<String, CountFlag>? get applicableCountFlags => _combineWithInherited(
    _inheritableFlags.whereType<CountFlag>(),
    countFlags,
  );

  /// Local option declarations with single and repeatable shapes combined.
  List<Option>? get _localOptions =>
      singleOptions == null && repeatedOptions == null
      ? null
      : [...?singleOptions?.values, ...?repeatedOptions?.values];

  /// Every option available here, resolved across the root-to-leaf chain so
  /// a nearer same-name definition fully replaces shadowed ones regardless
  /// of single/repeatable cardinality. Resolving before splitting keeps a
  /// type-changing override from resurrecting the shadowed definition in the
  /// other cardinality map.
  Map<String, Option> get _resolvedApplicableOptions => {
    for (final option in [..._inheritableOptions, ...?_localOptions])
      option.name: option,
  };

  bool _hasInheritedOption<T extends Option>() =>
      _inheritableOptions.any((option) => option is T);

  /// Single options available here, including inherited ones.
  Map<String, SingleOption>? get applicableSingleOptions {
    if (singleOptions == null && !_hasInheritedOption<SingleOption>()) {
      return null;
    }
    return {
      for (final option in _resolvedApplicableOptions.values)
        if (option is SingleOption) option.name: option,
    };
  }

  /// Repeatable options available here, including inherited ones.
  Map<String, RepeatableOption>? get applicableRepeatedOptions {
    if (repeatedOptions == null && !_hasInheritedOption<RepeatableOption>()) {
      return null;
    }
    return {
      for (final option in _resolvedApplicableOptions.values)
        if (option is RepeatableOption) option.name: option,
    };
  }

  /// Pair groups registered on this level.
  List<PairedOptions>? get applicablePairedOptionGroups => pairedOptionGroups;

  /// A copy of this registry whose input tables include every flag and option
  /// inherited from the root and enclosing groups.
  ///
  /// Local definitions win over inherited same-name inputs. Positionals,
  /// accessors, variadics, and child registries are never inherited and stay
  /// untouched.
  CommandRegistry withInheritedInputs() => CommandRegistry._(
    name: name,
    shortDescription: shortDescription,
    helpFlag: helpFlag,
    longDescription: longDescription,
    aliases: aliases,
    commandAliases: commandAliases,
    boolFlags: applicableBoolFlags,
    countFlags: applicableCountFlags,
    singleOptions: applicableSingleOptions,
    repeatedOptions: applicableRepeatedOptions,
    pairedOptionGroups: pairedOptionGroups,
    mandatoryPositionals: mandatoryPositionals,
    discretionaryPositionals: discretionaryPositionals,
    variadic: variadic,
    accessors: accessors,
    parent: parent,
    childRegistries: commandRegistries,
  );

  /// Returns the deepest registered command named by [args].
  ///
  /// Registered flags and the root name do not advance the command path. Help
  /// and the end-of-options separator stop traversal.
  CommandRegistry registryForArguments(List<String> args) {
    var registry = this;
    var helpRequested = false;
    var offset = 0;
    while (offset < args.length) {
      final token = args[offset];
      if (token == '--') break;
      if (token == registry.name && identical(registry, this)) {
        offset++;
        continue;
      }
      final inputLength = registry.registeredInputTokenLength(token);
      if (inputLength != null) {
        helpRequested = helpRequested || _containsHelpFlagToken(token);
        offset += inputLength;
        continue;
      }
      if (helpRequested) {
        offset++;
        continue;
      }

      final children = registry.commandRegistries ?? const <CommandRegistry>[];
      final commandName = registry.aliases?[token] ?? token;
      final command = children
          .where((candidate) => candidate.name == commandName)
          .firstOrNull;
      if (command == null) {
        // A leaf command's remaining bare tokens belong to its positional
        // parser, not to a nonexistent child command. Leave them in place so
        // Parser can validate the command's positionals and report any extra
        // values with the correct command context.
        if (children.isEmpty) break;
        if (helpRequested) break;
        throw MambaCommandNotFoundException(
          token,
          registry.fullPath,
          children.map((child) => child.name).toList(),
        );
      }
      registry = command;
      offset++;
    }
    return registry;
  }

  bool _containsHelpFlagToken(String token) =>
      token == '--help' ||
      (token.startsWith('-') &&
          !token.startsWith('--') &&
          token.substring(1).contains('h'));

  /// Whether [token] is a registered boolean or count flag.
  ///
  /// The check recognizes long names, valid negated boolean names, short
  /// names, and bundles of registered short flags, including built-in help.
  bool isRegisteredFlagToken(String token) {
    final boolFlags = applicableBoolFlags;
    final countFlags = applicableCountFlags;
    if (token.startsWith('--') && token.length > 2) {
      final name = token.substring(2).split('=').first;
      final negativeName = name.startsWith('no-') ? name.substring(3) : null;
      return boolFlags.containsKey(name) ||
          countFlags?.containsKey(name) == true ||
          (negativeName != null && boolFlags.containsKey(negativeName));
    }
    if (!token.startsWith('-') || token.length <= 1) return false;
    return token
        .substring(1)
        .split('')
        .every(
          (name) =>
              boolFlags.values.any((flag) => flag.short == name) ||
              countFlags?.values.any((flag) => flag.short == name) == true,
        );
  }

  /// Number of argument tokens occupied by a registered flag or option token.
  ///
  /// Inline long-option values occupy one token; other value-taking inputs
  /// occupy the option token and the following value token.
  int? registeredInputTokenLength(String token) {
    if (token.startsWith('--') && token.length > 2) {
      final separatorIndex = token.indexOf('=');
      final name = separatorIndex < 0
          ? token.substring(2)
          : token.substring(2, separatorIndex);
      if (_hasValueInput(name)) return separatorIndex < 0 ? 2 : 1;
    }
    if (token.startsWith('-') && token.length > 1) {
      final short = token.substring(1);
      if (_hasValueInput(short, byShortAlias: true)) return 2;
    }
    return isRegisteredFlagToken(token) ? 1 : null;
  }

  /// Options available here, including inherited ones.
  Iterable<NamedInput> _valueOptions() sync* {
    for (final option in [
      ...?applicableSingleOptions?.values,
      ...?applicableRepeatedOptions?.values,
      ...?applicablePairedOptionGroups?.expand((group) => group.options),
    ]) {
      yield option;
    }
  }

  bool _hasValueInput(String name, {bool byShortAlias = false}) {
    bool hasAccessorPath() {
      final segments = name.split('.');
      AccessorOption? accessor = accessors?[segments.first];
      for (final segment in segments.skip(1)) {
        if (accessor is! AccessorListOption) return false;
        accessor = accessor.options
            .where((option) => option.name == segment)
            .firstOrNull;
      }
      return accessor is AccessorPrimitiveOption;
    }

    final ordinaryOptions = <NamedInput>[..._valueOptions()];
    bool hasShort(NamedInput option) => switch (option) {
      Flag(short: final short) ||
      Option(short: final short) ||
      PairOption(short: final short) => short == name,
      _ => false,
    };
    if (byShortAlias) {
      return ordinaryOptions.any(hasShort);
    }
    return ordinaryOptions.any((option) => option.name == name) ||
        hasAccessorPath();
  }

  static void _validateGlobalFlagOverrides(
    List<Flag>? globalFlags,
    List<Flag>? descendantFlags,
  ) {
    if (globalFlags == null || descendantFlags == null) return;
    final globalNames = globalFlags.map((flag) => flag.name).toSet();
    for (final flag in descendantFlags) {
      if (globalNames.contains(flag.name)) {
        throw MambaRegistryError(
          'Global flag --${flag.name} cannot be overridden by a descendant.',
        );
      }
    }
  }

  static List<T>? _mergeByName<T extends NamedInput>(
    List<T>? inherited,
    List<T>? local,
  ) {
    if (inherited == null && local == null) return null;
    final localNames = local?.map((input) => input.name).toSet();
    return [
      ...?inherited?.where(
        (input) => !(localNames?.contains(input.name) ?? false),
      ),
      ...?local,
    ];
  }

  static final RegExp _inputName = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$');
  static final RegExp _shortInputName = RegExp(r'^[A-Za-z]$');

  static List<T>? _copyList<T>(List<T>? inputs) =>
      inputs == null ? null : List.unmodifiable(inputs);

  static Map<String, T>? _indexByName<T extends NamedInput>(
    Iterable<T>? inputs,
  ) => inputs == null ? null : {for (final input in inputs) input.name: input};

  static Map<String, String>? _indexAliases(List<Command>? commands) =>
      commands == null
      ? null
      : {
          for (final command in commands)
            for (final alias in command.aliases ?? const <String>[])
              alias: command.name,
        };

  static void _validateDefinition(
    String name,
    String shortDescription,
    List<String>? aliases,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<String> commandPath, {
    Iterable<NamedInput> inheritedInputs = const <NamedInput>[],
  }) {
    _validateCommandName(name);
    _validateShortDescription(shortDescription);
    _validateAliases(name, aliases, commandPath);
    _validateNamedInputs(options, 'Option');
    _validatePairedOptions(pairedOptions);
    _validateNamedInputs(flags, 'Flag');
    _validateAccessors(accessors);
    _validatePositionals(mandatoryPositionals, discretionaryPositionals);
    _validateNumericRanges([
      ...?options,
      ...?pairedOptions?.expand((group) => group.options),
    ]);
    _validateChoiceDefaults(
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      accessors,
    );
    _validateDuplicates(
      accessors,
      flags,
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
      commands,
      commandPath,
      inheritedInputsByName: {
        for (final input in inheritedInputs) input.name: input,
      },
    );
  }

  static void _validateAliases(
    String commandName,
    List<String>? aliases,
    List<String> commandPath,
  ) {
    if (aliases == null) return;
    final path = commandPath.join(' ');
    if (aliases.isEmpty) {
      throw MambaRegistryError(
        'Aliases for command path $path must not be empty.',
      );
    }
    final registered = <String>{};
    for (final alias in aliases) {
      if (alias.isEmpty || alias.startsWith('-')) {
        throw MambaRegistryError(
          'Alias $alias is not a usable command token for command path $path.',
        );
      }
      _validateCommandName(alias);
      if (!registered.add(alias)) {
        throw MambaRegistryError(
          'Alias $alias is registered more than once for command path $path.',
        );
      }
      if (alias == commandName) {
        throw MambaRegistryError(
          'Alias $alias cannot be the same as command path $path.',
        );
      }
    }
  }

  static void _validateCommandName(String name) {
    if (_inputName.hasMatch(name)) return;
    throw MambaRegistryError(
      'Command names must contain letter-led words separated by hyphens or underscores.',
    );
  }

  static void _validateShortDescription(String shortDescription) {
    if (shortDescription.isEmpty) {
      throw MambaRegistryError("Short description can't be empty");
    }
    if (shortDescription.length > 150) {
      throw MambaRegistryError(
        "Short description can't exceed 150 characters.",
      );
    }
  }

  static void _validateNamedInputs(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) return;
    for (final input in inputs) {
      if (input.name == 'help' ||
          (input is Flag && input.short == 'h') ||
          (input is Option && input.short == 'h') ||
          (input is PairOption && input.short == 'h')) {
        throw MambaRegistryError(
          'The help flag and -h alias are reserved by the executor',
        );
      }
      if (!_inputName.hasMatch(input.name)) {
        throw MambaRegistryError(
          '$inputKind names must contain letter-led words separated by hyphens or underscores.',
        );
      }
      final short = switch (input) {
        Flag(short: final short) || Option(short: final short) => short,
        PairOption(short: final short) => short,
        _ => null,
      };
      if (short != null && !_shortInputName.hasMatch(short)) {
        throw MambaRegistryError(
          '$inputKind short aliases must be a single letter',
        );
      }
    }
  }

  static void _validatePairedOptions(List<PairedOptions>? pairedOptions) {
    final groups = pairedOptions ?? const <PairedOptions>[];
    for (final group in groups) {
      if (group.options.isEmpty) {
        throw MambaRegistryError(
          'Paired options must contain at least one pair option',
        );
      }
    }
    _validateNamedInputs(
      groups.expand((group) => group.options),
      'Pair option',
    );
    _validateDuplicateNames(
      groups.expand((group) => group.options),
      'pair option',
    );
  }

  static void _validateAccessors(List<AccessorListOption>? accessors) {
    if (accessors != null) _validateAccessorLevel(accessors, 'accessor');
  }

  static void _validateAccessorLevel(
    List<AccessorOption> accessors,
    String inputKind,
  ) {
    _validateDuplicateNames(accessors, inputKind);
    for (final accessor in accessors) {
      if (accessor.name == 'help') {
        throw MambaRegistryError('The help flag is reserved by the executor');
      }
      _validatePositionalName(accessor.name);
      if (accessor case AccessorListOption(options: final options)) {
        _validateAccessorLevel(options, 'accessor option');
      }
    }
  }

  static void _validatePositionals(
    List<Positional>? mandatory,
    List<Positional>? discretionary,
  ) {
    for (final positional in [...?mandatory, ...?discretionary]) {
      _validatePositionalName(positional.name);
    }
  }

  static void _validatePositionalName(String name) {
    if (!_inputName.hasMatch(name)) {
      throw MambaRegistryError(
        'Positional names must contain letter-led words separated by hyphens or underscores.',
      );
    }
  }

  static void _validateNumericRanges(Iterable<NamedInput> inputs) {
    for (final input in inputs) {
      if (input is! NumericRangeValidated) continue;
      final range = input as NumericRangeValidated;
      final min = range.min;
      final max = range.max;
      if (min != null && max != null && min > max) {
        throw MambaRegistryError(
          'Minimum $min for ${input.name} must not exceed maximum $max.',
        );
      }
      if (input case NumericStepValidated(:final step?)) {
        if (!step.isFinite || step <= 0) {
          throw MambaRegistryError(
            'Step $step for ${input.name} must be greater than zero.',
          );
        }
        if (min == null || max == null) {
          throw MambaRegistryError(
            'Step for ${input.name} requires both a minimum and maximum.',
          );
        }
        if (!min.isFinite || !max.isFinite) {
          throw MambaRegistryError(
            'Step for ${input.name} requires finite minimum and maximum values.',
          );
        }
        final increments = (max - min) / step;
        if ((increments - increments.round()).abs() > 1e-12) {
          throw MambaRegistryError(
            'Step $step for ${input.name} must evenly divide the range from $min to $max.',
          );
        }
      }
    }
  }

  static void _validateChoiceDefaults(
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<AccessorListOption>? accessors,
  ) {
    void validate(Iterable<Enum> choices, Enum? defaultValue, String name) {
      if (choices.isEmpty) {
        throw MambaRegistryError('Choices for $name must not be empty.');
      }
      if (defaultValue != null && !choices.contains(defaultValue)) {
        throw MambaRegistryError(
          'Default ${defaultValue.name} is not a registered choice for $name',
        );
      }
    }

    void validateInput(NamedInput input) {
      switch (input) {
        case ChoiceOption(:final choices, :final defaultValue) ||
            ChoicePositional(:final choices, :final defaultValue) ||
            RepeatedChoicePositional(:final choices, :final defaultValue) ||
            AccessorChoiceOption(:final choices, :final defaultValue):
          validate(choices, defaultValue, input.name);
        case PairChoiceOption(:final choices):
          validate(choices, null, input.name);
        default:
      }
    }

    void validateAccessor(AccessorOption accessor) {
      validateInput(accessor);
      if (accessor case AccessorListOption(:final options)) {
        options.forEach(validateAccessor);
      }
    }

    for (final option in options ?? const <Option>[]) {
      if (option is ChoiceOption &&
          option.required &&
          option.defaultValue != null) {
        throw MambaRegistryError(
          'Required choice option ${option.name} must not declare a default.',
        );
      }
      validateInput(option);
    }
    for (final positional in mandatoryPositionals ?? const <Positional>[]) {
      if ((positional is ChoicePositional && positional.defaultValue != null) ||
          (positional is RepeatedChoicePositional &&
              positional.defaultValue != null)) {
        throw MambaRegistryError(
          'Required choice positional ${positional.name} must not declare a default.',
        );
      }
      validateInput(positional);
    }
    void validateVariadic(Variadic input) {
      if (input case ChoiceVariadic(:final choices, :final defaultValue)) {
        validate(choices, defaultValue, 'variadic');
      }
    }

    [
      ...?pairedOptions?.expand((option) => option.options),
      ...?discretionaryPositionals,
    ].forEach(validateInput);
    if (variadic != null) validateVariadic(variadic);
    accessors?.forEach(validateAccessor);
  }

  static void _validateDuplicates(
    List<AccessorListOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    List<Command>? commands,
    List<String> commandPath, {
    Map<String, NamedInput> inheritedInputsByName =
        const <String, NamedInput>{},
  }) {
    final registeredOptions = <NamedInput>[
      ...?options,
      ...?pairedOptions?.expand((pairedOption) => pairedOption.options),
    ];
    _validateDuplicateNames(registeredOptions, 'option');
    _validateDuplicateNames(flags, 'flag');
    _validateDuplicateNames([...?flags, ...registeredOptions], 'input');
    _validateDuplicateShortAliases([
      ...?flags,
      ...registeredOptions,
    ], inheritedInputsByName: inheritedInputsByName);
    _validateNegatableSpellings(flags, registeredOptions, accessors);
    _validateDuplicateCommandNames(commands);
    _validateDuplicateAliases(commands, commandPath);

    for (final accessor in accessors ?? const <AccessorOption>[]) {
      final flagIndex =
          flags?.indexWhere((flag) => flag.name == accessor.name) ?? -1;
      if (flagIndex >= 0) {
        throw MambaRegistryError(
          'This accessor ${accessor.name} has the same name as a flag at index $flagIndex',
        );
      }
      final optionIndex = registeredOptions.indexWhere(
        (option) => option.name == accessor.name,
      );
      if (optionIndex >= 0) {
        throw MambaRegistryError(
          'This accessor ${accessor.name} has the same name as an option at index $optionIndex',
        );
      }
    }

    final positionals = [...?mandatory, ...?discretionary];
    final names = <String>{};
    for (final positional in positionals) {
      if (!names.add(positional.name)) {
        throw MambaRegistryError(
          "A positional can't have the same name as another positional",
        );
      }
    }
    final commandNames = commands?.map((command) => command.name).toList();
    for (final positional in positionals) {
      final commandIndex = commandNames?.indexOf(positional.name) ?? -1;
      if (commandIndex >= 0) {
        throw MambaRegistryError(
          'This positional message has the same name as a command at index $commandIndex',
        );
      }
    }
  }

  static void _validateDuplicateShortAliases(
    Iterable<NamedInput> inputs, {
    Map<String, NamedInput> inheritedInputsByName =
        const <String, NamedInput>{},
  }) {
    final names = <String, String>{};
    for (final input in inputs) {
      final short = switch (input) {
        Flag(short: final short) ||
        Option(short: final short) ||
        PairOption(short: final short) => short,
        _ => null,
      };
      if (short == null) continue;
      final previousName = names[short];
      if (previousName != null) {
        // A local option may intentionally shadow an inherited global short
        // alias. This lets a command keep its established shorthand while
        // still allowing the global input before the command path.
        if (inheritedInputsByName[previousName] is Flag && input is Option) {
          names[short] = input.name;
          continue;
        }
        throw MambaRegistryError(
          'The short alias -$short is assigned to both $previousName and ${input.name}',
        );
      }
      names[short] = input.name;
    }
  }

  static void _validateNegatableSpellings(
    List<Flag>? flags,
    List<NamedInput> registeredOptions,
    List<AccessorListOption>? accessors,
  ) {
    // A negatable boolean flag also accepts --no-<name>; that synthesized
    // spelling belongs to the command token namespace and must not collide
    // with another registered input.
    final declaredNames = {
      for (final input in [...?flags, ...registeredOptions]) input.name,
      for (final accessor in accessors ?? const <AccessorListOption>[])
        accessor.name,
    };
    for (final flag in [...?flags]) {
      if (flag is! BooleanFlag || !flag.negatable) continue;
      final negatedName = 'no-${flag.name}';
      if (declaredNames.contains(negatedName)) {
        throw MambaRegistryError(
          'Flag spelling --$negatedName collides with a registered input.',
        );
      }
    }
  }

  static void _validateDuplicateCommandNames(List<Command>? commands) {
    final names = <String>{};
    for (final command in commands ?? const <Command>[]) {
      if (!names.add(command.name)) {
        throw MambaRegistryError(
          'There are duplicate command names: ${command.name}',
        );
      }
    }
  }

  static void _validateDuplicateAliases(
    List<Command>? commands,
    List<String> parentPath,
  ) {
    final registered = <String, String>{};
    final commandNames = {
      for (final command in commands ?? const <Command>[]) command.name,
    };
    for (final command in commands ?? const <Command>[]) {
      final commandPath = [...parentPath, command.name];
      _validateAliases(command.name, command.aliases, commandPath);
      for (final alias in command.aliases ?? const <String>[]) {
        if (commandNames.contains(alias)) {
          throw MambaRegistryError(
            'Alias $alias is the same as a command in command path ${commandPath.join(' ')}.',
          );
        }
        final registeredCommand = registered[alias];
        if (registeredCommand != null) {
          throw MambaRegistryError(
            'Alias $alias is already registered for a command; pick another one. Command path: ${commandPath.join(' ')}.',
          );
        }
        registered[alias] = command.name;
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
        throw MambaRegistryError(
          'There are duplicate $inputKind names at index $duplicateIndex and $index',
        );
      }
      names[input.name] = index;
    }
  }
}
