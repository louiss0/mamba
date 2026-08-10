import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

class MambaParseException extends MambaException {
  MambaParseException(super.message);
}

class Parser {
  final CommandRegistry _registry;

  Parser(this._registry);

  (List<String> command, Inputs inputs) parse(List<String> args) {
    final command = _parseCommand(args);
    final (positionals, variadic) = _parseArguments(args);

    if (args.isNotEmpty) {
      final commandContainsArg = args.any((arg) => command.contains(arg));

      if (!commandContainsArg && positionals != null || variadic != null) {
        throw MambaParseException('');
      }
    }

    final options = _parseOptions(args);
    final countFlags = _parseCountFlags(args);
    final boolFlags = _parseBooleanFlags(args);
    final accessorMap = _parseAccessorMap(args);

    return (
      command,
      (
        positionals: positionals,
        variadic: variadic,
        boolFlags: boolFlags,
        countFlags: countFlags,
        options: options,
        accessorMap: accessorMap,
      ),
    );
  }

  Map<String, AccessorValue>? _parseAccessorMap(List<String> args) {
    return null;
  }

  Map<String, String>? _parseOptions(List<String> args) {
    final registeredOptions = _registry.options;
  }

  List<String> _parseCommand(List<String> args) {
    final registeredSubCommandRegistries = _registry.commandRegistries;

    return [];
  }

  (Map<String, String>? positionals, List<String>? variadic)? _parseArguments(
    List<String> args,
  ) {
    final (registeredPositionals, registeredVariadic) = (
      _registry.positionals,
      _registry.variadic,
    );
  }

  Map<String, int>? _parseCountFlags(List<String> args) {
    final registeredCountFlags = _registry.countFlags;
  }

  Map<String, bool>? _parseBooleanFlags(List<String> args) {
    final registeredCountFlags = _registry.boolFlags;
  }
}
