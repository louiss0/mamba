import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

class MambaParseException extends MambaException {
  MambaParseException(super.message, {super.exitCode});
}

typedef ParsedArguments = (
  List<String> command,
  ParsedInputs inputs,
  List<String> args, {
  bool help,
  bool version,
});

/// Parses one command line into identity-keyed typed input values.
final class Parser {
  Parser(this._registry);
  final CommandRegistry _registry;

  ParsedArguments parse(List<String> tokens) {
    final resolution = _registry.resolveCommandPath(tokens);
    final commandPath = resolution.path;
    final registry = resolution.registry;
    final values = <InputDefinition, Object?>{};
    final positionals = <String>[];
    final trailing = <String>[];
    var help = false;
    var version = false;
    final consumed = <int>{};
    final optionInputs = [
      ...registry.applicableOptions,
      for (final group in registry.pairedOptionGroups) ...group.options,
      for (final group in registry.selectedOptionGroups)
        for (final selectable in group.options) selectable.option,
    ];
    for (var index = 0; index < tokens.length; index++) {
      if (consumed.contains(index) || resolution.tokenIndices.contains(index))
        continue;
      final token = tokens[index];
      if (token == '--') {
        trailing.addAll(tokens.skip(index + 1));
        break;
      }
      if (help || version) continue;
      if (token == '--help' || token == '-h') {
        help = true;
        continue;
      }
      if (token == '--version') {
        version = true;
        continue;
      }
      if (token.startsWith('--') && token.length > 2) {
        final (name, inline) = _split(token.substring(2));
        final accessor = _accessorFor(name, registry.accessors);
        if (accessor != null) {
          values[accessor] = _parseValue(
            accessor,
            _takeValue(tokens, index, consumed, name, inline, accessor),
          );
          continue;
        }
        final input = optionInputs
            .where((item) => item.name == name)
            .firstOrNull;
        if (input != null) {
          _put(
            values,
            input,
            _parseValue(
              input,
              _takeValue(tokens, index, consumed, name, inline, input),
            ),
          );
          continue;
        }
        final flag = registry.applicableFlags
            .where(
              (item) =>
                  item.name == name ||
                  (item is BooleanFlag &&
                      item.negatable &&
                      name == 'no-${item.name}'),
            )
            .firstOrNull;
        if (flag == null)
          throw MambaParseException('Unknown flag or option --$name.');
        if (inline != null)
          throw MambaParseException('Flag --$name does not accept a value');
        if (flag is BooleanFlag)
          values[flag] = !name.startsWith('no-');
        else if (flag is CountFlag)
          values[flag] = ((values[flag] as int?) ?? 0) + 1;
        continue;
      }
      if (token.startsWith('-') && token.length > 1) {
        final short = token.substring(1);
        final input = optionInputs
            .where((item) => _shortOf(item) == short)
            .firstOrNull;
        if (input != null) {
          _put(
            values,
            input,
            _parseValue(
              input,
              _takeValue(tokens, index, consumed, input.name, null, input),
            ),
          );
          continue;
        }
        for (final letter in short.split('')) {
          if (letter == 'h') {
            help = true;
            continue;
          }
          final flag = registry.applicableFlags
              .where((item) => item.short == letter)
              .firstOrNull;
          if (flag == null)
            throw MambaParseException(
              "This isn't a registered short flag or option",
            );
          if (flag is BooleanFlag) values[flag] = true;
          if (flag is CountFlag)
            values[flag] = ((values[flag] as int?) ?? 0) + 1;
        }
        continue;
      }
      positionals.add(token);
    }
    if (!help && !version) {
      _addDefaults(registry, values);
      _validateRequired(registry, values);
      _validateGroups(registry, values);
      _parsePositionals(registry, positionals, values);
      _validateVariadic(registry.variadic, trailing);
    }
    for (final flag in registry.applicableFlags) {
      if (flag is BooleanFlag && flag.name != 'help')
        values.putIfAbsent(flag, () => flag.defaultValue);
      if (flag is CountFlag) values.putIfAbsent(flag, () => 0);
    }
    return (
      commandPath,
      ParsedInputs(values, _knownInputs(registry)),
      List.unmodifiable(trailing),
      help: help,
      version: version,
    );
  }

  (String, String?) _split(String token) {
    final index = token.indexOf('=');
    return index < 0
        ? (token, null)
        : (token.substring(0, index), token.substring(index + 1));
  }

  String _takeValue(
    List<String> tokens,
    int index,
    Set<int> consumed,
    String name,
    String? inline,
    InputDefinition input,
  ) {
    if (inline != null) return inline;
    if (index + 1 >= tokens.length)
      throw MambaParseException('Option --$name requires a value');
    final value = tokens[index + 1];
    if (value == '--' || (value.startsWith('-') && !_allowsDash(input, value)))
      throw MambaParseException('Option --$name requires a value');
    consumed.add(index + 1);
    return value;
  }

