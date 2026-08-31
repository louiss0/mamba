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

/// Exposes optional inclusive bounds for a numeric input.
mixin NumericRangeValidated<T extends num> {
  T? get min;
  T? get max;
}

List<T>? _copyList<T>(List<T>? items) =>
    items == null ? null : List.unmodifiable(items);

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
    required List<T> choices,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices);
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
  ChoiceVariadic(
    super.name, {
    super.description,
    required List<T> choices,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices);
}

/// A choice variadic whose strict choices repeat across dash arguments.
///
/// [ChoiceVariadic] accepts one trailing choice. This subtype accepts every
/// trailing choice and renders completions as an unbounded series.
final class RepeatedChoiceVariadic<T extends Enum> extends ChoiceVariadic<T> {
  RepeatedChoiceVariadic(
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
    required List<T> choices,
    this.defaultValue,
    super.times = 1,
  }) : choices = List.unmodifiable(choices);
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
/// [PairedOptions] group. The parser stores their values in the same typed
/// maps as ordinary options, and help renders them within the group's
/// expression.
sealed class PairOption extends NamedInput {
  final String? short;
  const PairOption(String name, {required this.short, String? description})
    : super(name, description);
}

/// A regex-validated string companion in a paired option registration.
final class PairStringOption extends PairOption with RegExpValidated {
  PairStringOption(super.name, {RegExp? regex, super.short, super.description})
    : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// An integer companion in a paired option registration.
final class PairIntOption extends PairOption with NumericRangeValidated<int> {
  const PairIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });

  @override
  final int? min;
  @override
  final int? max;
}

/// A double companion in a paired option registration.
final class PairDoubleOption extends PairOption
    with NumericRangeValidated<double> {
  const PairDoubleOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });

  @override
  final double? min;
  @override
  final double? max;
}

/// An enum-choice companion in a paired option registration.
///
/// Pair options never declare defaults; an omitted pair group stays unset
/// instead of being completed through member defaults.
final class PairChoiceOption<T extends Enum> extends PairOption
    with ChoiceValidated<T> {
  PairChoiceOption(
    super.name, {
    required List<T> choices,
    super.short,
    super.description,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
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
final class RepeatablePairIntOption extends RepeatablePairOption
    with NumericRangeValidated<int> {
  const RepeatablePairIntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });

  @override
  final int? min;
  @override
  final int? max;
}

/// A repeatable double companion in a paired option registration.
final class RepeatablePairDoubleOption extends RepeatablePairOption
    with NumericRangeValidated<double> {
  const RepeatablePairDoubleOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.description,
  });

  @override
  final double? min;
  @override
  final double? max;
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
  StringOption(
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
final class IntOption extends SingleOption with NumericRangeValidated<int> {
  const IntOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.required,
    super.description,
    super.hidden,
  });

  @override
  final int? min;
  @override
  final int? max;
}

/// A single option that accepts a signed decimal number.
final class DoubleOption extends SingleOption
    with NumericRangeValidated<double> {
  const DoubleOption(
    super.name, {
    this.min,
    this.max,
    super.short,
    super.required,
    super.description,
    super.hidden,
  });

  @override
  final double? min;
  @override
  final double? max;
}

/// A single option that accepts one registered enum-member name.
///
/// The parser stores the selected member name and supplies [defaultValue] when
/// the option is omitted.
final class ChoiceOption<T extends Enum> extends SingleOption
    with ChoiceValidated<T> {
  ChoiceOption(
    super.name, {
    this.defaultValue,
    required List<T> choices,
    super.short,
    super.description,
    super.required,
    super.hidden,
  }) : choices = List.unmodifiable(choices);

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
final class RepeatableIntOption extends RepeatableOption
    with NumericRangeValidated<int> {
  const RepeatableIntOption(
    super.name, {
    this.min,
    this.max,
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });

  @override
  final int? min;
  @override
  final int? max;
}

/// A repeatable option that accepts signed decimal numbers.
final class RepeatableDoubleOption extends RepeatableOption
    with NumericRangeValidated<double> {
  const RepeatableDoubleOption(
    super.name, {
    this.min,
    this.max,
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });

  @override
  final double? min;
  @override
  final double? max;
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
    required List<T> choices,
    this.defaultValue,
    super.description,
  }) : choices = List.unmodifiable(choices);

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

