import 'dart:collection';

/// Describes a command-line option in an [ArgParser] or [ArgCommand] schema.
sealed class ArgOption {
  const ArgOption({this.alias});

  /// The single-character short form, without a leading dash.
  final String? alias;
}

/// Describes a Boolean option such as `--verbose`.
final class BooleanOption extends ArgOption {
  const BooleanOption({
    super.alias,
    this.defaultValue = false,
    this.negatable = true,
  });

  /// The value used when the option is omitted.
  final bool defaultValue;

  /// Whether `--no-<name>` is accepted.
  final bool negatable;
}

/// Describes a string-valued option such as `--output=dist`.
final class StringOption extends ArgOption {
  const StringOption({
    super.alias,
    this.defaultValue,
    this.choices,
    this.required = false,
  });

  /// The value used when the option is omitted.
  final String? defaultValue;

  /// Accepted values, or `null` when every string is accepted.
  final Set<String>? choices;

  /// Whether parsing fails when no value is supplied.
  final bool required;
}

/// Describes a named positional argument.
final class ArgPositional {
  const ArgPositional(
    this.name, {
    this.required = false,
    this.multiple = false,
  });

  final String name;

  /// Whether this positional must receive at least one value.
  final bool required;

  /// Whether this positional captures all remaining values.
  final bool multiple;
}

/// A declarative command schema activated by its name or an alias.
final class ArgCommand {
  ArgCommand(
    this.name, {
    Set<String> aliases = const {},
    Map<String, ArgOption> options = const {},
    Map<String, Object> accessors = const {},
    List<ArgPositional> positionals = const [],
    List<ArgCommand> commands = const [],
    this.allowTrailingOptions = true,
  }) : aliases = Set.unmodifiable(aliases),
       options = Map.unmodifiable(options),
       accessors = Map.unmodifiable(accessors),
       positionals = List.unmodifiable(positionals),
       commands = List.unmodifiable(commands);

  final String name;
  final Set<String> aliases;

  /// Ordinary options addressed by one non-dotted long name.
  final Map<String, ArgOption> options;

  /// Nested accessor trees whose option leaves are addressed with dotted flags.
  final Map<String, Object> accessors;

  final List<ArgPositional> positionals;
  final List<ArgCommand> commands;
  final bool allowTrailingOptions;
}

/// Identifies why command-line parsing failed.
enum ArgParseErrorCode {
  unknownOption,
  missingValue,
  unexpectedValue,
  invalidValue,
  missingRequiredOption,
  missingPositional,
  missingCommand,
  unknownCommand,
}

/// A command-line input error returned by [ArgParser.parse].
final class ArgParseError {
  const ArgParseError(this.code, this.message, {this.token, this.index});

  final ArgParseErrorCode code;
  final String message;
  final String? token;
  final int? index;

  @override
  String toString() => message;
}

/// The result of attempting to parse command-line arguments.
sealed class ArgParseOutcome {
  const ArgParseOutcome();

  bool get isSuccess => this is ArgParseSuccess;
}

/// A successful parse containing one merged [arguments] object.
final class ArgParseSuccess extends ArgParseOutcome {
  const ArgParseSuccess(this.arguments);

  final ArgArguments arguments;
}

/// An unsuccessful parse containing a user-facing [error].
final class ArgParseFailure extends ArgParseOutcome {
  const ArgParseFailure(this.error);

  final ArgParseError error;
}

/// Parsed options and positionals for one activated command path.
///
/// Like Yargs' `argv`, [values] merges global options, selected-command
/// options, and named positionals. Dotted option names become nested maps.
final class ArgArguments {
  ArgArguments._({
    required Map<String, Object?> flatOptions,
    required Map<String, Object?> positionals,
    required Map<String, Object?> values,
    required List<String> rest,
    required List<String> commandPath,
  }) : _flatOptions = UnmodifiableMapView(flatOptions),
       _positionals = _freezeMap(positionals),
       values = _freezeMap(values),
       rest = List.unmodifiable(rest),
       commandPath = List.unmodifiable(commandPath);

  final Map<String, Object?> _flatOptions;
  final Map<String, Object?> _positionals;

  /// All parsed data as an immutable, object-shaped map.
  final Map<String, Object?> values;

  /// Positional values not claimed by a positional schema.
  final List<String> rest;

  /// Canonical names of the selected commands, from root to leaf.
  final List<String> commandPath;

