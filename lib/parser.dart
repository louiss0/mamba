import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

/// Reports an invocation that does not match a registered command surface.
class MambaParseException extends MambaException {
  MambaParseException(super.message);
}

/// Validates command-line tokens against a [CommandRegistry].
///
/// It accepts command paths, long and short options, bundled flags, negatable
/// boolean flags, dotted accessors, positionals, and trailing arguments after
/// `--`. It returns the selected path and typed input maps without executing a
/// command.
class Parser {
  Parser(this._registry);

  final CommandRegistry _registry;

  /// Parses [args] into a command path, positional map, typed inputs, and
  /// arguments after `--`.
  ///
  /// Throws [MambaParseException] when names, values, required inputs, paired
  /// groups, or positional layout do not satisfy the registry.
  (
    List<String> command,
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  )
  parse(List<String> args) {
    final command = _findCommand(args);
    final commandIndexes = _commandTokenIndexes(args, command);
    final registry = _registryForCommand(command);
    final consumed = <int>{};
    final boolFlags = <String, bool>{};
    final countFlags = <String, int>{};
    final stringOptions = <String, String>{};
    final intOptions = <String, int>{};
    final doubleOptions = <String, double>{};
    final repeatedStringOptions = <String, List<String>>{};
    final repeatedIntOptions = <String, List<int>>{};
    final repeatedDoubleOptions = <String, List<double>>{};
    final accessorValues = <String, dynamic>{};
    final positionalValues = <String>[];
    final trailingArguments = <String>[];

    for (var index = 0; index < args.length; index++) {
      if (commandIndexes.contains(index)) continue;
      if (consumed.contains(index)) continue;

      final token = args[index];
      if (token == '--') {
        trailingArguments.addAll(args.skip(index + 1));
        break;
      }
      if (token.isEmpty) continue;

      if (token.startsWith('--') && token.length > 2) {
        final (name, inlineValue) = _splitLongOption(token.substring(2));
        if (_isAccessor(name, registry)) {
          _mergeAccessorValues(
            accessorValues,
            _parseAccessor(name, inlineValue, args, index, consumed, registry),
          );
          continue;
        }
        if (name.contains('.')) {
          throw MambaParseException("This isn't a registered acessor");
        }

        final option = _findOption(registry, name);
        if (option != null) {
          final value = _takeOptionValue(
            args,
            index,
            consumed,
            option.name,
            inlineValue,
          );
          _addOptionValue(
            option,
            value,
            stringOptions,
            intOptions,
            doubleOptions,
            repeatedStringOptions,
            repeatedIntOptions,
            repeatedDoubleOptions,
          );
          continue;
        }
        if (_parseLongFlag(name, registry, boolFlags, countFlags)) {
          if (inlineValue != null) {
            throw MambaParseException('Flag --$name does not accept a value');
          }
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
          boolFlags,
          countFlags,
          stringOptions,
          intOptions,
          doubleOptions,
          repeatedStringOptions,
          repeatedIntOptions,
          repeatedDoubleOptions,
        );
        continue;
      }
      positionalValues.add(token);
    }

    _addBooleanDefaults(registry, boolFlags);
    _addChoiceDefaults(registry, stringOptions);
    _addAccessorChoiceDefaults(registry, accessorValues);
    _validateRequiredOptions(
      registry,
      stringOptions,
      intOptions,
      doubleOptions,
      repeatedStringOptions,
      repeatedIntOptions,
      repeatedDoubleOptions,
    );
    _validatePairedOptions(
      registry,
      stringOptions,
      intOptions,
      doubleOptions,
      repeatedStringOptions,
      repeatedIntOptions,
      repeatedDoubleOptions,
    );
    final parsedPositionals = _parsePositionals(registry, positionalValues);

    return (
      command,
      parsedPositionals,
      (
        boolFlags: registry.boolFlags == null ? null : boolFlags,
        countFlags: registry.countFlags == null ? null : countFlags,
        stringOptions: _hasStringOptions(registry) ? stringOptions : null,
        intOptions: _hasSingleOptionType<IntOption>(registry)
            ? intOptions
            : null,
        doubleOptions: _hasSingleOptionType<DoubleOption>(registry)
            ? doubleOptions
            : null,
        repeatedStringOptions:
            _hasRepeatedOptionType<RepeatableStringOption>(registry)
            ? repeatedStringOptions
            : null,
        repeatedIntOptions:
            _hasRepeatedOptionType<RepeatableIntOption>(registry)
            ? repeatedIntOptions
            : null,
        repeatedDoubleOptions:
            _hasRepeatedOptionType<RepeatableDoubleOption>(registry)
            ? repeatedDoubleOptions
            : null,
        accessors: accessorValues.isEmpty ? null : accessorValues,
      ),
      trailingArguments,
    );
  }

