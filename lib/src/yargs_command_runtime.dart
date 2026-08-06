import 'dart:async';

import 'yargs_parser.dart';

/// A callback invoked after a [YargsCommand] has parsed successfully.
typedef YargsCommandHandler =
    FutureOr<void> Function(YargsCommandArguments arguments);

/// An explicit positional declaration for [YargsCommand].
final class YargsPositional {
  const YargsPositional(
    this.name, {
    this.required = false,
    this.multiple = false,
  });

  final String name;
  final bool required;
  final bool multiple;
}

enum YargsCommandOptionType { boolean, string, number, array, count }

/// A typed option declaration for [YargsCommand].
final class YargsCommandOption {
  const YargsCommandOption.boolean(
    this.name, {
    this.alias,
    this.required = false,
    this.choices,
    this.defaultValue,
    this.description,
    this.narg,
    this.conflicts = const {},
    this.implies = const {},
  }) : type = YargsCommandOptionType.boolean;

  const YargsCommandOption.string(
    this.name, {
    this.alias,
    this.required = false,
    this.choices,
    this.defaultValue,
    this.description,
    this.narg,
    this.conflicts = const {},
    this.implies = const {},
  }) : type = YargsCommandOptionType.string;

  const YargsCommandOption.number(
    this.name, {
    this.alias,
    this.required = false,
    this.choices,
    this.defaultValue,
    this.description,
    this.narg,
    this.conflicts = const {},
    this.implies = const {},
  }) : type = YargsCommandOptionType.number;

  const YargsCommandOption.array(
    this.name, {
    this.alias,
    this.required = false,
    this.choices,
    this.defaultValue,
    this.description,
    this.narg,
    this.conflicts = const {},
    this.implies = const {},
  }) : type = YargsCommandOptionType.array;

  const YargsCommandOption.count(
    this.name, {
    this.alias,
    this.description,
    this.conflicts = const {},
    this.implies = const {},
  }) : required = false,
       choices = null,
       defaultValue = null,
       narg = null,
       type = YargsCommandOptionType.count;

  final String name;
  final String? alias;
  final bool required;
  final Set<Object?>? choices;
  final Object? defaultValue;
  final String? description;
  final int? narg;
  final Set<String> conflicts;
  final Set<String> implies;
  final YargsCommandOptionType type;
}

/// A dependency-free command declaration backed by [YargsParser].
final class YargsCommand {
  YargsCommand(
    this.name, {
    this.description,
    this.aliases = const [],
    this.options = const [],
    this.positionals = const [],
    this.commands = const [],
    this.handler,
  });

  final String name;
  final String? description;
  final List<String> aliases;
  final List<YargsCommandOption> options;
  final List<YargsPositional> positionals;
  final List<YargsCommand> commands;
  final YargsCommandHandler? handler;
}

/// The named values passed to the selected command's handler.
final class YargsCommandArguments {
  YargsCommandArguments._(this.commandPath, this.values, this._positionals);

  final List<String> commandPath;
  final Map<String, Object?> values;
  final Map<String, Object?> _positionals;

  Object? operator [](String name) => values[name];

  bool? flag(String name) => values[name] is bool ? values[name] as bool : null;

  String? positional(String name) {
    final value = _positionals[name];
    return value is String ? value : null;
  }

  List<String>? positionals(String name) {
    final value = _positionals[name];
    return value is List<String> ? value : null;
  }
}

/// The result of selecting, parsing, and optionally handling a command.
sealed class YargsCommandOutcome {
  const YargsCommandOutcome();

  bool get isSuccess => this is YargsCommandSuccess;
}

/// A selected command and its parsed values.
final class YargsCommandSuccess extends YargsCommandOutcome {
  const YargsCommandSuccess(this.arguments);

  final YargsCommandArguments arguments;
}

/// A command-line error returned without throwing.
final class YargsCommandFailure extends YargsCommandOutcome {
  const YargsCommandFailure(this.message);

  final String message;
}

/// A small command runtime layered over the token-level [YargsParser].
///
/// Commands use explicit Dart declarations rather than Yargs's command-string
/// DSL. Root and ancestor options remain active while a nested command is
/// selected, matching the useful global-option behavior of Yargs.
final class YargsCommandRuntime {
  YargsCommandRuntime({
    List<YargsCommandOption> options = const [],
    List<YargsCommand> commands = const [],
  }) : options = List.unmodifiable(options),
       commands = List.unmodifiable(commands) {
    _validateCommands(this.commands);
  }

  final List<YargsCommandOption> options;
  final List<YargsCommand> commands;

