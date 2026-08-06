import 'dart:convert';
import 'dart:io';

/// A JSON configuration loader for a configured [YargsParserOptions.config] key.
typedef YargsParserConfigLoader = Map<String, Object?> Function(String path);

/// A synchronous value transformation applied after all value sources resolve.
typedef YargsParserCoercion = Object? Function(Object? value);

/// A typed array declaration, optionally with an element conversion hint.
final class YargsParserArrayOption {
  const YargsParserArrayOption(
    this.key, {
    this.boolean = false,
    this.string = false,
    this.number = false,
  });

  final String key;
  final bool boolean;
  final bool string;
  final bool number;
}

/// Controls the automatic transformations performed by [YargsParser].
final class YargsParserConfiguration {
  const YargsParserConfiguration({
    this.booleanNegation = true,
    this.camelCaseExpansion = true,
    this.combineArrays = false,
    this.dotNotation = true,
    this.duplicateArgumentsArray = true,
    this.flattenDuplicateArrays = true,
    this.greedyArrays = true,
    this.haltAtNonOption = false,
    this.nargsEatsOptions = false,
    this.negationPrefix = 'no-',
    this.parseNumbers = true,
    this.parsePositionalNumbers = true,
    this.populateDoubleDash = false,
    this.setPlaceholderKey = false,
    this.shortOptionGroups = true,
    this.stripAliased = false,
    this.stripDashed = false,
    this.unknownOptionsAsArgs = false,
  });

  final bool booleanNegation;
  final bool camelCaseExpansion;
  final bool combineArrays;
  final bool dotNotation;
  final bool duplicateArgumentsArray;
  final bool flattenDuplicateArrays;
  final bool greedyArrays;
  final bool haltAtNonOption;
  final bool nargsEatsOptions;
  final String negationPrefix;
  final bool parseNumbers;
  final bool parsePositionalNumbers;
  final bool populateDoubleDash;
  final bool setPlaceholderKey;
  final bool shortOptionGroups;
  final bool stripAliased;
  final bool stripDashed;
  final bool unknownOptionsAsArgs;

  /// Represents this configuration with the upstream package's property names.
  Map<String, Object> toMap() => {
    'boolean-negation': booleanNegation,
    'camel-case-expansion': camelCaseExpansion,
    'combine-arrays': combineArrays,
    'dot-notation': dotNotation,
    'duplicate-arguments-array': duplicateArgumentsArray,
    'flatten-duplicate-arrays': flattenDuplicateArrays,
    'greedy-arrays': greedyArrays,
    'halt-at-non-option': haltAtNonOption,
    'nargs-eats-options': nargsEatsOptions,
    'negation-prefix': negationPrefix,
    'parse-numbers': parseNumbers,
    'parse-positional-numbers': parsePositionalNumbers,
    'populate--': populateDoubleDash,
    'set-placeholder-key': setPlaceholderKey,
    'short-option-groups': shortOptionGroups,
    'strip-aliased': stripAliased,
    'strip-dashed': stripDashed,
    'unknown-options-as-args': unknownOptionsAsArgs,
  };
}

/// Parsing hints accepted by [YargsParser.parse] and [YargsParser.detailed].
///
/// Each field corresponds to the like-named `yargs-parser` option. Dart uses
/// typed collections instead of JavaScript's string-or-array unions. A `null`
/// [config] loader uses the built-in JSON-file loader.
final class YargsParserOptions {
  const YargsParserOptions({
    this.alias = const {},
    this.array = const [],
    this.boolean = const [],
    this.coerce = const {},
    this.config = const {},
    this.configObjects = const [],
    this.configuration = const YargsParserConfiguration(),
    this.count = const [],
    this.defaultValues = const {},
    this.envPrefix,
    this.environment,
    this.narg = const {},
    this.normalize = const [],
    this.number = const [],
    this.string = const [],
    this.key = const {},
  });

  final Map<String, Iterable<String>> alias;
  final Iterable<YargsParserArrayOption> array;
  final Iterable<String> boolean;
  final Map<String, YargsParserCoercion> coerce;
  final Map<String, YargsParserConfigLoader?> config;
  final Iterable<Map<String, Object?>> configObjects;
  final YargsParserConfiguration configuration;
  final Iterable<String> count;
  final Map<String, Object?> defaultValues;

  /// Reads matching variables from [Platform.environment] when omitted.
  final String? envPrefix;

  /// An injectable environment for hermetic applications and embedders.
  final Map<String, String>? environment;
  final Map<String, num> narg;
  final Iterable<String> normalize;
  final Iterable<String> number;
  final Iterable<String> string;

  /// Known keys used to establish aliases even when no type hint is supplied.
  final Map<String, Object?> key;
}

/// An error captured by [YargsParser.detailed] rather than thrown to its caller.
final class YargsParserException implements Exception {
  const YargsParserException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// The metadata returned by [YargsParser.detailed].
final class YargsParserDetailedResult {
  const YargsParserDetailedResult({
    required this.argv,
    required this.aliases,
    required this.newAliases,
    required this.defaulted,
    required this.configuration,
    required this.error,
  });