  bool _hasStringOptions(CommandRegistry registry) {
    final hasSingleOptions =
        registry.singleOptions?.values.any(
          (option) => option is StringOption || option is ChoiceOption,
        ) ??
        false;
    final hasPairedOptions =
        registry.pairedOptions?.values.any(
          (option) =>
              option is PairedStringOption || option is PairedChoiceOption,
        ) ??
        false;
    final hasPairOptions = _registeredPairOptions(
      registry,
    ).any((option) => option is PairStringOption || option is PairChoiceOption);
    return hasSingleOptions || hasPairedOptions || hasPairOptions;
  }

  bool _hasSingleOptionType<T extends SingleOption>(CommandRegistry registry) =>
      registry.singleOptions?.values.any((option) => option is T) == true ||
      (T == IntOption &&
          (registry.pairedOptions?.values.any(
                    (option) => option is PairedIntOption,
                  ) ==
                  true ||
              _registeredPairOptions(
                registry,
              ).any((option) => option is PairIntOption))) ||
      (T == DoubleOption &&
          (registry.pairedOptions?.values.any(
                    (option) => option is PairedDoubleOption,
                  ) ==
                  true ||
              _registeredPairOptions(
                registry,
              ).any((option) => option is PairDoubleOption)));

  bool _hasRepeatedOptionType<T extends RepeatableOption>(
    CommandRegistry registry,
  ) =>
      registry.repeatedOptions?.values.any((option) => option is T) == true ||
      (T == RepeatableStringOption &&
          (registry.pairedOptions?.values.any(
                    (option) => option is RepeatablePairedStringOption,
                  ) ==
                  true ||
              _registeredPairOptions(
                registry,
              ).any((option) => option is RepeatablePairStringOption))) ||
      (T == RepeatableIntOption &&
          (registry.pairedOptions?.values.any(
                    (option) => option is RepeatablePairedIntOption,
                  ) ==
                  true ||
              _registeredPairOptions(
                registry,
              ).any((option) => option is RepeatablePairIntOption))) ||
      (T == RepeatableDoubleOption &&
          (registry.pairedOptions?.values.any(
                    (option) => option is RepeatablePairedDoubleOption,
                  ) ==
                  true ||
              _registeredPairOptions(
                registry,
              ).any((option) => option is RepeatablePairDoubleOption)));

  List<String> _findCommand(List<String> args) {
    final command = <String>[];
    var registry = _registry;
    var offset = 0;
    while (offset < args.length) {
      final token = args[offset];
      if (token == '--') break;
      if (token == registry.name && command.isEmpty) {
        command.add(registry.name);
        offset++;
        continue;
      }

      final commandName = registry.aliases?[token] ?? token;
      final child = registry.commandRegistries
          ?.where((candidate) => candidate.name == commandName)
          .firstOrNull;
      if (child != null) {
        command.add(child.name);
        registry = child;
        offset++;
        continue;
      }
      final inputLength = _registeredInputTokenLength(token, registry);
      if (inputLength != null) {
        offset += inputLength;
        continue;
      }
      break;
    }
    return command;
  }

  Set<int> _commandTokenIndexes(List<String> args, List<String> command) {
    final indexes = <int>{};
    var commandIndex = 0;
    var registry = _registry;
    for (final (index, token) in args.indexed) {
      if (token == '--') break;
      if (commandIndex >= command.length) break;
      final commandName = command[commandIndex];
      final isCommandToken =
          token == commandName || registry.aliases?[token] == commandName;
      if (!isCommandToken) continue;
      indexes.add(index);
      if (!(commandName == registry.name && identical(registry, _registry))) {
        registry = registry.commandRegistries!.firstWhere(
          (candidate) => candidate.name == commandName,
        );
      }
      commandIndex++;
    }
    return indexes;
  }

