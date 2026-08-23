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

/// A regex-validated value registered in a command's positional sequence.
///
/// Register it in `mandatoryPositionals` or `discretionaryPositionals`; the
/// parser stores its complete-token match in [ParsedPositionals], and help
/// renders it as required or optional usage respectively.
class Positional extends NamedInput {
  static final RegExp anyToken = RegExp(r"\S+");

  Positional(String name, {String? description, RegExp? regex})
    : _regExp = regex ?? anyToken,
      super(name, description);

  final RegExp _regExp;

  /// Pattern every supplied token must match entirely.
  RegExp get regex => _regExp;
}

final class NormalPositional extends Positional {
  final RegExp regExp;

  NormalPositional(String name, {String? description, RegExp? regExp})
    : regExp = regExp ?? Positional.anyToken,
      super(name, description: description);

  @override
  RegExp get regex => regExp;
}

final class ChoicePositional<T extends Enum> extends Positional {
  final List<T> choices;
  final T? defaultValue;
  ChoicePositional(
    String name, {
    String? description,
    required this.choices,
    this.defaultValue,
  }) : super(name, description: description);

  @override
  RegExp get regex => Positional.anyToken;
}

final class RepeatedPositional extends NormalPositional {
  /// Maximum number of repetitions; accepts one value per repetition plus the
  /// original, so the default of 1 collects up to two values.
  final int maxCount;
  RepeatedPositional(
    String name, {
    String? description,
    RegExp? regExp,
    this.maxCount = 1,
  }) : super(name, description: description, regExp: regExp);
}

final class RepeatedChoicePositional<T extends Enum>
    extends ChoicePositional<T> {
  /// Maximum number of repetitions; accepts one value per repetition plus the
  /// original, so the default of 1 collects up to two values.
  final int maxCount;
  RepeatedChoicePositional(
    String name, {
    String? description,
    required List<T> choices,
    T? defaultValue,
    this.maxCount = 1,
  }) : super(
         name,
         description: description,
         choices: choices,
         defaultValue: defaultValue,
       );
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
    String name, {
    super.short,
    String? description,
    super.hidden,
    this.defaultValue = false,
    this.negatable = false,
  }) : super(name, description: description);

  final bool defaultValue;
  final bool negatable;
}

/// A flag whose registered value is incremented for every occurrence.
///
/// The parser accepts long, short, and bundled-short forms and returns its
/// count. Help lists visible count flags in Flags.
final class CountFlag extends Flag {
  const CountFlag(String name, {super.short, String? description, super.hidden})
    : super(name, description: description);
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
    String name, {
    required List<PairOption> options,
    required super.short,
    String? description,
    super.required,
    this.variant = false,
  }) : options = List.unmodifiable(options),
       super(name, description: description);

  final List<PairOption> options;
  final bool variant;
}

