import 'package:arg_parser/errors.dart';
import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';

final class MambaCommandNotFoundException extends MambaException {
  MambaCommandNotFoundException(
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

class _RootCommand extends GroupCommand {
  final _globalFlags = [BooleanFlag(name: "help"), CountFlag(name: "verbose")];

  Command resolve(List<String> path) {
    return _resolveFrom(current: this, path: path, index: 0);
  }

  Command _resolveFrom({
    required Command current,
    required List<String> path,
    required int index,
  }) {
    if (index == path.length) {
      return current;
    }

    final segment = path[index];
    final children = current.commands ?? const <Command>[];

    Command? matchedCommand;

    for (final child in children) {
      if (child.name == segment) {
        matchedCommand = child;
        break;
      }
    }

    if (matchedCommand == null) {
      throw MambaCommandNotFoundException(segment, [
        name,
        ...path.take(index),
      ], children.map((command) => command.name).toList(growable: false));
    }

    return _resolveFrom(current: matchedCommand, path: path, index: index + 1);
  }

  _RootCommand(
    super.name,
    super.shortDescription, {
    required super.defaultSubCommand,
    super.longDescription,
    super.positionalSchema,
    super.accessorFlagSchema,
    super.flags,
    super.singleOptions,
    super.repeatedOptions,
    super.commands,
  });
}

final class Executor {
  final _RootCommand _rootCommand;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,
    List<String>? defaultSubCommand,
    PositionalSchema? positionalSchema,
    Map<String, AccessorInput>? accessorFlagSchema,

    List<Flag>? flags,

    List<SingleOption>? singleOptions,
    List<RepeatableOption>? repeatedOptions,

    List<Command>? commands,
  }) : _rootCommand = _RootCommand(
         name,
         shortDescription,
         longDescription: longDescription,
         defaultSubCommand: defaultSubCommand,
         positionalSchema: positionalSchema,
         accessorFlagSchema: accessorFlagSchema,
         flags: flags,
         singleOptions: singleOptions,
         repeatedOptions: repeatedOptions,
         commands: commands,
       );

  void execute(List<String> args) {
    final parser = Parser(_rootCommand.registry);
    final (commandPath, inputs) = parser.parse(args);

    final command = _rootCommand.resolve(commandPath);

    command.run(inputs);
  }
}