  /// Reads a top-level property from [values].
  Object? operator [](String name) => values[name];

  /// Reads an option or positional using a dotted object path.
  Object? value(String path) {
    Object? current = values;
    for (final segment in path.split('.')) {
      if (current is! Map<String, Object?>) return null;
      current = current[segment];
    }
    return current;
  }

  /// Reads a nested object using a dotted path.
  Map<String, Object?>? object(String path) {
    final resolved = value(path);
    return resolved is Map<String, Object?> ? resolved : null;
  }

  /// Reads a Boolean option by its registered dotted name.
  bool? flag(String name) {
    final resolved = _flatOptions[name];
    return resolved is bool ? resolved : null;
  }

  /// Reads a string option by its registered dotted name.
  String? string(String name) {
    final resolved = _flatOptions[name];
    return resolved is String ? resolved : null;
  }

  /// Reads a single-value positional by name.
  String? positional(String name) {
    final resolved = _positionals[name];
    return resolved is String ? resolved : null;
  }

  /// Reads a variadic positional by name.
  List<String>? positionals(String name) {
    final resolved = _positionals[name];
    return resolved is List<String> ? resolved : null;
  }

  static Map<String, Object?> _freezeMap(Map<String, Object?> source) {
    final frozen = source.map(
      (key, value) => MapEntry(key, _freezeValue(value)),
    );
    return UnmodifiableMapView(frozen);
  }

  static Object? _freezeValue(Object? value) => switch (value) {
    Map<String, Object?> value => _freezeMap(value),
    List<String> value => List<String>.unmodifiable(value),
    _ => value,
  };
}

final class _RegisteredOption {
  const _RegisteredOption(this.name, this.schema);

  final String name;
  final ArgOption schema;
}

final class _SchemaNode {
  _SchemaNode._({
    required this.name,
    required this.options,
    required this.positionals,
    required this.commands,
    required this.commandAliases,
    required this.allowTrailingOptions,
  });

  factory _SchemaNode.create({
    required String? name,
    required Map<String, ArgOption> options,
    required Map<String, Object> accessors,
    required List<ArgPositional> positionals,
    required List<ArgCommand> commands,
    required bool allowTrailingOptions,
    Map<String, _RegisteredOption> inheritedOptions = const {},
    Map<String, _RegisteredOption> inheritedAliases = const {},
  }) {
    if (name != null) _validateIdentifier(name, 'command name');
    if (commands.isNotEmpty && positionals.isNotEmpty) {
      throw ArgumentError(
        'Command "$name" cannot declare both subcommands and positionals.',
      );
    }

    final localOptions = <String, _RegisteredOption>{};
    final activeOptions = Map<String, _RegisteredOption>.of(inheritedOptions);
    final activeAliases = Map<String, _RegisteredOption>.of(inheritedAliases);

    for (final entry in _combineOptions(options, accessors).entries) {
      final optionName = entry.key;
      for (final activeName in activeOptions.keys) {
        if (_pathsConflict(optionName, activeName)) {
          throw ArgumentError.value(
            optionName,
            'options',
            'Conflicts with option path "$activeName".',
          );
        }
      }

      final schema = _snapshotOption(entry.value);
      final registered = _RegisteredOption(optionName, schema);
      localOptions[optionName] = registered;
      activeOptions[optionName] = registered;

      final alias = schema.alias;
      if (alias != null) {
        if (alias.length != 1 || alias == '-') {
          throw ArgumentError.value(
            alias,
            'alias',
            'Must be exactly one character other than "-".',
          );
        }
        if (activeAliases.containsKey(alias)) {
          throw ArgumentError.value(
            alias,
            'alias',
            'Conflicts with another active option alias.',
          );
        }
        activeAliases[alias] = registered;
      }

      if (schema case StringOption(:final defaultValue, :final choices)) {
        if (defaultValue != null &&
            choices != null &&
            !choices.contains(defaultValue)) {
          throw ArgumentError.value(
            defaultValue,
            'defaultValue',
            'Must be one of the configured choices.',
          );
        }
      }
    }

    _validatePositionals(positionals, activeOptions.keys);

    final childCommands = <String, _SchemaNode>{};
    final childAliases = <String, _SchemaNode>{};
    for (final command in commands) {
      _validateIdentifier(command.name, 'command name');
      if (childCommands.containsKey(command.name) ||
          childAliases.containsKey(command.name)) {
        throw ArgumentError.value(
          command.name,
          'commands',
          'Command name is already registered.',
        );
      }

      for (final alias in command.aliases) {
        _validateIdentifier(alias, 'command alias');
        if (alias == command.name ||
            childCommands.containsKey(alias) ||
            childAliases.containsKey(alias)) {
          throw ArgumentError.value(
            alias,
            'aliases',
            'Command name or alias is already registered.',
          );
        }
      }

      final child = _SchemaNode.create(
        name: command.name,
        options: command.options,
        accessors: command.accessors,
        positionals: command.positionals,
        commands: command.commands,
        allowTrailingOptions: command.allowTrailingOptions,
        inheritedOptions: activeOptions,
        inheritedAliases: activeAliases,
      );
      childCommands[command.name] = child;
      for (final alias in command.aliases) {
        childAliases[alias] = child;
      }
    }

    return _SchemaNode._(
      name: name,
      options: Map.unmodifiable(localOptions),
      positionals: List.unmodifiable(positionals),
      commands: Map.unmodifiable(childCommands),
      commandAliases: Map.unmodifiable(childAliases),
      allowTrailingOptions: allowTrailingOptions,
    );
  }

