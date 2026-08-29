import 'dart:async';
import 'dart:convert';

import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';

/// A named value that a [Command] can register for an invocation.
///
/// Every input has a long name and an optional human-readable description used
/// by help formatters.
sealed class NamedInput {
  const NamedInput(this.name, this.description);

  final String name;
  final String? description;
}

/// Exposes the pattern used to validate candidate values.
mixin RegExpValidated {
  /// Pattern every validated value must match entirely.
  RegExp get regex;

  static final RegExp anyToken = RegExp(r"\S+");
}

/// Exposes the enum members available to a choice input.
mixin ChoiceValidated<T extends Enum> {
  /// Members every validated value must name.
  List<T> get choices;
}

/// A regex-validated value registered in a command's positional sequence.
///
/// Register it in `mandatoryPositionals` or `discretionaryPositionals`; the
/// parser stores its complete-token match in [ParsedPositionals], and help
/// renders it as required or optional usage respectively.
class Positional extends NamedInput with RegExpValidated {
  Positional(String name, {String? description, RegExp? regex})
    : _regExp = regex ?? RegExpValidated.anyToken,
      super(name, description);

  final RegExp _regExp;

  @override
  RegExp get regex => _regExp;
}

final class NormalPositional extends Positional {
  NormalPositional(super.name, {super.description, RegExp? regExp})
    : super(regex: regExp);
}

final class ChoicePositional<T extends Enum> extends Positional
    with ChoiceValidated<T> {
  @override
  final List<T> choices;
  final T? defaultValue;
  ChoicePositional(
    super.name, {
    super.description,
    required this.choices,
    this.defaultValue,
  });
}

/// A named, validated sequence of values supplied after `--`.
///
/// Register it in `variadic`; the parser leaves ordinary positionals to the
/// mandatory and discretionary definitions, then validates every token after
/// `--` and stores the values in the `variadic` map of [ParsedPositionals].
sealed class Variadic extends NamedInput {
  const Variadic(String name, {String? description}) : super(name, description);
}

final class NormalVariadic extends Variadic with RegExpValidated {
  final RegExp regExp;

  NormalVariadic(super.name, {super.description, RegExp? regExp})
    : regExp = regExp ?? RegExpValidated.anyToken;

  @override
  RegExp get regex => regExp;
}

final class ChoiceVariadic<T extends Enum> extends Variadic
    with ChoiceValidated<T> {
  @override
  final List<T> choices;
  final T? defaultValue;
  const ChoiceVariadic(
    super.name, {
    super.description,
    required this.choices,
    this.defaultValue,
  });
}

/// A choice variadic whose strict choices repeat across dash arguments.
///
/// It parses exactly like [ChoiceVariadic]; completions render its choices as
/// an unbounded series.
final class RepeatedChoiceVariadic<T extends Enum> extends ChoiceVariadic<T> {
  const RepeatedChoiceVariadic(
    super.name, {
    super.description,
    required super.choices,
    super.defaultValue,
  });
}

/// A positional that collects several tokens, one per repetition plus the
/// original.
///
/// The maximum number of repetitions defaults to 1, so a repeated positional
/// accepts up to two values unless raised. The parser gathers its values into
/// the `repeated` map of [ParsedPositionals].
sealed class RepeatedPositional extends Positional {
  /// Maximum number of repetitions; accepts one value per repetition plus the
  /// original, so the default of 1 collects up to two values.
  final int times;

  RepeatedPositional(
    super.name, {
    super.description,
    super.regex,
    this.times = 1,
  }) {
    if (times < 0) {
      throw MambaRegistryError.value(times, 'times', 'must not be negative');
    }
  }
}

final class RepeatedStringPositional extends RepeatedPositional {
  RepeatedStringPositional(
    super.name, {
    super.description,
    RegExp? regExp,
    super.times = 1,
  }) : super(regex: regExp);
}

final class RepeatedChoicePositional<T extends Enum> extends RepeatedPositional
    with ChoiceValidated<T> {
  @override
  final List<T> choices;
  final T? defaultValue;

  RepeatedChoicePositional(
    super.name, {
    super.description,
    required this.choices,
    this.defaultValue,
    super.times = 1,
  });
}

