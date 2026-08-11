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
    final (mandatory, discretionary, variadic) = _parseArguments(args);

    if (args.isNotEmpty) {
      final commandContainsArg = args.any((arg) => command.contains(arg));

      var argsIsNotInCommandsAndTHereAreNoPositionals =
          !commandContainsArg && mandatory != null ||
          discretionary != null ||
          variadic != null;

      if (argsIsNotInCommandsAndTHereAreNoPositionals) {
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
        mandatoryPositionals: mandatory,
        discretionaryPositionals: discretionary,
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

  (
    Map<String, String>? mandatory,
    Map<String, String>? discretionary,
    List<String>? variadic,
  )
  _parseArguments(List<String> args) {
    final (
      registeredMandatoryPositionals,
      registeredDiscretionaryPositionals,
      registeredVariadic,
    ) = (
      _registry.mandatoryPositionals,
      _registry.discretionaryPositionals,
      _registry.variadic,
    );

    return (null, null, null);
  }

  Map<String, int>? _parseCountFlags(List<String> args) {
    final registeredCountFlags = _registry.countFlags;
  }

  Map<String, bool>? _parseBooleanFlags(List<String> args) {
    final registeredCountFlags = _registry.boolFlags;
  }
}
