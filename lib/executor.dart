import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';

final class Executor {
  final CommandRegistry _registry;

  final List<String>? _aliases;
  final List<Command>? _commands;

  static final _globalFlags = [
    BooleanFlag(name: "help"),
    CountFlag(name: "verbose"),
  ];

  final List<Flag>? _flags;

  Executor(
    String name,
    String shortDescription, {
    String? longDescription,

    PositionalSchema? positionalSchema,
    Map<String, AccessorInput>? accessorFlagSchema,

    List<Flag>? flags,

    List<Option>? options,

    List<Command>? commands,

    List<String>? aliases,
  }) : _registry = CommandRegistry.create(
         name,
         shortDescription,
         longDescription: longDescription,
         positionalSchema: positionalSchema,
         accessors: accessorFlagSchema,
         flags: [..._globalFlags, ...?flags],
         options: options,
         commands: commands,
         aliases: aliases,
       ),
       _aliases = aliases,
       _flags = [..._globalFlags, ...?flags],
       _commands = commands;

  void execute(List<String> args) {
    final parser = Parser(_registry);
    final (commandPath, inputs) = parser.parse(args);

    late Command command;

    for (final name in commandPath) {
      final children = _commands ?? const <Command>[];

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