  final String? name;
  final Map<String, _RegisteredOption> options;
  final List<ArgPositional> positionals;
  final Map<String, _SchemaNode> commands;
  final Map<String, _SchemaNode> commandAliases;
  final bool allowTrailingOptions;

  static ArgOption _snapshotOption(ArgOption option) => switch (option) {
    BooleanOption(:final alias, :final defaultValue, :final negatable) =>
      BooleanOption(
        alias: alias,
        defaultValue: defaultValue,
        negatable: negatable,
      ),
    StringOption(
      :final alias,
      :final defaultValue,
      :final choices,
      :final required,
    ) =>
      StringOption(
        alias: alias,
        defaultValue: defaultValue,
        choices: choices == null ? null : Set.unmodifiable(choices),
        required: required,
      ),
  };

  static Map<String, ArgOption> _combineOptions(
    Map<String, ArgOption> options,
    Map<String, Object> accessors,
  ) {
    final combined = <String, ArgOption>{};
    for (final entry in options.entries) {
      _validateIdentifier(entry.key, 'option name');
      combined[entry.key] = entry.value;
    }
    combined.addAll(_flattenAccessors(accessors));
    return combined;
  }

  static Map<String, ArgOption> _flattenAccessors(
    Map<String, Object> options, {
    String prefix = '',
  }) {
    final flattened = <String, ArgOption>{};

    for (final entry in options.entries) {
      _validateIdentifier(entry.key, 'option key');
      final name = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;

      if (value is ArgOption) {
        flattened[name] = value;
        continue;
      }

      if (value is Map) {
        if (value.isEmpty) {
          throw ArgumentError.value(
            value,
            'options',
            'Object schema "$name" must contain an option.',
          );
        }

        final children = <String, Object>{};
        for (final child in value.entries) {
          if (child.key is! String) {
            throw ArgumentError.value(
              child.key,
              'options',
              'Object schema keys must be strings.',
            );
          }
          children[child.key as String] = child.value;
        }
        flattened.addAll(_flattenAccessors(children, prefix: name));
        continue;
      }

      throw ArgumentError.value(
        value,
        'options',
        'Option "$name" must be an ArgOption or a nested map.',
      );
    }

    return flattened;
  }

  static void _validatePositionals(
    List<ArgPositional> positionals,
    Iterable<String> optionNames,
  ) {
    final names = <String>{};
    var foundOptional = false;
    for (var index = 0; index < positionals.length; index++) {
      final positional = positionals[index];
      _validateIdentifier(positional.name, 'positional name');
      if (!names.add(positional.name)) {
        throw ArgumentError.value(
          positional.name,
          'positionals',
          'Positional name is already registered.',
        );
      }
      if (optionNames.any((name) => _pathsConflict(positional.name, name))) {
        throw ArgumentError.value(
          positional.name,
          'positionals',
          'Conflicts with an active option path.',
        );
      }
      if (positional.multiple && index != positionals.length - 1) {
        throw ArgumentError.value(
          positional.name,
          'positionals',
          'A variadic positional must be last.',
        );
      }
      if (foundOptional && positional.required) {
        throw ArgumentError.value(
          positional.name,
          'positionals',
          'A required positional cannot follow an optional positional.',
        );
      }
      if (!positional.required) foundOptional = true;
    }
  }