/// A valueless named input registered in a command's flag collection.
///
/// Flags have optional one-letter aliases. Hidden flags remain parseable but
/// are omitted from the Flags help section.
sealed class Flag extends NamedInput {
  const Flag(
    String name, {
    required this.short,
    String? description,
    this.hidden = false,
  }) : super(name, description);

  final String? short;
  final bool hidden;
}

/// A flag that registers a boolean value, default, and optional negated form.
///
/// The parser accepts its long name, short alias, and short bundles; a
/// negatable flag also accepts `--no-name`. Help lists visible flags in Flags.
final class BooleanFlag extends Flag {
  BooleanFlag(
    super.name, {
    super.short,
    super.description,
    super.hidden,
    this.defaultValue = false,
    this.negatable = false,
  });

  final bool defaultValue;
  final bool negatable;
}

/// A flag whose registered value is incremented for every occurrence.
///
/// The parser accepts long, short, and bundled-short forms and returns its
/// count. Help lists visible count flags in Flags.
final class CountFlag extends Flag {
  const CountFlag(super.name, {super.short, super.description, super.hidden});
}

/// A value-taking input registered in a command's option collection.
///
/// Options accept long and optional short forms. Required options must be
/// supplied; hidden options are not rendered in the Options help section.
sealed class Option extends NamedInput {
  const Option(
    String name, {
    required this.short,
    String? description,
    this.required = false,
    this.hidden = false,
  }) : super(name, description);

  final String? short;
  final bool required;
  final bool hidden;
}

/// A standalone registration that groups pair options.
///
/// The group itself is not an input. Its [options] are registered and parsed as
/// a unit; [required] makes the group mandatory and [variant] makes members
/// alternatives.
class PairedOptions {
  PairedOptions({
    required List<PairOption> options,
    this.description,
    this.required = false,
    this.variant = false,
  }) : options = List.unmodifiable(options);

  final List<PairOption> options;
  final String? description;
  final bool required;
  final bool variant;
}

/// A companion value registered as a member of a [PairedOptions].
///
/// Pair members inherit group requiredness and variant behavior from their
/// primary option. The parser stores their values in the same typed maps as
/// ordinary options, and help renders them within the group's expression.
sealed class PairOption extends NamedInput {
  final String? short;
  const PairOption(String name, {required this.short, String? description})
    : super(name, description);
}

/// A regex-validated string companion in a paired option registration.