  /// The parsed argument object. Positional arguments are in `argv['_']`.
  final Map<String, Object?> argv;
  final Map<String, List<String>> aliases;
  final Map<String, bool> newAliases;
  final Map<String, bool> defaulted;
  final YargsParserConfiguration configuration;
  final Object? error;
}

/// A Dart port of the token parser used by Yargs.
///
/// This parser intentionally has no command, validation, or help model. It
/// converts a command string or a pre-tokenized argument sequence into a
/// JavaScript-object-shaped Dart map, including aliases and dotted paths.
final class YargsParser {
  const YargsParser();

  /// Parses [arguments] and returns only its argument object.
  Map<String, Object?> parse(
    Object arguments, [
    YargsParserOptions options = const YargsParserOptions(),
  ]) => detailed(arguments, options).argv;

  /// Parses [arguments] and returns the parser metadata consumed by Yargs.
  YargsParserDetailedResult detailed(
    Object arguments, [
    YargsParserOptions options = const YargsParserOptions(),
  ]) {
    final tokens = _tokenizeArgString(arguments);
    final inputIsString = arguments is String;
    final state = _ParserState(tokens, inputIsString, options);
    return state.parse();
  }

  /// Converts dashed or underscored words to the parser's camel-case spelling.
  static String camelCase(String value) => _camelCase(value);

  /// Converts a camel-case word to a separated spelling.
  static String decamelize(String value, [String join = '-']) =>
      _decamelize(value, join);

  /// Whether [value] uses a numeric spelling recognized by yargs-parser.
  static bool looksLikeNumber(Object? value) => _looksLikeNumber(value);

  /// Performs yargs-parser's deliberately small convenience tokenization.
  static List<String> tokenizeArgString(Object arguments) =>
      _tokenizeArgString(arguments);
}

/// Parses [arguments] using a fresh [YargsParser].
Map<String, Object?> yargsParser(
  Object arguments, [
  YargsParserOptions options = const YargsParserOptions(),
]) => const YargsParser().parse(arguments, options);

/// Parses [arguments] and returns the detailed Yargs-compatible metadata.
YargsParserDetailedResult yargsParserDetailed(
  Object arguments, [
  YargsParserOptions options = const YargsParserOptions(),
]) => const YargsParser().detailed(arguments, options);

/// Converts dashed or underscored words to the parser's camel-case spelling.
String camelCase(String value) => _camelCase(value);

/// Converts a camel-case word to a separated spelling.
String decamelize(String value, [String join = '-']) =>
    _decamelize(value, join);

/// Whether [value] uses a numeric spelling recognized by yargs-parser.
bool looksLikeNumber(Object? value) => _looksLikeNumber(value);

/// Equivalent to the package's `tokenize-arg-string` helper.
List<String> tokenizeArgString(Object arguments) =>
    _tokenizeArgString(arguments);

List<String> _tokenizeArgString(Object arguments) {
  if (arguments is Iterable) return arguments.map((value) => '$value').toList();
  if (arguments is! String) {
    throw ArgumentError.value(
      arguments,
      'arguments',
      'Must be a String or Iterable.',
    );
  }

  final source = arguments.trim();
  final tokens = <String>[];
  var tokenIndex = 0;
  String? previous;
  String? opening;

  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == ' ' && opening == null) {
      if (previous != ' ') tokenIndex++;
      previous = character;
      continue;
    }
    if (character == opening) {
      opening = null;
    } else if ((character == "'" || character == '"') && opening == null) {
      opening = character;
    }
    while (tokens.length <= tokenIndex) {
      tokens.add('');
    }
    tokens[tokenIndex] += character;
    previous = character;
  }
  return tokens;
}

final class _ParserState {
  _ParserState(this.arguments, this.inputIsString, this.options)
    : configuration = options.configuration,
      defaults = Map<String, Object?>.of(options.defaultValues),
      aliases = _combineAliases(options.alias),
      environment = options.environment ?? Platform.environment {
    _initializeFlags();
    _extendAliases([
      options.key,
      aliases.map((key, value) => MapEntry<String, Object?>(key, value)),
      defaults,
      flags.arrays,
    ]);
    for (final entry in List<MapEntry<String, Object?>>.of(defaults.entries)) {
      for (final alias in flags.aliases[entry.key] ?? const []) {
        defaults[alias] = entry.value;
      }
    }
    _checkConfiguration();
  }

  final List<String> arguments;
  final bool inputIsString;
  final YargsParserOptions options;
  final YargsParserConfiguration configuration;
  final Map<String, Object?> defaults;
  final Map<String, List<String>> aliases;
  final Map<String, String> environment;
  final _Flags flags = _Flags();
  final Map<String, bool> newAliases = {};
  final Map<String, bool> defaulted = {};
  final Map<String, Object?> argv = {'_': <Object?>[]};
  Object? error;

  static final RegExp _negativeNumber = RegExp(
    r'^-([0-9]+(\.[0-9]+)?|\.[0-9]+)$',
  );