  static void _validateIdentifier(String name, String description) {
    if (!_isIdentifier(name)) {
      throw ArgumentError.value(
        name,
        description,
        'Use an alphanumeric kebab-case name without dots.',
      );
    }
  }

  static bool _isIdentifier(String value) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(value);

  static bool _pathsConflict(String first, String second) {
    final firstPath = first.split('.');
    final secondPath = second.split('.');
    return _isPrefix(firstPath, secondPath) || _isPrefix(secondPath, firstPath);
  }

  static bool _isPrefix(List<String> prefix, List<String> value) {
    if (prefix.length > value.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (prefix[index] != value[index]) return false;
    }
    return true;
  }
}

/// Parses tokens according to an immutable, command-oriented schema.
///
/// The schema model is inspired by Yargs: nested accessor trees produce dotted
/// CLI flags and nested values, while only the selected command branch
/// contributes its options and defaults. Root options remain global throughout
/// that selected branch.
final class ArgParser {
  ArgParser({
    Map<String, ArgOption> options = const {},
    Map<String, Object> accessors = const {},
    List<ArgPositional> positionals = const [],
    List<ArgCommand> commands = const [],
    bool allowTrailingOptions = true,
  }) : _root = _SchemaNode.create(
         name: null,
         options: Map.unmodifiable(options),
         accessors: Map.unmodifiable(accessors),
         positionals: List.unmodifiable(positionals),
         commands: List.unmodifiable(commands),
         allowTrailingOptions: allowTrailingOptions,
       );

  final _SchemaNode _root;

  /// Parses [tokens] without throwing for malformed command-line input.
  ArgParseOutcome parse(List<String> tokens) => _parseNode(
    _root,
    List.unmodifiable(tokens),
    baseIndex: 0,
    inheritedOptions: const {},
    inheritedAliases: const {},
    flatOptions: {},
    commandPath: const [],
  );

  ArgParseOutcome _parseNode(
    _SchemaNode node,
    List<String> tokens, {
    required int baseIndex,
    required Map<String, _RegisteredOption> inheritedOptions,
    required Map<String, _RegisteredOption> inheritedAliases,
    required Map<String, Object?> flatOptions,
    required List<String> commandPath,
  }) {
    final activeOptions = Map<String, _RegisteredOption>.of(inheritedOptions)
      ..addAll(node.options);
    final activeAliases = Map<String, _RegisteredOption>.of(inheritedAliases);
    for (final option in node.options.values) {
      if (option.schema.alias case final alias?) {
        activeAliases[alias] = option;
      }
      switch (option.schema) {
        case BooleanOption(:final defaultValue):
          flatOptions.putIfAbsent(option.name, () => defaultValue);
        case StringOption(:final defaultValue):
          if (defaultValue != null) {
            flatOptions.putIfAbsent(option.name, () => defaultValue);
          }
      }
    }

    final positionalTokens = <String>[];
    var parsesOptions = true;
    var index = 0;

    while (index < tokens.length) {
      final token = tokens[index];

      if (parsesOptions && token == '--') {
        parsesOptions = false;
        index++;
        continue;
      }

      if (parsesOptions && token.startsWith('--')) {
        final progress = _parseLongOption(
          tokens,
          index,
          baseIndex,
          activeOptions,
          flatOptions,
        );
        if (progress.error case final error?) return ArgParseFailure(error);
        index = progress.nextIndex;
        continue;
      }

      if (parsesOptions && token.startsWith('-') && token != '-') {
        final progress = _parseShortOptions(
          tokens,
          index,
          baseIndex,
          activeAliases,
          flatOptions,
        );
        if (progress.error case final error?) return ArgParseFailure(error);
        index = progress.nextIndex;
        continue;
      }

      if (node.commands.isNotEmpty) {
        if (!parsesOptions) break;
        final selected = node.commands[token] ?? node.commandAliases[token];
        if (selected == null) {
          return ArgParseFailure(
            ArgParseError(
              ArgParseErrorCode.unknownCommand,
              'Unknown command "$token".',
              token: token,
              index: baseIndex + index,
            ),
          );
        }

        return _parseNode(
          selected,
          tokens.sublist(index + 1),
          baseIndex: baseIndex + index + 1,
          inheritedOptions: activeOptions,
          inheritedAliases: activeAliases,
          flatOptions: flatOptions,
          commandPath: [...commandPath, selected.name!],
        );
      }

      positionalTokens.add(token);
      if (!node.allowTrailingOptions) parsesOptions = false;
      index++;
    }

    if (node.commands.isNotEmpty) {
      return ArgParseFailure(
        ArgParseError(
          ArgParseErrorCode.missingCommand,
          _missingCommandMessage(node, commandPath),
          index: baseIndex + index,
        ),
      );
    }

    while (index < tokens.length) {
      positionalTokens.add(tokens[index]);
      index++;
    }

    final missingOption = _getMissingOptionError(
      activeOptions.values,
      flatOptions,
      baseIndex + tokens.length,
      commandPath,
    );
    if (missingOption != null) return ArgParseFailure(missingOption);

    final bound = _bindPositionals(
      node.positionals,
      positionalTokens,
      baseIndex + tokens.length,
      commandPath,
    );
    if (bound.error case final error?) return ArgParseFailure(error);

    final values = <String, Object?>{};
    for (final entry in flatOptions.entries) {
      _insertNestedValue(values, entry.key.split('.'), entry.value);
    }
    values.addAll(bound.values);

    return ArgParseSuccess(
      ArgArguments._(
        flatOptions: Map.of(flatOptions),
        positionals: bound.values,
        values: values,
        rest: bound.rest,
        commandPath: commandPath,
      ),
    );
  }

