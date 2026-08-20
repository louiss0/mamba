import 'dart:async';
import 'dart:convert';

import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';

sealed class NamedInput {
  const NamedInput({required this.name, required this.description});

  final String name;
  final String? description;
}

class Positional extends NamedInput {
  Positional(String name, {super.description, RegExp? regex})
    : regex = regex ?? RegExp(r'\S+'),
      super(name: name);

  final RegExp regex;
}

sealed class Flag extends NamedInput {
  const Flag({
    required this.short,
    required super.name,
    required super.description,
    this.hidden = false,
  });

  final String? short;
  final bool hidden;
}

final class BooleanFlag extends Flag {
  BooleanFlag({
    super.short,
    required super.name,
    super.description,
    super.hidden,
    this.defaultValue = false,
    this.negatable = false,
  });

  final bool defaultValue;
  final bool negatable;
}

final class CountFlag extends Flag {
  const CountFlag({
    super.short,
    required super.name,
    super.description,
    super.hidden,
  });
}

sealed class Option extends NamedInput {
  const Option({
    required this.short,
    required super.name,
    required super.description,
    this.required = false,
    this.hidden = false,
  });

  final String? short;
  final bool required;
  final bool hidden;
}

/// An option with members that form either a required-together group or variant.
sealed class PairedOption extends Option {
  PairedOption({
    required List<PairOption> options,
    required super.short,
    required super.name,
    required super.description,
    super.required,
    this.variant = false,
  }) : options = List.unmodifiable(options);

  final List<PairOption> options;
  final bool variant;
}

