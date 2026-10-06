import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:mamba/built_in_flags.dart';
import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:mamba/src/system_process.dart' as system_process;

sealed class MambaExecutionResult {
  const new();
  int get exitCode;
}

final class MambaSuccessResult extends MambaExecutionResult {
  const new(this.output);
  final String? output;
  @override
  int get exitCode => 0;
}

final class MambaFailureResult extends MambaExecutionResult {
  new({
    required this.exitCode,
    required List<MambaExecutionError> errors,
    this.output,
  }) : errors = List.unmodifiable(errors) {
    if (exitCode == 0) {
      throw ArgumentError.value(exitCode, 'exitCode', 'must be non-zero');
    }
    if (errors.isEmpty) {
      throw ArgumentError.value(errors, 'errors', 'must not be empty');
    }
  }
  @override
  final int exitCode;
  final String? output;
  final List<MambaExecutionError> errors;
  String get message => errors.first.exception.message;
}

enum MambaExecutionPhase {
  parse,
  prePersistentRun,
  preRun,
  run,
  postRun,
  postPersistentRun,
}

final class MambaExecutionError {
  new({
    required this.phase,
    required this.exception,
    required this.stackTrace,
    required List<String> commandPath,
  }) : commandPath = List.unmodifiable(commandPath);
  final MambaExecutionPhase phase;
  final MambaException exception;
  final StackTrace stackTrace;
  final List<String> commandPath;
}

bool isClosedPipeFileSystemException(FileSystemException error) =>
    system_process.isClosedPipeFileSystemException(error);

abstract interface class MambaExecutor<T> {
  Future<T> execute(List<String> args);
}

final class Executor {
  static final List<Flag<Object?>> _defaultFlags = [
    MambaBuiltInFlags.verbose,
    MambaBuiltInFlags.version,
  ];

  new(
    this.name,
    this.shortDescription,
    String version,
    List<Command> commands, {
    this.longDescription,
    List<AccessorListOption>? accessors,
    List<Flag<Object?>>? flags,
    List<Option<Object?>>? options,
    List<String>? defaultCommandPath,
    this.context,
    this.helpFormatter,
  }) : _version = _validateVersion(version),
       commands = List.unmodifiable(commands),
       accessors = List.unmodifiable(accessors ?? const []),
       flags = List.unmodifiable(flags ?? const []),
       options = List.unmodifiable(options ?? const []),
       defaultCommandPath = defaultCommandPath == null
           ? null
           : List.unmodifiable(defaultCommandPath) {
    final placements = HashSet<Command>.identity();
    void visit(Iterable<Command> children) {
      for (final command in children) {
        if (!placements.add(command)) {
          throw MambaRegistryError(
            'Command instance ${command.name} occupies more than one path.',
          );
        }
        if (_owners[command] != null) {
          throw MambaRegistryError(
            'Command instance ${command.name} already belongs to a configured Executor.',
          );
        }
        if (command is GroupCommand) visit(command.commands);
      }
    }

    visit(this.commands);
    // Validate everything before claiming any identity or binding metadata.
    _execution = _Execution(this);
    for (final command in placements) {
      _owners[command] = this;
    }
    _execution.bindMetadata();
  }

  static final _owners = Expando<Executor>('configured command owner');
  late final _Execution _execution;
  final String name;
  final String shortDescription;
  final String _version;
  final String? longDescription;
  final List<AccessorListOption> accessors;
  final List<Flag<Object?>> flags;
  final List<Option<Object?>> options;
  final List<String>? defaultCommandPath;
  final List<Command> commands;
  final MambaContext? context;
  final HelpFormatter? helpFormatter;
  static final RegExp _semanticVersion = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );

  static String _validateVersion(String version) {
    final match = _semanticVersion.firstMatch(version);
    if (match != null && match.end == version.length) return version;
    throw MambaRegistryError('version must be a Semantic Version 2.0.0 value');
  }

  /// Creates an executor that returns results without process side effects.
  ///
  /// Supply [standardInput] to test a command that reads piped input in its
  /// [HookRunner.preRun] method.
  MambaExecutor<MambaExecutionResult> fake({
    ProcessedStandardInput? standardInput,
  }) => _FakeExecutor(_execution, () async => standardInput);

  /// Creates a process-facing executor.
  ///
  /// Reads and writes the current Dart process.
  MambaExecutor<void> create() {
    final process = system_process.SystemMambaProcess();
    return _CreateExecutor(_execution, process);
  }
}