  _OptionParseProgress _parseLongOption(
    List<String> tokens,
    int index,
    int baseIndex,
    Map<String, _RegisteredOption> activeOptions,
    Map<String, Object?> flatOptions,
  ) {
    final token = tokens[index];
    final body = token.substring(2);
    final equalsIndex = body.indexOf('=');
    final name = equalsIndex == -1 ? body : body.substring(0, equalsIndex);
    final hasInlineValue = equalsIndex != -1;
    final inlineValue = hasInlineValue ? body.substring(equalsIndex + 1) : null;
    final registered = activeOptions[name];

    if (registered != null) {
      switch (registered.schema) {
        case BooleanOption():
          if (hasInlineValue) {
            return _OptionParseProgress.failure(
              _inputError(
                ArgParseErrorCode.unexpectedValue,
                'Flag "--$name" does not accept a value.',
                token,
                baseIndex + index,
              ),
            );
          }
          flatOptions[name] = true;
          return _OptionParseProgress.success(index + 1);
        case StringOption():
          return _setStringValue(
            registered,
            tokens,
            index,
            baseIndex,
            flatOptions,
            inlineValue,
            hasInlineValue: hasInlineValue,
          );
      }
    }

    if (!hasInlineValue && name.startsWith('no-')) {
      final positiveName = name.substring(3);
      final positive = activeOptions[positiveName];
      if (positive?.schema case BooleanOption(negatable: true)) {
        flatOptions[positiveName] = false;
        return _OptionParseProgress.success(index + 1);
      }
    }

    return _OptionParseProgress.failure(
      _inputError(
        ArgParseErrorCode.unknownOption,
        'Unknown option "$token".',
        token,
        baseIndex + index,
      ),
    );
  }

  _OptionParseProgress _parseShortOptions(
    List<String> tokens,
    int index,
    int baseIndex,
    Map<String, _RegisteredOption> activeAliases,
    Map<String, Object?> flatOptions,
  ) {
    final token = tokens[index];
    final body = token.substring(1);
    var offset = 0;

    while (offset < body.length) {
      final alias = body[offset];
      final registered = activeAliases[alias];
      if (registered == null) {
        return _OptionParseProgress.failure(
          _inputError(
            ArgParseErrorCode.unknownOption,
            'Unknown option "-$alias" in "$token".',
            token,
            baseIndex + index,
          ),
        );
      }

      switch (registered.schema) {
        case BooleanOption():
          flatOptions[registered.name] = true;
          offset++;
        case StringOption():
          final hasAttachedValue = offset + 1 < body.length;
          var attachedValue = body.substring(offset + 1);
          if (attachedValue.startsWith('=')) {
            attachedValue = attachedValue.substring(1);
          }
          return _setStringValue(
            registered,
            tokens,
            index,
            baseIndex,
            flatOptions,
            attachedValue,
            hasInlineValue: hasAttachedValue,
          );
      }
    }

    return _OptionParseProgress.success(index + 1);
  }

