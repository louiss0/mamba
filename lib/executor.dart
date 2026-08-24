import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';

/// The observable result produced by an executor created with [Executor.fake].
sealed class MambaExecutionResult {
  const MambaExecutionResult();
}

/// Captures command output produced by a successful fake execution.
final class MambaSuccessResult extends MambaExecutionResult {
  final String output;
  const MambaSuccessResult(this.output);
}

/// Captures a Mamba exception produced by a failed fake execution.
final class MambaFailureResult extends MambaExecutionResult {
  final MambaException exception;
  const MambaFailureResult(this.exception);
}

/// Executes an argument list and delivers its result through an environment.
abstract interface class MambaExecutor<ReturnType> {
  /// Selects, validates, and runs the command addressed by [args].
  Future<ReturnType> execute(List<String> args);
}

/// Defines a root command surface and creates its execution environment.
///
/// Create one instance at the application's composition root. It owns the root
/// metadata, global inputs, command tree, context, and help formatter used to
/// construct each executor.
final class Executor {
  static final List<Flag> _defaultFlags = [
    BooleanFlag(
      'dry-run',
      description: 'Show what would happen without changing anything.',
    ),
    CountFlag('verbose', short: 'v', description: 'Increase output verbosity.'),
  ];

  final String name;

  final String shortDescription;

  final String? longDescription;

  final List<AccessorListOption>? accessors;

  final List<Flag>? flags;

  final List<Option>? options;

  final List<PairedOption>? pairedOptions;

  final List<String>? defaultSubCommandPath;

  final List<Command>? commands;

  final MambaContext? context;

  final HelpFormatter? helpFormatter;

  Executor(
    this.name,
    this.shortDescription, {
    this.longDescription,
    this.accessors,
    this.flags,
    this.options,
    this.pairedOptions,
    List<String>? defaultSubCommandPath,
    this.commands,
    this.context,
    this.helpFormatter,
  }) : defaultSubCommandPath = _copyDefaultSubCommandPath(
         name,
         defaultSubCommandPath,
       );

  /// Creates an executor for tests that returns success or failure values.
  ///
  /// Call this in one shared test-support file and import the resulting fake
  /// into test files. Unlike [create], it does not write to process streams.
  MambaExecutor<MambaExecutionResult> fake() => _Executor(
    this,
    (output) => MambaSuccessResult(output),
    (exception) => MambaFailureResult(exception),
  );

  /// Creates the production executor that writes output and failures to stdio.
  ///
  /// Call this where the executable is built, then pass command-line arguments
  /// to [MambaExecutor.execute]. Use [fake] rather than this method in tests.
  MambaExecutor<void> create() =>
      _Executor(this, stdout.writeln, stderr.writeln);

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
}

final class _Executor<ReturnType> implements MambaExecutor<ReturnType> {
  final HelpFormatter _helpFormatter;

  final CommandRegistry _registry;

  final MambaContext _context;

  final List<String>? _defaultSubCommandPath;

  final List<Command>? commands;

  final ReturnType Function(dynamic) writeOut;
  final ReturnType Function(dynamic) writeErr;

  _Executor(Executor factory, this.writeOut, this.writeErr)
    : _helpFormatter = factory.helpFormatter ?? MambaHelpFormatter(),
      _context = factory.context ?? MambaContext(),
      _defaultSubCommandPath = factory.defaultSubCommandPath,
      _registry = CommandRegistry.create(
        factory.name,
        factory.shortDescription,
        longDescription: factory.longDescription,
        accessors: factory.accessors,
        flags: [...Executor._defaultFlags, ...?factory.flags],
        options: factory.options,
        pairedOptions: factory.pairedOptions,
        commands: factory.commands,
      ),
      commands = factory.commands;

