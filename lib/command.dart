import 'dart:async';

import 'package:arg_parser/context.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

export 'context.dart';

abstract class GroupCommand extends Command {
  GroupCommand(
    super.name,
    super.shortDescription, {
    required super.longDescription,
    required super.mandatoryPositionals,
    required super.discretionaryPositionals,
    required super.variadic,
    required super.flags,
    required super.options,
    required super.pairedOptions,
    required super.accessors,
    required super.commands,
  });

  Future<void> runChildCommand(
    List<String> path,
    Map<String, String>? positionals,
    Inputs input,
    List<String> variadic,
  ) async {
    if (path.isEmpty) {
      throw ArgumentError('path is empty', 'path');
    }

    Command? command;
    var children = commands;
    for (final name in path) {
      command = children
          ?.where((candidate) => candidate.name == name)
          .firstOrNull;
      if (command == null) {
        throw MambaException(
          'command not found in ${this.name} ${path.join(" ")}',
        );
      }
      children = command.commands;
    }

    await command!.run(positionals, input, variadic);
  }

  @override
  FutureOr<void> run(
    Map<String, String>? positionals,
    Inputs input,
    List<String> variadic,
  );
}

mixin HookRunner {
  void preRun(MambaContext context) {}

  FutureOr<void> postRun(MambaReadContext context) {}
}