  _OptionParseProgress _setStringValue(
    _RegisteredOption registered,
    List<String> tokens,
    int index,
    int baseIndex,
    Map<String, Object?> flatOptions,
    String? inlineValue, {
    required bool hasInlineValue,
  }) {
    final token = tokens[index];
    if (!hasInlineValue && index + 1 >= tokens.length) {
      return _OptionParseProgress.failure(
        _inputError(
          ArgParseErrorCode.missingValue,
          'Option "--${registered.name}" requires a value.',
          token,
          baseIndex + index,
        ),
      );
    }

    final value = hasInlineValue ? inlineValue! : tokens[index + 1];
    final schema = registered.schema as StringOption;
    if (schema.choices case final choices?) {
      if (!choices.contains(value)) {
        return _OptionParseProgress.failure(
          _inputError(
            ArgParseErrorCode.invalidValue,
            'Invalid value "$value" for "--${registered.name}". '
            'Expected one of: ${choices.join(', ')}.',
            token,
            baseIndex + index,
          ),
        );
      }
    }

    flatOptions[registered.name] = value;
    return _OptionParseProgress.success(hasInlineValue ? index + 1 : index + 2);
  }

  static ArgParseError? _getMissingOptionError(
    Iterable<_RegisteredOption> activeOptions,
    Map<String, Object?> flatOptions,
    int index,
    List<String> commandPath,
  ) {
    for (final option in activeOptions) {
      if (option.schema case StringOption(required: true)) {
        if (!flatOptions.containsKey(option.name)) {
          final command = commandPath.isEmpty
              ? 'the root command'
              : '`${commandPath.join(' ')}`';
          return ArgParseError(
            ArgParseErrorCode.missingRequiredOption,
            'Missing required option "--${option.name}" for $command.',
            index: index,
          );
        }
      }
    }
    return null;
  }

  static _BoundPositionals _bindPositionals(
    List<ArgPositional> schemas,
    List<String> tokens,
    int index,
    List<String> commandPath,
  ) {
    final values = <String, Object?>{};
    var tokenIndex = 0;

    for (final schema in schemas) {
      if (schema.multiple) {
        final remaining = tokens.sublist(tokenIndex);
        if (schema.required && remaining.isEmpty) {
          return _BoundPositionals.failure(
            _missingPositionalError(schema.name, index, commandPath),
          );
        }
        if (remaining.isNotEmpty) values[schema.name] = remaining;
        tokenIndex = tokens.length;
        continue;
      }

      if (tokenIndex < tokens.length) {
        values[schema.name] = tokens[tokenIndex];
        tokenIndex++;
      } else if (schema.required) {
        return _BoundPositionals.failure(
          _missingPositionalError(schema.name, index, commandPath),
        );
      }
    }

    return _BoundPositionals.success(values, tokens.sublist(tokenIndex));
  }

  static ArgParseError _missingPositionalError(
    String name,
    int index,
    List<String> commandPath,
  ) {
    final command = commandPath.isEmpty
        ? 'the root command'
        : '`${commandPath.join(' ')}`';
    return ArgParseError(
      ArgParseErrorCode.missingPositional,
      'Missing argument <$name> for $command.',
      index: index,
    );
  }

  static String _missingCommandMessage(
    _SchemaNode node,
    List<String> commandPath,
  ) {
    final parent = commandPath.isEmpty
        ? 'the root command'
        : '`${commandPath.join(' ')}`';
    return 'Missing command for $parent. Expected one of: '
        '${node.commands.keys.join(', ')}.';
  }

  static void _insertNestedValue(
    Map<String, Object?> target,
    List<String> path,
    Object? value,
  ) {
    var current = target;
    for (var index = 0; index < path.length - 1; index++) {
      current =
          current.putIfAbsent(path[index], () => <String, Object?>{})
              as Map<String, Object?>;
    }
    current[path.last] = value;
  }

  static ArgParseError _inputError(
    ArgParseErrorCode code,
    String message,
    String token,
    int index,
  ) => ArgParseError(code, message, token: token, index: index);
}

final class _OptionParseProgress {
  const _OptionParseProgress.success(this.nextIndex) : error = null;

  const _OptionParseProgress.failure(this.error) : nextIndex = -1;

  final int nextIndex;
  final ArgParseError? error;
}

final class _BoundPositionals {
  const _BoundPositionals.success(this.values, this.rest) : error = null;

  const _BoundPositionals.failure(this.error)
    : values = const {},
      rest = const [];

  final Map<String, Object?> values;
  final List<String> rest;
  final ArgParseError? error;
}
