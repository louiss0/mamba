import 'dart:async';
import 'dart:convert';

import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

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

/// Exposes the increment used by a stepped double option.
mixin NumericStepValidated {
  double? get step;
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
  PairedOptions(
    List<PairOption> options, {
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
    with NumericRangeValidated<double>, NumericStepValidated {
  const PairDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
  });

  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
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
    with NumericRangeValidated<double>, NumericStepValidated {
  const RepeatablePairDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.description,
  });

  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
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
  final RegExp _regex;
  StringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.required,
    super.hidden,
  }) : _regex = regex ?? RegExpValidated.anyToken;

  @override
  RegExp get regex => _regex;
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
    with NumericRangeValidated<double>, NumericStepValidated {
  const DoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.short,
    super.required,
    super.description,
    super.hidden,
  });

  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
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
    with NumericRangeValidated<double>, NumericStepValidated {
  const RepeatableDoubleOption(
    super.name, {
    this.min,
    this.max,
    this.step,
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });

  @override
  final double? min;
  @override
  final double? max;
  @override
  final double? step;
}

class RepeatableChoiceOption<T extends Enum> extends RepeatableOption
    with ChoiceValidated<T> {
  RepeatableChoiceOption(
    super.name,
    List<T> choices, {
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  }) : choices = List.unmodifiable(choices);

  @override
  final List<T> choices;
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
    super.name,
    List<AccessorOption> options, {
    super.description,
    this.hidden = false,
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
