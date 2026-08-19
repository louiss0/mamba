import 'package:arg_parser/command.dart';

import 'errors.dart';

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
  final Map<String, AccessorOption>? accessors;
  final List<CommandRegistry>? commandRegistries;

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
  static final RegExp _namedInputName = RegExp(r'^[A-Za-z][A-Za-z0-9]*$');
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
          '$inputKind names must be alphanumeric and start with a letter',
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
