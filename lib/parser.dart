import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

class MambaParseException extends MambaException {
  MambaParseException(super.message);
}

sealed class _AccessorValue<T> {
  const _AccessorValue(this.value);

  final T value;
}

sealed class _AccessorPrimitive<T> extends _AccessorValue<T> {
  const _AccessorPrimitive(super.value);
}

final class AccessorString extends _AccessorPrimitive<String> {
  const AccessorString(super.value);
}

final class AccessorInt extends _AccessorPrimitive<int> {
  const AccessorInt(super.value);
}

final class AccessorDouble extends _AccessorPrimitive<double> {
  const AccessorDouble(super.value);
}

final class AccessorMap
    extends _AccessorValue<Map<String, _AccessorPrimitive>> {
  const AccessorMap(super.value);
}

typedef Inputs = ({
  Map<String, int>? countFlags,
  Map<String, bool>? boolFlags,
  Map<String, String>? options,
  Map<String, _AccessorValue>? accessorMap,
  Map<String, String>? positionals,
  List<String>? variadic,
});

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
