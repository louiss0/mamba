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
  final HelpFormatter _helpFormatter;

  final CommandRegistry _registry;

  final MambaContext _context;

  final void Function(String) _writeHelp;

  final void Function(Object) _writeOutput;

  final void Function(Object) _writeError;

  final List<Command>? commands;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    List<AccessorOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<Command>? commands,
    MambaContext? context,
    HelpFormatter? helpFormatter,
    void Function(String)? writeHelp,
    void Function(Object)? writeOutput,
    void Function(Object)? writeError,
  }) : _helpFormatter = helpFormatter ?? HelpFormatter(),
       _context = context ?? MambaContext(),
       _writeHelp = writeHelp ?? stdout.writeln,
       _writeOutput = writeOutput ?? stdout.writeln,
       _writeError = writeError ?? stderr.writeln,
       _registry = CommandRegistry.create(
         name,
         shortDescription,
         longDescription: longDescription,
         mandatoryPositionals: mandatoryPositionals,
         discretionaryPositionals: discretionaryPositionals,
         accessors: accessors,
         flags: flags,
         options: options,
         pairedOptions: pairedOptions,
         commands: commands,
       ),
       commands = commands;

  Future<void> execute(List<String> args) async {
    try {
      if (args.isEmpty || _requestsHelp(args)) {
        _writeHelp(_helpFormatter.formatHelp(_registryForArguments(args)));
        return;
      }

      final (commandPath, positionals, inputs, trailingArguments) = Parser(
        _registry,
      ).parse(args);
      final command = _commandForPath(commandPath);
      if (command == null) return;

      final hookRunner = command is HookRunner ? command : null;
      final context = MambaReadContext(_context);
      if (hookRunner != null) {
        final standardInput = stdioType(stdin) == StdioType.pipe
            ? ProcessedStandardInput(
                await stdin.expand((bytes) => bytes).toList(),
              )
            : null;
        hookRunner.preRun(standardInput, context, positionals, (
          stringOptions: inputs.stringOptions,
          intOptions: inputs.intOptions,
          doubleOptions: inputs.doubleOptions,
        ));
      }
      final output = await command.run(positionals, inputs, trailingArguments);
      _writeOutput(output);
      if (hookRunner != null) {
        await hookRunner.postRun(context);
      }
    } catch (error) {
      _writeError(error);
    }
  }

  CommandRegistry _registryForArguments(List<String> args) {
    var registry = _registry;
    var offset = args.firstOrNull == registry.name ? 1 : 0;

    while (offset < args.length && !_requestsHelp([args[offset]])) {
      final name = args[offset];
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

  Command? _commandForPath(List<String> path) {
    Command? command;
    var children = commands;
    for (final name in path) {
      if (name == _registry.name) continue;
      command = children?.singleWhere((candidate) => candidate.name == name);
      children = command?.commands;
    }
    return command;
  }

  bool _requestsHelp(List<String> args) {
    for (final argument in args) {
      if (argument == '--') return false;
      if (argument == '--help' || argument == '-h') return true;
    }
    return false;
  }
}