  void _initializeFlags() {
    for (final option in options.array) {
      flags.arrays[option.key] = true;
      if (option.boolean) flags.bools[option.key] = true;
      if (option.string) flags.strings[option.key] = true;
      if (option.number) flags.numbers[option.key] = true;
      flags.keys.add(option.key);
    }
    _addFlagNames(options.boolean, flags.bools);
    _addFlagNames(options.string, flags.strings);
    _addFlagNames(options.number, flags.numbers);
    _addFlagNames(options.count, flags.counts);
    _addFlagNames(options.normalize, flags.normalize);
    for (final entry in options.narg.entries) {
      flags.nargs[entry.key] = entry.value;
      flags.keys.add(entry.key);
    }
    for (final entry in options.coerce.entries) {
      flags.coercions[entry.key] = entry.value;
      flags.keys.add(entry.key);
    }
    for (final entry in options.config.entries) {
      flags.configs[entry.key] = entry.value;
    }
  }

  void _addFlagNames(Iterable<String> names, Map<String, Object?> target) {
    for (final name in names) {
      target[name] = true;
      flags.keys.add(name);
    }
  }

  YargsParserDetailedResult parse() {
    var notFlags = <String>[];
    final negationPattern = RegExp(
      '^--${RegExp.escape(configuration.negationPrefix)}(.+)',
    );

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      final truncated = argument.replaceFirst(RegExp(r'^-{3,}'), '---');
      final next = index + 1 < arguments.length ? arguments[index + 1] : null;

      if (argument != '--' &&
          argument.startsWith('-') &&
          _unknownAsArgument(argument, negationPattern)) {
        _pushPositional(argument);
      } else if (RegExp(r'^---+(=|$)').hasMatch(truncated)) {
        _pushPositional(argument);
      } else if (RegExp(r'^--.+=').hasMatch(argument) ||
          (!configuration.shortOptionGroups &&
              RegExp(r'^-.+=').hasMatch(argument))) {
        final match = RegExp(r'^--?([^=]+)=([\s\S]*)$').firstMatch(argument);
        if (match != null) {
          final key = match.group(1)!;
          final value = match.group(2)!;
          if (_checkAllAliases(key, flags.arrays) == true) {
            index = _eatArray(index, key, value);
          } else if (_checkAllAliases(key, flags.nargs) != null) {
            index = _eatNargs(index, key, value);
          } else {
            _setArg(key, value, stripQuotes: true);
          }
        }
      } else if (negationPattern.hasMatch(argument) &&
          configuration.booleanNegation) {
        final key = negationPattern.firstMatch(argument)!.group(1)!;
        _setArg(
          key,
          _checkAllAliases(key, flags.arrays) == true
              ? <Object?>[false]
              : false,
        );
      } else if (RegExp(r'^--.+').hasMatch(argument) ||
          (!configuration.shortOptionGroups &&
              RegExp(r'^-[^-]+').hasMatch(argument))) {
        final key = RegExp(r'^--?(.+)').firstMatch(argument)!.group(1)!;
        if (_checkAllAliases(key, flags.arrays) == true) {
          index = _eatArray(index, key);
        } else if (_checkAllAliases(key, flags.nargs) != null) {
          index = _eatNargs(index, key);
        } else if (next != null &&
            (!next.startsWith('-') || _negativeNumber.hasMatch(next)) &&
            _checkAllAliases(key, flags.bools) != true &&
            _checkAllAliases(key, flags.counts) != true) {
          _setArg(key, next);
          index++;
        } else if (next == 'true' || next == 'false') {
          _setArg(key, next);
          index++;
        } else {
          _setArg(key, _defaultValue(key));
        }
      } else if (RegExp(r'^-.\..+=').hasMatch(argument)) {
        final match = RegExp(r'^-([^=]+)=([\s\S]*)$').firstMatch(argument)!;
        _setArg(match.group(1)!, match.group(2)!);
      } else if (RegExp(r'^-.\..+').hasMatch(argument) &&
          !_negativeNumber.hasMatch(argument)) {
        final key = RegExp(r'^-(.\..+)').firstMatch(argument)!.group(1)!;
        if (next != null &&
            !next.startsWith('-') &&
            _checkAllAliases(key, flags.bools) != true &&
            _checkAllAliases(key, flags.counts) != true) {
          _setArg(key, next);
          index++;
        } else {
          _setArg(key, _defaultValue(key));
        }
      } else if (RegExp(r'^-[^-]+').hasMatch(argument) &&
          !_negativeNumber.hasMatch(argument)) {
        index = _parseShortGroup(index);
      } else if (RegExp(r'^-[0-9]$').hasMatch(argument) &&
          _negativeNumber.hasMatch(argument) &&
          _checkAllAliases(argument.substring(1), flags.bools) == true) {
        _setArg(argument.substring(1), _defaultValue(argument.substring(1)));
      } else if (argument == '--') {
        notFlags = arguments.sublist(index + 1);
        break;
      } else if (configuration.haltAtNonOption) {
        notFlags = arguments.sublist(index);
        break;
      } else {
        _pushPositional(argument);
      }
    }