/// A regex-validated string primary in a paired option registration.
final class PairedStringOption extends PairedOption {
  PairedStringOption(
    String name, {
    required super.options,
    RegExp? regex,
    super.short,
    String? description,
    super.required = false,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+'),
       super(name, description: description);

  final RegExp regex;
}

/// An integer primary in a paired option registration.
final class PairedIntOption extends PairedOption {
  PairedIntOption(
    String name, {
    required super.options,
    super.short,
    String? description,
    super.required,
    super.variant,
  }) : super(name, description: description);
}

/// A double primary in a paired option registration.
final class PairedDoubleOption extends PairedOption {
  PairedDoubleOption(
    String name, {
    required super.options,
    super.short,
    String? description,
    super.required,
    super.variant,
  }) : super(name, description: description);
}

/// An enum-choice primary in a paired option registration.
final class PairedChoiceOption<T extends Enum> extends PairedOption {
  PairedChoiceOption(
    String name, {
    required this.choices,
    required super.options,
    this.defaultValue,
    super.short,
    String? description,
    super.required,
    super.variant,
  }) : super(name, description: description);

  final List<T> choices;
  final T? defaultValue;
}

/// A paired primary that accumulates each supplied value into a typed list.
sealed class RepeatablePairedOption extends PairedOption {
  RepeatablePairedOption(
    String name, {
    required super.options,
    super.short,
    String? description,
    super.required = false,
    super.variant = false,
  }) : super(name, description: description);
}

/// A repeatable string primary in a paired option registration.
final class RepeatablePairedStringOption extends RepeatablePairedOption {
  RepeatablePairedStringOption(
    String name, {
    required super.options,
    RegExp? regex,
    super.short,
    String? description,
    super.required = false,
    super.variant = false,
  }) : regex = regex ?? RegExp(r'\S+'),
       super(name, description: description);

  final RegExp regex;
}

/// A repeatable integer primary in a paired option registration.
final class RepeatablePairedIntOption extends RepeatablePairedOption {
  RepeatablePairedIntOption(
    String name, {
    required super.options,
    super.short,
    String? description,
    super.required,
    super.variant,
  }) : super(name, description: description);
}

/// A repeatable double primary in a paired option registration.
final class RepeatablePairedDoubleOption extends RepeatablePairedOption {
  RepeatablePairedDoubleOption(
    String name, {
    required super.options,
    super.short,
    String? description,
    super.required,
    super.variant,
  }) : super(name, description: description);
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
final class PairStringOption extends PairOption {
  PairStringOption(
    String name, {
    RegExp? regex,
    super.short,
    String? description,
  }) : regex = regex ?? RegExp(r'\S+'),
       super(name, description: description);

  final RegExp regex;
}

/// An integer companion in a paired option registration.
final class PairIntOption extends PairOption {
  const PairIntOption(String name, {super.short, String? description})
    : super(name, description: description);
}

/// A double companion in a paired option registration.
final class PairDoubleOption extends PairOption {
  const PairDoubleOption(String name, {super.short, String? description})
    : super(name, description: description);
}

/// An enum-choice companion in a paired option registration.
final class PairChoiceOption<T extends Enum> extends PairOption {
  const PairChoiceOption(
    String name, {
    required this.choices,
    this.defaultValue,
    super.short,
    String? description,
  }) : super(name, description: description);

  final List<T> choices;
  final T? defaultValue;
}

/// A paired companion that accumulates each supplied value into a typed list.
sealed class RepeatablePairOption extends PairOption {
  const RepeatablePairOption(String name, {super.short, String? description})
    : super(name, description: description);
}

/// A repeatable string companion in a paired option registration.
final class RepeatablePairStringOption extends RepeatablePairOption {
  RepeatablePairStringOption(
    String name, {
    RegExp? regex,
    super.short,
    String? description,
  }) : regex = regex ?? RegExp(r'\S+'),
       super(name, description: description);

  final RegExp regex;
}

/// A repeatable integer companion in a paired option registration.
final class RepeatablePairIntOption extends RepeatablePairOption {
  const RepeatablePairIntOption(String name, {super.short, String? description})
    : super(name, description: description);
}

/// A repeatable double companion in a paired option registration.
final class RepeatablePairDoubleOption extends RepeatablePairOption {
  const RepeatablePairDoubleOption(
    String name, {
    super.short,
    String? description,
  }) : super(name, description: description);
}

/// A non-repeatable option that stores one typed value by name.
sealed class SingleOption extends Option {
  const SingleOption(
    String name, {
    required super.short,
    required String? description,
    super.required,
    super.hidden,
  }) : super(name, description: description);
}

/// A single string option validated by [regex].
final class StringOption extends SingleOption {
  const StringOption(
    String name, {
    required this.regex,
    super.short,
    String? description,
    super.required,
    super.hidden,
  }) : super(name, description: description);

  final RegExp regex;
}

/// A single option that accepts a signed decimal integer.
final class IntOption extends SingleOption {
  const IntOption(
    String name, {
    super.short,
    super.required,
    String? description,
    super.hidden,
  }) : super(name, description: description);
}

/// A single option that accepts a signed decimal number.
final class DoubleOption extends SingleOption {
  const DoubleOption(
    String name, {
    super.short,
    super.required,
    String? description,
    super.hidden,
  }) : super(name, description: description);
}

/// A single option that accepts one registered enum-member name.
///
/// The parser stores the selected member name and supplies [defaultValue] when
/// the option is omitted.
final class ChoiceOption<T extends Enum> extends SingleOption {
  const ChoiceOption(
    String name, {
    this.defaultValue,
    required this.choices,
    super.short,
    String? description,
    super.required,
    super.hidden,
  }) : super(name, description: description);

  final List<T> choices;
  final T? defaultValue;
}

/// An option that accumulates every supplied value into a typed list.
sealed class RepeatableOption extends Option {
  const RepeatableOption(
    String name, {
    required super.required,
    super.short,
    String? description,
    super.hidden,
  }) : super(name, description: description);
}

/// A repeatable string option validated by [regex].
final class RepeatableStringOption extends RepeatableOption {
  RepeatableStringOption(
    String name, {
    super.required = false,
    RegExp? regex,
    super.short,
    String? description,
    super.hidden,
  }) : regex = regex ?? RegExp(r'\S+'),
       super(name, description: description);

  final RegExp regex;
}

/// A repeatable option that accepts signed decimal integers.
final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption(
    String name, {
    super.required = false,
    super.short,
    String? description,
    super.hidden,
  }) : super(name, description: description);
}

/// A repeatable option that accepts signed decimal numbers.
final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption(
    String name, {
    super.required = false,
    super.short,
    String? description,
    super.hidden,
  }) : super(name, description: description);
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
  const AccessorPrimitiveOption(String name, {String? description})
    : super(name, description: description);
}

/// An object node that groups nested [AccessorOption] registrations.
///
/// Its name forms one dotted-path segment. A hidden list hides every descendant
/// from help while preserving the complete accessor path for parsing.
final class AccessorListOption extends AccessorOption {
  AccessorListOption(
    String name, {
    String? description,
    this.hidden = false,
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options),
       super(name, description: description);

  final bool hidden;
  final List<AccessorOption> options;
}

/// A regex-validated string leaf in a dotted accessor path.
final class AccessorStringOption extends AccessorPrimitiveOption {
  AccessorStringOption(String name, {String? description, RegExp? regex})
    : _regExp = regex ?? RegExp(r'\S+'),
      super(name, description: description);

  final RegExp _regExp;
  RegExp get regex => _regExp;
}

/// An integer leaf in a dotted accessor path.
final class AccessorIntOption extends AccessorPrimitiveOption {
  AccessorIntOption(String name, {String? description})
    : super(name, description: description);

  RegExp get regex => RegExp(r'\d+');
}

/// A double leaf in a dotted accessor path.
final class AccessorDoubleOption extends AccessorPrimitiveOption {
  AccessorDoubleOption(String name, {String? description})
    : super(name, description: description);

  RegExp get regex => RegExp(r'\d+\.\d+');
}

/// An enum-choice leaf in a dotted accessor path.
///
/// The parser stores the selected member name and merges [defaultValue] when it
/// is omitted.
final class AccessorChoiceOption<T extends Enum>
    extends AccessorPrimitiveOption {
  AccessorChoiceOption(
    String name, {
    required this.choices,
    this.defaultValue,
    String? description,
  }) : super(name, description: description);

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
