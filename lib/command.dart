import 'dart:async';

import 'package:arg_parser/context.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

export 'context.dart';

abstract class GroupCommand extends Command {
  GroupCommand({
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
    super.commands,
  });

  @override
  String get name;
  @override
  String get shortDescription;

  Future<String> runChildCommand(
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

    return command!.run(positionals, input, variadic);
  }

  @override
  FutureOr<String> run(
    Map<String, String>? positionals,
    Inputs input,
    List<String> variadic,
  );
}

mixin HookRunner {
  void preRun(MambaContext context) {}

  FutureOr<void> postRun(MambaReadContext context) {}
}