    _applyEnvironment(configOnly: true);
    _applyEnvironment();
    _setConfig();
    for (final object in options.configObjects) {
      _setConfigObject(object);
    }
    _applyDefaultsAndAliases(argv, logDefaults: true);
    _applyCoercions();
    if (configuration.setPlaceholderKey) _setPlaceholderKeys();
    for (final key in flags.counts.keys) {
      if (!_hasKey(argv, key.split('.'))) _setArg(key, 0);
    }

    final notFlagKey = configuration.populateDoubleDash ? '--' : '_';
    if (configuration.populateDoubleDash && notFlags.isNotEmpty) {
      argv[notFlagKey] = <Object?>[];
    }
    for (final value in notFlags) {
      (argv[notFlagKey]! as List<Object?>).add(value);
    }
    _stripOutput();

    return YargsParserDetailedResult(
      argv: argv,
      aliases: flags.aliases.map((key, value) => MapEntry(key, List.of(value))),
      newAliases: Map.of(newAliases),
      defaulted: Map.of(defaulted),
      configuration: configuration,
      error: error,
    );
  }

  int _parseShortGroup(int index) {
    final argument = arguments[index];
    final letters = argument.substring(1, argument.length - 1).split('');
    var broken = false;

    for (var letterIndex = 0; letterIndex < letters.length; letterIndex++) {
      final letter = letters[letterIndex];
      final suffix = argument.substring(letterIndex + 2);
      if (letterIndex + 1 < letters.length && letters[letterIndex + 1] == '=') {
        final value = argument.substring(letterIndex + 3);
        if (_checkAllAliases(letter, flags.arrays) == true) {
          index = _eatArray(index, letter, value);
        } else if (_checkAllAliases(letter, flags.nargs) != null) {
          index = _eatNargs(index, letter, value);
        } else {
          _setArg(letter, value);
        }
        broken = true;
        break;
      }
      if (suffix == '-') {
        _setArg(letter, suffix);
        continue;
      }
      if (RegExp(r'[A-Za-z]').hasMatch(letter) &&
          RegExp(r'^-?\d+(\.\d*)?(e-?\d+)?$').hasMatch(suffix) &&
          _checkAllAliases(suffix, flags.bools) != true) {
        _setArg(letter, suffix);
        broken = true;
        break;
      }
      if (letterIndex + 1 < letters.length &&
          RegExp(r'\W').hasMatch(letters[letterIndex + 1])) {
        _setArg(letter, suffix);
        broken = true;
        break;
      }
      _setArg(letter, _defaultValue(letter));
    }

    final key = argument[argument.length - 1];
    if (broken || key == '-') return index;
    if (_checkAllAliases(key, flags.arrays) == true) {
      return _eatArray(index, key);
    }
    if (_checkAllAliases(key, flags.nargs) != null) {
      return _eatNargs(index, key);
    }

    final next = index + 1 < arguments.length ? arguments[index + 1] : null;
    if (next != null &&
        (!RegExp(r'^(-|--)[^-]').hasMatch(next) ||
            _negativeNumber.hasMatch(next)) &&
        _checkAllAliases(key, flags.bools) != true &&
        _checkAllAliases(key, flags.counts) != true) {
      _setArg(key, next);
      return index + 1;
    }
    if (next == 'true' || next == 'false') {
      _setArg(key, next);
      return index + 1;
    }
    _setArg(key, _defaultValue(key));
    return index;
  }

  int _eatNargs(int index, String key, [String? inlineValue]) {
    final configured = _checkAllAliases(key, flags.nargs);
    final target = configured is num && !configured.isNaN
        ? configured.toInt()
        : 1;
    if (target == 0) {
      if (inlineValue != null) {
        _recordError('Argument unexpected for: $key');
      }
      _setArg(key, _defaultValue(key));
      return index;
    }

    var available = inlineValue == null ? 0 : 1;
    if (configuration.nargsEatsOptions) {
      if (arguments.length - (index + 1) + available < target) {
        _recordError('Not enough arguments following: $key');
      }
      available = target;
    } else {
      for (var cursor = index + 1; cursor < arguments.length; cursor++) {
        final candidate = arguments[cursor];
        if (!RegExp(r'^-[^0-9]').hasMatch(candidate) ||
            _negativeNumber.hasMatch(candidate) ||
            _unknownAsArgument(
              candidate,
              RegExp('^--${RegExp.escape(configuration.negationPrefix)}(.+)'),
            )) {
          available++;
        } else {
          break;
        }
      }
      if (available < target) {
        _recordError('Not enough arguments following: $key');
      }
    }

    var consumed = available < target ? available : target;
    if (inlineValue != null && consumed > 0) {
      _setArg(key, inlineValue);
      consumed--;
    }
    for (var cursor = index + 1; cursor < index + consumed + 1; cursor++) {
      _setArg(key, arguments[cursor]);
    }
    return index + consumed;
  }

  int _eatArray(int index, String key, [String? inlineValue]) {
    final values = <Object?>[];
    final next =
        inlineValue ??
        (index + 1 < arguments.length ? arguments[index + 1] : null);
    final nargs = _checkAllAliases(key, flags.nargs);

    if (_checkAllAliases(key, flags.bools) == true &&
        next != 'true' &&
        next != 'false') {
      values.add(true);
    } else if (next == null ||
        (inlineValue == null &&
            next.startsWith('-') &&
            !_negativeNumber.hasMatch(next) &&
            !_unknownAsArgument(
              next,
              RegExp('^--${RegExp.escape(configuration.negationPrefix)}(.+)'),
            ))) {
      if (defaults.containsKey(key)) {
        final defaultValue = defaults[key];
        values.addAll(defaultValue is List ? defaultValue : [defaultValue]);
      }
    } else {
      if (inlineValue != null) {
        values.add(_processValue(key, inlineValue, true));
      }
      for (var cursor = index + 1; cursor < arguments.length; cursor++) {
        if ((!configuration.greedyArrays && values.isNotEmpty) ||
            (nargs is num &&
                !nargs.isNaN &&
                nargs != 0 &&
                values.length >= nargs)) {
          break;
        }
        final candidate = arguments[cursor];
        if (candidate.startsWith('-') &&
            !_negativeNumber.hasMatch(candidate) &&
            !_unknownAsArgument(
              candidate,
              RegExp('^--${RegExp.escape(configuration.negationPrefix)}(.+)'),
            )) {
          break;
        }
        index = cursor;
        values.add(_processValue(key, candidate, inputIsString));
      }
    }

    if (nargs is num &&
        ((nargs != 0 && !nargs.isNaN && values.length < nargs) ||
            (nargs.isNaN && values.isEmpty))) {
      _recordError('Not enough arguments following: $key');
    }
    _setArg(key, values);
    return index;
  }

  void _setArg(String key, Object? value, {bool? stripQuotes}) {
    if (key.contains('-') && configuration.camelCaseExpansion) {
      _addNewAlias(key, key.split('.').map(_camelCase).join('.'));
    }
    final processed = _processValue(key, value, stripQuotes ?? inputIsString);
    final segments = key.split('.');
    _setKey(argv, segments, processed);

    for (final alias in flags.aliases[key] ?? const []) {
      _setKey(argv, alias.split('.'), processed);
    }
    if (segments.length > 1 && configuration.dotNotation) {
      for (final alias in flags.aliases[segments.first] ?? const []) {
        final List<String> aliasSegments = [
          ...alias.split('.'),
          ...segments.skip(1),
        ];
        if (!(flags.aliases[key] ?? const []).contains(
          aliasSegments.join('.'),
        )) {
          _setKey(argv, aliasSegments, processed);
        }
      }
    }
  }

  Object? _processValue(String key, Object? value, bool stripQuotes) {
    var processed = value;
    if (stripQuotes && processed is String) processed = _stripQuotes(processed);
    if ((_checkAllAliases(key, flags.bools) == true ||
            _checkAllAliases(key, flags.counts) == true) &&
        processed is String) {
      processed = processed == 'true';
    }
    if (processed is List) {
      processed = processed
          .map((item) => _maybeCoerceNumber(key, item))
          .toList();
    } else {
      processed = _maybeCoerceNumber(key, processed);
    }
    if (_checkAllAliases(key, flags.counts) == true &&
        (processed == null || processed is bool)) {
      processed = _countIncrement();
    }
    if (_checkAllAliases(key, flags.normalize) == true) {
      processed = processed is List
          ? processed.map((item) => _normalize(item)).toList()
          : _normalize(processed);
    }
    return processed;
  }

  Object? _maybeCoerceNumber(String key, Object? value) {
    if (!configuration.parsePositionalNumbers && key == '_') return value;
    if (_checkAllAliases(key, flags.strings) != true &&
        _checkAllAliases(key, flags.bools) != true &&
        value is! List) {
      final shouldCoerce =
          _looksLikeNumber(value) &&
          configuration.parseNumbers &&
          _isSafeNumeric(value);
      if (shouldCoerce ||
          (value != null && _checkAllAliases(key, flags.numbers) == true)) {
        return _parseNumber(value);
      }
    }
    return value;
  }

  void _pushPositional(String value) {
    final processed = _maybeCoerceNumber('_', value);
    if (processed is String || processed is num) {
      (argv['_']! as List<Object?>).add(processed);
    }
  }

  void _setConfig() {
    final lookup = <String, Object?>{};
    _applyDefaultsAndAliases(lookup);
    for (final entry in flags.configs.entries) {
      final path = argv[entry.key] ?? lookup[entry.key];
      if (path == null || '$path'.isEmpty) continue;
      try {
        final resolved = File('$path').absolute.path;
        final loader = entry.value as YargsParserConfigLoader?;
        final config = loader?.call(resolved) ?? _loadJsonConfig(resolved);
        _setConfigObject(config);
      } catch (caught) {
        if (argv.containsKey(entry.key)) {
          error = YargsParserException(
            'Invalid JSON config file: $path',
            caught,
          );
        }
      }
    }
  }

  Map<String, Object?> _loadJsonConfig(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('A config file must contain an object.');
    }
    return decoded.map((key, value) => MapEntry('$key', value));
  }

  void _setConfigObject(Map<String, Object?> config, [String? prefix]) {
    for (final entry in config.entries) {
      final key = prefix == null ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is Map && configuration.dotNotation) {
        _setConfigObject(
          value.map((key, value) => MapEntry('$key', value)),
          key,
        );
      } else if (!_hasKey(argv, key.split('.')) ||
          (_checkAllAliases(key, flags.arrays) == true &&
              configuration.combineArrays)) {
        _setArg(key, value);
      }
    }
  }

  void _applyEnvironment({bool configOnly = false}) {
    final configuredPrefix = options.envPrefix;
    if (configuredPrefix == null) return;
    for (final entry in environment.entries) {
      if (configuredPrefix.isNotEmpty &&
          !entry.key.startsWith(configuredPrefix)) {
        continue;
      }
      final keys = entry.key.split('__').indexed.map((item) {
        final raw = item.$1 == 0
            ? item.$2.substring(configuredPrefix.length)
            : item.$2;
        return _camelCase(raw);
      }).toList();
      final key = keys.join('.');
      if ((!configOnly || flags.configs.containsKey(key)) &&
          !_hasKey(argv, keys)) {
        _setArg(key, entry.value);
      }
    }
  }

  void _applyCoercions() {
    final applied = <String>{};
    for (final key in List<String>.of(argv.keys)) {
      if (applied.contains(key)) continue;
      final coerce = _checkAllAliases(key, flags.coercions);
      if (coerce is! YargsParserCoercion) continue;
      try {
        final value = _maybeCoerceNumber(key, coerce(argv[key]));
        for (final alias in [...flags.aliases[key] ?? const [], key]) {
          applied.add(alias);
          argv[alias] = value;
        }
      } catch (caught) {
        error = caught;
      }
    }
  }

  void _applyDefaultsAndAliases(
    Map<String, Object?> target, {
    bool logDefaults = false,
  }) {
    for (final entry in defaults.entries) {
      if (_hasKey(target, entry.key.split('.'))) continue;
      _setKey(target, entry.key.split('.'), entry.value);
      if (logDefaults) defaulted[entry.key] = true;
      for (final alias in flags.aliases[entry.key] ?? const []) {
        if (!_hasKey(target, alias.split('.'))) {
          _setKey(target, alias.split('.'), entry.value);
        }
      }
    }
  }

  void _setPlaceholderKeys() {
    for (final key in flags.keys) {
      if (!key.contains('.') && !argv.containsKey(key)) {
        argv[key] = null;
      }
    }
  }

  void _stripOutput() {
    if (configuration.camelCaseExpansion && configuration.stripDashed) {
      for (final key in List<String>.of(argv.keys)) {
        if (key != '--' && key.contains('-')) {
          argv.remove(key);
        }
      }
    }
    if (configuration.stripAliased) {
      final aliasValues = aliases.values.expand((value) => value).toSet();
      for (final alias in aliasValues) {
        if (configuration.camelCaseExpansion && alias.contains('-')) {
          argv.remove(alias.split('.').map(_camelCase).join('.'));
        }
        argv.remove(alias);
      }
    }
  }

  void _setKey(
    Map<String, Object?> target,
    List<String> segments,
    Object? value,
  ) {
    final keys = configuration.dotNotation ? segments : [segments.join('.')];
    Map<String, Object?> current = target;
    for (final segment in keys.take(keys.length - 1)) {
      final key = _sanitizeKey(segment);
      final existing = current[key];
      if (existing == null) {
        final nested = <String, Object?>{};
        current[key] = nested;
        current = nested;
      } else if (existing is Map<String, Object?>) {
        current = existing;
      } else if (existing is List) {
        final nested = <String, Object?>{};
        existing.add(nested);
        current = nested;
      } else {
        final nested = <String, Object?>{};
        current[key] = <Object?>[existing, nested];
        current = nested;
      }
    }

    final key = _sanitizeKey(keys.last);
    final isTypeArray = _checkAllAliases(keys.join('.'), flags.arrays) == true;
    final isValueArray = value is List;
    var duplicate = configuration.duplicateArgumentsArray;
    if (!duplicate && _checkAllAliases(key, flags.nargs) != null) {
      duplicate = true;
      final existing = current[key];
      final narg = flags.nargs[key];
      if ((existing != null && narg == 1) ||
          (existing is List && existing.length == narg)) {
        current[key] = null;
      }
    }

    final existing = current[key];
    if (value is _CountIncrement) {
      current[key] = _increment(existing is num ? existing : null);
    } else if (existing is List) {
      if (duplicate && isTypeArray && isValueArray) {
        current[key] = configuration.flattenDuplicateArrays
            ? [...existing, ...value]
            : ((existing.isNotEmpty && existing.first is List
                    ? existing
                    : [existing])
                ..add(value));
      } else if (!duplicate && isTypeArray == isValueArray) {
        current[key] = value;
      } else {
        current[key] = [...existing, value];
      }
    } else if (existing == null && isTypeArray) {
      current[key] = isValueArray ? value : [value];
    } else if (duplicate &&
        existing != null &&
        _checkAllAliases(key, flags.counts) != true &&
        _checkAllAliases(key, flags.bools) != true) {
      current[key] = [existing, value];
    } else {
      current[key] = value;
    }
  }

  bool _hasKey(Map<String, Object?> target, List<String> segments) {
    final keys = configuration.dotNotation ? segments : [segments.join('.')];
    Object? current = target;
    for (final key in keys.take(keys.length - 1)) {
      if (current is! Map) return false;
      current = current[key];
      if (current == null) return false;
    }
    return current is Map && current.containsKey(keys.last);
  }

  void _extendAliases(Iterable<Map<String, Object?>> sources) {
    for (final source in sources) {
      for (final key in source.keys) {
        if (flags.aliases.containsKey(key)) continue;
        final values = List<String>.of(aliases[key] ?? const []);
        flags.aliases[key] = values;
        for (final candidate in [...values, key]) {
          if (candidate.contains('-') && configuration.camelCaseExpansion) {
            final camel = _camelCase(candidate);
            if (camel != key && !values.contains(camel)) {
              values.add(camel);
              newAliases[camel] = true;
            }
          }
        }
        for (final candidate in [...values, key]) {
          if (candidate.length > 1 &&
              RegExp(r'[A-Z]').hasMatch(candidate) &&
              configuration.camelCaseExpansion) {
            final dashed = _decamelize(candidate, '-');
            if (dashed != key && !values.contains(dashed)) {
              values.add(dashed);
              newAliases[dashed] = true;
            }
          }
        }
        for (final alias in values) {
          flags.aliases[alias] = [
            key,
            ...values.where((value) => value != alias),
          ];
        }
      }
    }
  }

  void _addNewAlias(String key, String alias) {
    if ((flags.aliases[key] ?? const []).isEmpty) {
      flags.aliases[key] = [alias];
      newAliases[alias] = true;
    }
    if ((flags.aliases[alias] ?? const []).isEmpty) _addNewAlias(alias, key);
  }

  Object? _checkAllAliases(String key, Map<String, Object?> source) {
    for (final candidate in [...flags.aliases[key] ?? const [], key]) {
      if (source.containsKey(candidate)) return source[candidate];
    }
    return null;
  }

  bool _hasAnyFlag(String key) {
    return flags.keys.contains(key) ||
        [
          flags.aliases,
          flags.arrays,
          flags.bools,
          flags.strings,
          flags.numbers,
          flags.counts,
          flags.normalize,
          flags.configs,
          flags.nargs,
          flags.coercions,
        ].any((source) => source.containsKey(key));
  }

  bool _unknownAsArgument(String argument, RegExp negationPattern) =>
      configuration.unknownOptionsAsArgs &&
      _isUnknownOption(argument, negationPattern);

  bool _isUnknownOption(String argument, RegExp negationPattern) {
    final normalized = argument.replaceFirst(RegExp(r'^-{3,}'), '--');
    if (_negativeNumber.hasMatch(normalized)) return false;
    if (_hasAllShortFlags(normalized)) return false;
    final patterns = [
      RegExp(r'^-+([^=]+?)=[\s\S]*$'),
      negationPattern,
      RegExp(r'^-+([^=]+?)$'),
      RegExp(r'^-+([^=]+?)-$'),
      RegExp(r'^-+([^=]+?\d+)$'),
      RegExp(r'^-+([^=]+?)\W+.*$'),
    ];
    return !patterns.any((pattern) {
      final match = pattern.firstMatch(normalized);
      return match != null && _hasAnyFlag(match.group(1)!);
    });
  }

  bool _hasAllShortFlags(String argument) {
    if (_negativeNumber.hasMatch(argument) ||
        !RegExp(r'^-[^-]+').hasMatch(argument)) {
      return false;
    }
    final letters = argument.substring(1).split('');
    for (var index = 0; index < letters.length; index++) {
      final suffix = argument.substring(index + 2);
      if (!_hasAnyFlag(letters[index])) return false;
      if ((index + 1 < letters.length && letters[index + 1] == '=') ||
          suffix == '-' ||
          (RegExp(r'[A-Za-z]').hasMatch(letters[index]) &&
              RegExp(r'^-?\d+(\.\d*)?(e-?\d+)?$').hasMatch(suffix)) ||
          (index + 1 < letters.length &&
              RegExp(r'\W').hasMatch(letters[index + 1]))) {
        break;
      }
    }
    return true;
  }

  Object? _defaultValue(String key) {
    if (_checkAllAliases(key, flags.bools) != true &&
        _checkAllAliases(key, flags.counts) != true &&
        defaults.containsKey(key)) {
      return defaults[key];
    }
    if (_checkAllAliases(key, flags.strings) == true) return '';
    if (_checkAllAliases(key, flags.numbers) == true) return null;
    if (_checkAllAliases(key, flags.arrays) == true) return <Object?>[];
    return true;
  }

  void _checkConfiguration() {
    for (final key in flags.counts.keys) {
      if (_checkAllAliases(key, flags.arrays) == true) {
        _recordError(
          'Invalid configuration: $key, opts.count excludes opts.array.',
        );
        return;
      }
      if (_checkAllAliases(key, flags.nargs) != null) {
        _recordError(
          'Invalid configuration: $key, opts.count excludes opts.narg.',
        );
        return;
      }
    }
  }

  void _recordError(String message) => error = YargsParserException(message);
}

