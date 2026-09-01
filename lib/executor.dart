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

/// Whether a filesystem failure represents a closed inherited input pipe.
///
/// Operating systems expose this condition through different error codes and
/// message text, so both structural OS codes and known platform messages are
/// accepted.
bool isClosedPipeFileSystemException(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (code == 32 || code == 109 || code == 232) return true;
  final message = '${error.message} ${error.osError?.message ?? ''}'
      .toLowerCase();
  return message.contains('socket is closed') ||
      message.contains('pipe is being closed') ||
      message.contains('broken pipe');
}

/// Post-execution work captured while running a command.
typedef _ExecutionResult = ({
  String? output,
  FutureOr<void> Function()? postRun,
  List<FutureOr<void> Function()> postPersistentRuns,
});

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
    List<Command> commands, {
    this.longDescription,
    List<AccessorListOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<String>? defaultCommandPath,
    this.context,
    this.helpFormatter,
  }) : commands = List.unmodifiable(commands),
       accessors = accessors == null ? null : List.unmodifiable(accessors),
       flags = flags == null ? null : List.unmodifiable(flags),
       options = options == null ? null : List.unmodifiable(options),
       defaultCommandPath = _copyDefaultSubCommandPath(
         name,
         defaultCommandPath,
       );

  /// Creates an executor for tests that returns success or failure values.
  ///
  /// Invalid command definitions throw [MambaRegistryError] during this setup
  /// step; only thrown [Exception] values use the returned result. Other
  /// thrown objects propagate unchanged. Post-hooks are not run. Call this in
  /// one shared test-support file and import the resulting fake into test
  /// files. Unlike [create], it does not write to process streams.
  MambaExecutor<MambaExecutionResult> fake() => _FakeExecutor(_Execution(this));

  /// Creates the production executor that writes output and exceptions to stdio.
  ///
  /// Invalid command definitions throw [MambaRegistryError] during setup.
  /// It runs post-hooks after writing output and reports their thrown
  /// [Exception] values to standard error. Other thrown objects propagate
  /// unchanged. A command may return `null` to suppress successful output.
  /// Call this where the executable is built, then pass command-line arguments
  /// to [MambaExecutor.execute]. Use [fake] rather than this method in tests.
  MambaExecutor<void> create() => _CreateExecutor(_Execution(this));

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

final class _FakeExecutor implements MambaExecutor<MambaExecutionResult> {
  _FakeExecutor(this._execution);

  final _Execution _execution;

  @override
  Future<MambaExecutionResult> execute(List<String> args) async {
    try {
      final result = await _execution.execute(args);
      return MambaSuccessResult(result.output);
    } on Exception catch (exception) {
      return MambaFailureResult(
        exception is MambaException
            ? exception
            : MambaException(exception.toString()),
      );
    }
  }
}

final class _CreateExecutor implements MambaExecutor<void> {
  _CreateExecutor(this._execution);

  final _Execution _execution;

  @override
  Future<void> execute(List<String> args) async {
    late final _ExecutionResult result;
    try {
      result = await _execution.execute(args);
      if (result.output != null) stdout.writeln(result.output);
    } on Exception catch (exception) {
      stderr.writeln(exception);
      exitCode = 1;
      return;
    }

    if (result.postRun case final postRun?) {
      try {
        await postRun();
      } on Exception catch (exception) {
        stderr.writeln(exception);
        exitCode = 1;
      }
    }
    for (final postPersistentRun in result.postPersistentRuns) {
      try {
        await postPersistentRun();
      } on Exception catch (exception) {
        stderr.writeln(exception);
        exitCode = 1;
      }
    }
  }
}

final class _Execution {
  final HelpFormatter _helpFormatter;

  final CommandRegistry _registry;

  final MambaContext _context;

  final List<String>? _defaultSubCommandPath;

  final List<Command>? commands;

  _Execution(Executor factory)
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
      commands = List.unmodifiable(factory.commands) {
    final registryMap = _registry.toMap();
    _assignCompletionRegistryMap(commands, registryMap);
  }

  Future<_ExecutionResult> execute(List<String> args) async {
    final executionArguments = _argumentsWithDefaultCommands(args);
    final parsed = Parser(_registry).parse(executionArguments);
    final commandPath = parsed.$1;
    final positionals = parsed.$2;
    final inputs = parsed.$3;
    final trailingArguments = parsed.$4;
    final commandPathCommands = _commandsForPath(commandPath);
    final command = commandPathCommands.lastOrNull;
    final selectedRegistry = _registry
        .registryForArguments(executionArguments)
        .withInheritedInputs();
    if (parsed.help || command == null) {
      return (
        output: _helpFormatter.format(selectedRegistry),
        postRun: null,
        postPersistentRuns: const <FutureOr<void> Function()>[],
      );
    }

    final context = MambaReadContext(_context);
    final options = (
      stringOptions: inputs.stringOptions,
      intOptions: inputs.intOptions,
      doubleOptions: inputs.doubleOptions,
    );
    final persistentHooks = commandPathCommands
        .whereType<PersistentHookRunner>()
        .toList();
    for (final hook in persistentHooks) {
      await hook.prePersistentRun(_context, positionals, options);
    }
    FutureOr<void> Function()? postRun;
    if (command case final HookRunner hook) {
      final standardInput = await _readStandardInput();
      await hook.preRun(standardInput, context, positionals, options);
      postRun = () => hook.postRun(context);
    }
    final output = await command.run(positionals, inputs, trailingArguments);
    return (
      output: output,
      postRun: postRun,
      postPersistentRuns: [
        for (final hook in persistentHooks.reversed)
          () => hook.postPersistentRun(_context, positionals, options),
      ],
    );
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
    try {
      if (stdioType(stdin) != StdioType.pipe) return null;
      return ProcessedStandardInput(
        await stdin.expand((bytes) => bytes).toList(),
      );
    } on FileSystemException catch (error) {
      // Process.run can expose a closed inherited pipe as stdin.
      if (!isClosedPipeFileSystemException(error)) rethrow;
      return null;
    }
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
    // Help describes the command path the user explicitly named. Defaults are
    // dispatch behavior, not an implicit rewrite of that help target.
    if (_containsHelpFlag(args)) return args;
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

  bool _containsHelpFlag(Iterable<String> args) => args.any(
    (token) =>
        token == '--help' ||
        (token.startsWith('-') &&
            !token.startsWith('--') &&
            token.substring(1).contains('h')),
  );

  bool _isRootCommand(String name) =>
      _registry.commandRegistries?.any((command) => command.name == name) ==
          true ||
      _registry.aliases?.containsKey(name) == true;
}