  static void _validateCommands(List<YargsCommand> commands) {
    final names = <String>{};
    for (final command in commands) {
      if (command.name.isEmpty || !names.add(command.name)) {
        throw ArgumentError.value(
          command.name,
          'commands',
          'Command names must be unique.',
        );
      }
      for (final alias in command.aliases) {
        if (alias.isEmpty || !names.add(alias)) {
          throw ArgumentError.value(
            alias,
            'commands',
            'Command aliases must be unique.',
          );
        }
      }
      if (command.commands.isNotEmpty && command.positionals.isNotEmpty) {
        throw ArgumentError.value(
          command.name,
          'commands',
          'A command cannot declare both subcommands and positionals.',
        );
      }
      var optionalFound = false;
      for (var index = 0; index < command.positionals.length; index++) {
        final positional = command.positionals[index];
        if (positional.name.isEmpty) {
          throw ArgumentError.value(
            positional.name,
            'positionals',
            'Names cannot be empty.',
          );
        }
        if (positional.multiple && index != command.positionals.length - 1) {
          throw ArgumentError.value(
            positional.name,
            'positionals',
            'A variadic positional must be last.',
          );
        }
        if (optionalFound && positional.required) {
          throw ArgumentError.value(
            positional.name,
            'positionals',
            'A required positional cannot follow an optional positional.',
          );
        }
        if (!positional.required) optionalFound = true;
      }
      _validateCommands(command.commands);
    }
  }

  /// Renders concise help from explicit command and option declarations.
  String help([List<String> path = const []]) {
    final resolved = _resolvePath(path);
    if (resolved == null) return 'Unknown command path: ${path.join(' ')}.';

    final lines = <String>[
      'Usage: ${path.isEmpty ? '<command>' : path.join(' ')} [options]',
    ];
    if (resolved.description case final description?) {
      lines
        ..add('')
        ..add(description);
    }
    if (resolved.commands.isNotEmpty) {
      lines
        ..add('')
        ..add('Commands:');
      for (final command in resolved.commands) {
        final aliases = command.aliases.isEmpty
            ? ''
            : ' (${command.aliases.join(', ')})';
        lines.add(
          '  ${command.name}$aliases${_descriptionSuffix(command.description)}',
        );
      }
    }
    final activeOptions = _optionsForPath(path);
    if (activeOptions.isNotEmpty) {
      lines
        ..add('')
        ..add('Options:');
      for (final option in activeOptions) {
        final alias = option.alias == null ? '' : ', -${option.alias}';
        lines.add(
          '  --${option.name}$alias${_descriptionSuffix(option.description)}',
        );
      }
    }
    return lines.join('\n');
  }

  /// Returns command or option names matching the final completion token.
  List<String> completionCandidates(List<String> tokens) {
    final prefix = tokens.isEmpty ? '' : tokens.last;
    final pathTokens = tokens.isEmpty
        ? const <String>[]
        : tokens.sublist(0, tokens.length - 1);
    final resolved = _resolvePath(pathTokens);
    if (resolved == null) return const [];

    if (prefix.startsWith('-')) {
      return [
        for (final option in _optionsForPath(pathTokens)) ...[
          '--${option.name}',
          if (option.alias != null) '-${option.alias}',
        ],
      ].where((candidate) => candidate.startsWith(prefix)).toList();
    }
    return resolved.commands
        .where((command) => command.name.startsWith(prefix))
        .map((command) => command.name)
        .toList();
  }

  Future<YargsCommandOutcome> run(List<String> tokens) async {
    var offset = 0;
    var activeCommands = commands;
    var activeOptions = List<YargsCommandOption>.of(options);
    final commandPath = <String>[];
    final commandTokens = <String>[];
    YargsCommand? selected;

    while (activeCommands.isNotEmpty) {
      while (offset < tokens.length) {
        final nextOffset = _nextAfterKnownOption(tokens, offset, activeOptions);
        if (nextOffset == null) break;
        offset = nextOffset;
      }
      if (offset == tokens.length) {
        return const YargsCommandFailure('A command is required.');
      }
      selected = _findCommand(activeCommands, tokens[offset]);
      if (selected == null) {
        return YargsCommandFailure('Unknown command "${tokens[offset]}".');
      }
      commandPath.add(selected.name);
      commandTokens.add(tokens[offset]);
      activeCommands = selected.commands;
      activeOptions = [...activeOptions, ...selected.options];
      offset++;
    }

    if (selected == null) {
      return const YargsCommandFailure('A command is required.');
    }

    final parsed = const YargsParser().detailed(
      tokens,
      _parserOptions(activeOptions),
    );
    if (parsed.error != null) {
      return const YargsCommandFailure('Could not parse command options.');
    }

    final parsedPositionals = parsed.argv['_'];
    if (parsedPositionals is! List ||
        parsedPositionals.any((value) => value is! String)) {
      return const YargsCommandFailure('Command positionals must be text.');
    }
    final positionalTokens = List<String>.of(parsedPositionals.cast<String>());
    for (final commandToken in commandTokens) {
      final commandIndex = positionalTokens.indexOf(commandToken);
      if (commandIndex == -1) {
        return const YargsCommandFailure(
          'Could not locate a selected command.',
        );
      }
      positionalTokens.removeAt(commandIndex);
    }
    final unknownOption = positionalTokens.where(
      (token) => token.startsWith('-'),
    );
    if (unknownOption.isNotEmpty) {
      return YargsCommandFailure('Unknown option "${unknownOption.first}".');
    }

    final positionalValues = <String, Object?>{};
    var tokenIndex = 0;
    for (final positional in selected.positionals) {
      if (positional.multiple) {
        final remaining = positionalTokens.sublist(tokenIndex);
        if (positional.required && remaining.isEmpty) {
          return YargsCommandFailure(
            'Missing required argument <${positional.name}>.',
          );
        }
        if (remaining.isNotEmpty) positionalValues[positional.name] = remaining;
        tokenIndex = positionalTokens.length;
        break;
      }
      if (tokenIndex == positionalTokens.length) {
        if (positional.required) {
          return YargsCommandFailure(
            'Missing required argument <${positional.name}>.',
          );
        }
        continue;
      }
      positionalValues[positional.name] = positionalTokens[tokenIndex];
      tokenIndex++;
    }
    if (tokenIndex < positionalTokens.length) {
      return const YargsCommandFailure('Too many positional arguments.');
    }

    final values = Map<String, Object?>.of(parsed.argv)..remove('_');
    final optionError = _validateOptions(activeOptions, values);
    if (optionError != null) return YargsCommandFailure(optionError);
    values.addAll(positionalValues);
    final arguments = YargsCommandArguments._(
      List.unmodifiable(commandPath),
      Map.unmodifiable(values),
      Map.unmodifiable(positionalValues),
    );
    try {
      await selected.handler?.call(arguments);
    } catch (error) {
      return YargsCommandFailure('Command "${selected.name}" failed: $error');
    }
    return YargsCommandSuccess(arguments);
  }