/// All parsed single-valued string, integer, and double option members
/// available to hook callbacks, including single-valued paired members.
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
    List<String>? aliases,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    this.variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<AccessorListOption>? accessors,
  }) : aliases = _copyList(aliases),
       mandatoryPositionals = _copyList(mandatoryPositionals),
       discretionaryPositionals = _copyList(discretionaryPositionals),
       flags = _copyList(flags),
       options = _copyList(options),
       pairedOptions = _copyList(pairedOptions),
       accessors = _copyList(accessors);

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
    List<Command> commands, {
    List<String>? defaultSubCommandPath,
    super.aliases,
    List<Flag>? inheritedFlags,
    List<Option>? inheritedOptions,
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
  }) : commands = List.unmodifiable(commands),
       inheritedFlags = _copyList(inheritedFlags),
       inheritedOptions = _copyList(inheritedOptions),
       defaultSubCommandPath = _copyDefaultSubCommandPath(
         defaultSubCommandPath,
       ) {
    if (this.defaultSubCommandPath?.contains(name) == true) {
      throw MambaRegistryError.value(
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
      throw MambaRegistryError.value(
        path,
        'defaultSubCommandPath',
        'must not be empty',
      );
    }
    if (path.any((name) => name.isEmpty)) {
      throw MambaRegistryError.value(
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
/// optional [path] preserves the full location of malformed nested data in a
/// [MambaIntegrationException].
enum RegistryMapProps {
  name,
  description,
  flags,
  persistentFlags,
  persistentOptions,
  options,
  optionGroups,
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
      case RegistryMapProps.optionGroups:
        _parseOptionGroups(value, propertyPath);
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
    // Validate the caller's original map first so diagnostics preserve the
    // malformed value rather than an implementation-added help entry.
    _parseCommand(map, '');
    final normalizedMap = _withBuiltInHelp(map);
    _parseCommand(normalizedMap, '');
    return _freezeMap(normalizedMap);
  }

  /// Makes parser-owned help metadata available to every map-defined command.
  /// Callers cannot omit or redefine behavior that the parser always owns.
  static Map<String, dynamic> _withBuiltInHelp(Map<String, dynamic> command) {
    final normalized = Map<String, dynamic>.from(command);
    final flags = normalized['flags'];
    if (flags == null) {
      normalized['flags'] = {'help': _builtInHelpMap()};
    } else if (flags is Map) {
      normalized['flags'] = {
        ...Map<Object?, Object?>.from(flags),
        if (!flags.containsKey('help')) 'help': _builtInHelpMap(),
      };
    }
    final commands = normalized['commands'];
    if (commands is Map) {
      normalized['commands'] = {
        for (final entry in commands.entries)
          entry.key: entry.value is Map
              ? _withBuiltInHelp(Map<String, dynamic>.from(entry.value))
              : entry.value,
      };
    }
    return normalized;
  }

  static Map<String, dynamic> _builtInHelpMap() => {
    'short': 'h',
    'default': false,
    'negatable': false,
    'hidden': false,
    'description': 'Show this help message.',
  };
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
  _validateOptionGroupMembers(properties, path);
  _validateCommandSemantics(properties, path);
}

final RegExp _registryName = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$');
final RegExp _registryShortName = RegExp(r'^[A-Za-z]$');

void _validateCommandSemantics(Map<String, Object?> command, String path) {
  final namePath = _joinRegistryPath(path, 'name');
  _validateRegistryName(command['name'] as String, namePath);

  final descriptionPath = _joinRegistryPath(path, 'description');
  final description = command['description'] as String;
  if (description.isEmpty) {
    _invalid(description, descriptionPath, 'must not be empty');
  }
  // The serialized description starts with the live short description, which
  // live registration rejects when empty or longer than 150 characters.
  final shortDescription = description.split('\n\n').first;
  if (shortDescription.length > 150) {
    _invalid(
      shortDescription,
      descriptionPath,
      'must not exceed 150 characters before the long description',
    );
  }

  final inputCollections = [
    'flags',
    'persistentFlags',
    'options',
    'persistentOptions',
    'positionals',
    'accessors',
  ];
  // Positional names occupy a separate namespace: token syntax keeps their
  // values unambiguous, so live registration permits cross-category sharing.
  final positionalNames = <String>{};
  final localNames = <String>{};
  final persistentNames = <String>{};
  final localShorts = <String>{};
  final persistentShorts = <String>{};
  final negatedFlagNames = <String>{};
  for (final collectionName in inputCollections) {
    final value = command[collectionName];
    if (value is! Map) continue;
    final collection = _stringMap(
      value,
      _joinRegistryPath(path, collectionName),
    );
    for (final entry in collection.entries) {
      final inputPath = _joinRegistryPath(
        _joinRegistryPath(path, collectionName),
        entry.key,
      );
      _validateRegistryName(entry.key, inputPath);
      final isPositional = collectionName == 'positionals';
      final isPersistent =
          collectionName == 'persistentFlags' ||
          collectionName == 'persistentOptions';
      final names = isPositional
          ? positionalNames
          : isPersistent
          ? persistentNames
          : localNames;
      final shorts = isPersistent ? persistentShorts : localShorts;
      if (!names.add(entry.key)) {
        _invalid(
          entry.key,
          inputPath,
          'collides with another registered input',
        );
      }
      // The built-in help flag is the only input allowed to claim the
      // reserved help name or its -h short alias.
      final helpInput = entry.value is Map
          ? _map(entry.value, inputPath)
          : const <String, Object?>{};
      final isHelpFlagEntry =
          collectionName == 'flags' &&
          entry.key == 'help' &&
          helpInput['short'] == 'h' &&
          helpInput.containsKey('default') &&
          helpInput.containsKey('negatable');
      if (entry.key == 'help' && !isHelpFlagEntry) {
        _invalid(entry.key, inputPath, 'is reserved by the built-in help flag');
      }
      if (entry.value is Map) {
        final input = _map(entry.value, inputPath);
        final short = input['short'];
        if (short is String) {
          if (!_registryShortName.hasMatch(short)) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'must be a single letter',
            );
          }
          if (short == 'h' && !isHelpFlagEntry) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'is reserved by the built-in help flag',
            );
          }
          if (!shorts.add(short)) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'collides with another short alias',
            );
          }
        }
        if (input['negatable'] == true) {
          negatedFlagNames.add('no-${entry.key}');
        }
      }
    }
  }
  // Local options may replace persistent options of the same name, but every
  // other local/persistent name collision is ambiguous in the live registry.
  final localOptions = command['options'] is Map
      ? _stringMap(command['options'], _joinRegistryPath(path, 'options'))
      : const <String, Object?>{};
  final persistentOptions = command['persistentOptions'] is Map
      ? _stringMap(
          command['persistentOptions'],
          _joinRegistryPath(path, 'persistentOptions'),
        )
      : const <String, Object?>{};
  final persistentFlags = command['persistentFlags'] is Map
      ? _stringMap(
          command['persistentFlags'],
          _joinRegistryPath(path, 'persistentFlags'),
        )
      : const <String, Object?>{};
  final localFlags = command['flags'] is Map
      ? _stringMap(command['flags'], _joinRegistryPath(path, 'flags'))
      : const <String, Object?>{};
  for (final name in localNames.intersection(persistentNames)) {
    if (localOptions.containsKey(name) && persistentOptions.containsKey(name)) {
      continue;
    }
    _invalid(name, path, 'collides between local and persistent inputs');
  }
  Map<String, String> shortNames(Map<String, Object?> inputs) => {
    for (final entry in inputs.entries)
      if (_map(entry.value, path)['short'] case final String short)
        short: entry.key,
  };
  final localShortNames = shortNames({...localFlags, ...localOptions});
  final persistentShortNames = shortNames({
    ...persistentFlags,
    ...persistentOptions,
  });
  for (final short in localShorts.intersection(persistentShorts)) {
    if (localShortNames[short] == persistentShortNames[short]) continue;
    _invalid(
      short,
      path,
      'collides between local and persistent short aliases',
    );
  }

  // Every map represents the live built-in help flag exactly, rather than a
  // caller-defined approximation of parser-owned behavior.
  final help = localFlags['help'];
  const helpDescription = 'Show this help message.';
  if ((help != null && help is! Map) ||
      persistentFlags.containsKey('help') ||
      (help is Map &&
          (_map(help, _joinRegistryPath(path, 'flags.help'))['short'] != 'h' ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['default'] !=
                  false ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['negatable'] !=
                  false ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['hidden'] !=
                  false ||
              _map(
                    help,
                    _joinRegistryPath(path, 'flags.help'),
                  )['description'] !=
                  helpDescription))) {
    _invalid(
      help,
      _joinRegistryPath(path, 'flags.help'),
      'must be the canonical built-in help flag',
    );
  }

  // A negatable boolean flag also accepts --no-<name>; that synthesized
  // spelling belongs to the command token namespace and must not collide
  // with another registered input.
  final declaredNames = {...localNames, ...persistentNames};
  for (final negatedName in negatedFlagNames) {
    if (declaredNames.contains(negatedName)) {
      _invalid(
        negatedName,
        _joinRegistryPath(path, 'flags'),
        'collides with a synthesized negated flag spelling',
      );
    }
  }
  final positionals = command['positionals'];
  final commands = command['commands'];
  if (positionals is Map && commands is Map) {
    for (final name in positionals.keys) {
      if (commands.containsKey(name)) {
        _invalid(
          name,
          _joinRegistryPath(path, 'positionals'),
          'must not collide with a child command',
        );
      }
    }
  }
  final aliases = command['aliases'];
  if (aliases is List) {
    final registeredAliases = <String>{};
    for (final (index, alias) in aliases.indexed) {
      final aliasPath = _joinRegistryPath(
        _joinRegistryPath(path, 'aliases'),
        index.toString(),
      );
      _validateRegistryName(alias as String, aliasPath);
      if (alias == command['name'] || !registeredAliases.add(alias)) {
        _invalid(
          alias,
          aliasPath,
          'must be unique and differ from the command name',
        );
      }
    }
  }
}