  int? _registeredInputTokenLength(String token, CommandRegistry registry) {
    if (token.startsWith('--') && token.length > 2) {
      final (name, inlineValue) = _splitLongOption(token.substring(2));
      if (_isAccessor(name, registry) || _findOption(registry, name) != null) {
        return inlineValue == null ? 2 : 1;
      }
    }
    if (token.startsWith('-') && token.length > 1) {
      final names = token.substring(1);
      if (_findOption(registry, names) != null) return 2;
    }
    return registry.isRegisteredFlagToken(token) ? 1 : null;
  }

  CommandRegistry _registryForCommand(List<String> command) {
    var registry = _registry;
    for (final name in command) {
      if (name == registry.name) continue;
      registry = registry.commandRegistries!.firstWhere(
        (candidate) => candidate.name == name,
      );
    }
    return registry;
  }

  NamedInput? _findOption(CommandRegistry registry, String name) {
    final pairOptions = _registeredPairOptions(registry);
    return registry.singleOptions?[name] ??
        registry.repeatedOptions?[name] ??
        registry.pairedOptions?[name] ??
        pairOptions.where((option) => option.name == name).firstOrNull ??
        registry.singleOptions?.values
            .where((option) => option.short == name)
            .firstOrNull ??
        registry.repeatedOptions?.values
            .where((option) => option.short == name)
            .firstOrNull ??
        registry.pairedOptions?.values
            .where((option) => option.short == name)
            .firstOrNull ??
        pairOptions.where((option) => option.short == name).firstOrNull;
  }

  Iterable<PairOption> _registeredPairOptions(CommandRegistry registry) =>
      registry.pairedOptions?.values.expand((option) => option.options) ??
      const <PairOption>[];

  (String, String?) _splitLongOption(String token) {
    final separatorIndex = token.indexOf('=');
    return separatorIndex < 0
        ? (token, null)
        : (
            token.substring(0, separatorIndex),
            token.substring(separatorIndex + 1),
          );
  }

  String _takeOptionValue(
    List<String> args,
    int index,
    Set<int> consumed,
    String name,
    String? inlineValue,
  ) {
    if (inlineValue != null) return inlineValue;
    if (index + 1 >= args.length) {
      throw MambaParseException('Option --$name requires a value');
    }
    final value = args[index + 1];
    if (value.startsWith('-') && !_isNegativeNumber(value)) {
      throw MambaParseException('Option --$name requires a value');
    }
    consumed.add(index + 1);
    return value;
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
    if (countFlag == null) return false;
    countFlags.update(countFlag.name, (count) => count + 1, ifAbsent: () => 1);
    return true;
  }

