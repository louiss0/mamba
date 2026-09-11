import 'dart:async';
import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:mamba/src/process.dart';
import 'package:mamba/src/system_process.dart' as system_process;

export 'src/process.dart';

sealed class MambaExecutionResult {
  const MambaExecutionResult();
  int get exitCode;
}

final class MambaSuccessResult extends MambaExecutionResult {
  const MambaSuccessResult(this.output);
  final String? output;
  @override
  int get exitCode => 0;
}

final class MambaFailureResult extends MambaExecutionResult {
  MambaFailureResult({
    required this.exitCode,
    required List<MambaExecutionError> errors,
    this.output,
  }) : errors = List.unmodifiable(errors) {
    if (exitCode == 0)
      throw ArgumentError.value(exitCode, 'exitCode', 'must be non-zero');
    if (errors.isEmpty)
      throw ArgumentError.value(errors, 'errors', 'must not be empty');
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
  MambaExecutionError({
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
  static final List<Flag> _defaultFlags = [
    BooleanFlag(
      'dry-run',
      description: 'Show what would happen without changing anything.',
    ),
    CountFlag('verbose', short: 'v', description: 'Increase output verbosity.'),
    BooleanFlag(
      'version',
      short: 'V',
      description: 'Show the application version.',
    ),
  ];

  Executor(
    this.name,
    this.shortDescription,
    String version,
    List<Command> commands, {
    this.longDescription,
    List<AccessorListOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<SelectedOptionsDefinition>? selectedOptions,
    List<String>? defaultCommandPath,
    this.context,
    this.helpFormatter,
  }) : _version = _validateVersion(version),
       commands = List.unmodifiable(commands),
       accessors = List.unmodifiable(accessors ?? const []),
       flags = List.unmodifiable(flags ?? const []),
       options = List.unmodifiable(options ?? const []),
       selectedOptions = List.unmodifiable(selectedOptions ?? const []),
       defaultCommandPath = defaultCommandPath == null
           ? null
           : List.unmodifiable(defaultCommandPath);
  final String name;
  final String shortDescription;
  final String _version;
  final String? longDescription;
  final List<AccessorListOption> accessors;
  final List<Flag> flags;
  final List<Option> options;
  final List<SelectedOptionsDefinition> selectedOptions;
  final List<String>? defaultCommandPath;
  final List<Command> commands;
  final MambaContext? context;
  final HelpFormatter? helpFormatter;
  static String _validateVersion(String version) {
    if (RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$').hasMatch(version))
      return version;
    throw MambaRegistryError('version must be a Semantic Version 2.0.0 value');
  }

  MambaExecutor<MambaExecutionResult> fake() => _FakeExecutor(_Execution(this));

  /// Creates a process-facing executor.
  ///
  /// When [process] is omitted, it reads and writes the current Dart process.
  /// Supply a [MambaProcess] to redirect input, output, errors, and exit code.
  MambaExecutor<void> create({MambaProcess? process}) {
    final selectedProcess = process ?? system_process.SystemMambaProcess();
    return _CreateExecutor(
      _Execution(this, readStandardInput: selectedProcess.readStandardInput),
      selectedProcess,
    );
  }
}

final class _FakeExecutor implements MambaExecutor<MambaExecutionResult> {
  _FakeExecutor(this.execution);
  final _Execution execution;
  @override
  Future<MambaExecutionResult> execute(List<String> args) =>
      execution.execute(args);
}

final class _CreateExecutor implements MambaExecutor<void> {
  _CreateExecutor(this.execution, this.process);
  final _Execution execution;
  final MambaProcess process;
  @override
  Future<void> execute(List<String> args) async {
    final result = await execution.execute(args);
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
}

final class _Execution {
  _Execution(Executor executor, {this.readStandardInput})
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
        selectedOptions: executor.selectedOptions,
        accessors: executor.accessors,
        commands: executor.commands,
      ),
      _defaultCommandPath = executor.defaultCommandPath == null
          ? null
          : CommandRegistry.create(
              executor.name,
              executor.shortDescription,
              commands: executor.commands,
            ).canonicalCommandPath(executor.defaultCommandPath!) {
    _assignCompletion(commands, _registry.toMap());
  }
  final HelpFormatter _help;
  final Future<ProcessedStandardInput?> Function()? readStandardInput;
  final MambaContext _context;
  final String _version;
  final List<Command> commands;
  final CommandRegistry _registry;
  final List<String>? _defaultCommandPath;
  Future<MambaExecutionResult> execute(List<String> args) async {
    final registry = _registry.registryForArguments(args);
    ParsedArguments parsed;
    try {
      parsed = Parser(_registry).parse(args);
    } on Exception catch (error, trace) {
      return _failure(
        MambaExecutionPhase.parse,
        error,
        trace,
        registry.fullPath,
      );
    }
    final path = args.isEmpty && _defaultCommandPath != null
        ? [_registry.name, ..._defaultCommandPath]
        : parsed.$1;
    final errorPath = args.isEmpty && _defaultCommandPath != null
        ? path
        : registry.fullPath;
    if (parsed.version)
      return MambaSuccessResult(
        parsed.help
            ? '${_registry.name} $_version\n\n${_help.format(registry)}'
            : '${_registry.name} $_version',
      );
    final commandPath = _commandsForPath(path);
    final command = commandPath.lastOrNull;
    if (parsed.help || command == null)
      return MambaSuccessResult(_help.format(registry));
    final invocation = CommandInvocation(parsed.$2);
    final readContext = MambaReadContext(_context);
    final errors = <MambaExecutionError>[];
    final persistent = <PersistentHookRunner>[];
    HookRunner? ordinary;
    for (final candidate in commandPath) {
      if (candidate is PersistentHookRunner) {
        try {
          await candidate.prePersistentRun(invocation, _context);
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
        await command.preRun(invocation, readContext, await _readInput());
        ordinary = command;
      } on Exception catch (error, trace) {
        errors.add(_error(MambaExecutionPhase.preRun, error, trace, errorPath));
      }
    }
    String? output;
    if (errors.isEmpty) {
      try {
        output = await command.run(invocation, parsed.$3);
      } on Exception catch (error, trace) {
        errors.add(_error(MambaExecutionPhase.run, error, trace, errorPath));
      }
    }
    if (ordinary != null) {
      try {
        await ordinary.postRun(invocation, readContext);
      } on Exception catch (error, trace) {
        errors.add(
          _error(MambaExecutionPhase.postRun, error, trace, errorPath),
        );
      }
    }
    for (final hook in persistent.reversed) {
      try {
        await hook.postPersistentRun(invocation, _context);
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
  List<Command> _commandsForPath(List<String> path) {
    var children = commands;
    final selected = <Command>[];
    for (final name in path) {
      if (name == _registry.name) continue;
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

  Future<ProcessedStandardInput?> _readInput() async =>
      readStandardInput?.call();

  void _assignCompletion(Iterable<Command> candidates, RegistryRecord record) {
    for (final command in candidates) {
      if (command is CompletionCommand) command.registryRecord = record;
      if (command is GroupCommand) _assignCompletion(command.commands, record);
    }
  }
}
