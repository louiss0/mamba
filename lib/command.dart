import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mamba/context.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';

/// Metadata used by the parser, registry, help, and completion integrations.
abstract interface class InputDefinition {
  String get name;
  String? get description;
}

/// An identity-based, typed handle for a parsed command value.
sealed class Input<T> implements InputDefinition {
  const Input();
}

mixin RegExpValidated {
  RegExp get regex;
  static final RegExp anyToken = RegExp(r'\S+');
}

mixin ChoiceValidated<T extends Enum> {
  List<T> get choices;
}

mixin NumericRangeValidated<T extends num> {
  T? get min;
  T? get max;
}

mixin NumericStepValidated {
  double? get step;
}

List<T>? _copyList<T>(List<T>? items) =>
    items == null ? null : List.unmodifiable(items);

sealed class Positional<T> extends Input<T> with RegExpValidated {
  Positional(this.name, {this.description, RegExp? regex})
    : _regex = regex ?? RegExpValidated.anyToken;
  @override
  final String name;
  @override
  final String? description;
  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class NormalPositional extends Positional<String> {
  NormalPositional(super.name, {super.description, RegExp? regExp})
    : super(regex: regExp);
}

final class ChoicePositional<T extends Enum> extends Positional<T>
    with ChoiceValidated<T> {
  ChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  final T? defaultValue;
}

sealed class RepeatedPositional<T> extends Positional<List<T>> {
  RepeatedPositional(
    super.name, {
    super.description,
    super.regex,
    this.times = 1,
  }) {
    if (times < 0)
      throw MambaRegistryError.value(times, 'times', 'must not be negative');
  }
  final int times;
}

final class RepeatedStringPositional extends RepeatedPositional<String> {
  RepeatedStringPositional(
    super.name, {
    super.description,
    RegExp? regExp,
    super.times = 1,
  }) : super(regex: regExp);
}

final class RepeatedChoicePositional<T extends Enum>
    extends RepeatedPositional<T>
    with ChoiceValidated<T> {
  RepeatedChoicePositional(
    super.name, {
    super.description,
    required List<T> choices,
    this.defaultValue,
    super.times = 1,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  final T? defaultValue;
}

sealed class Variadic {
  const Variadic({this.description});
  final String? description;
}

final class NormalVariadic extends Variadic with RegExpValidated {
  NormalVariadic({super.description, RegExp? regExp})
    : regex = regExp ?? RegExpValidated.anyToken;
  final RegExp regex;
}

class ChoiceVariadic<T extends Enum> extends Variadic with ChoiceValidated<T> {
  ChoiceVariadic({
    super.description,
    required List<T> choices,
    this.defaultValue,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  final T? defaultValue;
}

final class RepeatedChoiceVariadic<T extends Enum> extends ChoiceVariadic<T> {
  RepeatedChoiceVariadic({
    super.description,
    required super.choices,
    super.defaultValue,
  });
}

sealed class Flag<T> extends Input<T> {
  const Flag(
    this.name, {
    required this.short,
    this.description,
    this.hidden = false,
  });
  @override
  final String name;
  final String? short;
  @override
  final String? description;
  final bool hidden;
}

final class BooleanFlag extends Flag<bool> {
  const BooleanFlag(
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

final class CountFlag extends Flag<int> {
  const CountFlag(super.name, {super.short, super.description, super.hidden});
}

sealed class Option<T> extends Input<T> {
  const Option(
    this.name, {
    required this.short,
    this.description,
    this.required = false,
    this.hidden = false,
  });
  @override
  final String name;
  final String? short;
  @override
  final String? description;
  final bool required;
  final bool hidden;
}

sealed class SingleOption<T> extends Option<T> {
  const SingleOption(
    super.name, {
    required super.short,
    required super.description,
    super.required,
    super.hidden,
  });
}

final class StringOption extends SingleOption<String> with RegExpValidated {
  StringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
    super.required,
    super.hidden,
  }) : _regex = regex ?? RegExpValidated.anyToken;
  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class IntOption extends SingleOption<int>
    with NumericRangeValidated<int> {
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

final class DoubleOption extends SingleOption<double>
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

final class ChoiceOption<T extends Enum> extends SingleOption<T>
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

sealed class RepeatableOption<T> extends Option<List<T>> {
  const RepeatableOption(
    super.name, {
    required super.required,
    super.short,
    super.description,
    super.hidden,
  });
}

final class RepeatableStringOption extends RepeatableOption<String>
    with RegExpValidated {
  RepeatableStringOption(
    super.name, {
    super.required = false,
    RegExp? regex,
    super.short,
    super.description,
    super.hidden,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class RepeatableIntOption extends RepeatableOption<int>
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

final class RepeatableDoubleOption extends RepeatableOption<double>
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

final class RepeatableChoiceOption<T extends Enum> extends RepeatableOption<T>
    with ChoiceValidated<T> {
  List<T> append(T value, List<T>? values) =>
      List.unmodifiable([...?values, value]);
  RepeatableChoiceOption(
    super.name,
    List<T> choices, {
    super.required = false,
    super.short,
    super.description,
    super.hidden,
    this.unique = false,
  }) : choices = List.unmodifiable(choices);
  @override
  final List<T> choices;
  final bool unique;
}

/// A group whose members must either all be supplied or all be omitted.
final class PairedOptions {
  PairedOptions(
    List<PairOption> options, {
    this.description,
    this.required = false,
  }) : options = List.unmodifiable(options);
  final List<PairOption> options;
  final String? description;
  final bool required;
}

sealed class PairOption<T> extends Input<T> {
  const PairOption(this.name, {required this.short, this.description});
  @override
  final String name;
  final String? short;
  @override
  final String? description;
}

final class PairStringOption extends PairOption<String> with RegExpValidated {
  PairStringOption(super.name, {RegExp? regex, super.short, super.description})
    : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class PairIntOption extends PairOption<int>
    with NumericRangeValidated<int> {
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

final class PairDoubleOption extends PairOption<double>
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

final class PairChoiceOption<T extends Enum> extends PairOption<T>
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

sealed class RepeatablePairOption<T> extends PairOption<List<T>> {
  const RepeatablePairOption(super.name, {super.short, super.description});
}

final class RepeatablePairStringOption extends RepeatablePairOption<String>
    with RegExpValidated {
  RepeatablePairStringOption(
    super.name, {
    RegExp? regex,
    super.short,
    super.description,
  }) : regex = regex ?? RegExpValidated.anyToken;
  @override
  final RegExp regex;
}

final class RepeatablePairIntOption extends RepeatablePairOption<int>
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

final class RepeatablePairDoubleOption extends RepeatablePairOption<double>
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

abstract interface class SelectionMember<Result extends Object> {
  PairOption get option;
  Result map(Object? value);
}

final class SelectableOption<Value, Result extends Object>
    implements SelectionMember<Result> {
  const SelectableOption(this.option, this.toResult);
  @override
  final PairOption<Value> option;
  final Result Function(Value value) toResult;
  @override
  Result map(Object? value) => toResult(value as Value);
}

final class SelectedOptions<Result extends Object> extends Input<Result> {
  SelectedOptions(
    List<SelectionMember<Result>> options, {
    this.description,
    this.required = false,
  }) : options = List.unmodifiable(options);
  final List<SelectionMember<Result>> options;
  final String? description;
  final bool required;
  @override
  String get name => options.map((option) => option.option.name).join('|');
}

sealed class AccessorOption implements InputDefinition {
  const AccessorOption(this.name, {this.description});
  @override
  final String name;
  @override
  final String? description;
}

sealed class AccessorPrimitiveOption<T> extends Input<T>
    implements AccessorOption {
  const AccessorPrimitiveOption(this.name, {this.description});
  @override
  final String name;
  @override
  final String? description;
}

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

final class AccessorStringOption extends AccessorPrimitiveOption<String>
    with RegExpValidated {
  AccessorStringOption(super.name, {super.description, RegExp? regex})
    : _regex = regex ?? RegExpValidated.anyToken;
  final RegExp _regex;
  @override
  RegExp get regex => _regex;
}

final class AccessorIntOption extends AccessorPrimitiveOption<int> {
  const AccessorIntOption(super.name, {super.description});
  RegExp get regex => RegExp(r'[+-]?\d+');
}

final class AccessorDoubleOption extends AccessorPrimitiveOption<double> {
  const AccessorDoubleOption(super.name, {super.description});
  RegExp get regex => RegExp(r'[+-]?(?:\d+\.\d+|\d+)');
}

final class AccessorChoiceOption<T extends Enum>
    extends AccessorPrimitiveOption<T>
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

final class ParsedInputs {
  ParsedInputs(Map<InputDefinition, Object?> values)
    : _values = Map.unmodifiable(values);
  final Map<InputDefinition, Object?> _values;
  T? valueOf<T>(Input<T> input) => _values[input] as T?;
  T require<T>(Input<T> input) {
    final value = valueOf(input);
    if (value == null)
      throw StateError('Parser omitted required input --${input.name}.');
    return value;
  }

  bool contains(InputDefinition input) => _values.containsKey(input);
}

final class CommandInvocation {
  const CommandInvocation(this.inputs, this.context);
  final ParsedInputs inputs;
  final MambaContext context;
}

abstract class Command {
  final String? longDescription;
  final List<String>? aliases;
  final List<Positional>? mandatoryPositionals;
  final List<Positional>? discretionaryPositionals;
  final Variadic? variadic;
  final List<Flag>? flags;
  final List<Option>? options;
  final List<PairedOptions>? pairedOptions;
  final List<SelectedOptions>? selectedOptions;
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
    List<SelectedOptions>? selectedOptions,
    List<AccessorListOption>? accessors,
  }) : aliases = _copyList(aliases),
       mandatoryPositionals = _copyList(mandatoryPositionals),
       discretionaryPositionals = _copyList(discretionaryPositionals),
       flags = _copyList(flags),
       options = _copyList(options),
       pairedOptions = _copyList(pairedOptions),
       selectedOptions = _copyList(selectedOptions),
       accessors = _copyList(accessors);
  String get name;
  String get shortDescription;
  FutureOr<String?> run(CommandInvocation invocation, List<String> args);
}

abstract class GroupCommand extends Command {
  final List<String>? defaultSubCommandPath;
  final List<Flag>? inheritedFlags;
  final List<Option>? inheritedOptions;
  final List<Command> commands;
  GroupCommand(
    List<Command> commands, {
    List<String>? defaultSubCommandPath,
    super.aliases,
    List<Flag>? propagatedFlags,
    List<Option>? propagatedOptions,
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.selectedOptions,
    super.accessors,
  }) : commands = List.unmodifiable(commands),
       inheritedFlags = _copyList(propagatedFlags),
       inheritedOptions = _copyList(propagatedOptions),
       defaultSubCommandPath = _copyPath(defaultSubCommandPath);
  static List<String>? _copyPath(List<String>? path) {
    if (path == null) return null;
    if (path.isEmpty || path.any((part) => part.isEmpty))
      throw MambaRegistryError(
        'defaultSubCommandPath must contain command names',
      );
    return List.unmodifiable(path);
  }

  FutureOr<String?> runChildCommand(
    List<String> path,
    CommandInvocation invocation,
    List<String> args,
  ) async {
    if (path.isEmpty || path.contains(name))
      throw ArgumentError.value(path, 'path');
    Command? current;
    List<Command>? children = commands;
    for (final part in path) {
      current = children
          ?.where(
            (candidate) =>
                candidate.name == part ||
                candidate.aliases?.contains(part) == true,
          )
          .firstOrNull;
      if (current == null)
        throw MambaException('command not found in $name ${path.join(' ')}');
      children = current is GroupCommand ? current.commands : null;
    }
    return current!.run(invocation, args);
  }

  @override
  FutureOr<String?> run(CommandInvocation invocation, List<String> args) {
    final path = defaultSubCommandPath;
    return path == null ? '' : runChildCommand(path, invocation, args);
  }
}

enum ShellCompletion { bash, zsh, fish, powershell, carapace }

class CompletionCommand extends Command {
  late RegistryRecord registryRecord;
  final void Function(String path) createFile;
  @override
  String get name => 'completion';
  @override
  String get shortDescription => 'Generate completion for various shells';
  CompletionCommand({
    void Function(String)? createFile,
    super.longDescription,
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.options,
  }) : createFile = createFile ?? _createFileSynchronously;
  CompletionCommand.preset(
    void Function(String path)? createFile, {
    String? longDescription,
  }) : this(
         createFile: createFile,
         longDescription:
             longDescription ??
             'Generate completions for Bash ZSH Fish or Powershell',
         aliases: ['cmp', 'cpt'],
         mandatoryPositionals: [shellInput],
         discretionaryPositionals: [pathInput],
       );
  @override
  String? run(CommandInvocation invocation, List<String> args) {
    final shell = invocation.inputs.require(shellInput);
    final path = invocation.inputs.valueOf(pathInput) ?? '';
    final extension = _extensionFor(shell);
    if (path.isNotEmpty && !_isValidPath(path, extension))
      throw MambaException(
        'When shell is ${shell.name} the path must end in $extension and must have ${registryRecord.name} in the file name',
      );
    createFile(path);
    return 'Created completion ${shell.name} in $path';
  }

  static final ChoicePositional<ShellCompletion> shellInput = ChoicePositional(
    'shell',
    choices: ShellCompletion.values,
  );
  static final NormalPositional pathInput = NormalPositional('path');
  String _extensionFor(ShellCompletion shell) => switch (shell) {
    ShellCompletion.bash => '.bash',
    ShellCompletion.zsh => '.zsh',
    ShellCompletion.fish => '.fish',
    ShellCompletion.powershell => '.ps1',
    ShellCompletion.carapace => '.yaml',
  };
  bool _isValidPath(String path, String extension) {
    if (!path.endsWith(extension)) return false;
    final name = path.split(RegExp(r'[/\\]')).last;
    return name
        .substring(0, name.length - extension.length)
        .contains(registryRecord.name);
  }

  static void _createFileSynchronously(String path) {
    File(path).createSync(exclusive: true);
  }
}

final class ProcessedStandardInput {
  const ProcessedStandardInput(this.bytes);
  final List<int> bytes;
  String get text => String.fromCharCodes(bytes);
  String get utf8Text => utf8.decode(bytes);
  dynamic get json => jsonDecode(utf8Text);
}

mixin HookRunner on Command {
  FutureOr<void> preRun(
    ProcessedStandardInput? input,
    CommandInvocation invocation,
  );
  FutureOr<void> postRun(CommandInvocation invocation) {}
}

mixin PersistentHookRunner on GroupCommand {
  FutureOr<void> prePersistentRun(CommandInvocation invocation);
  FutureOr<void> postPersistentRun(CommandInvocation invocation) {}
}