void _validateRegistryName(String name, String path) {
  if (!_registryName.hasMatch(name)) {
    _invalid(
      name,
      path,
      'must contain letter-led words separated by hyphens or underscores',
    );
  }
}

void _validateOptionGroupMembers(
  Map<String, Object?> command,
  String commandPath,
) {
  final groups = command['optionGroups'];
  if (groups is! List) return;
  final options = command['options'] is Map
      ? _stringMap(
          command['options'],
          _joinRegistryPath(commandPath, 'options'),
        )
      : const <String, Object?>{};
  final groupedMembers = <Object?>{};
  for (final (groupIndex, entry) in groups.indexed) {
    final groupPath = _joinRegistryPath(
      _joinRegistryPath(commandPath, 'optionGroups'),
      groupIndex.toString(),
    );
    final group = _map(entry, groupPath);
    final members = group['members'] as List;
    for (final (memberIndex, member) in members.indexed) {
      final memberPath = _joinRegistryPath(
        _joinRegistryPath(groupPath, 'members'),
        memberIndex.toString(),
      );
      if (!groupedMembers.add(member)) {
        _invalid(member, memberPath, 'must belong to only one option group');
      }
      if (!options.containsKey(member)) {
        _invalid(member, memberPath, 'must reference a registered option');
      }
      final option = options[member];
      // Pair options never declare defaults, so no member of any option
      // group may carry serialized default metadata.
      if (option is Map && _map(option, memberPath).containsKey('default')) {
        _invalid(
          _map(option, memberPath)['default'],
          _joinRegistryPath(memberPath, 'default'),
          'must not be declared for pair options',
        );
      }
    }
  }
}

