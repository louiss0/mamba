import 'dart:async';
import 'dart:convert';

import 'package:arg_parser/context.dart';
import 'package:arg_parser/errors.dart';

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

class Variadic extends Positional {
  Variadic(super.name, {super.description, super.regex});
}

sealed class Flag extends NamedInput {
  const Flag({
    required this.short,
    required super.name,
    required super.description,
  });

  final String? short;
}

final class BooleanFlag extends Flag {
  BooleanFlag({
    super.short,
    required super.name,
    super.description,
    this.defaultValue = false,
    this.negatable = false,
  });

  final bool defaultValue;
  final bool negatable;
}

final class CountFlag extends Flag {
  const CountFlag({super.short, required super.name, super.description});
}

sealed class Option extends NamedInput {
  const Option({
    required this.short,
    required super.name,
    required super.description,
    this.required = false,
  });

  final String? short;
  final bool required;

  static StringOption stringOption(
    String name,
    RegExp regex, {
    String? short,
    String? description,
    bool required = false,
  }) => StringOption(
    name: name,
    regex: regex,
    short: short,
    description: description,
    required: required,
  );

  static IntOption intOption(
    String name, {
    String? short,
    String? description,
    bool required = false,
  }) => IntOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static DoubleOption doubleOption(
    String name, {
    String? short,
    String? description,
    bool required = false,
  }) => DoubleOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static ChoiceOption<T> choiceOption<T extends Enum>(
    String name,
    List<T> choices, {
    String? short,
    String? description,
    bool required = false,
  }) => ChoiceOption(
    name: name,
    choices: choices,
    short: short,
    description: description,
    required: required,
  );
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
    super.required,
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

final class PairedRepeatableStringOption extends PairedOption {
  PairedRepeatableStringOption({
    required super.name,
    required super.options,
    RegExp? regex,
    super.short,
    super.description,
    super.required,
    super.variant,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairedRepeatableIntOption extends PairedOption {
  PairedRepeatableIntOption({
    required super.name,
    required super.options,
    super.short,
    super.description,
    super.required,
    super.variant,
  });
}

final class PairedRepeatableDoubleOption extends PairedOption {
  PairedRepeatableDoubleOption({
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
sealed class PairOption extends Option {
  const PairOption({
    required super.short,
    required super.name,
    required super.description,
  }) : super(required: false);
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
  PairChoiceOption({
    required this.choices,
    this.defaultValue,
    required super.name,
    super.short,
    super.description,
  });

  final List<T> choices;
  final T? defaultValue;
}

final class PairRepeatableStringOption extends PairOption {
  PairRepeatableStringOption({
    required super.name,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class PairRepeatableIntOption extends PairOption {
  const PairRepeatableIntOption({
    required super.name,
    super.short,
    super.description,
  });
}

final class PairRepeatableDoubleOption extends PairOption {
  const PairRepeatableDoubleOption({
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
  });
}

final class StringOption extends SingleOption {
  StringOption({
    required super.name,
    required this.regex,
    super.short,
    super.description,
    super.required,
  });

  final RegExp regex;
}

final class IntOption extends SingleOption {
  IntOption({
    required super.name,
    super.short,
    super.required,
    super.description,
  });
}

final class DoubleOption extends SingleOption {
  DoubleOption({
    required super.name,
    super.short,
    super.required,
    super.description,
  });
}

final class ChoiceOption<T extends Enum> extends SingleOption {
  ChoiceOption({
    this.defaultValue,
    required this.choices,
    required super.name,
    super.short,
    super.description,
    super.required,
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
  });

  static RepeatableIntOption intOption({
    required String name,
    String? short,
    String? description,
    bool required = false,
  }) => RepeatableIntOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static RepeatableDoubleOption doubleOption({
    required String name,
    String? short,
    String? description,
    bool required = false,
  }) => RepeatableDoubleOption(
    name: name,
    short: short,
    description: description,
    required: required,
  );

  static RepeatableStringOption stringOption({
    required String name,
    required RegExp regex,
    String? short,
    String? description,
    bool required = false,
  }) => RepeatableStringOption(
    name: name,
    short: short,
    description: description,
    required: required,
    regex: regex,
  );
}

final class RepeatableStringOption extends RepeatableOption {
  RepeatableStringOption({
    required super.name,
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExp(r'\S+');

  final RegExp regex;
}

final class RepeatableIntOption extends RepeatableOption {
  const RepeatableIntOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
  });
}

final class RepeatableDoubleOption extends RepeatableOption {
  const RepeatableDoubleOption({
    required super.name,
    super.required = false,
    super.short,
    super.description,
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
    required List<AccessorOption> options,
  }) : options = List.unmodifiable(options);

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

abstract class Command {
  final String? longDescription;
  final List<Positional>? mandatoryPositionals;
  final List<Positional>? discretionaryPositionals;
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOption>? pairedOptions;
  final List<AccessorOption>? accessors;
  final List<Command>? commands;

  Command({
    this.longDescription,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.flags,
    this.options,
    this.pairedOptions,
    this.accessors,
    this.commands,
  });

  String get name;
  String get shortDescription;

  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> variadic,
  );
}

abstract class GroupCommand extends Command {
  GroupCommand({
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
    super.commands,
  });

  @override
  String get name;
  @override
  String get shortDescription;

  Future<String> runChildCommand(
    List<String> path,
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> variadic,
  ) async {
    if (path.isEmpty) {
      throw ArgumentError('path is empty', 'path');
    }

    Command? command;
    var children = commands;
    for (final name in path) {
      command = children
          ?.where((candidate) => candidate.name == name)
          .firstOrNull;
      if (command == null) {
        throw MambaException(
          'command not found in ${this.name} ${path.join(" ")}',
        );
      }
      children = command.commands;
    }

    return command!.run(positionals, input, variadic);
  }

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> variadic,
  );
}

class ProcessedStandardInput {
  final List<int> bytes;
  ProcessedStandardInput(this.bytes);

  String get text => String.fromCharCodes(bytes);

  String get utf8Text => utf8.decode(bytes);

  dynamic get json => jsonDecode(utf8Text);
}

/// Gives Commands the power to run functions before and After the run function
/// The user is expected to make use of `preRun()` It's the input processor
mixin HookRunner on Command {
  /// Runs before every command run
  void prePersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  );

  /// Runs before the selected command
  void preRun(
    ProcessedStandardInput input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {
    print("The selected ${super.name} will run");
  }

  /// Runs after the selected command
  FutureOr<void> postRun(MambaReadContext context) {
    print("The selected ${super.name} has ran");
  }

  /// Runs after every command run
  FutureOr<void> postPersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {
    print("This command ${super.name} has hooked into the context");
  }
}