final class _Flags {
  final Map<String, List<String>> aliases = {};
  final Map<String, Object?> arrays = {};
  final Map<String, Object?> bools = {};
  final Map<String, Object?> strings = {};
  final Map<String, Object?> numbers = {};
  final Map<String, Object?> counts = {};
  final Map<String, Object?> normalize = {};
  final Map<String, Object?> configs = {};
  final Map<String, Object?> nargs = {};
  final Map<String, Object?> coercions = {};
  final List<String> keys = [];
}

Map<String, List<String>> _combineAliases(
  Map<String, Iterable<String>> aliases,
) {
  final groups = <List<String>>[];
  for (final entry in aliases.entries) {
    groups.add([...entry.value, entry.key]);
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (var index = 0; index < groups.length; index++) {
      for (var other = index + 1; other < groups.length; other++) {
        if (groups[index].any(groups[other].contains)) {
          groups[index].addAll(groups[other]);
          groups.removeAt(other);
          changed = true;
          break;
        }
      }
      if (changed) break;
    }
  }
  final combined = <String, List<String>>{};
  for (final group in groups) {
    final unique = group.toSet().toList();
    if (unique.isNotEmpty) {
      final key = unique.removeLast();
      combined[key] = unique;
    }
  }
  return combined;
}

final class _CountIncrement {
  const _CountIncrement();
}