  bool _allowsDash(InputDefinition input, String value) =>
      input is RegExpValidated &&
      _matches((input as RegExpValidated).regex, value);
  void _put(
    Map<InputDefinition, Object?> values,
    InputDefinition input,
    Object value,
  ) {
    switch (input) {
      case RepeatableOptionDefinition():
        final existing = values[input] as List?;
        if (input.unique && existing?.contains(value) == true) {
          throw MambaParseException(
            'Option --${input.name} accepts each choice once; ${(value as Enum).name} was provided more than once.',
          );
        }
        values[input] = input.appendValue(value, existing);
      case RepeatablePairStringOption() ||
          RepeatablePairIntOption() ||
          RepeatablePairDoubleOption():
        values[input] = List.unmodifiable([...?values[input] as List?, value]);
      default:
        if (input is PairOption && values.containsKey(input)) {
          throw MambaParseException(
            'Selected option --${input.name} was provided more than once.',
          );
        }
        values[input] = value;
    }
  }

  Object _parseValue(InputDefinition input, String value) => switch (input) {
    RegExpValidated()
        when input is! AccessorIntOption && input is! AccessorDoubleOption =>
      _regex(input as RegExpValidated, value),
    NumericRangeValidated<int>() ||
    AccessorIntOption() => _integer(input, value),
    NumericRangeValidated<double>() ||
    AccessorDoubleOption() => _double(input, value),
    ChoiceValidated() => _choice(input as ChoiceValidated, value),
    _ => throw StateError('Unsupported input ${input.name}'),
  };
  String _regex(RegExpValidated input, String value) {
    if (!_matches(input.regex, value))
      throw MambaParseException(
        "Option --${(input as InputDefinition).name} does not accept '$value'.",
      );
    return value;
  }

