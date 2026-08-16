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

  final void Function(String) _writeHelp;

  final List<Command>? commands;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<AccessorOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOption>? pairedOptions,
    List<Command>? commands,
    HelpFormatter? helpFormatter,
    void Function(String)? writeHelp,
  }) : _helpFormatter = helpFormatter ?? HelpFormatter(),
       _writeHelp = writeHelp ?? print,
       _registry = CommandRegistry.create(
         name,
         shortDescription,
         longDescription: longDescription,
         mandatoryPositionals: mandatoryPositionals,
         discretionaryPositionals: discretionaryPositionals,
         variadic: variadic,
         accessors: accessors,
         flags: flags,
         options: options,
         pairedOptions: pairedOptions,
         commands: commands,
       ),
       commands = commands;

  void execute(List<String> args) {
    if (args.isEmpty || _requestsHelp(args)) {
      _writeHelp(_helpFormatter.formatHelp(_registryForArguments(args)));
      return;
    }

    final (commandPath, inputs, variadic) = Parser(_registry).parse(args);
    _commandForPath(commandPath)?.run(inputs, variadic);
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

  bool _requestsHelp(List<String> args) =>
      args.contains('--help') || args.contains('-h');
}