_CountIncrement _countIncrement() => const _CountIncrement();

num _increment([num? value]) => value == null ? 1 : value + 1;

String _sanitizeKey(String key) => key == '__proto__' ? '___proto___' : key;

String _stripQuotes(String value) {
  if (value.length >= 2 &&
      (value.startsWith("'") || value.startsWith('"')) &&
      value.endsWith(value[0])) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

String _camelCase(String value) {
  final isMixedCase =
      value != value.toLowerCase() && value != value.toUpperCase();
  final source = isMixedCase ? value : value.toLowerCase();
  if (!source.contains('-') && !source.contains('_')) return source;
  final output = StringBuffer();
  var uppercaseNext = false;
  final leading = RegExp(r'^-+').firstMatch(source)?.group(0)?.length ?? 0;
  for (var index = leading; index < source.length; index++) {
    var character = source[index];
    if (uppercaseNext) {
      uppercaseNext = false;
      character = character.toUpperCase();
    }
    if (index != 0 && (character == '-' || character == '_')) {
      uppercaseNext = true;
    } else if (character != '-' && character != '_') {
      output.write(character);
    }
  }
  return output.toString();
}

String _decamelize(String value, String join) {
  final lowercase = value.toLowerCase();
  final output = StringBuffer();
  for (var index = 0; index < value.length; index++) {
    if (lowercase[index] != value[index] && index > 0) {
      output
        ..write(join)
        ..write(lowercase[index]);
    } else {
      output.write(value[index]);
    }
  }
  return output.toString();
}

bool _looksLikeNumber(Object? value) {
  if (value == null) return false;
  if (value is num) return true;
  final text = '$value';
  if (RegExp(r'^0x[0-9a-f]+$', caseSensitive: false).hasMatch(text)) {
    return true;
  }
  if (RegExp(r'^0[^.]').hasMatch(text)) {
    return false;
  }
  return RegExp(r'^-?(?:\d+(?:\.\d*)?|\.\d+)(e[-+]?\d+)?$').hasMatch(text);
}

bool _isSafeNumeric(Object? value) {
  if (value == null) return false;
  final number = _parseNumber(value);
  return number is int ||
      (number is double && number.isFinite && number.abs() <= 9007199254740991);
}

num _parseNumber(Object? value) {
  final text = '$value';
  if (text.startsWith('0x') || text.startsWith('0X')) {
    return int.parse(text.substring(2), radix: 16);
  }
  return num.parse(text);
}

Object? _normalize(Object? value) =>
    value is String ? _normalizePath(value) : value;

/// Mirrors `path.normalize()` rather than resolving against the current folder.
///
/// A normalize hint changes separators and removes lexical `.`/`..` segments;
/// it must not turn a relative argument into an absolute path.
String _normalizePath(String value) {
  if (value.isEmpty) return '.';

  final isWindows = Platform.isWindows;
  final separator = isWindows ? '\\' : '/';
  final hasTrailingSeparator = RegExp(r'[\\/]$').hasMatch(value);
  final driveMatch = isWindows ? RegExp(r'^[A-Za-z]:').firstMatch(value) : null;
  final drive = driveMatch?.group(0) ?? '';
  var remainder = value.substring(drive.length);
  final absolute = remainder.startsWith('/') || remainder.startsWith('\\');
  final segments = <String>[];

  for (final segment in remainder.split(RegExp(r'[\\/]+'))) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else if (!absolute) {
        segments.add(segment);
      }
      continue;
    }
    segments.add(segment);
  }

  final joined = segments.join(separator);
  final root = absolute ? '$drive$separator' : drive;
  var normalized = root + joined;
  if (normalized.isEmpty) normalized = absolute ? separator : '.';
  if (hasTrailingSeparator &&
      normalized != separator &&
      !normalized.endsWith(separator)) {
    normalized += separator;
  }
  return normalized;
}
