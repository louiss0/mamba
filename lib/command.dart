import 'dart:async';

import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

abstract class GroupCommand extends Command {
  GroupCommand(
    super.name,
    super.shortDescription, {
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

  FutureOr<void> runChildCommand(
    List<String> path,
    Inputs input,
    List<String> variadic,
  ) async {
    if (path.isEmpty) {
      throw ArgumentError('path is empty', 'path');
    }

    var commands = super.commands;

    final command = path.fold<Command?>(null, (command, word) {
      var output = commands!.firstWhere((c) => c.name == word);
      commands = output.commands;
      return output;
    });

    if (command == null) {
      throw MambaException('command not found in $name ${path.join(" ")}');
    }
    await command.run(input, variadic);
  }

  @override
  FutureOr<String> run(Inputs input, List<String> variadic);
}

class MambaContextKey<T> {}

class MambaContext {
  final Map<MambaContextKey<dynamic>, dynamic> _values = {};

  void set<T>(MambaContextKey<T> key, T value) {
    _values[key] = value;
  }

  T? get<T>(MambaContextKey<T> key) {
    return _values[key] as T?;
  }
}

class MambaReadContext {
  final MambaContext _context;

  MambaReadContext(this._context);

  T? get<T>(MambaContextKey<T> key) {
    return _context.get(key);
  }
}

mixin HookRunner {
  void preRun(MambaContext context) {}

  FutureOr<void> postRun(MambaReadContext context) {}
}
