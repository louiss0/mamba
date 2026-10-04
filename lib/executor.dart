import 'dart:async';
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
    // Default paths are declaration errors, not invocation errors.
    if (this.defaultCommandPath != null ||
        this.commands.any(_hasGroupDefault)) {
      _Execution(this);
    }
  }

  static bool _hasGroupDefault(Command command) =>
      command is GroupCommand &&
      (command.defaultSubCommandPath != null ||
          command.commands.any(_hasGroupDefault));
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
  }) => _FakeExecutor(
    _Execution(this, readStandardInput: () async => standardInput),
  );

  /// Creates a process-facing executor.
  ///
  /// Reads and writes the current Dart process.
  MambaExecutor<void> create() {
    final process = system_process.SystemMambaProcess();
    return _CreateExecutor(
      _Execution(this, readStandardInput: process.readStandardInput),
      process,
    );
  }
}

final class _FakeExecutor implements MambaExecutor<MambaExecutionResult> {
  new(this.execution);
  final _Execution execution;
  @override
  Future<MambaExecutionResult> execute(List<String> args) =>
      execution.execute(args);
}

final class _CreateExecutor implements MambaExecutor<void> {
  new(this.execution, this.process);
  final _Execution execution;
  final system_process.SystemMambaProcess process;
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
  new(Executor executor, {this.readStandardInput})
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
      ),
      _defaultCommandPath = executor.defaultCommandPath == null
          ? null
          : CommandRegistry.create(
              executor.name,
              executor.shortDescription,
              commands: executor.commands,
            ).canonicalCommandPath(
              executor.defaultCommandPath!,
              allowGroup: true,
            ) {
    _validateGroupDefaults(commands);
    if (_defaultCommandPath != null) _effectivePath(const []);
    _assignCompletion(commands, _registry.toRecord());
  }
  final HelpFormatter _help;
  final Future<ProcessedStandardInput?> Function()? readStandardInput;
  final MambaContext _context;
  final String _version;
  final List<Command> commands;
  final CommandRegistry _registry;
  final List<String>? _defaultCommandPath;
  Future<MambaExecutionResult> execute(List<String> args) async {
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
        await command.preRun(inputs, readContext, await _readInput());
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
      final length =
          scope.registeredInputTokenLength(token) ??
          _defaultTarget(scope).registeredInputTokenLength(token);
      if (length != null) index += length - 1;
    }
    return false;
  }

  CommandRegistry _defaultTarget(CommandRegistry scope) =>
      _registry.descendant(_effectivePath(_relativePath(scope)));

  /// [scope]'s path as an invocation names it: without the application name.
  static List<String> _relativePath(CommandRegistry scope) =>
      scope.parent == null ? const [] : scope.fullPath.skip(1).toList();

  List<String> _effectivePath(List<String> explicit) {
    final path = [...explicit];
    var followedDefault = false;
    while (true) {
      final selected = _commandsForPath(path).lastOrNull;
      final next = selected is GroupCommand
          ? selected.defaultSubCommandPath
          : selected == null
          ? _defaultCommandPath
          : null;
      if (next == null) {
        if (followedDefault && selected is GroupCommand) {
          throw MambaRegistryError(
            'Default command path must end at an executable command.',
          );
        }
        return path;
      }
      followedDefault = true;
      final parent = _registry.descendant(path);
      final canonical = <String>[];
      var current = parent;
      for (final segment in next) {
        final child = current.commandRegistries
            .where(
              (candidate) =>
                  candidate.name == segment ||
                  candidate.commandAliases?.contains(segment) == true,
            )
            .firstOrNull;
        if (child == null) {
          throw MambaRegistryError(
            'Unknown default command segment $segment under ${current.fullPath.join(' ')}.',
          );
        }
        canonical.add(child.name);
        current = child;
      }
      path.addAll(canonical);
    }
  }

  void _validateGroupDefaults(Iterable<Command> candidates) {
    for (final candidate in candidates) {
      if (candidate is GroupCommand) {
        if (candidate.defaultSubCommandPath != null) {
          _effectivePath(_pathOf(candidate));
        }
        _validateGroupDefaults(candidate.commands);
      }
    }
  }

  List<String> _pathOf(Command target) {
    List<String>? visit(List<Command> children, List<String> prefix) {
      for (final child in children) {
        final path = [...prefix, child.name];
        if (identical(child, target)) return path;
        if (child is GroupCommand) {
          final found = visit(child.commands, path);
          if (found != null) return found;
        }
      }
      return null;
    }

    return visit(commands, const []) ?? const [];
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

  Future<ProcessedStandardInput?> _readInput() async =>
      readStandardInput?.call();

  void _assignCompletion(Iterable<Command> candidates, RegistryRecord record) {
    for (final command in candidates) {
      if (command is CompletionCommand) command.registryRecord = record;
      if (command is GroupCommand) _assignCompletion(command.commands, record);
    }
  }
}