  void _parseShortInputs(
    String names,
    CommandRegistry registry,
    List<String> args,
    int index,
    Set<int> consumed,
    Map<String, bool> boolFlags,
    Map<String, int> countFlags,
    Map<String, String> stringOptions,
    Map<String, int> intOptions,
    Map<String, double> doubleOptions,
    Map<String, List<String>> repeatedStringOptions,
    Map<String, List<int>> repeatedIntOptions,
    Map<String, List<double>> repeatedDoubleOptions,
  ) {
    final option = _findOption(registry, names);
    if (option != null) {
      _addOptionValue(
        option,
        _takeOptionValue(args, index, consumed, option.name, null),
        stringOptions,
        intOptions,
        doubleOptions,
        repeatedStringOptions,
        repeatedIntOptions,
        repeatedDoubleOptions,
      );
      return;
    }

    for (final character in names.split('')) {
      final boolFlag = registry.boolFlags?.values
          .where((flag) => flag.short == character)
          .firstOrNull;
      if (boolFlag != null) {
        boolFlags[boolFlag.name] = true;
        continue;
      }
      final countFlag = registry.countFlags?.values
          .where((flag) => flag.short == character)
          .firstOrNull;
      if (countFlag != null) {
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

  void _addOptionValue(
    NamedInput option,
    String value,
    Map<String, String> stringOptions,
    Map<String, int> intOptions,
    Map<String, double> doubleOptions,
    Map<String, List<String>> repeatedStringOptions,
    Map<String, List<int>> repeatedIntOptions,
    Map<String, List<double>> repeatedDoubleOptions,
  ) {
    switch (option) {
      case StringOption(:final regex):
        stringOptions[option.name] = _parseStringOption(regex, value);
      case IntOption():
        intOptions[option.name] = _parseInt(value);
      case DoubleOption():
        doubleOptions[option.name] = _parseDouble(value);
      case ChoiceOption(:final choices):
        stringOptions[option.name] = _parseChoiceOption(
          option.name,
          choices.map((choice) => choice.name),
          value,
        );
      case PairedStringOption(:final regex):
        stringOptions[option.name] = _parseStringOption(regex, value);
      case PairedIntOption():
        intOptions[option.name] = _parseInt(value);
      case PairedDoubleOption():
        doubleOptions[option.name] = _parseDouble(value);
      case PairedChoiceOption(:final choices):
        stringOptions[option.name] = _parseChoiceOption(
          option.name,
          choices.map((choice) => choice.name),
          value,
        );
      case PairStringOption(:final regex):
        stringOptions[option.name] = _parseStringOption(regex, value);
      case PairIntOption():
        intOptions[option.name] = _parseInt(value);
      case PairDoubleOption():
        doubleOptions[option.name] = _parseDouble(value);
      case PairChoiceOption(:final choices):
        stringOptions[option.name] = _parseChoiceOption(
          option.name,
          choices.map((choice) => choice.name),
          value,
        );
      case RepeatableStringOption(:final regex):
        _addRepeatedValue(
          option.name,
          _parseStringOption(regex, value),
          repeatedStringOptions,
        );
      case RepeatableIntOption():
        _addRepeatedValue(option.name, _parseInt(value), repeatedIntOptions);
      case RepeatableDoubleOption():
        _addRepeatedValue(
          option.name,
          _parseDouble(value),
          repeatedDoubleOptions,
        );
      case RepeatablePairedStringOption(:final regex):
        _addRepeatedValue(
          option.name,
          _parseStringOption(regex, value),
          repeatedStringOptions,
        );
      case RepeatablePairedIntOption():
        _addRepeatedValue(option.name, _parseInt(value), repeatedIntOptions);
      case RepeatablePairedDoubleOption():
        _addRepeatedValue(
          option.name,
          _parseDouble(value),
          repeatedDoubleOptions,
        );
      case RepeatablePairStringOption(:final regex):
        _addRepeatedValue(
          option.name,
          _parseStringOption(regex, value),
          repeatedStringOptions,
        );
      case RepeatablePairIntOption():
        _addRepeatedValue(option.name, _parseInt(value), repeatedIntOptions);
      case RepeatablePairDoubleOption():
        _addRepeatedValue(
          option.name,
          _parseDouble(value),
          repeatedDoubleOptions,
        );
      // Registry construction prevents non-option inputs from reaching here.
      // coverage:ignore-start
      case _:
        throw StateError('Unsupported named input value');
      // coverage:ignore-end
    }
  }

  void _addRepeatedValue<T>(String name, T value, Map<String, List<T>> values) {
    values.update(name, (items) => [...items, value], ifAbsent: () => [value]);
  }

  String _parseStringOption(RegExp regex, String value) {
    if (!_matchesEntirely(regex, value)) {
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
        'Invalid double value: $value never have spaces in between numbers',
      );
    }
    return double.parse(value);
  }

  bool _matchesEntirely(RegExp regex, String value) {
    final match = regex.firstMatch(value);
    return match != null && match.start == 0 && match.end == value.length;
  }

  bool _isNegativeNumber(String value) =>
      _matchesEntirely(RegExp(r'-(?:\d+\.?\d*|\.\d+)'), value);

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
      if (option case ChoiceOption(defaultValue: final defaultValue?)) {
        values.putIfAbsent(option.name, () => defaultValue.name);
      }
    }
  }

  void _addAccessorChoiceDefaults(
    CommandRegistry registry,
    Map<String, dynamic> values,
  ) {
    for (final entry
        in (registry.accessors ?? const <String, AccessorListOption>{})
            .entries) {
      final defaults = _accessorChoiceDefaults(entry.value);
      if (defaults != null) {
        values[entry.key] = _mergeAccessorDefaults(defaults, values[entry.key]);
      }
    }
  }

  dynamic _accessorChoiceDefaults(AccessorOption accessor) =>
      switch (accessor) {
        AccessorChoiceOption(defaultValue: final defaultValue?) =>
          defaultValue.name,
        AccessorChoiceOption() || AccessorPrimitiveOption() => null,
        AccessorListOption(options: final options) =>
          _accessorListChoiceDefaults(options),
      };

