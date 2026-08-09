import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

class MambaParseException extends MambaException {
  MambaParseException(super.message);
}

class Parser {
  final CommandRegistry _registry;

  Parser(this._registry);

  (List<String> command, Inputs? inputs) parse(List<String> args) {
    return (
      [],
      (
        variadic: null,
        accessorMap: null,
        boolFlags: null,
        countFlags: null,
        options: null,
        positionals: null,
      ),
    );
  }
}
