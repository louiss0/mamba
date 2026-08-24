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

/// Validates candidate values against a pattern that must match entirely.
///
/// Inputs expose their pattern through [regex]; the shared [matchesEntirely]
/// check keeps whole-token validation identical for every regex input.
mixin RegExpValidated {
  /// Pattern every validated value must match entirely.
  RegExp get regex;

  /// Whether [value] is a complete match of [regex].
  bool matchesEntirely(String value) {
    final match = regex.firstMatch(value);
    return match != null && match.start == 0 && match.end == value.length;
  }
}

/// Validates candidate values against registered enum-member names.
///
/// Inputs expose their members through [choices]; the shared [isValidChoice]
/// check keeps choice validation identical for every choice input.
mixin ChoiceValidated<T extends Enum> {
  /// Members every validated value must name.
  List<T> get choices;

  /// Whether [value] names one of the [choices].
  bool isValidChoice(String value) =>
      choices.any((choice) => choice.name == value);
}

/// A regex-validated value registered in a command's positional sequence.
///
/// Register it in `mandatoryPositionals` or `discretionaryPositionals`; the
/// parser stores its complete-token match in [ParsedPositionals], and help
/// renders it as required or optional usage respectively.
class Positional extends NamedInput with RegExpValidated {
  static final RegExp anyToken = RegExp(r"\S+");

  Positional(String name, {String? description, RegExp? regex})
    : _regExp = regex ?? anyToken,
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

/// Every remaining positional value registered after all positionals fill.
///
/// Register it in `variadic`; the parser validates each absorbed token once
/// mandatory and discretionary positionals have taken theirs, then stores the
/// collected values in the `variadic` map of [ParsedPositionals].
sealed class Variadic extends NamedInput {
  const Variadic(String name, {String? description}) : super(name, description);
}

final class NormalVariadic extends Variadic with RegExpValidated {
  final RegExp regExp;

  NormalVariadic(super.name, {super.description, RegExp? regExp})
    : regExp = regExp ?? Positional.anyToken;

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
  });
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

/// A primary option registered with companion members as a group or variant.
///
/// The primary and [options] use ordinary option syntax. The parser requires
/// all members together unless [variant] is true, when it permits only one;
/// help joins the members with ` & ` or ` | ` respectively.
sealed class PairedOption extends Option {
  PairedOption(
    super.name, {
    required List<PairOption> options,
    required super.short,
    super.description,
    super.required,
    this.variant = false,
  }) : options = List.unmodifiable(options);

  final List<PairOption> options;
  final bool variant;
}

/// A regex-validated string primary in a paired option registration.
final class PairedStringOption extends PairedOption with RegExpValidated {
  PairedStringOption(
    super.name, {
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required = false,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// An integer primary in a paired option registration.
final class PairedIntOption extends PairedOption {
  PairedIntOption(
    super.name, {
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// A double primary in a paired option registration.
final class PairedDoubleOption extends PairedOption {
  PairedDoubleOption(
    super.name, {
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// An enum-choice primary in a paired option registration.
final class PairedChoiceOption<T extends Enum> extends PairedOption
    with ChoiceValidated<T> {
  PairedChoiceOption(
    super.name, {
    required this.choices,
    required super.options,
    this.defaultValue,
    super.short,
    super.description,
    super.required,
    super.variant,
  });

  @override
  final List<T> choices;
  final T? defaultValue;
}

/// A paired primary that accumulates each supplied value into a typed list.
sealed class RepeatablePairedOption extends PairedOption {
  RepeatablePairedOption(
    super.name, {
    required super.options,
    super.short,
    super.description,
    super.required = false,
    super.variant = false,
  });
}

/// A repeatable string primary in a paired option registration.
final class RepeatablePairedStringOption extends RepeatablePairedOption
    with RegExpValidated {
  RepeatablePairedStringOption(
    super.name, {
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required = false,
    super.variant = false,
  }) : regex = regex ?? RegExp(r'\S+');

  @override
  final RegExp regex;
}

/// A repeatable integer primary in a paired option registration.
final class RepeatablePairedIntOption extends RepeatablePairedOption {
  RepeatablePairedIntOption(
    super.name, {
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// A repeatable double primary in a paired option registration.
final class RepeatablePairedDoubleOption extends RepeatablePairedOption {
  RepeatablePairedDoubleOption(
    super.name, {
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// A companion value registered as a member of a [PairedOption].
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

  RegExp get regex => RegExp(r'\d+');
}

/// A double leaf in a dotted accessor path.
final class AccessorDoubleOption extends AccessorPrimitiveOption {
  AccessorDoubleOption(super.name, {super.description});

  RegExp get regex => RegExp(r'\d+\.\d+');
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

  /// Input absorbing every positional token left after all positionals fill.
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOption>? pairedOptions;

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
  FutureOr<String> run(
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
          ?.where((candidate) => candidate.name == name)
          .firstOrNull;
      if (command == null) {
        throw MambaException(
          'command not found in ${this.name} ${path.join(" ")}',
        );
      }
      children = command is GroupCommand ? command.commands : null;
    }

    return (await command!.run(positionals, input, trailingArguments));
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
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) async {
    final path = defaultSubCommandPath;
    if (path == null) return '';
    return runChildCommand(path, positionals, input, trailingArguments);
  }
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
