import 'dart:async';
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
  final String? output;
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

  final List<String>? defaultCommandPath;

  final List<Command> commands;

  final MambaContext? context;

  final HelpFormatter? helpFormatter;

  Executor(
    this.name,
    this.shortDescription,
    this.commands, {
    this.longDescription,
    this.accessors,
    this.flags,
    this.options,
    List<String>? defaultCommandPath,
    this.context,
    this.helpFormatter,
  }) : defaultCommandPath = _copyDefaultSubCommandPath(
         name,
         defaultCommandPath,
       );

  /// Creates an executor for tests that returns success or failure values.
  ///
  /// Invalid command definitions throw [MambaRegistryError] during this setup
  /// step; only invocation and execution failures use the returned result.
  /// Call this in one shared test-support file and import the resulting fake
  /// into test files. Unlike [create], it does not write to process streams.
  MambaExecutor<MambaExecutionResult> fake() => _Executor(
    this,
    (output) => MambaSuccessResult(output),
    (exception) => MambaFailureResult(exception),
  );

  /// Creates the production executor that writes output and failures to stdio.
  ///
  /// Invalid command definitions throw [MambaRegistryError] during setup.
  /// A command may return `null` to suppress successful output.
  /// Call this where the executable is built, then pass command-line arguments
  /// to [MambaExecutor.execute]. Use [fake] rather than this method in tests.
  MambaExecutor<void> create() => _Executor(
    this,
    (output) {
      if (output != null) stdout.writeln(output);
    },
    (exception) {
      stderr.writeln(exception);
      exitCode = 1;
    },
  );

  static List<String>? _copyDefaultSubCommandPath(
    String registryName,
    List<String>? path,
  ) {
    if (path == null) return null;
    if (path.isEmpty) {
      throw MambaRegistryError.value(
        path,
        'defaultSubCommandPath',
        'must not be empty',
      );
    }
    if (path.any((name) => name.isEmpty)) {
      throw MambaRegistryError.value(
        path,
        'defaultSubCommandPath',
        'must contain command names',
      );
    }
    if (path.contains(registryName)) {
      throw MambaRegistryError.value(
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
      _defaultSubCommandPath = factory.defaultCommandPath,
      _registry = CommandRegistry.create(
        factory.name,
        factory.shortDescription,
        longDescription: factory.longDescription,
        accessors: factory.accessors,
        flags: [...Executor._defaultFlags, ...?factory.flags],
        options: factory.options,

        commands: factory.commands,
      ),
      commands = factory.commands {
    final registryMap = RegistryMap(_registry.toMap());
    _assignCompletionRegistryMap(commands, registryMap);
  }

  @override
  Future<ReturnType> execute(List<String> args) async {
    final enteredPersistentHooks = <PersistentHookRunner>[];
    HookRunner? enteredHook;
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
    Object? output;
    Exception? primaryException;
    Error? primaryError;
    Object? primaryThrowable;

    try {
      final executionArguments = _argumentsWithDefaultCommands(args);
      switch (Parser(_registry).parse(executionArguments)) {
        case ParsedHelp(:final registry):
          output = _helpFormatter.format(registry);
        case ParsedInvocation(:final value):
          final (commandPath, positionals, inputs, trailingArguments) = value;
          final commandPathCommands = _commandsForPath(commandPath);
          final command = commandPathCommands.lastOrNull;
          if (command == null) {
            output = _helpFormatter.format(
              _registry
                  .registryForArguments(executionArguments)
                  .withInheritedInputs(),
            );
            break;
          }
          context = MambaReadContext(_context);
          parsedPositionals = positionals;
          options = (
            stringOptions: inputs.stringOptions,
            intOptions: inputs.intOptions,
            doubleOptions: inputs.doubleOptions,
          );
          for (final hook
              in commandPathCommands.whereType<PersistentHookRunner>()) {
            await hook.prePersistentRun(_context, positionals, options);
            enteredPersistentHooks.add(hook);
          }
          if (command case final HookRunner hook) {
            final standardInput = await _readStandardInput();
            await hook.preRun(standardInput, context, positionals, options);
            enteredHook = hook;
          }
          output = await command.run(positionals, inputs, trailingArguments);
      }
    } on Error catch (error) {
      primaryError = error;
    } on Exception catch (error) {
      primaryException = error;
    } catch (error) {
      primaryThrowable = error;
    }

    final cleanupExceptions = <Exception>[];
    Error? cleanupError;
    Object? cleanupThrowable;
    Future<void> clean(FutureOr<void> Function() callback) async {
      try {
        await callback();
      } on Error catch (error) {
        cleanupError ??= error;
      } on Exception catch (error) {
        cleanupExceptions.add(error);
      } catch (error) {
        cleanupThrowable ??= error;
      }
    }

    if (enteredHook != null && context != null) {
      await clean(() => enteredHook!.postRun(context!));
    }
    for (final hook in enteredPersistentHooks.reversed) {
      await clean(
        () => hook.postPersistentRun(_context, parsedPositionals, options),
      );
    }

    // Non-Exception failures remain outside the recoverable result boundary,
    // but their primary and cleanup diagnostics must never be discarded.
    if (primaryError != null ||
        primaryThrowable != null ||
        cleanupError != null ||
        cleanupThrowable != null) {
      throw MambaExecutionError(
        primaryFailure: primaryError ?? primaryThrowable ?? primaryException,
        cleanupFailures: [
          ...cleanupExceptions,
          if (cleanupError != null) cleanupError!,
          if (cleanupThrowable != null) cleanupThrowable!,
        ],
      );
    }
    if (cleanupExceptions.isNotEmpty) {
      return writeErr(
        MambaExecutionException(
          primaryFailure: primaryException,
          cleanupFailures: cleanupExceptions,
        ),
      );
    }
    if (primaryException != null) {
      return writeErr(
        primaryException is MambaException
            ? primaryException
            : MambaException(primaryException.toString()),
      );
    }
    return writeOut(output);
  }

  void _assignCompletionRegistryMap(
    Iterable<Command>? candidates,
    RegistryMap registryMap,
  ) {
    if (candidates == null) return;
    for (final command in candidates) {
      if (command is CompletionCommand) command.registryMap = registryMap;
      if (command is GroupCommand) {
        _assignCompletionRegistryMap(command.commands, registryMap);
      }
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