void _parseCommands(Object? value, String path) {
  final commands = _stringMap(value, path);
  final aliases = <String>{};
  for (final entry in commands.entries) {
    final commandPath = _joinRegistryPath(path, entry.key);
    final command = _map(entry.value, commandPath);
    _parseCommand(command, commandPath);
    if (command['name'] != entry.key) {
      _invalid(
        command['name'],
        _joinRegistryPath(commandPath, 'name'),
        'must match its command collection key',
      );
    }
    for (final alias in command['aliases'] as List? ?? const <Object?>[]) {
      final aliasPath = _joinRegistryPath(commandPath, 'aliases');
      if (commands.containsKey(alias) || !aliases.add(alias as String)) {
        _invalid(
          alias,
          aliasPath,
          'must not collide with a sibling command or alias',
        );
      }
    }
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
    'pattern',
    'min',
    'max',
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
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  _expectValueType(value['valueType'], _joinRegistryPath(path, 'valueType'));
  if (value['valueType'] == 'choice' && !value.containsKey('choices')) {
    _invalid(value, choicesPath, 'is required for a choice option');
  }
  if (value.containsKey('choices')) {
    _parseNonEmptyStringList(value['choices'], choicesPath);
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], defaultPath);
    if (value['valueType'] != 'choice') {
      _invalid(
        value['default'],
        defaultPath,
        'is only supported for choice options',
      );
    }
    if (value['required'] == true) {
      _invalid(
        value['default'],
        defaultPath,
        'must not be declared for a required option',
      );
    }
    if (value['valueType'] == 'choice' &&
        value['choices'] is List &&
        !(value['choices'] as List).contains(value['default'])) {
      _invalid(value['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (value.containsKey('pairedOptions')) {
    final pairedOptionsPath = _joinRegistryPath(path, 'pairedOptions');
    _parseStringList(value['pairedOptions'], pairedOptionsPath);
    if (value['pairedOptions'] is List &&
        (value['pairedOptions'] as List).isNotEmpty &&
        value.containsKey('default')) {
      _invalid(
        value['default'],
        _joinRegistryPath(path, 'default'),
        'must not be declared for pair options',
      );
    }
  }
  if (value.containsKey('pattern')) {
    _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
  }
  _validateNumericRangeProperties(value, path);
}

void _validateNumericRangeProperties(Map<String, Object?> value, String path) {
  final valueType = value['valueType'];
  final min = value['min'];
  final max = value['max'];
  if (min == null && max == null) return;
  if (valueType != 'int' && valueType != 'double') {
    _invalid(value, path, 'numeric bounds require an int or double value type');
  }
  final isInt = valueType == 'int';
  for (final entry in {'min': min, 'max': max}.entries) {
    if (entry.value != null &&
        (entry.value is! num || (isInt && entry.value is! int))) {
      _invalid(
        entry.value,
        _joinRegistryPath(path, entry.key),
        'must match the numeric value type',
      );
    }
  }
  if (min is num && max is num && min > max) {
    _invalid(max, _joinRegistryPath(path, 'max'), 'must not be less than min');
  }
}

void _parseOptionGroups(Object? value, String path) {
  if (value is! List) {
    _invalid(value, path, 'must be a List of option groups');
  }
  for (final (index, entry) in value.indexed) {
    final groupPath = _joinRegistryPath(path, index.toString());
    final group = _map(entry, groupPath);
    const properties = {'mode', 'required', 'members'};
    _validateProperties(group, groupPath, properties, properties);
    final modePath = _joinRegistryPath(groupPath, 'mode');
    _expectString(group['mode'], modePath);
    if (group['mode'] != 'all' && group['mode'] != 'oneOf') {
      _invalid(group['mode'], modePath, 'must be all or oneOf');
    }
    _expectBool(group['required'], _joinRegistryPath(groupPath, 'required'));
    final membersPath = _joinRegistryPath(groupPath, 'members');
    _parseStringList(group['members'], membersPath);
    if (group['members'] case List(isEmpty: true)) {
      _invalid(group['members'], membersPath, 'must not be empty');
    }
  }
}

void _parsePositional(Map<String, Object?> value, String path) {
  const requiredProperties = {'required', 'description'};
  const optionalProperties = {
    'choices',
    'default',
    'repeatable',
    'times',
    'pattern',
  };
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
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  if (value.containsKey('choices')) {
    _parseNonEmptyStringList(value['choices'], choicesPath);
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], defaultPath);
    if (!value.containsKey('choices')) {
      _invalid(
        value['default'],
        defaultPath,
        'is only supported for choice positionals',
      );
    }
    if (value['required'] == true) {
      _invalid(
        value['default'],
        defaultPath,
        'must not be declared for a required positional',
      );
    }
    if (value['choices'] is List &&
        !(value['choices'] as List).contains(value['default'])) {
      _invalid(value['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (value.containsKey('repeatable')) {
    _expectBool(value['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (value.containsKey('times')) {
    final timesPath = _joinRegistryPath(path, 'times');
    _expectNonNegativeInt(value['times'], timesPath);
    if (value['repeatable'] != true) {
      _invalid(
        value['times'],
        timesPath,
        'requires repeatable positional metadata',
      );
    }
  }
  if (value['repeatable'] == true && !value.containsKey('times')) {
    _invalid(
      value,
      _joinRegistryPath(path, 'times'),
      'is required for a repeated positional',
    );
  }
  if (value.containsKey('pattern')) {
    _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
  }
}

void _parseVariadic(Object? value, String path) {
  final variadic = _map(value, path);
  const requiredProperties = {'description'};
  const optionalProperties = {'choices', 'default', 'repeatable', 'pattern'};
  _validateProperties(variadic, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);
  _expectString(
    variadic['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  if (variadic.containsKey('choices')) {
    _parseNonEmptyStringList(variadic['choices'], choicesPath);
  }
  if (variadic.containsKey('default')) {
    _expectString(variadic['default'], defaultPath);
    if (!variadic.containsKey('choices')) {
      _invalid(
        variadic['default'],
        defaultPath,
        'is only supported for choice variadics',
      );
    }
    if (variadic['choices'] is List &&
        !(variadic['choices'] as List).contains(variadic['default'])) {
      _invalid(variadic['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (variadic.containsKey('repeatable')) {
    _expectBool(variadic['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (variadic.containsKey('pattern')) {
    _expectString(variadic['pattern'], _joinRegistryPath(path, 'pattern'));
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

void _parseAccessorRoot(Map<String, Object?> value, String path) =>
    _parseTypedAccessor(value, path);

void _parseTypedAccessor(Map<String, Object?> value, String path) {
  final kindPath = _joinRegistryPath(path, 'kind');
  _expectString(value['kind'], kindPath);
  switch (value['kind']) {
    case 'group':
      const properties = {'kind', 'hidden', 'description', 'options'};
      _validateProperties(value, path, properties, properties);
      _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
      _expectString(
        value['description'],
        _joinRegistryPath(path, 'description'),
        nullable: true,
      );
      final optionsPath = _joinRegistryPath(path, 'options');
      final options = _stringMap(value['options'], optionsPath);
      for (final entry in options.entries) {
        final optionPath = _joinRegistryPath(optionsPath, entry.key);
        _validateRegistryName(entry.key, optionPath);
        if (entry.key == 'help') {
          _invalid(
            entry.key,
            optionPath,
            'is reserved by the built-in help flag',
          );
        }
        _parseTypedAccessor(_map(entry.value, optionPath), optionPath);
      }
    case 'value':
      const properties = {
        'kind',
        'valueType',
        'description',
        'choices',
        'default',
        'pattern',
      };
      const requiredProperties = {'kind', 'valueType', 'description'};
      _validateProperties(value, path, properties, requiredProperties);
      _expectValueType(
        value['valueType'],
        _joinRegistryPath(path, 'valueType'),
      );
      final choicesPath = _joinRegistryPath(path, 'choices');
      if (value['valueType'] == 'choice' && !value.containsKey('choices')) {
        _invalid(value, choicesPath, 'is required for a choice accessor');
      }
      _expectString(
        value['description'],
        _joinRegistryPath(path, 'description'),
        nullable: true,
      );
      if (value.containsKey('choices')) {
        _parseNonEmptyStringList(value['choices'], choicesPath);
      }
      if (value.containsKey('pattern')) {
        _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
      }
      if (value.containsKey('default')) {
        final defaultPath = _joinRegistryPath(path, 'default');
        _expectString(value['default'], defaultPath);
        if (value['valueType'] != 'choice') {
          _invalid(
            value['default'],
            defaultPath,
            'is only supported for choice accessors',
          );
        }
        final choices = value['choices'];
        if (value['valueType'] == 'choice' &&
            choices is List &&
            !choices.contains(value['default'])) {
          _invalid(
            value['default'],
            defaultPath,
            'must be a registered accessor choice',
          );
        }
      }
    default:
      _invalid(value['kind'], kindPath, 'must be group or value');
  }
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

void _parseNonEmptyStringList(Object? value, String path) {
  _parseStringList(value, path);
  if (value case List(isEmpty: true)) {
    _invalid(value, path, 'must not be empty');
  }
}

Map<String, dynamic> _freezeMap(Map<Object?, Object?> source) =>
    Map<String, dynamic>.unmodifiable({
      for (final entry in source.entries)
        entry.key as String: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) => switch (value) {
  Map() => _freezeMap(value),
  List() => List<Object?>.unmodifiable(value.map(_freezeValue)),
  _ => value,
};

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
    throw MambaIntegrationException('$path $message (value: $value)');

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
  FutureOr<void> preRun(
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
  FutureOr<void> prePersistentRun(
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
