import 'dart:io';

import 'package:arg_parser/command.dart';
import 'package:arg_parser/context.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';

final class _MambaCommandNotFoundException extends MambaException {
  _MambaCommandNotFoundException(
    /// The command segment that could not be resolved.
    String name,

    /// The successfully resolved path before the missing command.
    List<String> parentPath,

    /// Commands that are actually available beneath the parent.
    List<String> availableCommands,
  ) : super(
        "Command $name was not found under ${parentPath.join(' ')}."
        "${availableCommands.isEmpty ? 'This command has no subcommands.' : 'Available commands: ${availableCommands.join(', ')}'}",
      );
}

final class Executor {
  static final List<Flag> _defaultFlags = List.unmodifiable([
    BooleanFlag(
      name: 'dry-run',
      description: 'Show what would happen without changing anything.',
    ),
    CountFlag(
      name: 'verbose',
      short: 'v',
      description: 'Increase output verbosity.',
    ),
  ]);

  final HelpFormatter _helpFormatter;

  final CommandRegistry _registry;

  final MambaContext _context;

  final List<String>? _defaultSubCommandPath;

  final List<Command>? commands;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,
    List<AccessorOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<String>? defaultSubCommandPath,
    List<Command>? commands,
    MambaContext? context,
    HelpFormatter? helpFormatter,
  }) : _helpFormatter = helpFormatter ?? MambaHelpFormatter(),
       _context = context ?? MambaContext(),
       _defaultSubCommandPath = _copyDefaultSubCommandPath(
         name,
         defaultSubCommandPath,
       ),
       _registry = CommandRegistry.create(
         name,
         shortDescription,
         longDescription: longDescription,
         accessors: accessors,
         flags: [..._defaultFlags, ...?flags],
         options: options,
         pairedOptions: pairedOptions,
         commands: commands,
         inheritFlags: true,
       ),
       commands = commands;

  Future<void> execute(List<String> args) async {
    try {
      if (_requestsHelp(args)) {
        stdout.writeln(_helpFormatter.format(_registryForArguments(args)));
        return;
      }

      final executionArguments = _argumentsWithDefaultCommand(args);
      if (executionArguments.isEmpty) {
        stdout.writeln(_helpFormatter.format(_registryForArguments(args)));
        return;
      }

      final (commandPath, positionals, inputs, trailingArguments) = Parser(
        _registry,
      ).parse(executionArguments);
      final commandPathCommands = _commandsForPath(commandPath);
      final command = commandPathCommands.lastOrNull;
      if (command == null) return;

      final persistentHookRunners = commandPathCommands.whereType<HookRunner>();
      final hookRunner = command is HookRunner ? command : null;
      final context = MambaReadContext(_context);
      final options = (
        stringOptions: inputs.stringOptions,
        intOptions: inputs.intOptions,
        doubleOptions: inputs.doubleOptions,
      );
      for (final persistentHookRunner in persistentHookRunners) {
        persistentHookRunner.prePersistentRun(_context, positionals, options);
      }
      if (hookRunner != null) {
        final standardInput = await _readStandardInput();
        hookRunner.preRun(standardInput, context, positionals, options);
      }
      final output = await command.run(positionals, inputs, trailingArguments);
      stdout.writeln(output);
      if (hookRunner != null) {
        await hookRunner.postRun(context);
      }
      for (final persistentHookRunner
          in persistentHookRunners.toList().reversed) {
        await persistentHookRunner.postPersistentRun(
          _context,
          positionals,
          options,
        );
      }
    } catch (error) {
      stderr.writeln(error);
    }
  }

  Future<ProcessedStandardInput?> _readStandardInput() async {
    if (stdioType(stdin) != StdioType.pipe) return null;
    return ProcessedStandardInput(
      await stdin.expand((bytes) => bytes).toList(),
    );
  }

  CommandRegistry _registryForArguments(List<String> args) {
    var registry = _registry;
    var offset = 0;
    while (offset < args.length) {
      final name = args[offset];
      if (name == '--' || _requestsHelp([name])) break;
      if (name == registry.name && identical(registry, _registry)) {
        offset++;
        continue;
      }
      if (_isRegisteredFlagToken(name, registry)) {
        offset++;
        continue;
      }

      final children = registry.commandRegistries ?? const <CommandRegistry>[];
      final command = children
          .where((candidate) => candidate.name == name)
          .firstOrNull;
      if (command == null) {
        throw _MambaCommandNotFoundException(name, [
          registry.name,
        ], children.map((child) => child.name).toList());
      }
      registry = command;
      offset++;
    }
    return registry;
  }

  bool _isRegisteredFlagToken(String token, CommandRegistry registry) {
    if (token.startsWith('--') && token.length > 2) {
      final name = token.substring(2).split('=').first;
      final negativeName = name.startsWith('no-') ? name.substring(3) : null;
      return registry.boolFlags?.containsKey(name) == true ||
          registry.countFlags?.containsKey(name) == true ||
          (negativeName != null &&
              registry.boolFlags?.containsKey(negativeName) == true);
    }
    if (!token.startsWith('-') || token.length <= 1) return false;
    return token
        .substring(1)
        .split('')
        .every(
          (name) =>
              registry.boolFlags?.values.any((flag) => flag.short == name) ==
                  true ||
              registry.countFlags?.values.any((flag) => flag.short == name) ==
                  true,
        );
  }

  List<Command> _commandsForPath(List<String> path) {
    final selectedCommands = <Command>[];
    var children = commands;
    for (final name in path) {
      if (name == _registry.name) continue;
      final command = children?.singleWhere(
        (candidate) => candidate.name == name,
      );
      if (command == null) return const [];
      selectedCommands.add(command);
      children = command.commands;
    }
    return selectedCommands;
  }

  List<String> _argumentsWithDefaultCommand(List<String> args) {
    final path = _defaultSubCommandPath;
    if (path == null || !_needsDefaultCommand(args)) return args;

    final rootIndex = args.indexOf(_registry.name);
    if (rootIndex >= 0) {
      return [
        ...args.take(rootIndex + 1),
        ...path,
        ...args.skip(rootIndex + 1),
      ];
    }
    return [...path, ...args];
  }

  bool _needsDefaultCommand(List<String> args) {
    if (_defaultSubCommandPath == null || args.isEmpty) {
      return _defaultSubCommandPath != null;
    }

    var offset = 0;
    while (offset < args.length) {
      final token = args[offset];
      if (token == '--') return false;
      if (token == _registry.name) {
        offset++;
        continue;
      }
      if (_isRegisteredFlagToken(token, _registry)) {
        offset++;
        continue;
      }
      if (_isRootCommand(token)) return false;
      return false;
    }
    return true;
  }

  bool _isRootCommand(String name) =>
      _registry.commandRegistries?.any((command) => command.name == name) ==
      true;

  static List<String>? _copyDefaultSubCommandPath(
    String registryName,
    List<String>? path,
  ) {
    if (path == null) return null;
    if (path.isEmpty) {
      throw ArgumentError.value(
        path,
        'defaultSubCommandPath',
        'must not be empty',
      );
    }
    if (path.any((name) => name.isEmpty)) {
      throw ArgumentError.value(
        path,
        'defaultSubCommandPath',
        'must contain command names',
      );
    }
    if (path.contains(registryName)) {
      throw ArgumentError.value(
        path,
        'defaultSubCommandPath',
        'must be relative to the executor',
      );
    }
    return List.unmodifiable(path);
  }

  bool _requestsHelp(List<String> args) {
    for (final argument in args) {
      if (argument == '--') return false;
      if (argument == '--help' || argument == '-h') return true;
    }
    return false;
  }
}
