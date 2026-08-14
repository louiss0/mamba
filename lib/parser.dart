import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';

class MambaParseException extends MambaException {
  MambaParseException(super.message);
}

class Parser {
  Parser(this._registry);

  final CommandRegistry _registry;

  (List<String> command, Inputs inputs) parse(List<String> args) {
    final command = _findCommand(args);
    final registry = _registryForCommand(command);
    final commandLength = command.length;
    final consumed = <int>{};
    final singleOptions = <String, String>{};
    final repeatedOptions = <String, List<String>>{};
    final boolFlags = <String, bool>{};
    final countFlags = <String, int>{};
    final accessorMap = <String, Object>{};
    final positionals = <String>[];
    for (var index = 0; index < args.length; index++) {
      if (index < commandLength && args[index] == command[index]) {
        continue;
      }
      if (consumed.contains(index)) {
        continue;
      }

      final token = args[index];
      if (token.isEmpty) {
        continue;
      }
      if (token.startsWith('--') && token.length > 2) {
        final name = token.substring(2);
        if (_isAccessor(name, registry)) {
          final values = _parseAccessor(name, args, index, consumed, registry);
          _mergeAccessorValues(accessorMap, values);
          continue;
        }
        if (name.contains('.')) {
          throw MambaParseException("This isn't a registered acessor");
        }
        final option = _findOption(registry, name);
        if (option != null) {
          final value = _takeOptionValue(args, index, consumed, option.name);
          if (option is RepeatableOption) {
            _addRepeatedOptionValue(option, value, repeatedOptions);
          } else {
            singleOptions[option.name] = _parseOptionValue(
              option as SingleOption,
              value,
            );
          }
          continue;
        }
        if (_parseLongFlag(name, registry, boolFlags, countFlags)) {
          continue;
        }
        throw MambaParseException("This isn't a registered flag");
      }
      if (token.startsWith('-') && token.length > 1) {
        _parseShortInputs(
          token.substring(1),
          registry,
          args,
          index,
          consumed,
          singleOptions,
          repeatedOptions,
          boolFlags,
          countFlags,
        );
        continue;
      }
      positionals.add(token);
    }

    _addBooleanDefaults(registry, boolFlags);
    _addChoiceDefaults(registry, singleOptions);
    _addAccessorChoiceDefaults(registry, accessorMap);
    _validateRequiredOptions(registry, singleOptions, repeatedOptions);
    final parsedPositionals = _parsePositionals(registry, positionals);

    final flags = <String, dynamic>{...boolFlags, ...countFlags};
    final options = <String, dynamic>{...singleOptions, ...repeatedOptions};
    final positionalValues = <String, dynamic>{
      ...?parsedPositionals.$1,
      ...?parsedPositionals.$2,
    };

    return (
      command,
      (
        flags: registry.flagSchema?.toRecord(flags),
        options: registry.optionSchema?.toRecord(options),
        positionals: registry.positionalSchema?.toRecord(positionalValues),
        acessors: registry.accessorSchema?.toRecord(accessorMap),
        variadic: parsedPositionals.$3 ?? const [],
      ),
    );
  }

  List<String> _findCommand(List<String> args) {
    final command = <String>[];
    var registry = _registry;
    var offset = 0;
    if (args.isNotEmpty && args.first == registry.name) {
      command.add(registry.name);
      offset = 1;
    }
    while (offset < args.length) {
      final child = registry.commandRegistries
          ?.where((candidate) => candidate.name == args[offset])
          .firstOrNull;
      if (child == null) {
        break;
      }
      command.add(child.name);
      registry = child;
      offset++;
    }
    return command;
  }

  CommandRegistry _registryForCommand(List<String> command) {
    var registry = _registry;
    for (final name in command) {
      if (name == registry.name) {
        continue;
      }
      registry = registry.commandRegistries!.firstWhere(
        (candidate) => candidate.name == name,
      );
    }
    return registry;
  }

  Option? _findOption(CommandRegistry registry, String name) {
    return registry.singleOptions?[name] ??
        registry.repeatedOptions?[name] ??
        registry.singleOptions?.values
            .where((option) => option.short == name)
            .firstOrNull ??
        registry.repeatedOptions?.values
            .where((option) => option.short == name)
            .firstOrNull;
  }

