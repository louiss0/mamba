import 'package:mamba/built_in_flags.dart';
import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/src/input_validation.dart' as validation;
import 'package:mamba/src/token_ownership.dart';
import 'package:mamba/src/choice_spelling.dart';

typedef _ConflictEdge = ({
  String sourceName,
  InputDefinition source,
  String targetName,
  InputDefinition target,
});

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
  Map<String, List<String>> conflicts,
  List<String>? defaultCommandPath,
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

extension RegistryPositionalCardinality on RegistryPositional {
  int get slots => repeatable == true ? times! : 1;
}

typedef RegistryVariadic = ({
  String? description,
  List<String>? choices,
  String? pattern,
});

/// One group of related options: a paired set or a selected set.
///
/// [required] requires all paired members or at least one selected member.
/// [single] limits a selected group to at most one member and is false for a
/// paired group. In registry-produced records, a member's `pairedOptions` is
/// empty for a selected group and lists the partners for a paired group.
typedef RegistryOptionGroup = ({
  bool required,
  bool single,
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
    this.conflicts = const {},
    this.defaultCommandPath,
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
  final Map<String, List<String>> conflicts;
  final List<String>? defaultCommandPath;
}

enum RegistryValueKind {
  string('string'),
  integer('int'),
  decimal('double'),
  choice('choice');

  const new(this.wireName);
  final String wireName;
}

/// One interpretation of an input's value across parsing and registry output.
RegistryValueKind valueKindOf(InputDefinition input) {
  if (input is ChoiceValidated) return RegistryValueKind.choice;
  if (input is AccessorIntOption || input is NumericRangeValidated<int>) {
    return RegistryValueKind.integer;
  }
  if (input is AccessorDoubleOption || input is NumericRangeValidated<double>) {
    return RegistryValueKind.decimal;
  }
  return RegistryValueKind.string;
}

sealed class RegistryAccessor {
  const new(this.name, this.description);
  factory group({
    required String name,
    required bool hidden,
    String? description,
    required List<RegistryAccessor> options,
  }) => RegistryAccessorGroup(
    name: name,
    hidden: hidden,
    description: description,
    options: options,
  );
  factory value({
    required String name,
    required String valueType,
    bool required = false,
    String? description,
    List<String>? choices,
    String? defaultValue,
    String? pattern,
  }) => RegistryAccessorValue(
    name: name,
    required: required,
    valueKind: switch (valueType) {
      'string' => RegistryValueKind.string,
      'int' => RegistryValueKind.integer,
      'double' => RegistryValueKind.decimal,
      'choice' => RegistryValueKind.choice,
      _ => throw ArgumentError.value(valueType, 'valueType'),
    },
    description: description,
    choices: choices,
    defaultValue: defaultValue,
    pattern: pattern,
  );
  final String name;
  final String? description;
  String get kind;
  bool get required => false;
  bool? get hidden => null;
  String? get valueType => null;
  List<String>? get choices => null;
  String? get defaultValue => null;
  String? get pattern => null;
  List<RegistryAccessor>? get options => null;
}

final class RegistryAccessorGroup extends RegistryAccessor {
  new({
    required String name,
    required this.hidden,
    String? description,
    required List<RegistryAccessor> options,
  }) : options = List.unmodifiable(options),
       super(name, description);
  @override
  String get kind => 'group';
  @override
  final bool hidden;
  @override
  final List<RegistryAccessor> options;
}

final class RegistryAccessorValue extends RegistryAccessor {
  new({
    required String name,
    required this.valueKind,
    this.required = false,
    String? description,
    List<String>? choices,
    this.defaultValue,
    this.pattern,
  }) : choices = choices == null ? null : List.unmodifiable(choices),
       super(name, description);
  @override
  String get kind => 'value';
  final RegistryValueKind valueKind;
  @override
  final bool required;
  @override
  String get valueType => valueKind.wireName;
  @override
  final List<String>? choices;
  @override
  final String? defaultValue;
  @override
  final String? pattern;
}

final class CommandResolution {
  const new({
    required this.registry,
    required this.path,
    required this.tokenIndices,
  });

  final CommandRegistry registry;
  final List<String> path;
  final Set<int> tokenIndices;
}

final class MambaCommandNotFoundException extends MambaException {
  new(String name, List<String> parentPath, List<String> available)
    : super(
        'Command $name was not found under ${parentPath.join(' ')}. ${available.isEmpty ? 'This command has no subcommands.' : 'Available commands: ${available.join(', ')}'}',
      );
}

final class MambaApplicationNameException extends MambaException {
  new(String name)
    : super(
        'A command path never begins with the application name. "$name" is the application, not a command under it.',
      );
}

final class CommandRegistry {
  new _({
    required this.name,
    required this.shortDescription,
    this.defaultCommandPath,
    this.longDescription,
    this.commandAliases,
    this.parent,
    List<Flag<Object?>>? flags,
    List<Option<Object?>>? options,
    List<PairedOptionsDefinition>? pairedOptions,
    List<SelectedOptions>? selectedOptions,
    Map<String, List<String>>? conflicts,
    List<MandatoryPositional<Object?>>? mandatoryPositionals,
    List<DiscretionaryPositional<Object?>>? discretionaryPositionals,
    this.variadic,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<Flag<Object?>>? publishedFlags,
    List<Option<Object?>>? publishedOptions,
    List<AccessorListOption>? publishedAccessors,
  }) : flags = List.unmodifiable(flags ?? const []),
       options = List.unmodifiable(options ?? const []),
       pairedOptionGroups = List.unmodifiable(pairedOptions ?? const []),
       selectedOptions = List.unmodifiable(selectedOptions ?? const []),
       _declaredConflicts = Map<String, List<String>>.unmodifiable({
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
       publishedAccessors = List.unmodifiable(publishedAccessors ?? const []),
       commands = List.unmodifiable(commands ?? const []) {
    _validateEffectiveSpellings();
    _effectiveConflictEdges;
  }
  final String name;
  final String shortDescription;
  final List<String>? defaultCommandPath;
  final String? longDescription;
  final List<String>? commandAliases;
  final CommandRegistry? parent;
  final List<Flag<Object?>> flags;
  final List<Option<Object?>> options;
  final List<PairedOptionsDefinition> pairedOptionGroups;
  final List<SelectedOptions> selectedOptions;
  final Map<String, List<String>> _declaredConflicts;
  Map<String, List<String>> get conflicts {
    final result = <String, List<String>>{};
    for (final edge in _effectiveConflictEdges) {
      (result[edge.sourceName] ??= []).add(edge.targetName);
    }
    return Map.unmodifiable({
      for (final entry in result.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }

  late final List<_ConflictEdge> _localConflictEdges = _resolveConflicts();

  List<_ConflictEdge> get _allConflictEdges => [
    ...?parent?._allConflictEdges,
    ..._localConflictEdges,
  ];

  List<_ConflictEdge> get _effectiveConflictEdges {
    final lineage = inputLineage;
    InputDefinition? applicable(String name, InputDefinition input) =>
        lineage[input] ??
        (identical(conflictInput(name), input) ? input : null);
    return [
      for (final edge in _allConflictEdges)
        if (applicable(edge.sourceName, edge.source) != null &&
            applicable(edge.targetName, edge.target) != null)
          (
            sourceName: edge.sourceName,
            source: applicable(edge.sourceName, edge.source) as InputDefinition,
            targetName: edge.targetName,
            target: applicable(edge.targetName, edge.target) as InputDefinition,
          ),
    ];
  }

  List<_ConflictEdge> _resolveConflicts() {
    final edges = <_ConflictEdge>[];
    bool required(InputDefinition input) =>
        input is RequiredInput ||
        pairedOptionGroups.any(
          (group) => group.required && group.options.contains(input),
        );
    InputDefinition endpoint(String name, String role) {
      final input = conflictInput(name);
      if (input == null ||
          identical(input, MambaBuiltInFlags.help) ||
          identical(input, MambaBuiltInFlags.version)) {
        throw MambaRegistryError(
          'Conflict $role $name is not a registered ordinary input.',
        );
      }
      return input;
    }

    for (final entry in _declaredConflicts.entries) {
      final key = endpoint(entry.key, 'key');
      for (final (index, name) in entry.value.indexed) {
        final member = endpoint(
          name,
          'member at index $index for ${entry.key}:',
        );
        if (required(key) && required(member)) {
          throw MambaRegistryError(
            'Inputs --${entry.key} and --$name are both required but cannot be used together.',
          );
        }
        if (required(key) || required(member)) {
          final requiredName = required(key) ? entry.key : name;
          final optionalName = required(key) ? name : entry.key;
          throw MambaRegistryError(
            'Input --$optionalName cannot be supplied because it conflicts with required input --$requiredName.',
          );
        }
        edges.add((
          sourceName: entry.key,
          source: key,
          targetName: name,
          target: member,
        ));
      }
    }
    return List.unmodifiable(edges);
  }

  final List<MandatoryPositional<Object?>> mandatoryPositionals;
  final List<DiscretionaryPositional<Object?>> discretionaryPositionals;
  final Variadic? variadic;
  final List<AccessorListOption> accessors;
  final List<Flag<Object?>> publishedFlags;
  final List<Option<Object?>> publishedOptions;
  final List<AccessorListOption> publishedAccessors;
  final List<Command> commands;
  late final List<CommandRegistry> commandRegistries = [
    for (final command in commands) _fromCommand(command, this),
  ];
  List<String> get fullPath => [...?parent?.fullPath, name];

  /// [fullPath] as an invocation names it: without the application name.
  ///
  /// A command path never begins with the application name, so this is the
  /// shape resolution and default-command lookup work in. Keeping it beside
  /// [fullPath] is what stops the two spellings drifting apart.
  List<String> get relativePath =>
      parent == null ? const [] : fullPath.skip(1).toList();
  List<Flag<Object?>> get applicableFlags {
    final resolved = <String, Flag<Object?>>{
      for (final flag in [
        ...?parent?._publishedFlagsToHere,
        ...publishedFlags,
        ...flags,
      ])
        flag.name: flag,
    };
    resolved[MambaBuiltInFlags.help.name] = MambaBuiltInFlags.help;
    return List.unmodifiable(resolved.values);
  }

  List<Flag<Object?>> get _publishedFlagsToHere => [
    ...?parent?._publishedFlagsToHere,
    ...publishedFlags,
  ];
  List<Option<Object?>> get applicableOptions => List.unmodifiable(
    {
      for (final option in [
        ...?parent?._publishedOptionsToHere,
        ...publishedOptions,
        ...options,
      ])
        option.name: option,
    }.values,
  );
  List<Option<Object?>> get _publishedOptionsToHere => [
    ...?parent?._publishedOptionsToHere,
    ...publishedOptions,
  ];
  List<AccessorListOption> get applicableAccessors => List.unmodifiable(
    {
      for (final accessor in [
        ...?parent?._publishedAccessorsToHere,
        ...publishedAccessors,
        ...accessors,
      ])
        accessor.name: accessor,
    }.values,
  );
  List<AccessorListOption> get _publishedAccessorsToHere => [
    ...?parent?._publishedAccessorsToHere,
    ...publishedAccessors,
  ];
  factory create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<MandatoryPositional<Object?>>? mandatoryPositionals,
    List<DiscretionaryPositional<Object?>>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag<Object?>>? flags,
    List<Option<Object?>>? options,
    List<PairedOptionsDefinition>? pairedOptions,
    List<SelectedOptions>? selectedOptions,
    Map<String, List<String>>? conflicts,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<String>? defaultCommandPath,
  }) {
    _validate(
      name,
      shortDescription,
      flags: [...?flags, MambaBuiltInFlags.help],
      options: options,
      paired: pairedOptions,
      selected: selectedOptions,
      conflicts: conflicts,
      accessors: accessors,
      mandatory: mandatoryPositionals,
      discretionary: discretionaryPositionals,
      variadic: variadic,
      commands: commands,
    );
    final registry = CommandRegistry._(
      name: name,
      defaultCommandPath: defaultCommandPath == null
          ? null
          : List.unmodifiable(defaultCommandPath),
      shortDescription: shortDescription,
      longDescription: longDescription,
      flags: flags,
      options: options,
      pairedOptions: pairedOptions,
      selectedOptions: selectedOptions,
      conflicts: conflicts,
      mandatoryPositionals: mandatoryPositionals,
      discretionaryPositionals: discretionaryPositionals,
      variadic: variadic,
      accessors: accessors,
      commands: commands,
      publishedFlags: flags,
      publishedOptions: options,
      publishedAccessors: accessors,
    );
    void validateTree(CommandRegistry scope) {
      for (final child in scope.commandRegistries) {
        validateTree(child);
      }
      if (scope.defaultCommandPath != null) {
        scope.canonicalCommandPath(scope.defaultCommandPath!, allowGroup: true);
      }
    }

    validateTree(registry);
    return registry;
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
      conflicts: command.conflicts,
      accessors: command.accessors,
      mandatory: command.mandatoryPositionals,
      discretionary: command.discretionaryPositionals,
      variadic: command.variadic,
      commands: group?.commands,
      propagatedFlags: group?.inheritedFlags,
      propagatedOptions: group?.inheritedOptions,
    );
    return CommandRegistry._(
      name: command.name,
      defaultCommandPath: group?.defaultSubCommandPath,
      shortDescription: command.shortDescription,
      longDescription: command.longDescription,
      commandAliases: command.aliases,
      parent: parent,
      flags: command.flags,
      options: command.options,
      pairedOptions: command.pairedOptions,
      selectedOptions: command.selectedOptions,
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

  /// Resolves command tokens while skipping values owned by applicable inputs.
  CommandResolution resolveCommandPath(
    List<String> args, {
    CommandRegistry Function(CommandRegistry)? defaultTarget,
  }) {
    var registry = this;
    final path = <CommandRegistry>[];
    final indices = <int>{};
    for (var index = 0; index < args.length; index++) {
      final token = args[index];
      if (token == '--') break;
      final next = index + 1 < args.length ? args[index + 1] : null;
      final ownedLength =
          registry.registeredInputTokenLength(token, next: next) ??
          defaultTarget
              ?.call(registry)
              .registeredInputTokenLength(token, next: next);
      if (MambaBuiltInFlags.isControl(token)) break;
      if (ownedLength != null) {
        index += ownedLength - 1;
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
        continue;
      }
      if (path.isEmpty && token == name) {
        throw MambaApplicationNameException(name);
      }
    }
    return CommandResolution(
      registry: registry,
      path: List.unmodifiable(path.map((item) => item.name)),
      tokenIndices: Set.unmodifiable(indices),
    );
  }

  CommandRegistry registryForArguments(List<String> args) =>
      resolveCommandPath(args).registry;

  CommandRegistry registryForPath(List<String> path) {
    if (path.isEmpty || path.first != name) {
      throw ArgumentError.value(path, 'path', 'must start with $name');
    }
    return descendant(path.skip(1));
  }

  /// The registry [path] names below this one, empty path being this registry.
  ///
  /// A command path never begins with the application name, so this is the
  /// shape an invocation resolves to.
  CommandRegistry descendant(Iterable<String> path) {
    var registry = this;
    for (final segment in path) {
      registry = registry.commandRegistries.singleWhere(
        (child) => child.name == segment,
      );
    }
    return registry;
  }

  List<String> canonicalCommandPath(
    List<String> path, {
    bool allowGroup = false,
  }) {
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
    if (!allowGroup && registry.commandRegistries.isNotEmpty) {
      throw MambaRegistryError(
        'defaultCommandPath must end at an executable command.',
      );
    }
    return List.unmodifiable(canonical);
  }

  int? registeredInputTokenLength(String token, {String? next}) {
    int width(InputDefinition input) =>
        next == null || ownsSeparateValue(input, next) ? 2 : 1;
    if (token.startsWith('--')) {
      final name = token.substring(2).split('=').first;
      final input =
          _allValueInputs.where((input) => input.name == name).firstOrNull ??
          _accessorFor(name);
      if (input != null) return token.contains('=') ? 1 : width(input);
      if (applicableFlags.any(
        (flag) =>
            flag.name == name ||
            (flag is BooleanFlag &&
                flag.negatable &&
                name == 'no-${flag.name}'),
      )) {
        return 1;
      }
    }
    if (token.startsWith('-') && token.length > 1) {
      final short = token.substring(1).split('=').first;
      if (token.contains('=')) return 1;
      final input = _allValueInputs
          .where((input) => _shortOf(input) == short)
          .firstOrNull;
      if (input != null) return width(input);
      if (short
          .split('')
          .every(
            (letter) => applicableFlags.any((flag) => _shortOf(flag) == letter),
          )) {
        return 1;
      }
    }
    return null;
  }

  Iterable<InputDefinition> get _allValueInputs sync* {
    yield* applicableOptions;
    for (final group in pairedOptionGroups) {
      yield* group.options;
    }
    for (final group in selectedOptions) {
      yield* group.options;
    }
  }

  AccessorPrimitiveOption<Object?>? _accessorFor(String path) {
    AccessorOption? current = applicableAccessors
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

  /// Checks the spellings that actually answer for this command.
  ///
  /// Local declarations shadow propagated ones by name, so the effective set is
  /// the one the parser reads. A short alias may only answer for one of them,
  /// and no declaration may claim a spelling Mamba always interprets itself.
  void _validateEffectiveSpellings() {
    // Computing lineage also checks that every override preserves retained types.
    inputLineage;
    final shorts = <String, String>{};
    final longs = <String, String>{};
    void claim(String spelling, String owner) {
      final previous = longs[spelling];
      if (previous != null) {
        throw MambaRegistryError(
          'Spelling --$spelling is used by both $previous and $owner.',
        );
      }
      longs[spelling] = owner;
    }

    final leaves = <AccessorPrimitiveOption<Object?>>{};
    for (final accessor in applicableAccessors) {
      _rejectReservedSpelling(accessor);
      void visit(AccessorOption input, String path) {
        if (input is AccessorPrimitiveOption && !leaves.add(input)) {
          throw MambaRegistryError(
            'Accessor leaf ${input.name} is reused in multiple effective paths.',
          );
        }
        claim(path, accessor.name);
        if (input is AccessorListOption) {
          for (final child in input.options) {
            visit(child, '$path.${child.name}');
          }
        }
      }

      visit(accessor, accessor.name);
    }
    final inputs = <InputDefinition>[
      ...applicableFlags,
      ...applicableOptions,
      for (final group in pairedOptionGroups) ...group.options,
      for (final group in selectedOptions) ...group.options,
    ];
    for (final input in inputs) {
      claim(input.name, input.name);
      if (input is BooleanFlag && input.negatable) {
        claim('no-${input.name}', input.name);
      }
      _rejectReservedSpelling(input);
      final short = _shortOf(input);
      if (short == null) continue;
      final previous = shorts[short];
      if (previous != null) {
        throw MambaRegistryError(
          'Short alias -$short is used by both $previous and ${input.name}.',
        );
      }
      shorts[short] = input.name;
    }
  }

  /// Maps actual applicable declaration identities to their effective handles.
  /// Names alone never connect declarations from an unavailable local scope.
  late final Map<InputDefinition, InputDefinition> inputLineage =
      _resolveInputLineage();

  Map<InputDefinition, InputDefinition> _resolveInputLineage() {
    final aliases = <InputDefinition, InputDefinition>{};
    void pair(InputDefinition ancestor, InputDefinition effective) {
      if (ancestor is! Input ||
          effective is! Input ||
          ancestor.outputType != effective.outputType ||
          (ancestor is Flag) != (effective is Flag) ||
          (ancestor is AccessorListOption) !=
              (effective is AccessorListOption) ||
          (ancestor is AccessorPrimitiveOption) !=
              (effective is AccessorPrimitiveOption) ||
          (ancestor is RepeatableOptionDefinition) !=
              (effective is RepeatableOptionDefinition) ||
          (ancestor is! AccessorListOption &&
              valueKindOf(ancestor) != valueKindOf(effective))) {
        throw MambaRegistryError(
          'Override of ${ancestor.name} must preserve kind, output type, and cardinality.',
        );
      }
      aliases[ancestor] = effective;
      if (ancestor is AccessorListOption && effective is AccessorListOption) {
        for (final child in ancestor.options) {
          final replacement = effective.options
              .where((item) => item.name == child.name)
              .firstOrNull;
          if (replacement == null) {
            throw MambaRegistryError(
              'Accessor override ${ancestor.name} omits ${child.name}.',
            );
          }
          pair(child, replacement);
        }
      }
    }

    void family(List<InputDefinition> candidates) {
      final effective = <String, InputDefinition>{
        for (final input in candidates) input.name: input,
      };
      for (final input in candidates) {
        pair(input, effective[input.name] as InputDefinition);
      }
    }

    family([...?parent?._publishedFlagsToHere, ...publishedFlags, ...flags]);
    family([
      ...?parent?._publishedOptionsToHere,
      ...publishedOptions,
      ...options,
    ]);
    family([
      ...?parent?._publishedAccessorsToHere,
      ...publishedAccessors,
      ...accessors,
    ]);
    return Map.unmodifiable(aliases);
  }

  /// Rejects [input] when it claims a spelling Mamba always reads itself.
  ///
  /// Checked in two places on purpose, because they see different sets: a
  /// declaration and the inputs it propagates arrive here through [_validate],
  /// while the set that actually answers for a command — inherited plus local
  /// — arrives through [_validateEffectiveSpellings]. An ancestor can publish a
  /// flag only its descendants ever see, so neither check covers the other.
  static void _rejectReservedSpelling(InputDefinition input) {
    final reserved = _reservedSpelling(input);
    if (reserved == null) return;
    throw MambaRegistryError(
      'Input $reserved for ${input.name} is reserved for Mamba.',
    );
  }

  /// The reserved spelling [input] claims, or null when it claims none.
  ///
  /// Mamba's own declarations are exempt: the registry supplies help itself
  /// and an executor may supply version. A user declaration claiming either
  /// spelling is rejected, because the parser always reads it as the built-in.
  static String? _reservedSpelling(InputDefinition input) {
    if (identical(input, MambaBuiltInFlags.help) ||
        identical(input, MambaBuiltInFlags.version)) {
      return null;
    }
    if (input.name == MambaBuiltInFlags.help.name ||
        input.name == MambaBuiltInFlags.version.name) {
      return '--${input.name}';
    }
    final short = _shortOf(input);
    if (short == MambaBuiltInFlags.help.short ||
        short == MambaBuiltInFlags.version.short) {
      return '-$short';
    }
    return null;
  }

  static String? _shortOf(InputDefinition input) => switch (input) {
    Flag(:final short) ||
    Option(:final short) ||
    PairOption(:final short) => short,
    _ => null,
  };
  RegistryRecord toRecord() => _record(this);
  static RegistryRecord _record(CommandRegistry registry) {
    final options = [
      ...registry.applicableOptions,
      for (final group in registry.pairedOptionGroups) ...group.options,
      for (final group in registry.selectedOptions) ...group.options,
    ];
    return (
      name: registry.name,
      conflicts: registry.conflicts,
      defaultCommandPath: registry.defaultCommandPath == null
          ? null
          : registry.canonicalCommandPath(
              registry.defaultCommandPath!,
              allowGroup: true,
            ),
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
      optionGroups: List<RegistryOptionGroup>.unmodifiable([
        for (final group in <PairedOptionsDefinition>[
          ...registry.pairedOptionGroups,
          ...registry.selectedOptions,
        ])
          (
            required: group.required,
            single: group is SelectedOptions && group.single,
            members: List<String>.unmodifiable(
              group.options.map((item) => item.name),
            ),
          ),
      ]),
      accessors: registry.applicableAccessors.isEmpty
          ? null
          : List.unmodifiable([
              for (final accessor in registry.applicableAccessors)
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
      conflicts: record.conflicts,
      defaultCommandPath: record.defaultCommandPath,
    );
  }

  static RegistryFlag _flagRecord(Flag<Object?> flag) => (
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
      valueType: valueKindOf(input).wireName,
      repeatable:
          input is RepeatableOptionDefinition || input is RepeatablePairOption
          ? true
          : null,
      unique: input is RepeatableOptionDefinition && input.unique ? true : null,
      choices: choice == null
          ? null
          : List.unmodifiable(choice.map(choiceSpelling)),
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

  static String _defaultText(Object? value) => switch (value) {
    Enum value => choiceSpelling(value),
    List<Object?> values => values.map(_defaultText).join(','),
    _ => value.toString(),
  };

  static RegistryPositional _positionalRecord(
    Positional<Object?> input,
    bool required,
  ) {
    final choices = input is ChoiceValidated
        ? (input as ChoiceValidated).choices.cast<Enum>()
        : null;
    return (
      name: input.name,
      required: required,
      description: input.description,
      choices: choices == null
          ? null
          : List.unmodifiable(choices.map(choiceSpelling)),
      defaultValue: switch (input) {
        DefaultValue(:final defaultValue) when defaultValue is List<Enum> =>
          defaultValue.map(choiceSpelling).join(','),
        DefaultValue(:final defaultValue) => choiceSpelling(
          defaultValue as Enum,
        ),
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
          : List.unmodifiable(choices.map(choiceSpelling)),
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
          valueType: valueKindOf(input).wireName,
          required: input is RequiredInput,
          description: input.description,
          choices: input is ChoiceValidated
              ? List.unmodifiable(
                  (input as ChoiceValidated).choices.cast<Enum>().map(
                    choiceSpelling,
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
  static final _name = RegExp(
    r'^[A-Za-z][A-Za-z0-9]*(?:[-_][A-Za-z][A-Za-z0-9]*)*$',
  );

  /// The name shape every command, alias, and input shares.
  ///
  /// A word leads with a letter and may carry digits, so `max-workers2` is a
  /// legal name. Words are separated by exactly one hyphen or underscore,
  /// which keeps `dry__run` and `2fast` out.
  static String _invalidName(String name, String kind) =>
      '$kind "$name" must be letter-led words of letters and digits '
      'separated by a single hyphen or underscore.';

  static void _validate(
    String name,
    String description, {
    List<Flag<Object?>>? flags,
    List<Option<Object?>>? options,
    List<PairedOptionsDefinition>? paired,
    List<SelectedOptions>? selected,
    List<Flag<Object?>>? propagatedFlags,
    List<Option<Object?>>? propagatedOptions,
    Map<String, List<String>>? conflicts,
    List<AccessorListOption>? accessors,
    List<Positional<Object?>>? mandatory,
    List<Positional<Object?>>? discretionary,
    Variadic? variadic,
    List<Command>? commands,
  }) {
    if (!_name.hasMatch(name)) {
      throw MambaRegistryError(_invalidName(name, 'Command name'));
    }
    if (description.isEmpty) {
      throw MambaRegistryError('Command "$name" must have a description.');
    }
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
      ...?propagatedFlags,
      ...?propagatedOptions,
      for (final group in paired ?? const <PairedOptionsDefinition>[])
        ...group.options,
      for (final group in selected ?? const <SelectedOptions>[])
        ...group.options,
    ];
    final names = <String>{};
    final shorts = <String, InputDefinition>{};
    for (final input in inputs) {
      if (!_name.hasMatch(input.name)) {
        throw MambaRegistryError(_invalidName(input.name, 'Input name'));
      }
      _rejectReservedSpelling(input);
      if (!names.add(input.name)) {
        throw MambaRegistryError('Input --${input.name} is registered twice.');
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
      if (!_name.hasMatch(command.name)) {
        throw MambaRegistryError(_invalidName(command.name, 'Command name'));
      }
      if (!commandNames.add(command.name)) {
        throw MambaRegistryError(
          'Command ${command.name} is registered twice.',
        );
      }
      for (final alias in command.aliases ?? const <String>[]) {
        if (!_name.hasMatch(alias)) {
          throw MambaRegistryError(_invalidName(alias, 'Command alias'));
        }
        if (!commandNames.add(alias)) {
          throw MambaRegistryError(
            'Alias $alias for ${command.name} is registered twice.',
          );
        }
      }
    }
    if (variadic is ChoiceVariadic) {
      final spellings = variadic.choices.map(choiceSpelling).toList();
      if (spellings.isEmpty || spellings.toSet().length != spellings.length) {
        throw MambaRegistryError(
          'Variadic choices must have nonempty, unique offered entries.',
        );
      }
    }
    final leaves = <AccessorPrimitiveOption<Object?>>{};
    void visit(AccessorOption input) {
      if (!_name.hasMatch(input.name)) {
        throw MambaRegistryError(_invalidName(input.name, 'Accessor name'));
      }
      if (input is AccessorPrimitiveOption && !leaves.add(input)) {
        throw MambaRegistryError(
          'Accessor leaf ${input.name} is reused in multiple paths.',
        );
      }
      if (input is AccessorListOption) {
        final level = <String>{};
        for (final child in input.options) {
          if (!level.add(child.name)) {
            throw MambaRegistryError('Duplicate accessor ${child.name}');
          }
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
        if (choices.isEmpty) {
          throw MambaRegistryError(
            'Choices for ${input.name} must not be empty.',
          );
        }
        if (choices.map(choiceSpelling).toSet().length != choices.length) {
          throw MambaRegistryError(
            'Offered choice spellings for ${input.name} must be unique.',
          );
        }
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
        if (input is RepeatableOptionDefinition &&
            input.unique &&
            defaultValue is List &&
            defaultValue.toSet().length != defaultValue.length) {
          throw MambaRegistryError(
            'Unique defaults for ${input.name} must not repeat a choice.',
          );
        }
        if (!defaultsAreRegistered) {
          throw MambaRegistryError(
            'Every default must be a registered choice for ${input.name}.',
          );
        }
      }
      if (input is AccessorListOption) {
        for (final child in input.options) {
          validateChoices(child);
        }
      }
    }

    for (final input in [
      ...?options,
      ...?propagatedOptions,
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
    for (final positional in [...?mandatory, ...?discretionary]) {
      if (positional is! RepeatedPositionalDefinition ||
          positional is! DefaultValue) {
        continue;
      }
      final repeated = positional as RepeatedPositionalDefinition;
      final defaults = (positional as DefaultValue).defaultValue;
      if (defaults is List && defaults.length > repeated.times) {
        throw MambaRegistryError(
          'Default for ${repeated.name} declares ${defaults.length} values but holds at most ${repeated.times}.',
        );
      }
    }
    void validateNumeric(InputDefinition input) {
      if (input is NumericRangeValidated) {
        final range = input as NumericRangeValidated;
        if ((range.min != null && !range.min!.isFinite) ||
            (range.max != null && !range.max!.isFinite)) {
          throw MambaRegistryError('Bounds must be finite for ${input.name}.');
        }
        if (range.min != null && range.max != null && range.min! > range.max!) {
          throw MambaRegistryError(
            'Minimum must not exceed maximum for ${input.name}.',
          );
        }
      }
      if (input is NumericStepValidated) {
        final stepped = input as NumericStepValidated;
        final step = stepped.step;
        if (step != null) {
          if (!step.isFinite || step <= 0) {
            throw MambaRegistryError(
              'Step must be finite and positive for ${input.name}.',
            );
          }
          final range = input as NumericRangeValidated;
          if (range.min == null || range.max == null) {
            throw MambaRegistryError(
              'Stepped doubles require both finite bounds for ${input.name}.',
            );
          }
        }
      }
      if (input is DefaultValue) {
        final defaulted = input as DefaultValue;
        final defaults = defaulted.defaultValue is List
            ? defaulted.defaultValue as List
            : [defaulted.defaultValue];
        for (final value in defaults) {
          if (value is num && !value.isFinite) {
            throw MambaRegistryError(
              'Default must be finite for ${input.name}.',
            );
          }
          if (input is RegExpValidated &&
              input is! ChoiceValidated &&
              (value is! String ||
                  !validation.matchesEntireValue(
                    (input as RegExpValidated).regex,
                    value,
                  ))) {
            throw MambaRegistryError(
              'Default value is invalid for ${input.name}.',
            );
          }
          if (input is NumericStepValidated &&
              input is NumericRangeValidated &&
              value is num) {
            final stepped = input as NumericStepValidated;
            final range = input as NumericRangeValidated;
            if (stepped.step != null &&
                range.min != null &&
                !validation.followsNumericStep(
                  value,
                  range.min!,
                  stepped.step!,
                )) {
              throw MambaRegistryError(
                'Default value does not follow the step for ${input.name}.',
              );
            }
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
        for (final child in input.options) {
          validateNumeric(child);
        }
      }
    }

    for (final input in [
      ...?options,
      ...?propagatedOptions,
      ...?mandatory,
      ...?discretionary,
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