final class PairedStringOption extends PairedOption {
  PairedStringOption({
    required super.name,
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required = false,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairedIntOption extends PairedOption {
  PairedIntOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedDoubleOption extends PairedOption {
  PairedDoubleOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedChoiceOption<T extends Enum> extends PairedOption {
  PairedChoiceOption({
    required this.choices,
    required super.options,
    this.defaultValue,
    required super.name,
    super.short,
    super.description,
    super.required,
    super.variant,
  });

  final List<T> choices;
  final T? defaultValue;
}

sealed class RepeatablePairedOption extends PairedOption {
  RepeatablePairedOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required = false,
    super.variant = false,
  });
}

final class RepeatablePairedStringOption extends RepeatablePairedOption {
  RepeatablePairedStringOption({
    required super.name,
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required = false,
    super.variant = false,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class RepeatablePairedIntOption extends RepeatablePairedOption {
  RepeatablePairedIntOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class RepeatablePairedDoubleOption extends RepeatablePairedOption {
  RepeatablePairedDoubleOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

/// A member of a [PairedOption] group or variant.
///
/// Pair members always inherit their requiredness from their primary option and
/// therefore do not expose a `required` constructor parameter.
sealed class PairOption extends NamedInput {
  final String? short;
  const PairOption({
    required this.short,
    required super.name,
    required super.description,
  });
}

final class PairStringOption extends PairOption {
  PairStringOption({
    required super.name,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairIntOption extends PairOption {
  const PairIntOption({required super.name, super.short, super.description});
}

final class PairDoubleOption extends PairOption {
  const PairDoubleOption({required super.name, super.short, super.description});
}

final class PairChoiceOption<T extends Enum> extends PairOption {
  const PairChoiceOption({
    required this.choices,
    this.defaultValue,
    required super.name,
    super.short,
    super.description,
  });

  final List<T> choices;
  final T? defaultValue;
}

sealed class RepeatablePairOption extends PairOption {
  const RepeatablePairOption({
    required super.name,
    super.short,
    super.description,
  });
}

final class RepeatablePairStringOption extends RepeatablePairOption {
  RepeatablePairStringOption({
    required super.name,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class RepeatablePairIntOption extends RepeatablePairOption {
  const RepeatablePairIntOption({
    required super.name,
    super.short,
    super.description,
  });
}

final class RepeatablePairDoubleOption extends RepeatablePairOption {
  const RepeatablePairDoubleOption({
    required super.name,
    super.short,
    super.description,
  });
}

sealed class SingleOption extends Option {
  const SingleOption({
    required super.short,
    required super.name,
    required super.description,
    super.required,
    super.hidden,
  });
}

final class StringOption extends SingleOption {
  const StringOption({
    required super.name,
    required this.regex,
    super.short,
    super.description,
    super.required,
    super.hidden,
  });

  final RegExp regex;
}

final class IntOption extends SingleOption {
  const IntOption({
    required super.name,
    super.short,
    super.required,
    super.description,
    super.hidden,
  });
}

final class DoubleOption extends SingleOption {
  const DoubleOption({
    required super.name,
    super.short,
    super.required,
    super.description,
    super.hidden,
  });
}

final class ChoiceOption<T extends Enum> extends SingleOption {
  const ChoiceOption({
    this.defaultValue,
    required this.choices,
    required super.name,
    super.short,
    super.description,
    super.required,
    super.hidden,
  });

  final List<T> choices;
  final T? defaultValue;
}

sealed class RepeatableOption extends Option {
  const RepeatableOption({
    required super.name,
    required super.required,
    super.short,
    super.description,
    super.hidden,
  });
}

final class RepeatableStringOption extends RepeatableOption {
  RepeatableStringOption({
    required super.name,
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });
}

final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
    super.hidden,
  });
}

sealed class AccessorOption extends NamedInput {
  const AccessorOption({required super.name, super.description});
}

sealed class AccessorPrimitiveOption extends AccessorOption {
  const AccessorPrimitiveOption({required super.name, super.description});
}

final class AccessorListOption extends AccessorOption {
  AccessorListOption({
    required super.name,
    super.description,
    this.hidden = false,
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options);

  final bool hidden;
  final List<AccessorOption> options;
}

final class AccessorStringOption extends AccessorPrimitiveOption {
  AccessorStringOption({required super.name, super.description, RegExp? regex})
    : _regExp = regex ?? RegExp(r'\S+');

  final RegExp _regExp;
  RegExp get regex => _regExp;
}

final class AccessorIntOption extends AccessorPrimitiveOption {
  AccessorIntOption({required super.name, super.description});

  RegExp get regex => RegExp(r'\d+');
}

final class AccessorDoubleOption extends AccessorPrimitiveOption {
  AccessorDoubleOption({required super.name, super.description});

  RegExp get regex => RegExp(r'\d+\.\d+');
}

final class AccessorChoiceOption<T extends Enum>
    extends AccessorPrimitiveOption {
  AccessorChoiceOption({
    required this.choices,
    this.defaultValue,
    required super.name,
    super.description,
  });

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

typedef ParsedSingleOptions = ({
  Map<String, String>? stringOptions,
  Map<String, int>? intOptions,
  Map<String, double>? doubleOptions,
});

typedef ParsedPositionals = Map<String, String>?;

/// The Blueprint for any class that wants to be a command
/// The name and short description must be provided
/// If the short description is
abstract class Command {
  final String? longDescription;
  final List<Positional>? mandatoryPositionals;
  final List<Positional>? discretionaryPositionals;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOption>? pairedOptions;
  final List<AccessorOption>? accessors;

  Command({
    this.longDescription,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.flags,
    this.options,
    this.pairedOptions,
    this.accessors,
  });

  String get name;
  String get shortDescription;

  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  );
}

/// This type of command is allowed to select it's subcommands to run
/// This type of commands should only use it's sub command runner in `run`
abstract class GroupCommand extends Command {
  final List<String>? defaultSubCommandPath;
  final List<Flag>? inheritedFlags;
  final List<Option>? inheritedOptions;
  final List<Command> commands;

  GroupCommand(
    this.commands, {
    List<String>? defaultSubCommandPath,
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

/// Is used for allowing the user to process standard input
/// It's automatically sent bytes from standard input
final class ProcessedStandardInput {
  final List<int> bytes;
  ProcessedStandardInput(this.bytes);

  String get text => String.fromCharCodes(bytes);

  String get utf8Text => utf8.decode(bytes);

  dynamic get json => jsonDecode(utf8Text);
}

/// Gives Commands the power to run functions before and After the run function
/// The user is expected to make use of `preRun()` It's the input processor
mixin HookRunner on Command {
  /// Runs before the selected command
  void preRun(
    ProcessedStandardInput? input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  );

  /// Runs after the selected command
  FutureOr<void> postRun(MambaReadContext context) {}
}

mixin PersistentHookRunner on GroupCommand {
  void prePersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  );

  /// Runs after every command run
  FutureOr<void> postPersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {}
}
