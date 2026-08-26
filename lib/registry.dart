import 'package:mamba/command.dart';

import 'errors.dart';

/// Reports a command name that is not a child of the selected command path.
final class MambaCommandNotFoundException extends MambaException {
  MambaCommandNotFoundException(
    String name,
    List<String> parentPath,
    List<String> availableCommands,
  ) : super(
        "Command $name was not found under ${parentPath.join(' ')}."
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

  CommandRegistry._({
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
    this.pairedOptions,
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
  final Map<String, PairedOption>? pairedOptions;
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
  /// The factory indexes inputs by name, reserves the built-in help flag, and
  /// creates child registries for [commands]. It rejects ambiguous names,
  /// aliases, positional definitions, and invalid input definitions.
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

    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      helpFlag: _helpFlag,
      longDescription: longDescription,
      aliases: _indexAliases(commands),
      boolFlags: _indexByName<BooleanFlag>(flags?.whereType<BooleanFlag>()),
      countFlags: _indexByName<CountFlag>(flags?.whereType<CountFlag>()),
      singleOptions: _indexByName<SingleOption>(
        options?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        options?.whereType<RepeatableOption>(),
      ),
      pairedOptions: _indexByName<PairedOption>(pairedOptions),
      mandatoryPositionals: _indexByName<Positional>(mandatoryPositionals),
      discretionaryPositionals: _indexByName<Positional>(
        discretionaryPositionals,
      ),
      variadic: variadic,
      accessors: _indexByName<AccessorListOption>(accessors),
      parent: null,
      publishedFlags: flags,
      publishedOptions: options == null && pairedOptions == null
          ? null
          : [...?options, ...?pairedOptions],
      commands: commands,
      parentPath: [name],
      descendantFlags: flags,
      descendantOptions: options == null && pairedOptions == null
          ? null
          : [...?options, ...?pairedOptions],
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
    final publishedFlags = _mergeByName(inheritedFlags, ownPublishedFlags);
    final publishedOptions = _mergeByName(
      inheritedOptions,
      ownPublishedOptions,
    );
    final localOptions =
        command.options == null && command.pairedOptions == null
        ? null
        : [...?command.options, ...?command.pairedOptions];
    // Inherited inputs join the validation surface so conflicts with local
    // declarations are still reported at the level that would collide.
    final registeredFlags = _mergeByName(publishedFlags, command.flags);
    final registeredOptions = _mergeByName(publishedOptions, localOptions);
    final ordinaryOptions = registeredOptions
        ?.where((option) => option is! PairedOption)
        .toList();
    final pairedOptions = registeredOptions?.whereType<PairedOption>().toList();

    final commandPath = [...parentPath, command.name];
    _validateDefinition(
      command.name,
      command.shortDescription,
      command.aliases,
      command.mandatoryPositionals,
      command.discretionaryPositionals,
      command.variadic,
      registeredFlags,
      ordinaryOptions,
      pairedOptions,
      command.accessors,
      childCommands,
      commandPath,
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
      pairedOptions: _indexByName<PairedOption>(
        localOptions?.whereType<PairedOption>().toList(),
      ),
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

  /// Exports this registry as a serializable command description.
  ///
  /// Includes every registry name so exported command trees are self-contained.
  Map<String, dynamic> toMap() {
    final description = longDescription == null
        ? shortDescription
        : '$shortDescription\n\n$longDescription';
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      if (commandAliases != null) 'aliases': commandAliases,
    };

    final registeredBooleanFlags = boolFlags;
    final registeredCountFlags = countFlags;
    if (registeredBooleanFlags != null || registeredCountFlags != null) {
      map['flags'] = {
        for (final flag
            in registeredBooleanFlags?.values ?? const <BooleanFlag>[])
          flag.name: _mapBooleanFlag(flag),
        for (final flag in registeredCountFlags?.values ?? const <CountFlag>[])
          flag.name: _mapCountFlag(flag),
      };
    }

    final registeredSingleOptions = singleOptions;
    final registeredRepeatedOptions = repeatedOptions;
    final registeredPairedOptions = pairedOptions;
    if (registeredSingleOptions != null ||
        registeredRepeatedOptions != null ||
        registeredPairedOptions != null) {
      map['options'] = {
        for (final option
            in registeredSingleOptions?.values ?? const <SingleOption>[])
          option.name: _mapOption(option),
        for (final option
            in registeredRepeatedOptions?.values ?? const <RepeatableOption>[])
          option.name: _mapOption(option),
        for (final pairedOption
            in registeredPairedOptions?.values ?? const <PairedOption>[])
          pairedOption.name: _mapOption(pairedOption),
        for (final pairOption
            in registeredPairedOptions?.values.expand(
                  (option) => option.options,
                ) ??
                const <PairOption>[])
          pairOption.name: _mapOption(pairOption),
      };
    }

    final registeredMandatoryPositionals = mandatoryPositionals;
    final registeredDiscretionaryPositionals = discretionaryPositionals;
    if (registeredMandatoryPositionals != null ||
        registeredDiscretionaryPositionals != null) {
      map['positionals'] = {
        for (final positional
            in registeredMandatoryPositionals?.values ?? const <Positional>[])
          positional.name: _mapPositional(positional.name, positional, true),
        for (final positional
            in registeredDiscretionaryPositionals?.values ??
                const <Positional>[])
          positional.name: _mapPositional(positional.name, positional, false),
      };
    }

    final registeredVariadic = variadic;
    if (registeredVariadic != null) {
      map['variadic'] = _mapVariadic(registeredVariadic);
    }

    final registeredAccessors = accessors;
    if (registeredAccessors != null) {
      map['accessors'] = {
        for (final entry in registeredAccessors.entries)
          entry.key: _mapAccessorList(entry.value),
      };
    }

    final registeredCommands = commandRegistries;
    if (registeredCommands != null) {
      map['commands'] = {
        for (final command in registeredCommands) command.name: command.toMap(),
      };
    }
    return map;
  }

  static Map<String, dynamic> _mapBooleanFlag(BooleanFlag flag) => {
    'short': flag.short,
    'default': flag.defaultValue,
    'negatable': flag.negatable,
    'hidden': flag.hidden,
    'description': flag.description,
  };

  static Map<String, dynamic> _mapCountFlag(CountFlag flag) => {
    if (flag.short != null) 'short': flag.short,
    'hidden': flag.hidden,
    'description': flag.description,
  };

  static Map<String, dynamic> _mapOption(NamedInput input) {
    final (
      name,
      short,
      required,
      hidden,
      description,
      repeatable,
      variant,
      choiceData,
    ) = switch (input) {
      Option(
        name: final name,
        short: final short,
        required: final required,
        hidden: final hidden,
        description: final description,
      ) =>
        (
          name,
          short,
          required,
          hidden,
          description,
          input is RepeatableOption || input is RepeatablePairedOption,
          input is PairedOption && input.variant,
          switch (input) {
            ChoiceOption(choices: final choices, defaultValue: final value) ||
            PairedChoiceOption(
              choices: final choices,
              defaultValue: final value,
            ) => {
              'choices': choices.map((choice) => choice.name).toList(),
              if (value != null) 'default': value.name,
            },
            _ => const <String, dynamic>{},
          },
        ),
      PairOption(
        name: final name,
        short: final short,
        description: final description,
      ) =>
        (
          name,
          short,
          false,
          false,
          description,
          input is RepeatablePairOption,
          false,
          switch (input) {
            PairChoiceOption(
              choices: final choices,
              defaultValue: final value,
            ) =>
              {
                'choices': choices.map((choice) => choice.name).toList(),
                if (value != null) 'default': value.name,
              },
            _ => const <String, dynamic>{},
          },
        ),
      _ => throw ArgumentError('Expected an option input'),
    };
    return {
      'short': short,
      'required': required,
      'hidden': hidden,
      'description': description,
      if (repeatable) 'repeatable': true,
      if (variant) 'variant': true,
      ...choiceData,
    };
  }

  static Map<String, dynamic> _mapPositional(
    String name,
    Positional positional,
    bool required,
  ) => {'required': required, 'description': positional.description};

  static Map<String, dynamic> _mapVariadic(
    Variadic variadic,
  ) => switch (variadic) {
    ChoiceVariadic(:final description, :final choices, :final defaultValue) => {
      'description': description,
      'choices': choices.map((choice) => choice.name).toList(),
      'default': ?defaultValue?.name,
    },
    NormalVariadic(:final description) => {'description': description},
  };

  static Object _mapAccessorList(
    AccessorListOption accessor, {
    bool root = true,
  }) {
    final nestedLists = accessor.options.whereType<AccessorListOption>();
    if (root && nestedLists.isEmpty) {
      return {
        if (accessor.hidden) 'hidden': true,
        'description': accessor.description,
        'options': {
          for (final option in accessor.options)
            option.name: {'description': option.description},
        },
      };
    }
    return {
      if (accessor.hidden) 'hidden': true,
      for (final option in accessor.options)
        option.name: switch (option) {
          AccessorListOption() => _mapAccessorList(option, root: false),
          AccessorPrimitiveOption() => option.description,
        },
    };
  }

  /// Whether [args] request built-in help before an end-of-options separator.
  bool requestsHelp(List<String> args) {
    for (final argument in args) {
      if (argument == '--') return false;
      if (argument == '--help' || argument == '-h') return true;
    }
    return false;
  }

  /// Flags and options published by this level and every ancestor, ordered
  /// from the root down.
  List<Flag> get _inheritableFlags => [
    for (CommandRegistry? level = this; level != null; level = level.parent)
      ...?level.publishedFlags,
  ];

  List<Option> get _inheritableOptions => [
    for (CommandRegistry? level = this; level != null; level = level.parent)
      ...?level.publishedOptions,
  ];

  static Map<String, T>? _combineWithInherited<T extends NamedInput>(
    Iterable<T> inherited,
    Map<String, T>? local,
  ) {
    if (local == null && inherited.isEmpty) return null;
    return {for (final input in inherited) input.name: input, ...?local};
  }

  /// Boolean flags available here: inherited inputs plus local declarations,
  /// with a local same-name definition taking precedence.
  Map<String, BooleanFlag>? get applicableBoolFlags => _combineWithInherited(
    _inheritableFlags.whereType<BooleanFlag>(),
    boolFlags,
  );

  /// Count flags available here, including inherited ones.
  Map<String, CountFlag>? get applicableCountFlags => _combineWithInherited(
    _inheritableFlags.whereType<CountFlag>(),
    countFlags,
  );

  /// Single options available here, including inherited ones.
  Map<String, SingleOption>? get applicableSingleOptions =>
      _combineWithInherited(
        _inheritableOptions.whereType<SingleOption>(),
        singleOptions,
      );

  /// Repeatable options available here, including inherited ones.
  Map<String, RepeatableOption>? get applicableRepeatedOptions =>
      _combineWithInherited(
        _inheritableOptions.whereType<RepeatableOption>(),
        repeatedOptions,
      );

  /// Paired options available here, including inherited ones.
  Map<String, PairedOption>? get applicablePairedOptions =>
      _combineWithInherited(
        _inheritableOptions.whereType<PairedOption>(),
        pairedOptions,
      );

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
    pairedOptions: applicablePairedOptions,
    mandatoryPositionals: mandatoryPositionals,
    discretionaryPositionals: discretionaryPositionals,
    variadic: variadic,
    accessors: accessors,
    childRegistries: commandRegistries,
  );

  /// Returns the deepest registered command named by [args].
  ///
  /// Registered flags and the root name do not advance the command path. Help
  /// and the end-of-options separator stop traversal.
  CommandRegistry registryForArguments(List<String> args) {
    var registry = this;
    var offset = 0;
    while (offset < args.length) {
      final token = args[offset];
      if (token == '--' || requestsHelp([token])) break;
      if (token == registry.name && identical(registry, this)) {
        offset++;
        continue;
      }
      final inputLength = registry.registeredInputTokenLength(token);
      if (inputLength != null) {
        offset += inputLength;
        continue;
      }

      final children = registry.commandRegistries ?? const <CommandRegistry>[];
      final commandName = registry.aliases?[token] ?? token;
      final command = children
          .where((candidate) => candidate.name == commandName)
          .firstOrNull;
      if (command == null) {
        throw MambaCommandNotFoundException(token, [
          registry.name,
        ], children.map((child) => child.name).toList());
      }
      registry = command;
      offset++;
    }
    return registry;
  }

  /// Whether [token] is a registered boolean, count, or built-in help flag.
  ///
  /// The check recognizes long names, valid negated boolean names, short names,
  /// and bundles of short flags.
  bool isRegisteredFlagToken(String token) {
    final boolFlags = applicableBoolFlags;
    final countFlags = applicableCountFlags;
    if (token.startsWith('--') && token.length > 2) {
      final name = token.substring(2).split('=').first;
      final negativeName = name.startsWith('no-') ? name.substring(3) : null;
      return name == helpFlag.name ||
          boolFlags?.containsKey(name) == true ||
          countFlags?.containsKey(name) == true ||
          (negativeName != null &&
              boolFlags?.containsKey(negativeName) == true);
    }
    if (!token.startsWith('-') || token.length <= 1) return false;
    return token
        .substring(1)
        .split('')
        .every(
          (name) =>
              helpFlag.short == name ||
              boolFlags?.values.any((flag) => flag.short == name) == true ||
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
  Iterable<Option> _valueOptions() sync* {
    for (final option in [
      ...?applicableSingleOptions?.values,
      ...?applicableRepeatedOptions?.values,
      ...?applicablePairedOptions?.values,
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

    final ordinaryOptions = <Option>[..._valueOptions()];
    final pairOptions = applicablePairedOptions?.values.expand(
      (option) => option.options,
    );
    if (byShortAlias) {
      return ordinaryOptions.any((option) => option.short == name) ||
          pairOptions?.any((option) => option.short == name) == true;
    }
    return ordinaryOptions.any((option) => option.name == name) ||
        pairOptions?.any((option) => option.name == name) == true ||
        hasAccessorPath();
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

  static final RegExp _keyboardSymbol = RegExp(r'[^A-Za-z0-9_-]');
  static final RegExp _namedInputName = RegExp(r'^[A-Za-z][A-Za-z0-9-]*$');
  static final RegExp _shortInputName = RegExp(r'^[A-Za-z]$');
  static final RegExp _number = RegExp(r'\d');

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
    List<PairedOption>? pairedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<String> commandPath,
  ) {
    _validateCommandName(name);
    _validateShortDescription(shortDescription);
    _validateAliases(name, aliases, commandPath);
    _validateNamedInputs(options, 'Option');
    _validatePairedOptions(pairedOptions);
    _validateNamedInputs(flags, 'Flag');
    _validateAccessors(accessors);
    _validatePositionals(mandatoryPositionals, discretionaryPositionals);
    _validateVariadic(variadic);
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
    );
  }

  static void _validateVariadic(Variadic? variadic) {
    if (variadic == null) return;
    _validatePositionalName(variadic.name);
  }

  static void _validateAliases(
    String commandName,
    List<String>? aliases,
    List<String> commandPath,
  ) {
    if (aliases == null) return;
    final path = commandPath.join(' ');
    if (aliases.isEmpty) {
      throw MambaException('Aliases for command path $path must not be empty.');
    }
    final registered = <String>{};
    for (final alias in aliases) {
      if (alias.isEmpty || alias.startsWith('-')) {
        throw MambaException(
          'Alias $alias is not a usable command token for command path $path.',
        );
      }
      _validateCommandName(alias);
      if (!registered.add(alias)) {
        throw MambaException(
          'Alias $alias is registered more than once for command path $path.',
        );
      }
      if (alias == commandName) {
        throw MambaException(
          'Alias $alias cannot be the same as command path $path.',
        );
      }
    }
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
      if (input.name == 'help' ||
          (input is Flag && input.short == 'h') ||
          (input is Option && input.short == 'h')) {
        throw MambaRegistryError(
          'The help flag and -h alias are reserved by the executor',
        );
      }
      if (!_namedInputName.hasMatch(input.name)) {
        throw MambaRegistryError(
          '$inputKind names must use letters, numbers, or hyphens and start with a letter',
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
    if (!_namedInputName.hasMatch(name)) {
      throw MambaRegistryError(
        'Positional names must use letters, numbers, or hyphens and start with a letter',
      );
    }
  }

  static void _validateChoiceDefaults(
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<AccessorListOption>? accessors,
  ) {
    void validate(Iterable<Enum> choices, Enum? defaultValue, String name) {
      if (defaultValue != null && !choices.contains(defaultValue)) {
        throw MambaRegistryError(
          'Default ${defaultValue.name} is not a registered choice for $name',
        );
      }
    }

    void validateInput(NamedInput input) {
      switch (input) {
        case ChoiceOption(:final choices, :final defaultValue) ||
            PairedChoiceOption(:final choices, :final defaultValue) ||
            PairChoiceOption(:final choices, :final defaultValue) ||
            ChoicePositional(:final choices, :final defaultValue) ||
            RepeatedChoicePositional(:final choices, :final defaultValue) ||
            ChoiceVariadic(:final choices, :final defaultValue) ||
            AccessorChoiceOption(:final choices, :final defaultValue):
          validate(choices, defaultValue, input.name);
        default:
      }
    }

    void validateAccessor(AccessorOption accessor) {
      validateInput(accessor);
      if (accessor case AccessorListOption(:final options)) {
        options.forEach(validateAccessor);
      }
    }

    [
      ...?options,
      ...?pairedOptions,
      ...?pairedOptions?.expand((option) => option.options),
      ...?mandatoryPositionals,
      ...?discretionaryPositionals,
    ].forEach(validateInput);
    if (variadic != null) validateInput(variadic);
    accessors?.forEach(validateAccessor);
  }

  static void _validateDuplicates(
    List<AccessorListOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    List<Command>? commands,
    List<String> commandPath,
  ) {
    final registeredOptions = [
      ...?options,
      ...?pairedOptions,
      ...?pairedOptions?.expand((pairedOption) => pairedOption.options),
    ];
    _validateDuplicateNames(registeredOptions, 'option');
    _validateDuplicateNames(flags, 'flag');
    _validateDuplicateNames([...?flags, ...registeredOptions], 'input');
    _validateDuplicateShortAliases([...?flags, ...registeredOptions]);
    _validateDuplicateCommandNames(commands);
    _validateDuplicateAliases(commands, commandPath);

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

  static void _validateDuplicateShortAliases(Iterable<NamedInput> inputs) {
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
        throw MambaException(
          'The short alias -$short is assigned to both $previousName and ${input.name}',
        );
      }
      names[short] = input.name;
    }
  }

  static void _validateDuplicateCommandNames(List<Command>? commands) {
    final names = <String>{};
    for (final command in commands ?? const <Command>[]) {
      if (!names.add(command.name)) {
        throw MambaException(
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
          throw MambaException(
            'Alias $alias is the same as a command in command path ${commandPath.join(' ')}.',
          );
        }
        final registeredCommand = registered[alias];
        if (registeredCommand != null) {
          throw MambaException(
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
        throw MambaException(
          'There are duplicate $inputKind names at index $duplicateIndex and $index',
        );
      }
      names[input.name] = index;
    }
  }
}