final class _FakeExecutor implements MambaExecutor<MambaExecutionResult> {
  new(this.execution, this.readStandardInput);
  final _Execution execution;
  final Future<ProcessedStandardInput?> Function() readStandardInput;
  @override
  Future<MambaExecutionResult> execute(List<String> args) =>
      execution.execute(args, readStandardInput: readStandardInput);
}

final class _CreateExecutor implements MambaExecutor<void> {
  new(this.execution, this.process);
  final _Execution execution;
  final system_process.SystemMambaProcess process;

  // Everything below here runs in the process being created, so a parent VM
  // cannot measure it. `test/system_process_test.dart` runs this path for real
  // and asserts the bytes and the exit code.
  // coverage:ignore-start
  @override
  Future<void> execute(List<String> args) async {
    final result = await execution.execute(
      args,
      readStandardInput: process.readStandardInput,
    );
    switch (result) {
      case MambaSuccessResult(:final output):
        if (output != null) process.writeOutput(output);
      case MambaFailureResult(
        :final output,
        :final errors,
        exitCode: final code,
      ):
        if (output != null) process.writeOutput(output);
        for (final error in errors) {
          process.writeError(error.exception.message);
        }
        process.processExitCode = code;
    }
  }
  // coverage:ignore-end
}

final class _Execution {
  new(Executor executor)
    : _help = executor.helpFormatter ?? MambaHelpFormatter(),
      _context = executor.context ?? MambaContext(),
      _version = executor._version,
      commands = executor.commands,
      _registry = CommandRegistry.create(
        executor.name,
        executor.shortDescription,
        longDescription: executor.longDescription,
        flags: [...Executor._defaultFlags, ...executor.flags],
        options: executor.options,
        accessors: executor.accessors,
        commands: executor.commands,
        defaultCommandPath: executor.defaultCommandPath,
      ) {
    _validateGroupDefaults(_registry);
    _registry.toRecord();
  }
  final HelpFormatter _help;
  void bindMetadata() => _assignCompletion(commands, _registry.toRecord());
  bool _inFlight = false;
  final MambaContext _context;
  final String _version;
  final List<Command> commands;
  final CommandRegistry _registry;
  Future<MambaExecutionResult> execute(
    List<String> args, {
    required Future<ProcessedStandardInput?> Function() readStandardInput,
  }) async {
    if (_inFlight) {
      throw StateError(
        'A configured Executor already has an invocation in flight.',
      );
    }
    _inFlight = true;
    try {
      return await _execute(args, readStandardInput);
    } finally {
      _inFlight = false;
    }
  }

  Future<MambaExecutionResult> _execute(
    List<String> args,
    Future<ProcessedStandardInput?> Function() readStandardInput,
  ) async {
    final CommandResolution explicit;
    try {
      explicit = _registry.resolveCommandPath(
        args,
        defaultTarget: _defaultTarget,
      );
    } on Exception catch (error, trace) {
      return _failure(MambaExecutionPhase.parse, error, trace, [
        _registry.name,
      ]);
    }
    final helpOrVersion = _requestsControlFlag(args, explicit);
    final selectedPath = helpOrVersion
        ? explicit.path
        : _effectivePath(explicit.path);
    final registry = helpOrVersion
        ? explicit.registry
        : _registry.descendant(selectedPath);
    ParsedArguments parsed;
    try {
      parsed = Parser(
        _registry,
      ).parse(args, defaultPath: selectedPath, defaultTarget: _defaultTarget);
    } on Exception catch (error, trace) {
      return _failure(
        MambaExecutionPhase.parse,
        error,
        trace,
        registry.fullPath,
      );
    }
    final path = parsed.$1;
    final errorPath = registry.fullPath;
    if (parsed.version) {
      return MambaSuccessResult(
        parsed.help
            ? '${_registry.name} $_version\n\n${_help.format(registry)}'
            : '${_registry.name} $_version',
      );
    }
    final commandPath = _commandsForPath(path);
    final command = commandPath.lastOrNull;
    if (parsed.help || command == null) {
      final helpRegistry = parsed.help ? explicit.registry : registry;
      return MambaSuccessResult(_help.format(helpRegistry));
    }
    // Only a group can be left without anything to run, so only a group is
    // handed the formatter and the registry it resolved to.
    if (command is GroupCommand) command.help = CommandHelp(_help, registry);
    final inputs = parsed.$2;
    final readContext = MambaReadContext(_context);
    final errors = <MambaExecutionError>[];
    final persistent = <PersistentHookRunner>[];
    HookRunner? ordinary;
    for (final candidate in commandPath) {
      if (candidate is PersistentHookRunner) {
        try {
          await candidate.prePersistentRun(inputs, _context);
          persistent.add(candidate);
        } on Exception catch (error, trace) {
          errors.add(
            _error(
              MambaExecutionPhase.prePersistentRun,
              error,
              trace,
              errorPath,
            ),
          );
          break;
        }
      }
    }
    if (errors.isEmpty && command is HookRunner) {
      try {
        await command.preRun(inputs, readContext, await readStandardInput());
        ordinary = command;
      } on Exception catch (error, trace) {
        errors.add(_error(MambaExecutionPhase.preRun, error, trace, errorPath));
      }
    }
    String? output;
    if (errors.isEmpty) {
      try {
        output = await command.run(inputs, parsed.$3);
      } on Exception catch (error, trace) {
        errors.add(_error(MambaExecutionPhase.run, error, trace, errorPath));
      }
    }
    if (ordinary != null) {
      try {
        await ordinary.postRun(inputs, readContext);
      } on Exception catch (error, trace) {
        errors.add(
          _error(MambaExecutionPhase.postRun, error, trace, errorPath),
        );
      }
    }
    for (final hook in persistent.reversed) {
      try {
        await hook.postPersistentRun(inputs, _context);
      } on Exception catch (error, trace) {
        errors.add(
          _error(
            MambaExecutionPhase.postPersistentRun,
            error,
            trace,
            errorPath,
          ),
        );
      }
    }
    if (errors.isEmpty) return MambaSuccessResult(output);
    return MambaFailureResult(
      exitCode: errors.first.exception.exitCode,
      errors: errors,
      output: output,
    );
  }