  String _takeOptionValue(
    List<String> args,
    int index,
    Set<int> consumed,
    String name,
  ) {
    if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
      throw MambaParseException('Option --$name requires a value');
    }
    consumed.add(index + 1);
    return args[index + 1];
  }

  bool _parseLongFlag(
    String name,
    CommandRegistry registry,
    Map<String, bool> boolFlags,
    Map<String, int> countFlags,
  ) {
    final negativeName = name.startsWith('no-') ? name.substring(3) : null;
    final boolFlag =
        registry.boolFlags?[name] ??
        (negativeName == null ? null : registry.boolFlags?[negativeName]);
    if (boolFlag != null) {
      if (negativeName != null && !boolFlag.negatable) {
        throw MambaParseException("This isn't a registered flag");
      }
      boolFlags[boolFlag.name] = negativeName == null;
      return true;
    }
    final countFlag = registry.countFlags?[name];
    if (countFlag != null) {
      countFlags.update(
        countFlag.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      return true;
    }
    return false;
  }

  void _parseShortInputs(
    String names,
    CommandRegistry registry,
    List<String> args,
    int index,
    Set<int> consumed,
    Map<String, String> singleOptions,
    Map<String, List<String>> repeatedOptions,
    Map<String, bool> boolFlags,
    Map<String, int> countFlags,
  ) {
    final option = _findOption(registry, names);
    if (option != null) {
      final value = _takeOptionValue(args, index, consumed, option.name);
      if (option is RepeatableOption) {
        _addRepeatedOptionValue(option, value, repeatedOptions);
      } else {
        singleOptions[option.name] = _parseOptionValue(
          option as SingleOption,
          value,
        );
      }
      return;
    }

    var negative = false;
    for (final character in names.split('')) {
      if (character == '-') {
        boolFlags.clear();
        negative = true;
        continue;
      }
      final boolFlag = registry.boolFlags?.values
          .where((flag) => flag.short == character)
          .firstOrNull;
      if (boolFlag != null) {
        if (negative && !boolFlag.negatable) {
          throw MambaParseException(
            "This isn't a registered short flag or option",
          );
        }
        boolFlags[boolFlag.name] = !negative;
        negative = false;
        continue;
      }
      final countFlag = registry.countFlags?.values
          .where((flag) => flag.short == character)
          .firstOrNull;
      if (countFlag != null && !negative) {
        countFlags.update(
          countFlag.name,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        continue;
      }
      throw MambaParseException("This isn't a registered short flag or option");
    }
  }

  String _parseOptionValue(SingleOption option, String value) {
    return switch (option) {
      StringOption(:final regex) => _parseStringOption(regex, value),
      IntOption() => _parseNumberOption(_parseInt, value),
      DoubleOption() => _parseNumberOption(_parseDouble, value),
      ChoiceOption(:final choices) => _parseChoiceOption(
        option.name,
        choices.map((choice) => choice.name),
        value,
      ),
    };
  }

  String _parseNumberOption(Object Function(String) parse, String value) {
    parse(value);
    return value;
  }

  String _parseStringOption(RegExp regex, String value) {
    if (!regex.hasMatch(value)) {
      throw MambaParseException("This value doesn't satify the requirement");
    }
    return value;
  }

  String _parseChoiceOption(
    String name,
    Iterable<String> choices,
    String value,
  ) {
    final names = choices.toList();
    if (!names.contains(value)) {
      throw MambaParseException(
        '$value is not a valid choice for $name\nMust be one of: $names',
      );
    }
    return value;
  }

  void _addRepeatedOptionValue(
    RepeatableOption option,
    String value,
    Map<String, List<String>> options,
  ) {
    final values = options[option.name] ?? [];
    _validateRepeatedValue(option, value, values.length);
    options[option.name] = [...values, value];
  }

  void _validateRepeatedValue(
    RepeatableOption option,
    String value,
    int count,
  ) {
    String? error;
    switch (option) {
      case RepeatableStringOption(:final regex):
        if (!_matchesEntirely(regex, value)) {
          error = 'Invalid input must be a ';
        }
      case RepeatableIntOption():
        if (!_matchesEntirely(RegExp(r'[+-]?\d+'), value)) {
          error = value.trim() != value
              ? "Invalid input must be a int.\nDon't add spaces"
              : 'Invalid input must be a int';
        }
      case RepeatableDoubleOption():
        if (!_matchesEntirely(RegExp(r'[+-]?(?:\d+\.\d+|\d+)'), value)) {
          error = value.trimLeft() != value
              ? "Invalid input must be a  double.\nDon't add spaces"
              : value.trimRight() != value
              ? "Invalid input must be a double.\nDon't add spaces"
              : 'Invalid input must be a double';
        }
    }
    if (error != null) {
      throw MambaParseException('Wrong option at ${count + 1} $error');
    }
  }

  int _parseInt(String value) {
    if (!_matchesEntirely(RegExp(r'[+-]?\d+'), value)) {
      throw MambaParseException(
        'Invalid int value: $value never have spaces in between numbers',
      );
    }
    return int.parse(value);
  }

  double _parseDouble(String value) {
    if (!_matchesEntirely(RegExp(r'[+-]?(?:\d+\.\d+|\d+)'), value)) {
      throw MambaParseException(
        'Invalid int value: $value never have spaces in between numbers',
      );
    }
    return double.parse(value);
  }

  bool _matchesEntirely(RegExp regex, String value) {
    final match = regex.firstMatch(value);
    return match != null && match.start == 0 && match.end == value.length;
  }

  void _addBooleanDefaults(CommandRegistry registry, Map<String, bool> values) {
    for (final flag in registry.boolFlags?.values ?? const <BooleanFlag>[]) {
      values.putIfAbsent(flag.name, () => flag.defaultValue);
    }
  }

  void _addChoiceDefaults(
    CommandRegistry registry,
    Map<String, String> values,
  ) {
    for (final option
        in registry.singleOptions?.values ?? const <SingleOption>[]) {
      if (option is ChoiceOption &&
          option.defaultValue != null &&
          !values.containsKey(option.name)) {
        values[option.name] = option.defaultValue!.name;
      }
    }
  }

  void _addAccessorChoiceDefaults(
    CommandRegistry registry,
    Map<String, Object> values,
  ) {
    for (final entry
        in (registry.accessors ?? const <String, AccessorOption>{}).entries) {
      final defaults = _accessorChoiceDefaults(entry.value);
      if (defaults == null) continue;
      values[entry.key] = _mergeAccessorDefaults(defaults, values[entry.key]);
    }
  }

  Object? _accessorChoiceDefaults(AccessorOption accessor) {
    return switch (accessor) {
      AccessorChoiceOption(defaultValue: final defaultValue?) =>
        defaultValue.name,
      AccessorChoiceOption() => null,
      AccessorPrimitiveOption() => null,
      AccessorListOption(options: final options) => _accessorListChoiceDefaults(
        options,
      ),
    };
  }

  Map<String, Object>? _accessorListChoiceDefaults(
    List<AccessorOption> options,
  ) {
    final defaults = <String, Object>{};
    for (final option in options) {
      final value = _accessorChoiceDefaults(option);
      if (value != null) defaults[option.name] = value;
    }
    return defaults.isEmpty ? null : defaults;
  }

  Object _mergeAccessorDefaults(Object defaults, Object? current) {
    if (defaults is! Map<String, Object> || current is! Map<String, Object>) {
      return current ?? defaults;
    }

    return {
      ...current,
      for (final entry in defaults.entries)
        entry.key: _mergeAccessorDefaults(entry.value, current[entry.key]),
    };
  }

  void _validateRequiredOptions(
    CommandRegistry registry,
    Map<String, String> singleOptions,
    Map<String, List<String>> repeatedOptions,
  ) {
    for (final option in [
      ...?registry.singleOptions?.values,
      ...?registry.repeatedOptions?.values,
    ]) {
      if (option.required &&
          !singleOptions.containsKey(option.name) &&
          !repeatedOptions.containsKey(option.name)) {
        final message = option is StringOption
            ? 'The ${option.name} is required'
            : 'Option --${option.name} is required';
        throw MambaParseException(message);
      }
    }
  }

  (Map<String, String>?, Map<String, String>?, List<String>?) _parsePositionals(
    CommandRegistry registry,
    List<String> values,
  ) {
    final mandatory =
        registry.mandatoryPositionals?.values.toList() ?? const <Positional>[];
    final discretionary =
        registry.discretionaryPositionals?.values.toList() ??
        const <Positional>[];
    final mandatoryValues = <String, String>{};
    final discretionaryValues = <String, String>{};
    var index = 0;

    for (final positional in mandatory) {
      if (index >= values.length ||
          !positional.regex!.hasMatch(values[index])) {
        throw MambaParseException(
          'The ${positional.name} is required at $index after this command',
        );
      }
      mandatoryValues[positional.name] = values[index++];
    }
    for (final positional in discretionary) {
      if (index >= values.length) break;
      if (!positional.regex!.hasMatch(values[index])) {
        throw ArgumentError(
          'Invalid value for positional ${positional.name} at $index after the command',
        );
      }
      discretionaryValues[positional.name] = values[index++];
    }
    final variadic = registry.variadic;
    if (variadic != null) {
      final rest = values.skip(index).toList();
      for (final value in rest) {
        if (!variadic.regex!.hasMatch(value)) {
          throw ArgumentError('Invalid value for variadic ${variadic.name}');
        }
      }
      return (
        mandatoryValues.isEmpty ? null : mandatoryValues,
        discretionaryValues.isEmpty ? null : discretionaryValues,
        rest,
      );
    }
    if (index != values.length) {
      throw MambaParseException(
        "This term isn't a registered command positional or variadic",
      );
    }
    return (
      mandatoryValues.isEmpty ? null : mandatoryValues,
      discretionaryValues.isEmpty ? null : discretionaryValues,
      null,
    );
  }

  bool _isAccessor(String path, CommandRegistry registry) =>
      _accessorForPath(path, registry) != null;

  AccessorPrimitiveOption? _accessorForPath(
    String path,
    CommandRegistry registry,
  ) {
    AccessorOption? accessor = registry.accessors?[path.split('.').first];
    for (final segment in path.split('.').skip(1)) {
      if (accessor is! AccessorListOption) return null;
      accessor = accessor.options
          .where((option) => option.name == segment)
          .firstOrNull;
    }
    return accessor is AccessorPrimitiveOption ? accessor : null;
  }

  Map<String, Object> _parseAccessor(
    String path,
    List<String> args,
    int index,
    Set<int> consumed,
    CommandRegistry registry,
  ) {
    final parts = path.split('.');
    final input = _accessorForPath(path, registry)!;
    final value = _takeOptionValue(args, index, consumed, path);
    final parsed = _parseAccessorValue(input, value);
    var values = <String, Object>{parts.last: parsed};

    for (final segment in parts.reversed.skip(1)) {
      values = {segment: values};
    }
    return values;
  }

  void _mergeAccessorValues(
    Map<String, Object> destination,
    Map<String, Object> values,
  ) {
    for (final entry in values.entries) {
      final value = entry.value;
      final current = destination[entry.key];
      destination[entry.key] = _mergeAccessorValuesAtLevel(current, value);
    }
  }

  Object _mergeAccessorValuesAtLevel(Object? current, Object value) {
    if (current is! Map<String, Object> || value is! Map<String, Object>) {
      return value;
    }

    return {
      ...current,
      for (final entry in value.entries)
        entry.key: _mergeAccessorValuesAtLevel(current[entry.key], entry.value),
    };
  }

  String _parseAccessorValue(AccessorPrimitiveOption option, String value) {
    return switch (option) {
      AccessorStringOption(:final regex) => _parseStringOption(regex, value),
      AccessorIntOption() => _parseNumberOption(_parseInt, value),
      AccessorDoubleOption() => _parseNumberOption(_parseDouble, value),
      AccessorChoiceOption(:final choices) => _parseChoiceOption(
        option.name,
        choices.map((choice) => choice.name),
        value,
      ),
    };
  }
}