  YargsCommand? _resolvePath(List<String> path) {
    var scope = YargsCommand('', commands: commands);
    for (final token in path) {
      final selected = _findCommand(scope.commands, token);
      if (selected == null) return null;
      scope = selected;
    }
    return scope;
  }

  List<YargsCommandOption> _optionsForPath(List<String> path) {
    var scope = YargsCommand('', commands: commands);
    final activeOptions = List<YargsCommandOption>.of(options);
    for (final token in path) {
      final selected = _findCommand(scope.commands, token);
      if (selected == null) return const [];
      activeOptions.addAll(selected.options);
      scope = selected;
    }
    return activeOptions;
  }

  static String _descriptionSuffix(String? description) =>
      description == null ? '' : '  $description';

  static int? _nextAfterKnownOption(
    List<String> tokens,
    int index,
    List<YargsCommandOption> options,
  ) {
    final token = tokens[index];
    if (!token.startsWith('-') || token == '-') return null;

    final name = token.startsWith('--')
        ? token.substring(2).split('=').first
        : token.substring(1);
    final option = options.where(
      (option) => option.name == name || option.alias == name,
    );
    if (option.isEmpty) return null;

    if (token.contains('=')) return index + 1;
    final selected = option.single;
    if (selected.type != YargsCommandOptionType.boolean &&
        selected.type != YargsCommandOptionType.count) {
      return index + 1 + (selected.narg ?? 1);
    }
    final next = index + 1 < tokens.length ? tokens[index + 1] : null;
    return next == 'true' || next == 'false' ? index + 2 : index + 1;
  }

  static String? _validateOptions(
    List<YargsCommandOption> options,
    Map<String, Object?> values,
  ) {
    for (final option in options) {
      final value = values[option.name];
      if (option.required && !values.containsKey(option.name)) {
        return 'Missing required option --${option.name}.';
      }
      if (option.choices != null &&
          value != null &&
          !option.choices!.contains(value)) {
        return 'Invalid value "$value" for --${option.name}. '
            'Expected one of: ${option.choices!.join(', ')}.';
      }
      if (!values.containsKey(option.name)) continue;
      for (final conflict in option.conflicts) {
        if (values.containsKey(conflict)) {
          return '--${option.name} cannot be used with --$conflict.';
        }
      }
      for (final implied in option.implies) {
        if (!values.containsKey(implied)) {
          return '--${option.name} requires --$implied.';
        }
      }
    }
    return null;
  }

  static YargsCommand? _findCommand(List<YargsCommand> commands, String token) {
    for (final command in commands) {
      if (command.name == token || command.aliases.contains(token)) {
        return command;
      }
    }
    return null;
  }

  static YargsParserOptions _parserOptions(List<YargsCommandOption> options) {
    return YargsParserOptions(
      boolean: options
          .where((option) => option.type == YargsCommandOptionType.boolean)
          .map((option) => option.name),
      string: options
          .where((option) => option.type == YargsCommandOptionType.string)
          .map((option) => option.name),
      number: options
          .where((option) => option.type == YargsCommandOptionType.number)
          .map((option) => option.name),
      array: options
          .where((option) => option.type == YargsCommandOptionType.array)
          .map((option) => YargsParserArrayOption(option.name)),
      count: options
          .where((option) => option.type == YargsCommandOptionType.count)
          .map((option) => option.name),
      narg: {
        for (final option in options)
          if (option.narg != null) option.name: option.narg!,
      },
      defaultValues: {
        for (final option in options)
          if (option.defaultValue != null) option.name: option.defaultValue,
      },
      alias: {
        for (final option in options)
          if (option.alias != null) option.name: [option.alias!],
      },
      configuration: const YargsParserConfiguration(
        parsePositionalNumbers: false,
        unknownOptionsAsArgs: true,
      ),
    );
  }
}