  Map<String, dynamic>? _accessorListChoiceDefaults(
    List<AccessorOption> options,
  ) {
    final defaults = <String, dynamic>{};
    for (final option in options) {
      final value = _accessorChoiceDefaults(option);
      if (value != null) defaults[option.name] = value;
    }
    return defaults.isEmpty ? null : defaults;
  }

  dynamic _mergeAccessorDefaults(dynamic defaults, dynamic current) {
    if (defaults is! Map<String, dynamic> || current is! Map<String, dynamic>) {
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
    Map<String, String> stringOptions,
    Map<String, int> intOptions,
    Map<String, double> doubleOptions,
    Map<String, List<String>> repeatedStringOptions,
    Map<String, List<int>> repeatedIntOptions,
    Map<String, List<double>> repeatedDoubleOptions,
  ) {
    for (final option in [
      ...?registry.singleOptions?.values,
      ...?registry.repeatedOptions?.values,
    ]) {
      if (!option.required) continue;
      final present = switch (option) {
        StringOption() ||
        ChoiceOption() => stringOptions.containsKey(option.name),
        IntOption() => intOptions.containsKey(option.name),
        DoubleOption() => doubleOptions.containsKey(option.name),
        RepeatableStringOption() => repeatedStringOptions.containsKey(
          option.name,
        ),
        RepeatableIntOption() => repeatedIntOptions.containsKey(option.name),
        RepeatableDoubleOption() => repeatedDoubleOptions.containsKey(
          option.name,
        ),
        // Paired options are validated by _validatePairedOptions.
        PairedOption() => false, // coverage:ignore-line
      };
      if (!present) {
        final message = option is StringOption
            ? 'The ${option.name} is required'
            : 'Option --${option.name} is required';
        throw MambaParseException(message);
      }
    }
  }

  void _validatePairedOptions(
    CommandRegistry registry,
    Map<String, String> stringOptions,
    Map<String, int> intOptions,
    Map<String, double> doubleOptions,
    Map<String, List<String>> repeatedStringOptions,
    Map<String, List<int>> repeatedIntOptions,
    Map<String, List<double>> repeatedDoubleOptions,
  ) {
    for (final pairedOption
        in registry.pairedOptions?.values ?? const <PairedOption>[]) {
      final options = <NamedInput>[pairedOption, ...pairedOption.options];
      final provided = options
          .where(
            (option) => _isPairedOptionPresent(
              option,
              stringOptions,
              intOptions,
              doubleOptions,
              repeatedStringOptions,
              repeatedIntOptions,
              repeatedDoubleOptions,
            ),
          )
          .length;
      if (pairedOption.required && provided == 0) {
        throw MambaParseException(
          'Paired option --${pairedOption.name} is required',
        );
      }
      if (pairedOption.variant) {
        if (provided > 1) {
          throw MambaParseException(
            'Variant options ${options.map((option) => '--${option.name}').join(', ')} accept only one option',
          );
        }
        continue;
      }
      if (provided > 0 && provided != options.length) {
        throw MambaParseException(
          'Paired options ${options.map((option) => '--${option.name}').join(', ')} must be passed together',
        );
      }
    }
  }

  bool _isPairedOptionPresent(
    NamedInput option,
    Map<String, String> stringOptions,
    Map<String, int> intOptions,
    Map<String, double> doubleOptions,
    Map<String, List<String>> repeatedStringOptions,
    Map<String, List<int>> repeatedIntOptions,
    Map<String, List<double>> repeatedDoubleOptions,
  ) => switch (option) {
    PairedStringOption() ||
    PairedChoiceOption() ||
    PairStringOption() ||
    PairChoiceOption() => stringOptions.containsKey(option.name),
    PairedIntOption() || PairIntOption() => intOptions.containsKey(option.name),
    PairedDoubleOption() ||
    PairDoubleOption() => doubleOptions.containsKey(option.name),
    RepeatablePairedStringOption() || RepeatablePairStringOption() =>
      repeatedStringOptions.containsKey(option.name),
    RepeatablePairedIntOption() ||
    RepeatablePairIntOption() => repeatedIntOptions.containsKey(option.name),
    RepeatablePairedDoubleOption() || RepeatablePairDoubleOption() =>
      repeatedDoubleOptions.containsKey(option.name),
    // Only paired primary and member options are supplied by callers.
    // coverage:ignore-start
    StringOption() ||
    ChoiceOption() ||
    IntOption() ||
    DoubleOption() ||
    RepeatableStringOption() ||
    RepeatableIntOption() ||
    RepeatableDoubleOption() => false,
    _ => false,
    // coverage:ignore-end
  };

  ParsedPositionals _parsePositionals(
    CommandRegistry registry,
    List<String> values,
  ) {
    final mandatory =
        registry.mandatoryPositionals?.values.toList() ?? const <Positional>[];
    final discretionary =
        registry.discretionaryPositionals?.values.toList() ??
        const <Positional>[];
    final singles = <String, String>{};
    final repeated = <String, List<String>>{};
    var index = 0;

    // Values are consumed strictly in registration order, so a repeated
    // positional greedily takes up to maxCount + 1 values before later
    // positionals
    // are filled.
    void fill(List<Positional> registered, {required bool isMandatory}) {
      for (final positional in registered) {
        final maxCount = switch (positional) {
          RepeatedPositional() => positional.times,
          _ => null,
        };
        // A repeated positional accepts one value per repetition plus the
        // original, so a maxCount of 1 collects up to two values.
        if (maxCount != null) {
          final collected = <String>[];
          while (index < values.length &&
              collected.length <= maxCount &&
              _matchesEntirely(positional.regex, values[index])) {
            collected.add(values[index++]);
          }
          if (collected.isEmpty && isMandatory) {
            throw MambaParseException(
              'The ${positional.name} is required at $index after this command',
            );
          }
          if (collected.isNotEmpty) {
            repeated[positional.name] = collected;
          }
        } else if (index < values.length) {
          if (!_matchesEntirely(positional.regex, values[index])) {
            if (!isMandatory) {
              throw ArgumentError(
                'Invalid value for positional ${positional.name} at $index after the command',
              );
            }
            throw MambaParseException(
              'The ${positional.name} is required at $index after this command',
            );
          }
          singles[positional.name] = values[index++];
        } else if (isMandatory) {
          throw MambaParseException(
            'The ${positional.name} is required at $index after this command',
          );
        }
      }
    }

    fill(mandatory, isMandatory: true);
    fill(discretionary, isMandatory: false);
    if (index != values.length) {
      throw MambaParseException(
        "This term isn't a registered command positional",
      );
    }
    return (
      singles: singles.isEmpty ? null : singles,
      repeated: repeated.isEmpty ? null : repeated,
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

  Map<String, dynamic> _parseAccessor(
    String path,
    String? inlineValue,
    List<String> args,
    int index,
    Set<int> consumed,
    CommandRegistry registry,
  ) {
    final parts = path.split('.');
    final value = _parseAccessorValue(
      _accessorForPath(path, registry)!,
      _takeOptionValue(args, index, consumed, path, inlineValue),
    );
    Map<String, dynamic> values = {parts.last: value};
    for (final segment in parts.reversed.skip(1)) {
      values = {segment: values};
    }
    return values;
  }

  void _mergeAccessorValues(
    Map<String, dynamic> destination,
    Map<String, dynamic> values,
  ) {
    for (final entry in values.entries) {
      destination[entry.key] = _mergeAccessorValuesAtLevel(
        destination[entry.key],
        entry.value,
      );
    }
  }

  dynamic _mergeAccessorValuesAtLevel(dynamic current, dynamic value) {
    if (current is! Map<String, dynamic> || value is! Map<String, dynamic>) {
      return value;
    }
    return {
      ...current,
      for (final entry in value.entries)
        entry.key: _mergeAccessorValuesAtLevel(current[entry.key], entry.value),
    };
  }

  dynamic _parseAccessorValue(AccessorPrimitiveOption option, String value) =>
      switch (option) {
        AccessorStringOption(:final regex) => _parseStringOption(regex, value),
        AccessorIntOption() => _parseInt(value),
        AccessorDoubleOption() => _parseDouble(value),
        AccessorChoiceOption(:final choices) => _parseChoiceOption(
          option.name,
          choices.map((choice) => choice.name),
          value,
        ),
      };
}
