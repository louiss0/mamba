import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';

class _RootCommand extends GroupCommand {
  final _globalFlags = [BooleanFlag(name: "help"), CountFlag(name: "verbose")];

  _RootCommand(
    super.name,
    super.shortDescription, {
    required super.defaultSubCommand,
    super.longDescription,
    super.positionalSchema,
    super.accessorFlagSchema,
    super.flags,
    super.options,
    super.commands,
  });
}

final class Executor {
  final Command _rootCommand;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,
    List<String>? defaultSubCommand,
    PositionalSchema? positionalSchema,
    Map<String, AccessorInput>? accessorFlagSchema,

    List<Flag>? flags,

    List<Option>? options,

    List<Command>? commands,

    List<String>? aliases,
  }) : _rootCommand = _RootCommand(
         name,
         shortDescription,
         longDescription: longDescription,
         defaultSubCommand: defaultSubCommand,
         positionalSchema: positionalSchema,
         accessorFlagSchema: accessorFlagSchema,
         flags: flags,
         options: options,
         commands: commands,
       );

  void execute(List<String> args) {
    final parser = Parser(_rootCommand.registry);
    final (commandPath, inputs) = parser.parse(args);

    var command = _rootCommand;

    for (final name in commandPath) {
      final children = _rootCommand.commands ?? const <Command>[];

      Command? next;

      for (final child in children) {
        if (child.name == name) {
          next = child;
          break;
        }
      }

      if (next == null) {
        throw StateError(
          'Parsed command "$name" does not exist in runtime command tree',
        );
      }

      command = next;
    }

    command.run(inputs);
  }
}