  @override
  Future<ReturnType> execute(List<String> args) async {
    HookRunner? hookRunner;
    var persistentHookRunners = const Iterable<PersistentHookRunner>.empty();
    MambaReadContext? context;
    ParsedPositionals parsedPositionals = (
      singles: null,
      repeated: null,
      variadic: null,
    );
    ParsedSingleOptions options = (
      stringOptions: null,
      intOptions: null,
      doubleOptions: null,
    );
    try {
      if (_registry.requestsHelp(args)) {
        return writeOut(
          _helpFormatter.format(_registry.registryForArguments(args)),
        );
      }

      final executionArguments = _argumentsWithDefaultCommands(args);
      if (executionArguments.isEmpty) {
        return writeOut(
          _helpFormatter.format(_registry.registryForArguments(args)),
        );
      }

      final (commandPath, positionals, inputs, trailingArguments) = Parser(
        _registry,
      ).parse(executionArguments);

      final commandPathCommands = _commandsForPath(commandPath);
      final command = commandPathCommands.lastOrNull;
      if (command == null) {
        return writeOut(_helpFormatter.format(_registry));
      }

      persistentHookRunners = commandPathCommands
          .whereType<PersistentHookRunner>();
      hookRunner = command is HookRunner ? command : null;
      context = MambaReadContext(_context);
      parsedPositionals = positionals;
      options = (
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
      return writeOut(output);
    } on Exception catch (error) {
      return writeErr(
        error is MambaException ? error : MambaException(error.toString()),
      );
    } finally {
      if (hookRunner != null && context != null) {
        await hookRunner.postRun(context);
      }

      await Future.forEach(
        persistentHookRunners.toList().reversed,
        (persistentHookRunner) => persistentHookRunner.postPersistentRun(
          _context,
          parsedPositionals,
          options,
        ),
      );
    }
  }

  Future<ProcessedStandardInput?> _readStandardInput() async {
    if (stdioType(stdin) != StdioType.pipe) return null;
    return ProcessedStandardInput(
      await stdin.expand((bytes) => bytes).toList(),
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
      children = command is GroupCommand ? command.commands : null;
    }
    return selectedCommands;
  }

  List<String> _argumentsWithDefaultCommands(List<String> args) {
    var arguments = _argumentsWithRootDefaultCommand(args);
    final appliedGroupDefaults = <GroupCommand>{};
    while (true) {
      final insertion = _groupDefaultInsertion(arguments);
      if (insertion == null || !appliedGroupDefaults.add(insertion.group)) {
        break;
      }
      arguments = [
        ...arguments.take(insertion.index),
        ...insertion.path,
        ...arguments.skip(insertion.index),
      ];
    }
    return arguments;
  }

  List<String> _argumentsWithRootDefaultCommand(List<String> args) {
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

  ({GroupCommand group, int index, List<String> path})? _groupDefaultInsertion(
    List<String> args,
  ) {
    var registry = _registry;
    var childCommands = commands;
    GroupCommand? selectedGroup;
    var insertionIndex = 0;
    var offset = 0;

    while (offset < args.length) {
      final token = args[offset];
      if (token == '--') break;
      if (token == _registry.name && identical(registry, _registry)) {
        offset++;
        continue;
      }

      final inputLength = registry.registeredInputTokenLength(token);
      if (inputLength != null) {
        offset += inputLength;
        continue;
      }

      final commandName = registry.aliases?[token] ?? token;
      final command = childCommands
          ?.where((candidate) => candidate.name == commandName)
          .firstOrNull;
      final childRegistry = registry.commandRegistries
          ?.where((candidate) => candidate.name == commandName)
          .firstOrNull;
      if (command == null || childRegistry == null) break;

      registry = childRegistry;
      selectedGroup = command is GroupCommand ? command : null;
      childCommands = selectedGroup?.commands;
      insertionIndex = offset + 1;
      offset++;
    }

    final path = selectedGroup?.defaultSubCommandPath;
    return path == null
        ? null
        : (group: selectedGroup!, index: insertionIndex, path: path);
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
      final inputLength = _registry.registeredInputTokenLength(token);
      if (inputLength != null) {
        offset += inputLength;
        continue;
      }
      if (_isRootCommand(token)) return false;
      return false;
    }
    return true;
  }

  bool _isRootCommand(String name) =>
      _registry.commandRegistries?.any((command) => command.name == name) ==
          true ||
      _registry.aliases?.containsKey(name) == true;
}