/// A regex-validated string companion in a paired option registration.
final class PairStringOption extends PairOption with RegExpValidated {
  PairStringOption(super.name, {RegExp? regex, super.short, super.description})
    : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// An integer companion in a paired option registration.
final class PairIntOption extends PairOption {
  const PairIntOption(super.name, {super.short, super.description});
}

/// A double companion in a paired option registration.
final class PairDoubleOption extends PairOption {
  const PairDoubleOption(super.name, {super.short, super.description});
}

/// An enum-choice companion in a paired option registration.
final class PairChoiceOption<T extends Enum> extends PairOption
    with ChoiceValidated<T> {
  const PairChoiceOption(
    super.name, {
    required this.choices,
    this.defaultValue,
    super.short,
    super.description,
  });

  @override
  final List<T> choices;
  final T? defaultValue;
}

/// A paired companion that accumulates each supplied value into a typed list.
sealed class RepeatablePairOption extends PairOption {
  const RepeatablePairOption(super.name, {super.short, super.description});
}

/// A repeatable string companion in a paired option registration.
final class RepeatablePairStringOption extends RepeatablePairOption
    with RegExpValidated {
  RepeatablePairStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// A repeatable integer companion in a paired option registration.
final class RepeatablePairIntOption extends RepeatablePairOption {
  const RepeatablePairIntOption(super.name, {super.short, super.description});
}

/// A repeatable double companion in a paired option registration.
final class RepeatablePairDoubleOption extends RepeatablePairOption {
  const RepeatablePairDoubleOption(
    super.name, {
    super.short,
    super.description,
  });
}

/// A non-repeatable option that stores one typed value by name.
sealed class SingleOption extends Option {
  const SingleOption(
    super.name, {
    required super.short,
    required super.description,
    super.required,
    super.hidden,
  });
}

/// A single string option validated by [regex].
final class StringOption extends SingleOption with RegExpValidated {
  const StringOption(
    super.name, {
    required this.regex,
    super.short,
    super.description,
    super.required,
    super.hidden,
  });

  @override
  final RegExp regex;
}

/// A single option that accepts a signed decimal integer.
final class IntOption extends SingleOption {
  const IntOption(
    super.name, {
    super.short,
    super.required,
    super.description,
    super.hidden,
  });
}

/// A single option that accepts a signed decimal number.
final class DoubleOption extends SingleOption {
  const DoubleOption(
    super.name, {
    super.short,
    super.required,
    super.description,
    super.hidden,
  });
}

/// A single option that accepts one registered enum-member name.
///
/// The parser stores the selected member name and supplies [defaultValue] when
/// the option is omitted.
final class ChoiceOption<T extends Enum> extends SingleOption
    with ChoiceValidated<T> {
  const ChoiceOption(
    super.name, {
    this.defaultValue,
    required this.choices,
    super.short,
    super.description,
    super.required,
    super.hidden,
  });

  @override
  final List<T> choices;
  final T? defaultValue;
}

/// An option that accumulates every supplied value into a typed list.
sealed class RepeatableOption extends Option {
  const RepeatableOption(
    super.name, {
    required super.required,
    super.short,
    super.description,
    super.hidden,
  });
}

/// A repeatable string option validated by [regex].
final class RepeatableStringOption extends RepeatableOption
    with RegExpValidated {
  RepeatableStringOption(
    super.name, {
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// A repeatable option that accepts signed decimal integers.
final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption(
    super.name, {
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });
}

/// A repeatable option that accepts signed decimal numbers.
final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption(
    super.name, {
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });
}

/// A named leaf or object registered for dotted accessor syntax.
///
/// Accessors are parsed from long dotted paths and returned in the nested
/// `accessors` map of [ParsedNamedInputs]. Visible leaves appear in Accessor
/// flags help.
sealed class AccessorOption extends NamedInput {
  const AccessorOption(String name, {String? description})
    : super(name, description);
}

/// A value-taking leaf in an accessor registration tree.
sealed class AccessorPrimitiveOption extends AccessorOption {
  const AccessorPrimitiveOption(super.name, {super.description});
}

/// An object node that groups nested [AccessorOption] registrations.
///
/// Its name forms one dotted-path segment. A hidden list hides every descendant
/// from help while preserving the complete accessor path for parsing.
final class AccessorListOption extends AccessorOption {
  AccessorListOption(
    super.name, {
    super.description,
    this.hidden = false,
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options);

  final bool hidden;
  final List<AccessorOption> options;
}

/// A regex-validated string leaf in a dotted accessor path.
final class AccessorStringOption extends AccessorPrimitiveOption
    with RegExpValidated {
  AccessorStringOption(super.name, {super.description, RegExp? regex})
    : _regExp = regex ?? RegExp(r'\S+');

  final RegExp _regExp;
  @override
  RegExp get regex => _regExp;
}

/// An integer leaf in a dotted accessor path.
final class AccessorIntOption extends AccessorPrimitiveOption {
  AccessorIntOption(super.name, {super.description});

  RegExp get regex => RegExp(r'[+-]?\d+');
}

/// A double leaf in a dotted accessor path.
final class AccessorDoubleOption extends AccessorPrimitiveOption {
  AccessorDoubleOption(super.name, {super.description});

  RegExp get regex => RegExp(r'[+-]?(?:\d+\.\d+|\d+)');
}

/// An enum-choice leaf in a dotted accessor path.
///
/// The parser stores the selected member name and merges [defaultValue] when it
/// is omitted.
final class AccessorChoiceOption<T extends Enum> extends AccessorPrimitiveOption
    with ChoiceValidated<T> {
  AccessorChoiceOption(
    super.name, {
    required this.choices,
    this.defaultValue,
    super.description,
  });

  @override
  final List<T> choices;
  final T? defaultValue;
}

/// Parsed command inputs grouped by their concrete value type.
typedef ParsedNamedInputs = ({
  Map<String, bool>? boolFlags,
  Map<String, int>? countFlags,
  Map<String, String>? stringOptions,
  Map<String, int>? intOptions,
  Map<String, double>? doubleOptions,
  Map<String, List<String>>? repeatedStringOptions,
  Map<String, List<int>>? repeatedIntOptions,
  Map<String, List<double>>? repeatedDoubleOptions,
  Map<String, dynamic>? accessors,
});

/// The non-repeated ordinary options available to hook callbacks.
typedef ParsedSingleOptions = ({
  Map<String, String>? stringOptions,
  Map<String, int>? intOptions,
  Map<String, double>? doubleOptions,
});

/// Positional values keyed by their registered name and split by kind:
/// single positionals hold one string while repeated positionals hold every
/// collected value. Each map is `null` when no such positional is registered
/// or supplied.
typedef ParsedPositionals = ({
  Map<String, String>? singles,
  Map<String, List<String>>? repeated,

  /// Values after `--` keyed by their registered variadic name; `null` when no
  /// registered variadic value is supplied.
  Map<String, List<String>>? variadic,
});

/// A declarative command definition and its executable behavior.
///
/// Subclasses register aliases, positionals, flags, options, paired options,
/// and accessors through this constructor, then provide [name],
/// [shortDescription], and [run]. The executor gives [run] the values
/// validated by the parser.
abstract class Command {
  final String? longDescription;

  /// Alternative names used to select this command among its siblings.
  final List<String>? aliases;
  final List<Positional>? mandatoryPositionals;
  final List<Positional>? discretionaryPositionals;

  /// Input validating and naming values supplied after `--`.
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOptions>? pairedOptions;

  /// Top-level accessor groups registered for this command.
  ///
  /// Leaf accessors are declared inside each [AccessorListOption].
  final List<AccessorListOption>? accessors;

  Command({
    this.longDescription,
    this.aliases,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.flags,
    this.options,
    this.pairedOptions,
    this.accessors,
  });

  String get name;
  String get shortDescription;

  /// Runs this command with parser-validated values and trailing arguments.
  ///
  /// The returned text is delivered to the executor's output environment.
  /// Returns `null` when no output should be produced.
  FutureOr<String?> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  );
}

/// A command that registers children and can run one by a relative path.
///
/// Group commands contribute nested command registries. Their inherited flags
/// and options are published to descendants, and [defaultSubCommandPath] can
/// select a child when no explicit child is supplied.
abstract class GroupCommand extends Command {
  final List<String>? defaultSubCommandPath;
  final List<Flag>? inheritedFlags;
  final List<Option>? inheritedOptions;
  final List<Command> commands;

  GroupCommand(
    this.commands, {
    List<String>? defaultSubCommandPath,
    super.aliases,
    this.inheritedFlags,
    this.inheritedOptions,
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
  }) : defaultSubCommandPath = _copyDefaultSubCommandPath(
         defaultSubCommandPath,
       ) {
    if (this.defaultSubCommandPath?.contains(name) == true) {
      throw ArgumentError.value(
        defaultSubCommandPath,
        'defaultSubCommandPath',
        'must be relative to the group command',
      );
    }
  }

  @override
  String get name;
  @override
  String get shortDescription;

  /// Runs the descendant addressed by a non-empty relative [path].
  FutureOr<String> runChildCommand(
    List<String> path,
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) async {
    if (path.isEmpty) {
      throw ArgumentError('path is empty', 'path');
    }
    if (path.contains(name)) {
      throw ArgumentError.value(
        path,
        'path',
        'must be relative to the group command',
      );
    }

    Command? command;
    List<Command>? children = commands;
    for (final name in path) {
      command = children
          ?.where(
            (candidate) =>
                candidate.name == name ||
                candidate.aliases?.contains(name) == true,
          )
          .firstOrNull;
      if (command == null) {
        throw MambaException(
          'command not found in ${this.name} ${path.join(" ")}',
        );
      }
      children = command is GroupCommand ? command.commands : null;
    }

    return (await command!.run(positionals, input, trailingArguments)) ?? '';
  }

  static List<String>? _copyDefaultSubCommandPath(List<String>? path) {
    if (path == null) return null;
    if (path.isEmpty) {
      throw ArgumentError.value(
        path,
        'defaultSubCommandPath',
        'must not be empty',
      );
    }
    if (path.any((name) => name.isEmpty)) {
      throw ArgumentError.value(
        path,
        'defaultSubCommandPath',
        'must contain command names',
      );
    }
    return List.unmodifiable(path);
  }

  @override
  FutureOr<String?> run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) async {
    final path = defaultSubCommandPath;
    if (path == null) return '';
    return runChildCommand(path, positionals, input, trailingArguments);
  }
}

/// Properties accepted in a serialised [CommandRegistry] map.
///
/// Each property validates the shape written by [CommandRegistry.toMap]. The
/// optional [path] preserves the full location of malformed nested data in an
/// [ArgumentError].
enum RegistryMapProps {
  name,
  description,
  flags,
  persistentFlags,
  persistentOptions,
  options,
  commands,
  accessors,
  aliases,
  positionals,
  variadic;

  Object? parse(Object? value, [String? path]) {
    final propertyPath = path ?? this.name;
    switch (this) {
      case RegistryMapProps.name:
      case RegistryMapProps.description:
        _expectString(value, propertyPath);
      case RegistryMapProps.flags:
      case RegistryMapProps.persistentFlags:
        _parseInputCollection(value, propertyPath, _parseFlag);
      case RegistryMapProps.options:
      case RegistryMapProps.persistentOptions:
        _parseInputCollection(value, propertyPath, _parseOption);
      case RegistryMapProps.commands:
        _parseCommands(value, propertyPath);
      case RegistryMapProps.accessors:
        _parseAccessors(value, propertyPath);
      case RegistryMapProps.aliases:
        _parseAliases(value, propertyPath);
      case RegistryMapProps.positionals:
        _parseInputCollection(value, propertyPath, _parsePositional);
      case RegistryMapProps.variadic:
        _parseVariadic(value, propertyPath);
    }
    return value;
  }
}

/// A validated serialisable representation of a command registry.
///
/// The root map and every nested command must contain a string `name` and
/// `description`. All other registry properties are optional.
extension type RegistryMap._(Map<String, dynamic> map) {
  RegistryMap(Map<String, dynamic> map) : this._(_parse(map));

  static Map<String, dynamic> _parse(Map<String, dynamic> map) {
    _parseCommand(map, '');
    return Map<String, dynamic>.unmodifiable(map);
  }
}

void _parseCommand(Map<Object?, Object?> value, String path) {
  final properties = _stringMap(value, path);
  _validateProperties(
    properties,
    path,
    RegistryMapProps.values.map((property) => property.name).toSet(),
    const {'name', 'description'},
  );

  for (final property in RegistryMapProps.values) {
    final propertyValue = properties[property.name];
    if (propertyValue != null || properties.containsKey(property.name)) {
      property.parse(propertyValue, _joinRegistryPath(path, property.name));
    }
  }
}

void _parseCommands(Object? value, String path) {
  final commands = _stringMap(value, path);
  for (final entry in commands.entries) {
    final commandPath = _joinRegistryPath(path, entry.key);
    _parseCommand(_map(entry.value, commandPath), commandPath);
  }
}

void _parseInputCollection(
  Object? value,
  String path,
  void Function(Map<String, Object?> value, String path) parseInput,
) {
  final inputs = _stringMap(value, path);
  for (final entry in inputs.entries) {
    final inputPath = _joinRegistryPath(path, entry.key);
    parseInput(_map(entry.value, inputPath), inputPath);
  }
}

void _parseFlag(Map<String, Object?> value, String path) {
  const commonProperties = {'hidden', 'description'};
  const booleanProperties = {'short', 'default', 'negatable'};
  final isBoolean =
      value.containsKey('default') || value.containsKey('negatable');
  _validateProperties(
    value,
    path,
    {...commonProperties, ...booleanProperties},
    isBoolean ? {...commonProperties, ...booleanProperties} : commonProperties,
  );

  _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );

  if (isBoolean) {
    _expectString(
      value['short'],
      _joinRegistryPath(path, 'short'),
      nullable: true,
    );
    _expectBool(value['default'], _joinRegistryPath(path, 'default'));
    _expectBool(value['negatable'], _joinRegistryPath(path, 'negatable'));
  } else if (value.containsKey('short')) {
    _expectString(value['short'], _joinRegistryPath(path, 'short'));
  }
}

void _parseOption(Map<String, Object?> value, String path) {
  const requiredProperties = {
    'short',
    'required',
    'hidden',
    'description',
    'valueType',
  };
  const optionalProperties = {
    'repeatable',
    'variant',
    'choices',
    'default',
    'pairedOptions',
  };
  _validateProperties(value, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);

  _expectString(
    value['short'],
    _joinRegistryPath(path, 'short'),
    nullable: true,
  );
  _expectBool(value['required'], _joinRegistryPath(path, 'required'));
  _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );

  if (value.containsKey('repeatable')) {
    _expectBool(value['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (value.containsKey('variant')) {
    _expectBool(value['variant'], _joinRegistryPath(path, 'variant'));
  }
  if (value.containsKey('choices')) {
    _parseStringList(value['choices'], _joinRegistryPath(path, 'choices'));
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], _joinRegistryPath(path, 'default'));
  }
  if (value.containsKey('valueType')) {
    _expectValueType(value['valueType'], _joinRegistryPath(path, 'valueType'));
  }
  if (value.containsKey('pairedOptions')) {
    _parseStringList(
      value['pairedOptions'],
      _joinRegistryPath(path, 'pairedOptions'),
    );
  }
}

void _parsePositional(Map<String, Object?> value, String path) {
  const requiredProperties = {'required', 'description'};
  const optionalProperties = {'choices', 'default', 'repeatable', 'times'};
  _validateProperties(value, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);
  _expectBool(value['required'], _joinRegistryPath(path, 'required'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
  if (value.containsKey('choices')) {
    _parseStringList(value['choices'], _joinRegistryPath(path, 'choices'));
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], _joinRegistryPath(path, 'default'));
  }
  if (value.containsKey('repeatable')) {
    _expectBool(value['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (value.containsKey('times')) {
    _expectNonNegativeInt(value['times'], _joinRegistryPath(path, 'times'));
  }
}

void _parseVariadic(Object? value, String path) {
  final variadic = _map(value, path);
  const requiredProperties = {'description'};
  const optionalProperties = {'choices', 'default', 'repeatable'};
  _validateProperties(variadic, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);
  _expectString(
    variadic['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
  if (variadic.containsKey('choices')) {
    _parseStringList(variadic['choices'], _joinRegistryPath(path, 'choices'));
  }
  if (variadic.containsKey('default')) {
    _expectString(variadic['default'], _joinRegistryPath(path, 'default'));
  }
  if (variadic.containsKey('repeatable')) {
    _expectBool(variadic['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
}

void _parseAliases(Object? value, String path) => _parseStringList(value, path);

void _parseAccessors(Object? value, String path) {
  final accessors = _stringMap(value, path);
  for (final entry in accessors.entries) {
    _parseAccessorRoot(
      _map(entry.value, _joinRegistryPath(path, entry.key)),
      _joinRegistryPath(path, entry.key),
    );
  }
}

void _parseAccessorRoot(Map<String, Object?> value, String path) {
  if (value.containsKey('options')) {
    const properties = {'hidden', 'description', 'options'};
    _validateProperties(value, path, properties, {'description', 'options'});
    _parseHiddenAccessor(value, path);

    final options = _stringMap(
      value['options'],
      _joinRegistryPath(path, 'options'),
    );
    for (final entry in options.entries) {
      final optionPath = _joinRegistryPath(
        _joinRegistryPath(path, 'options'),
        entry.key,
      );
      final option = _map(entry.value, optionPath);
      _validateProperties(option, optionPath, {'description'}, {'description'});
      _expectString(
        option['description'],
        _joinRegistryPath(optionPath, 'description'),
        nullable: true,
      );
    }
    return;
  }
  _parseAccessorBranch(value, path);
}

void _parseAccessorBranch(Map<String, Object?> value, String path) {
  for (final entry in value.entries) {
    final entryPath = _joinRegistryPath(path, entry.key);
    // A nested accessor may itself be named `hidden`, so only a bool at this
    // level is metadata; strings, nulls, and maps are accessor values.
    if (entry.key == 'hidden' && entry.value is bool) continue;
    if (entry.value is Map) {
      _parseAccessorBranch(_map(entry.value, entryPath), entryPath);
    } else {
      _expectString(entry.value, entryPath, nullable: true);
    }
  }
}

void _parseHiddenAccessor(Map<String, Object?> value, String path) {
  if (value.containsKey('hidden')) {
    _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
  }
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
}

void _validateProperties(
  Map<String, Object?> value,
  String path,
  Set<String> allowedProperties,
  Set<String> requiredProperties,
) {
  for (final entry in value.entries) {
    if (!allowedProperties.contains(entry.key)) {
      _invalid(
        entry.value,
        _joinRegistryPath(path, entry.key),
        'is not a supported registry property',
      );
    }
  }
  for (final property in requiredProperties) {
    if (!value.containsKey(property)) {
      _invalid(value, _joinRegistryPath(path, property), 'is required');
    }
  }
}

Map<String, Object?> _map(Object? value, String path) =>
    _stringMap(value, path);

Map<String, Object?> _stringMap(Object? value, String path) {
  if (value is! Map) {
    _invalid(value, path, 'must be a map with String keys');
  }
  final parsed = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) {
      _invalid(key, path, 'map keys must be non-empty Strings');
    }
    parsed[key] = entry.value;
  }
  return parsed;
}

void _parseStringList(Object? value, String path) {
  if (value is! List) {
    _invalid(value, path, 'must be a List<String>');
  }
  for (final (index, entry) in value.indexed) {
    _expectString(entry, _joinRegistryPath(path, index.toString()));
  }
}

void _expectString(Object? value, String path, {bool nullable = false}) {
  if (value == null && nullable) return;
  if (value is! String) _invalid(value, path, 'must be a String');
}

void _expectBool(Object? value, String path) {
  if (value is! bool) _invalid(value, path, 'must be a bool');
}

void _expectNonNegativeInt(Object? value, String path) {
  if (value is! int || value < 0) {
    _invalid(value, path, 'must be a non-negative int');
  }
}

void _expectValueType(Object? value, String path) {
  const valueTypes = {'string', 'int', 'double', 'choice'};
  if (value is! String || !valueTypes.contains(value)) {
    _invalid(value, path, 'must be a supported option value type');
  }
}

String _joinRegistryPath(String parent, String property) =>
    parent.isEmpty ? property : '$parent.$property';

Never _invalid(Object? value, String path, String message) =>
    throw ArgumentError.value(value, path, message);

/// A command that generates output from the executor's complete command map.
///
/// The [Executor] assigns [registryMap] when it creates an execution
/// environment. Subclasses can pass this validated map to an integration
/// without creating or retaining a live registry.
abstract class CompletionCommand extends Command {
  late final RegistryMap registryMap;

  CompletionCommand({
    super.longDescription,
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
  });
}

/// Standard input captured for a selected command's pre-run hook.
///
/// The executor provides this only when standard input is piped. Consumers can
/// interpret the captured bytes as character, UTF-8, or JSON data.
final class ProcessedStandardInput {
  final List<int> bytes;
  ProcessedStandardInput(this.bytes);

  String get text => String.fromCharCodes(bytes);

  String get utf8Text => utf8.decode(bytes);

  dynamic get json => jsonDecode(utf8Text);
}

/// Adds hooks around the selected command's [Command.run] invocation.
///
/// [preRun] receives piped standard input, a read-only context, positionals,
/// and non-repeated ordinary options. [postRun] runs after the command.
mixin HookRunner on Command {
  /// Runs before the selected command.
  void preRun(
    ProcessedStandardInput? input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  );

  /// Runs after the selected command.
  FutureOr<void> postRun(MambaReadContext context) {}
}

/// Adds hooks around a descendant execution while retaining mutable context.
///
/// A group's persistent pre-hook runs before its selected descendant, and its
/// post-hook runs afterward in reverse group-path order. Context mutations are
/// visible to descendant commands and hooks.
mixin PersistentHookRunner on GroupCommand {
  /// Runs before a selected descendant command.
  void prePersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  );

  /// Runs after a selected descendant command.
  FutureOr<void> postPersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {}
}