  MambaFailureResult _failure(
    MambaExecutionPhase phase,
    Object exception,
    StackTrace trace,
    List<String> path,
  ) {
    final error = _error(phase, exception, trace, path);
    return MambaFailureResult(
      exitCode: error.exception.exitCode,
      errors: [error],
    );
  }

  MambaExecutionError _error(
    MambaExecutionPhase phase,
    Object exception,
    StackTrace trace,
    List<String> path,
  ) => MambaExecutionError(
    phase: phase,
    exception: exception is MambaException
        ? exception
        : MambaException(exception.toString()),
    stackTrace: trace,
    commandPath: path,
  );
  bool _requestsControlFlag(List<String> args, CommandResolution explicit) {
    var scope = _registry;
    for (var index = 0; index < args.length; index++) {
      final token = args[index];
      if (token == '--') break;
      if (explicit.tokenIndices.contains(index)) {
        scope =
            scope.commandRegistries
                .where(
                  (child) =>
                      child.name == token ||
                      child.commandAliases?.contains(token) == true,
                )
                .firstOrNull ??
            scope;
        continue;
      }
      if (MambaBuiltInFlags.isControl(token)) return true;
      final next = index + 1 < args.length ? args[index + 1] : null;
      final length =
          scope.registeredInputTokenLength(token, next: next) ??
          _defaultTarget(scope).registeredInputTokenLength(token, next: next);
      if (length != null) index += length - 1;
    }
    return false;
  }

  CommandRegistry _defaultTarget(CommandRegistry scope) =>
      _registry.descendant(_effectivePath(scope.relativePath));

  List<String> _effectivePath(List<String> explicit) {
    final path = [...explicit];
    var followedDefault = false;
    while (true) {
      final scope = _registry.descendant(path);
      final next = scope.defaultCommandPath;
      if (next == null) {
        if (followedDefault &&
            _commandsForPath(path).lastOrNull is GroupCommand) {
          throw MambaRegistryError(
            'Default command path must end at an executable command.',
          );
        }
        return path;
      }
      followedDefault = true;
      path.addAll(scope.canonicalCommandPath(next, allowGroup: true));
    }
  }

  void _validateGroupDefaults(CommandRegistry scope) {
    if (scope.defaultCommandPath != null) _effectivePath(scope.relativePath);
    for (final child in scope.commandRegistries) {
      _validateGroupDefaults(child);
    }
  }

  List<Command> _commandsForPath(List<String> path) {
    var children = commands;
    final selected = <Command>[];
    for (final name in path) {
      final command = children
          .where(
            (candidate) =>
                candidate.name == name ||
                candidate.aliases?.contains(name) == true,
          )
          .firstOrNull;
      if (command == null) return const [];
      selected.add(command);
      children = command is GroupCommand ? command.commands : const [];
    }
    return selected;
  }

  void _assignCompletion(Iterable<Command> candidates, RegistryRecord record) {
    for (final command in candidates) {
      if (command is CompletionCommand) command.registryRecord = record;
      if (command is GroupCommand) _assignCompletion(command.commands, record);
    }
  }
}
