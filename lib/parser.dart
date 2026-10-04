import 'package:mamba/built_in_flags.dart';
import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:mamba/src/input_validation.dart' as validation;
import 'package:mamba/src/suggestion.dart' as suggestion;

class MambaParseException extends MambaException {
  new(super.message, {super.exitCode});
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
  new(this._registry);
  final CommandRegistry _registry;

  /// Reads [tokens] against the resolved registry and returns typed values.
  ///
  /// A `--help` or `--version` token ends validation for everything after it:
  /// the remaining tokens are skipped rather than rejected, so
  /// `--typo --help` fails while `--help --typo` succeeds. This is deliberate —
  /// an invocation that is only asking for help is answered, not corrected —
  /// but it does mean validation depends on argument order.
  ParsedArguments parse(
    List<String> tokens, {
    List<String>? defaultPath,
    CommandRegistry Function(CommandRegistry)? defaultTarget,
  }) {
    final resolution = _registry.resolveCommandPath(
      tokens,
      defaultTarget: defaultTarget,
    );
    final commandPath = defaultPath ?? resolution.path;
    final registry = defaultPath == null
        ? resolution.registry
        : _registry.registryForPath(defaultPath);
    final values = <Object, Object?>{};
    final positionals = <String>[];
    final trailing = <String>[];
    var help = false;
    var version = false;
    final consumed = <int>{};
    final optionInputs = [
      ...registry.applicableOptions,
      for (final group in registry.pairedOptionGroups) ...group.options,
      for (final group in registry.selectedOptions) ...group.options,
    ];
    for (var index = 0; index < tokens.length; index++) {
      if (consumed.contains(index) || resolution.tokenIndices.contains(index)) {
        continue;
      }
      final token = tokens[index];
      if (token == '--') {
        trailing.addAll(tokens.skip(index + 1));
        break;
      }
      if (token == '--help' || token == '-h') {
        values[MambaBuiltInFlags.help] = true;
        help = true;
        continue;
      }
      if (token == '--version') {
        values[MambaBuiltInFlags.version] = true;
        version = true;
        continue;
      }
      if (help || version) continue;
      if (token.startsWith('--') && token.length > 2) {
        final (name, inline) = _split(token.substring(2));
        final accessor = _accessorFor(name, registry.applicableAccessors);
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
        final flag =
            registry.applicableFlags
                .where((item) => item.name == name)
                .firstOrNull ??
            registry.applicableFlags
                .where(
                  (item) =>
                      item is BooleanFlag &&
                      item.negatable &&
                      name == 'no-${item.name}',
                )
                .firstOrNull;
        if (flag == null) {
          throw _unknownInput(registry, name);
        }
        if (inline != null) {
          throw MambaParseException('Flag --$name does not accept a value');
        }
        if (flag is BooleanFlag) {
          values[flag] = name == 'no-${flag.name}' ? false : true;
        } else if (flag is CountFlag) {
          values[flag] = ((values[flag] as int?) ?? 0) + 1;
        }
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
          if (letter == MambaBuiltInFlags.help.short) {
            // A group does not publish the built-in help flag to its
            // descendants, so the clustered path cannot find it by lookup. The
            // handle is recorded here so a clustered `-h` reads the same as a
            // lone one.
            values[MambaBuiltInFlags.help] = true;
            help = true;
            continue;
          }
          final flag = registry.applicableFlags
              .where((item) => item.short == letter)
              .firstOrNull;
          if (flag == null) {
            throw MambaParseException(
              '"-$letter" isn\'t a registered short flag or option.'
              '${_shortInventory(registry)}',
            );
          }
          if (identical(flag, MambaBuiltInFlags.version)) version = true;
          if (flag is BooleanFlag) values[flag] = true;
          if (flag is CountFlag) {
            values[flag] = ((values[flag] as int?) ?? 0) + 1;
          }
        }
        continue;
      }
      positionals.add(token);
    }
    if (!help && !version) {
      _addDefaults(registry, values);
      _validateRequired(registry, values);
      _validateConflicts(registry, values);
      _validateGroups(registry, values);
      _parsePositionals(registry, positionals, values);
      _validateVariadic(registry.variadic, trailing);
    }
    for (final flag in registry.applicableFlags) {
      if (flag is BooleanFlag && flag.name != 'help') {
        values.putIfAbsent(flag, () => flag.defaultValue);
      }
      if (flag is CountFlag) values.putIfAbsent(flag, () => 0);
    }
    _addAccessorMaps(registry, values);
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
    if (index + 1 >= tokens.length) {
      throw MambaParseException('Option --$name requires a value');
    }
    final value = tokens[index + 1];
    if (value == '--' ||
        (value.startsWith('-') && !_allowsDash(input, value))) {
      throw MambaParseException('Option --$name requires a value');
    }
    consumed.add(index + 1);
    return value;
  }

  bool _allowsDash(InputDefinition input, String value) =>
      (input is RegExpValidated &&
          _matches((input as RegExpValidated).regex, value)) ||
      ((input is NumericRangeValidated<int> || input is AccessorIntOption) &&
          _matches(AccessorIntOption.syntax, value)) ||
      ((input is NumericRangeValidated<double> ||
              input is AccessorDoubleOption) &&
          _matches(AccessorDoubleOption.syntax, value));
  void _put(Map<Object, Object?> values, InputDefinition input, Object value) {
    void appendPairValue<T>(RepeatablePairOption<T> option) {
      final existing = values[option] as List<T>?;
      values[option] = List<T>.unmodifiable([...?existing, value as T]);
    }

    switch (input) {
      case RepeatableOptionDefinition():
        final existing = values[input] as List?;
        if (input.unique && existing?.contains(value) == true) {
          throw MambaParseException(
            'Option --${input.name} accepts each choice once; ${(value as Enum).name} was provided more than once.',
          );
        }
        values[input] = input.appendValue(value, existing);
      case RepeatablePairStringOption():
        appendPairValue<String>(input);
      case RepeatablePairIntOption():
        appendPairValue<int>(input);
      case RepeatablePairDoubleOption():
        appendPairValue<double>(input);
      default:
        if (input is PairOption && values.containsKey(input)) {
          throw MambaParseException(
            'Selected option --${input.name} was provided more than once.',
          );
        }
        values[input] = value;
    }
  }

  Object _parseValue(InputDefinition input, String value) =>
      switch (valueKindOf(input)) {
        RegistryValueKind.string => _regex(input as RegExpValidated, value),
        RegistryValueKind.integer => _integer(input, value),
        RegistryValueKind.decimal => _double(input, value),
        RegistryValueKind.choice => _choice(input as ChoiceValidated, value),
      };

  String _regex(RegExpValidated input, String value) {
    if (!_matches(input.regex, value)) {
      throw MambaParseException(
        "Option --${(input as InputDefinition).name} does not accept '$value'.",
      );
    }
    return value;
  }

  int _integer(InputDefinition input, String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw MambaParseException(
        'Invalid int value: $value must be a signed decimal integer',
      );
    }
    _range(input, parsed);
    return parsed;
  }

  double _double(InputDefinition input, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || !_matches(AccessorDoubleOption.syntax, value)) {
      throw MambaParseException(
        'Invalid double value: $value must be a signed decimal number',
      );
    }
    _range(input, parsed);
    if (input is NumericStepValidated && input is NumericRangeValidated) {
      final stepped = input as NumericStepValidated;
      final range = input as NumericRangeValidated;
      if (stepped.step != null && range.min != null) {
        if (!validation.followsNumericStep(
          parsed,
          range.min as num,
          stepped.step!,
        )) {
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
      if ((min != null && value < min) || (max != null && value > max)) {
        throw MambaParseException(
          'Option --${input.name} is outside its accepted range.',
        );
      }
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

  bool _matches(RegExp regex, String value) =>
      validation.matchesEntireValue(regex, value);

  void _addDefaults(CommandRegistry registry, Map<Object, Object?> values) {
    for (final option in registry.applicableOptions) {
      if (option case DefaultValue(defaultValue: final value)) {
        values.putIfAbsent(option, () => value);
      }
    }
    void access(AccessorOption input) {
      if (input case DefaultValue(defaultValue: final value)) {
        values.putIfAbsent(input, () => value);
      }
      if (input is AccessorListOption) {
        for (final child in input.options) {
          access(child);
        }
      }
    }

    for (final accessor in registry.applicableAccessors) {
      access(accessor);
    }
  }

  void _validateRequired(
    CommandRegistry registry,
    Map<Object, Object?> values,
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

    for (final accessor in registry.applicableAccessors) {
      validateAccessor(accessor, accessor.name);
    }
  }

  void _validateGroups(CommandRegistry registry, Map<Object, Object?> values) {
    for (final group in registry.pairedOptionGroups) {
      final present = group.options.where(values.containsKey).toList();
      if (group.required && present.length != group.options.length) {
        final missing = group.options
            .where((item) => !values.containsKey(item))
            .map((item) => '--${item.name}')
            .join(', ');
        throw MambaParseException(
          'Required paired options are missing: $missing',
        );
      }
      if (present.isNotEmpty && present.length != group.options.length) {
        throw MambaParseException(
          'Paired options ${group.options.map((item) => '--${item.name}').join(', ')} must be passed together',
        );
      }
      _addGroupValuesFor(group, values);
      for (final option in group.options) {
        values.remove(option);
      }
    }
    for (final group in registry.selectedOptions) {
      final selected = group.options.where(values.containsKey).toList();
      if (group.required && selected.isEmpty) {
        throw MambaParseException(
          'At least one selected option is required: ${group.options.map((option) => '--${option.name}').join(', ')}',
        );
      }
      if (group.single && selected.length > 1) {
        throw MambaParseException('Selected options accept only one option.');
      }
      _addGroupValuesFor(group, values);
      for (final option in group.options) {
        values.remove(option);
      }
    }
  }

  void _validateConflicts(
    CommandRegistry registry,
    Map<Object, Object?> values,
  ) {
    for (final entry in registry.conflicts.entries) {
      final key = registry.conflictInput(entry.key)!;
      if (!values.containsKey(key)) continue;
      for (final memberName in entry.value) {
        final member = registry.conflictInput(memberName)!;
        if (values.containsKey(member)) {
          throw MambaParseException(
            'Input --${entry.key} conflicts with --$memberName.',
          );
        }
      }
    }
  }

  void _addAccessorMaps(CommandRegistry registry, Map<Object, Object?> values) {
    Map<String, Object?> mapAccessor(AccessorListOption accessor) {
      final map = <String, Object?>{};
      for (final option in accessor.options) {
        if (option is AccessorListOption) {
          map[option.name] = mapAccessor(option);
        } else if (values.containsKey(option)) {
          map[option.name] = values[option];
        }
      }
      return Map.unmodifiable(map);
    }

    for (final accessor in registry.applicableAccessors) {
      values[accessor] = mapAccessor(accessor);
    }
  }

  void _addGroupValuesFor(
    PairedOptionsDefinition group,
    Map<Object, Object?> values,
  ) {
    values[group] = group.valuesFrom(values);
  }

  void _parsePositionals(
    CommandRegistry registry,
    List<String> source,
    Map<Object, Object?> values,
  ) {
    var index = 0;
    for (final positional in [
      ...registry.mandatoryPositionals,
      ...registry.discretionaryPositionals,
    ]) {
      final required = registry.mandatoryPositionals.contains(positional);
      if (positional case final RepeatedPositionalDefinition definition) {
        final collected = <Object>[];
        // Membership is decided before the value is read, so a token that is
        // not one of this input's values stops the run instead of raising. That
        // leaves the token for the next positional and keeps a genuine
        // violation from being reported as an unknown command.
        while (index < source.length &&
            collected.length < definition.times &&
            _accepts(positional, source[index])) {
          collected.add(_positionalValue(positional, source[index]));
          index++;
        }
        if (collected.isEmpty && positional is DefaultValue) {
          collected.addAll(
            (positional as DefaultValue<List>).defaultValue.cast<Object>(),
          );
        }
        if (collected.isEmpty && required) {
          throw MambaParseException(
            'The ${positional.name} is required at $index after this command',
          );
        }
        if (collected.isNotEmpty) {
          values[positional] = definition.freezeValues(collected);
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
    if (index != source.length) {
      final leftover = source[index];
      // A repeated positional ended because the next word was not one of its
      // values. Naming the declaration that turned it away keeps the reader
      // from hunting for a command typo that was never there.
      final rejectedBy = [
          ...registry.mandatoryPositionals,
          ...registry.discretionaryPositionals,
        ]
          .whereType<RepeatedPositionalDefinition>()
          .where((input) => !_accepts(input, leftover))
          .firstOrNull;
      if (rejectedBy != null) {
        throw MambaParseException(
          "'$leftover' is not an accepted value for ${rejectedBy.name}.",
        );
      }
      throw _unregisteredTerm(registry, leftover);
    }
  }

  /// Whether [value] is one of the values [input] declares.
  ///
  /// Deciding membership before parsing is what lets a repeated positional stop
  /// at the first word that belongs to the input after it, without treating a
  /// malformed value as the end of the command line.
  bool _accepts(InputDefinition input, String value) {
    if (input case ChoiceValidated(:final choices)) {
      return choices.cast<Enum>().any((choice) => choice.name == value);
    }
    return _matches((input as RegExpValidated).regex, value);
  }

  /// Rejects [term] with the context a reader needs to correct it.
  ///
  /// The word is named so the reader knows which token was rejected, and the
  /// registry decides whether a command or a subcommand was the right word for
  /// where they typed it. Nearby commands and aliases are offered by name and
  /// by kind, so a near miss reads as the kind of thing it almost was rather
  /// than as a bare rejection.
  MambaParseException _unregisteredTerm(CommandRegistry registry, String term) {
    final kind = registry.parent == null ? 'command' : 'subcommand';

    return MambaParseException(
      '"$term" isn\'t a registered $kind, alias, or argument.'
      '${suggestion.adviceFor(term, _candidates(registry))}',
    );
  }

  /// Every child command [term] could plausibly have meant.
  ///
  /// A positional is left out on purpose: its name belongs to whoever declared
  /// it and only the parser matches against it, so offering one would point a
  /// reader at a word they never typed and cannot act on.
  Iterable<suggestion.Suggestion> _candidates(CommandRegistry registry) sync* {
    for (final child in registry.commandRegistries) {
      yield suggestion.Suggestion(
        suggestion.SuggestionKind.command,
        child.name,
      );
      for (final alias in child.commandAliases ?? const <String>[]) {
        yield suggestion.Suggestion(suggestion.SuggestionKind.alias, alias);
      }
    }
  }

  /// Rejects a `--` input that matches no registered flag or option.
  MambaParseException _unknownInput(CommandRegistry registry, String name) =>
      MambaParseException(
        'Unknown flag or option --$name.'
        '${suggestion.adviceFor(name, _inputCandidates(registry))}',
      );

  /// Every registered flag, option, and accessor a mistyped `--` input could
  /// have meant.
  ///
  /// Repeatable options are ordinary options that may be written more than
  /// once, so they are covered by [CommandRegistry.applicableOptions]. The
  /// paired and selected groups are walked too, because their members are
  /// accepted wherever an option is.
  Iterable<suggestion.Suggestion> _inputCandidates(
    CommandRegistry registry,
  ) sync* {
    for (final flag in registry.applicableFlags) {
      yield suggestion.Suggestion(suggestion.SuggestionKind.flag, flag.name);
    }
    for (final group in registry.pairedOptionGroups) {
      for (final option in group.options) {
        yield suggestion.Suggestion(
          suggestion.SuggestionKind.option,
          option.name,
        );
      }
    }
    for (final group in registry.selectedOptions) {
      for (final option in group.options) {
        yield suggestion.Suggestion(
          suggestion.SuggestionKind.option,
          option.name,
        );
      }
    }
    for (final option in registry.applicableOptions) {
      yield suggestion.Suggestion(
        suggestion.SuggestionKind.option,
        option.name,
      );
    }
    for (final accessor in registry.applicableAccessors) {
      yield suggestion.Suggestion(
        suggestion.SuggestionKind.option,
        accessor.name,
      );
    }
  }

  /// Every registered short flag a mistyped letter could have meant.
  /// Lists the short tokens the reader could have typed instead.
  ///
  /// A mistyped letter has nothing worth guessing at, because every other
  /// single letter sits one edit away. The whole inventory is short enough to
  /// read and is what a reader who cannot recall the letter actually wants, so
  /// it is offered in place of a suggestion.
  String _shortInventory(CommandRegistry registry) =>
      ' Registered shorts: ${_shorts(registry).join(', ')}.';

  /// Every short token the clustered short parser would accept.
  ///
  /// The built-in help short leads because the same loop accepts it whether or
  /// not a registry declares it, and it is the letter a reader reaches for
  /// first, so the inventory is never empty. Hidden inputs are withheld
  /// because a hidden input is not meant to be advertised.
  List<String> _shorts(CommandRegistry registry) {
    final shorts = <String>[];
    final seen = <String>{};

    void add(String? short, bool hidden) {
      if (short == null || short.isEmpty || hidden) return;
      if (seen.add(short)) shorts.add('-$short');
    }

    add(MambaBuiltInFlags.help.short, MambaBuiltInFlags.help.hidden);
    for (final flag in registry.applicableFlags) {
      add(flag.short, flag.hidden);
    }
    for (final option in registry.applicableOptions) {
      add(option.short, option.hidden);
    }

    return shorts;
  }

  Object _positionalValue(Positional<Object?> input, String value) =>
      input is ChoiceValidated
      ? _choice(input as ChoiceValidated, value)
      : _regex(input, value);
  void _validateVariadic(Variadic? variadic, List<String> values) {
    if (values.isEmpty || variadic == null) return;
    if (variadic is ChoiceVariadic && values.length > 1) {
      throw MambaParseException(
        'The registered variadic accepts only one value.',
      );
    }
    for (final value in values) {
      if (variadic is NormalVariadic && !_matches(variadic.regex, value)) {
        throw MambaParseException(
          "The term isn't accepted by the registered variadic",
        );
      }
      if (variadic is ChoiceVariadic &&
          !variadic.choices.any((choice) => choice.name == value)) {
        throw MambaParseException(
          "The term isn't accepted by the registered variadic",
        );
      }
    }
  }

  AccessorPrimitiveOption<Object?>? _accessorFor(
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

  Iterable<Object> _knownInputs(CommandRegistry registry) sync* {
    final known = <InputDefinition>[];
    yield* registry.applicableFlags;
    yield* registry.applicableOptions;
    yield* registry.mandatoryPositionals;
    yield* registry.discretionaryPositionals;
    yield* registry.pairedOptionGroups;
    yield* registry.selectedOptions;
    void collectAccessors(AccessorListOption root) {
      known.add(root);
      for (final option in root.options) {
        if (option is AccessorListOption) {
          collectAccessors(option);
        } else {
          // A leaf is a declaration the reader holds, so it has to answer
          // `valueOf` on its own as well as through the map its root builds.
          known.add(option);
        }
      }
    }

    for (final accessor in registry.applicableAccessors) {
      collectAccessors(accessor);
    }
    yield* known;
  }

  String? _shortOf(InputDefinition input) =>
      input is Option ? input.short : (input as PairOption).short;
}
