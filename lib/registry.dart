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
/// a definition by name while preserving its input semantics. Group registries
/// recursively organize children and carry explicitly inherited flags and
/// options to descendants; local same-name definitions take precedence.
final class CommandRegistry {
  static final BooleanFlag _helpFlag = BooleanFlag(
    name: 'help',
    short: 'h',
    description: 'Show this help message.',
  );

  CommandRegistry._({
    required this.name,
    required this.shortDescription,
    required this.helpFlag,
    this.longDescription,
    this.boolFlags,
    this.countFlags,
    this.singleOptions,
    this.repeatedOptions,
    this.pairedOptions,
    this.pairOptions,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.accessors,
    this.commandRegistries,
  });

  final String name;
  final String shortDescription;
  final BooleanFlag helpFlag;
  final String? longDescription;
  final Map<String, CountFlag>? countFlags;
  final Map<String, BooleanFlag>? boolFlags;
  final Map<String, SingleOption>? singleOptions;
  final Map<String, RepeatableOption>? repeatedOptions;
  final Map<String, PairedOption>? pairedOptions;
  final Map<String, PairOption>? pairOptions;
  final Map<String, Positional>? mandatoryPositionals;
  final Map<String, Positional>? discretionaryPositionals;
  final Map<String, AccessorOption>? accessors;
  final List<CommandRegistry>? commandRegistries;

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
      flags,
      options,
      pairedOptions,
      accessors,
      commands,
    );

    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      helpFlag: _helpFlag,
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
      accessors: _indexByName<AccessorOption>(accessors),
      commandRegistries: commands?.map(_fromCommand).toList(),
    );
  }

  static CommandRegistry _fromCommand(
    Command command, {
    List<Flag>? inheritedFlags,
    List<Option>? inheritedOptions,
  }) {
    final group = command is GroupCommand ? command : null;
    final childCommands = group?.commands;
    final publishedFlags = _mergeByName(inheritedFlags, group?.inheritedFlags);
    final publishedOptions = _mergeByName(
      inheritedOptions,
      group?.inheritedOptions,
    );
    final registeredFlags = _mergeByName(publishedFlags, command.flags);
    final localOptions =
        command.options == null && command.pairedOptions == null
        ? null
        : [...?command.options, ...?command.pairedOptions];
    final registeredOptions = _mergeByName(publishedOptions, localOptions);
    final ordinaryOptions = registeredOptions
        ?.where((option) => option is! PairedOption)
        .toList();
    final pairedOptions = registeredOptions?.whereType<PairedOption>().toList();

    _validateDefinition(
      command.name,
      command.shortDescription,
      command.mandatoryPositionals,
      command.discretionaryPositionals,
      registeredFlags,
      ordinaryOptions,
      pairedOptions,
      command.accessors,
      childCommands,
    );

    return CommandRegistry._(
      name: command.name,
      shortDescription: command.shortDescription,
      helpFlag: _helpFlag,
      longDescription: command.longDescription,
      boolFlags: _indexByName<BooleanFlag>(
        registeredFlags?.whereType<BooleanFlag>(),
      ),
      countFlags: _indexByName<CountFlag>(
        registeredFlags?.whereType<CountFlag>(),
      ),
      singleOptions: _indexByName<SingleOption>(
        ordinaryOptions?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        ordinaryOptions?.whereType<RepeatableOption>(),
      ),
      pairedOptions: _indexByName<PairedOption>(pairedOptions),
      pairOptions: _indexByName<PairOption>(
        pairedOptions?.expand((pairedOption) => pairedOption.options),
      ),
      mandatoryPositionals: _indexByName<Positional>(
        command.mandatoryPositionals,
      ),
      discretionaryPositionals: _indexByName<Positional>(
        command.discretionaryPositionals,
      ),
      accessors: _indexByName<AccessorOption>(command.accessors),
      commandRegistries: childCommands
          ?.map(
            (child) => _fromCommand(
              child,
              inheritedFlags: publishedFlags,
              inheritedOptions: publishedOptions,
            ),
          )
          .toList(),
    );
  }

  /// Whether [args] request built-in help before an end-of-options separator.
  bool requestsHelp(List<String> args) {
    for (final argument in args) {
      if (argument == '--') return false;
      if (argument == '--help' || argument == '-h') return true;
    }
    return false;
  }

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
      if (registry.isRegisteredFlagToken(token)) {
        offset++;
        continue;
      }

      final children = registry.commandRegistries ?? const <CommandRegistry>[];
      final command = children
          .where((candidate) => candidate.name == token)
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

  static void _validateDefinition(
    String name,
    String shortDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
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
    _validatePositionals(mandatoryPositionals, discretionaryPositionals);
    _validateDuplicates(
      accessors,
      flags,
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
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

  static void _validateAccessors(List<AccessorOption>? accessors) {
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
    List<Command>? commands,
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