  int _integer(InputDefinition input, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null)
      throw MambaParseException(
        'Invalid int value: $value must be a signed decimal integer',
      );
    _range(input, parsed);
    return parsed;
  }

  double _double(InputDefinition input, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || !RegExp(r'[+-]?(?:\d+\.\d+|\d+)').hasMatch(value))
      throw MambaParseException(
        'Invalid double value: $value must be a signed decimal number',
      );
    _range(input, parsed);
    if (input is NumericStepValidated && input is NumericRangeValidated) {
      final stepped = input as NumericStepValidated;
      final range = input as NumericRangeValidated;
      if (stepped.step != null && range.min != null) {
        final increments =
            (parsed - (range.min as num).toDouble()) / stepped.step!;
        if ((increments - increments.round()).abs() > 1e-12) {
          throw MambaParseException(
            'Option --${input.name} must increment by ${stepped.step} from ${range.min} to ${range.max} (received $parsed).',
          );
        }
      }
    }
    return parsed;
  }

  void _range(InputDefinition input, num value) {
    if (input is NumericRangeValidated) {
      final range = input as NumericRangeValidated;
      final min = range.min;
      final max = range.max;
      if ((min != null && value < min) || (max != null && value > max))
        throw MambaParseException(
          'Option --${input.name} is outside its accepted range.',
        );
    }
  }

  Object _choice(ChoiceValidated input, String value) {
    return input.choices
            .cast<Enum>()
            .where((choice) => choice.name == value)
            .firstOrNull ??
        (throw MambaParseException(
          '$value is not a valid choice for ${(input as InputDefinition).name}',
        ));
  }

  bool _matches(RegExp regex, String value) {
    final match = regex.firstMatch(value);
    return match != null && match.start == 0 && match.end == value.length;
  }

  void _addDefaults(
    CommandRegistry registry,
    Map<InputDefinition, Object?> values,
  ) {
    for (final option in registry.applicableOptions) {
      if (option case DefaultValue(defaultValue: final value))
        values.putIfAbsent(option, () => value);
    }
    void access(AccessorOption input) {
      if (input case DefaultValue(defaultValue: final value))
        values.putIfAbsent(input, () => value);
      if (input is AccessorListOption)
        for (final child in input.options) access(child);
    }

    for (final accessor in registry.accessors) access(accessor);
  }

  void _validateRequired(
    CommandRegistry registry,
    Map<InputDefinition, Object?> values,
  ) {
    for (final option in registry.applicableOptions) {
      if (option.isRequired && !values.containsKey(option)) {
        throw MambaParseException('Option --${option.name} is required.');
      }
    }
    void validateAccessor(AccessorOption option, String path) {
      if (option is AccessorPrimitiveOption &&
          option is RequiredInput &&
          !values.containsKey(option)) {
        throw MambaParseException('Option --$path is required.');
      }
      if (option is AccessorListOption) {
        for (final child in option.options) {
          validateAccessor(child, '$path.${child.name}');
        }
      }
    }

    for (final accessor in registry.accessors) {
      validateAccessor(accessor, accessor.name);
    }
  }

  void _validateGroups(
    CommandRegistry registry,
    Map<InputDefinition, Object?> values,
  ) {
    for (final group in registry.pairedOptionGroups) {
      final present = group.options.where(values.containsKey).toList();
      if (group.isRequired && present.length != group.options.length) {
        final missing = group.options
            .where((item) => !values.containsKey(item))
            .map((item) => '--${item.name}')
            .join(', ');
        throw MambaParseException(
          'Required paired options are missing: $missing',
        );
      }
      if (present.isNotEmpty && present.length != group.options.length)
        throw MambaParseException(
          'Paired options ${group.options.map((item) => '--${item.name}').join(', ')} must be passed together',
        );
      if (present.length == group.options.length) {
        values[group] = group.map(
          PairValues({
            for (final option in group.options) option: values[option],
          }),
        );
        for (final option in group.options) {
          values.remove(option);
        }
      }
    }
    for (final group in registry.selectedOptionGroups) {
      final members = group.options
          .where((item) => values.containsKey(item.option))
          .toList();
      if (group.isRequired && members.isEmpty)
        throw MambaParseException(
          'One selected option is required: ${group.options.map((item) => '--${item.option.name}').join(', ')}',
        );
      if (members.length > 1)
        throw MambaParseException('Selected options accept only one option');
      if (members.length == 1) {
        final member = members.single;
        values[group] = group.map(values[member.option], member);
      }
      for (final member in group.options) {
        values.remove(member.option);
      }
    }
  }

  void _parsePositionals(
    CommandRegistry registry,
    List<String> source,
    Map<InputDefinition, Object?> values,
  ) {
    var index = 0;
    for (final positional in [
      ...registry.mandatoryPositionals,
      ...registry.discretionaryPositionals,
    ]) {
      final required = registry.mandatoryPositionals.contains(positional);
      if (positional is RepeatedPositionalDefinition) {
        final collected = <Object>[];
        while (index < source.length &&
            collected.length <=
                (positional as RepeatedPositionalDefinition).times) {
          try {
            collected.add(_positionalValue(positional, source[index]));
            index++;
          } on MambaParseException {
            break;
          }
        }
        if (collected.isEmpty && positional is DefaultValue)
          collected.addAll(
            (positional as DefaultValue<List>).defaultValue.cast<Object>(),
          );
        if (collected.isEmpty && required)
          throw MambaParseException(
            'The ${positional.name} is required at $index after this command',
          );
        if (collected.isNotEmpty) {
          values[positional] = (positional as RepeatedPositionalDefinition)
              .freezeValues(collected);
        }
      } else if (index < source.length) {
        values[positional] = _positionalValue(positional, source[index++]);
      } else if (positional is DefaultValue) {
        values[positional] = (positional as DefaultValue).defaultValue;
      } else if (required) {
        throw MambaParseException(
          'The ${positional.name} is required at $index after this command',
        );
      }
    }
    if (index != source.length)
      throw MambaParseException(
        "This term isn't a registered command positional",
      );
  }

  Object _positionalValue(Positional input, String value) =>
      input is ChoiceValidated
      ? _choice(input as ChoiceValidated, value)
      : _regex(input, value);
  void _validateVariadic(Variadic? variadic, List<String> values) {
    if (values.isEmpty || variadic == null) return;
    if (variadic is ChoiceVariadic &&
        variadic is! RepeatedChoiceVariadic &&
        values.length > 1)
      throw MambaParseException(
        'The registered variadic accepts only one value.',
      );
    for (final value in values) {
      if (variadic is NormalVariadic && !_matches(variadic.regex, value))
        throw MambaParseException(
          "The term isn't accepted by the registered variadic",
        );
      if (variadic is ChoiceVariadic &&
          !variadic.choices.any((choice) => choice.name == value))
        throw MambaParseException(
          "The term isn't accepted by the registered variadic",
        );
    }
  }

  AccessorPrimitiveOption? _accessorFor(
    String path,
    List<AccessorListOption> roots,
  ) {
    AccessorOption? current = roots
        .where((item) => item.name == path.split('.').first)
        .firstOrNull;
    for (final part in path.split('.').skip(1)) {
      if (current is! AccessorListOption) return null;
      current = current.options.where((item) => item.name == part).firstOrNull;
    }
    return current is AccessorPrimitiveOption ? current : null;
  }

  Iterable<InputDefinition> _knownInputs(CommandRegistry registry) sync* {
    final known = <InputDefinition>[];
    yield* registry.applicableFlags;
    yield* registry.applicableOptions;
    yield* registry.mandatoryPositionals;
    yield* registry.discretionaryPositionals;
    yield* registry.pairedOptionGroups;
    yield* registry.selectedOptionGroups;
    void visit(AccessorOption option) {
      if (option is AccessorPrimitiveOption) {
        // Accessor leaves are declaration handles even though their spelling is
        // a dotted path.
        known.add(option);
      } else if (option is AccessorListOption) {
        for (final child in option.options) visit(child);
      }
    }

    for (final root in registry.accessors) visit(root);
    yield* known;
  }

  String? _shortOf(InputDefinition input) => switch (input) {
    Flag(:final short) ||
    Option(:final short) ||
    PairOption(:final short) => short,
    _ => null,
  };
}
