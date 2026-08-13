import 'package:chalkdart/chalkstrings.dart';

import 'registry.dart';

/// Renders a [CommandRegistry] as ANSI-styled command-line help text.
class HelpFormatter {
  String formatHelp(CommandRegistry registry) {
    final buffer = StringBuffer();
    final positionals = [
      ...?registry.mandatoryPositionals?.values.map(_requiredPositional),
      ...?registry.discretionaryPositionals?.values.map(_optionalPositional),
      if (registry.variadic != null) _variadicPositional(registry.variadic!),
    ];
    final commandLine =
        '${registry.name}${positionals.isEmpty ? '' : ' ${positionals.join(' ')}'}';

    buffer.writeln("$commandLine  '${registry.shortDescription}'");

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      buffer
        ..writeln('-' * 10)
        ..writeln(longDescription)
        ..writeln('-' * 10);
    }

    _writeSection(buffer, 'Flags', [
      ...?registry.boolFlags?.values.map(_flag),
      ...?registry.countFlags?.values.map(_flag),
    ]);
    _writeSection(buffer, 'Accessor flags', _accessors(registry));
    _writeSection(buffer, 'Options', [
      ...?registry.singleOptions?.values.map(_option),
      ...?registry.repeatedOptions?.values.map(_option),
    ]);
    _writeSection(
      buffer,
      'Commands',
      registry.commandRegistries
              ?.map(
                (command) =>
                    '${command.name} ${command.shortDescription}'.brightYellow,
              )
              .toList() ??
          const [],
    );

    return buffer.toString();
  }

  String _requiredPositional(Positional positional) =>
      '< ${positional.name} >'.red;

  String _optionalPositional(Positional positional) =>
      '[ ${positional.name} ]'.dimGray;

  String _variadicPositional(Variadic positional) =>
      '[ ...${positional.name} ]'.dimGray;

  String _flag(Flag flag) => _entry(
    name: flag.name,
    short: flag.short,
    description: flag.description,
    required: false,
    variadic: false,
  );

  String _option(Option option) => _entry(
    name: option.name,
    short: option.short,
    description: option.description,
    required: option.required,
    variadic: option is RepeatableOption,
  );

  List<String> _accessors(CommandRegistry registry) {
    final values = <String>[];

    for (final entry in registry.accessorSchema?.entries ?? const []) {
      switch (entry.value) {
        case AccessorNamedInput(:final input):
          values.add(_accessorEntry(entry.key, input));
        case AccessorInputGroup(:final inputs):
          for (final input in inputs.entries) {
            values.add(
              _accessorEntry('${entry.key}.${input.key}', input.value),
            );
          }
      }
    }

    return values;
  }

  String _accessorEntry(String name, NamedInput input) => _entry(
    name: name,
    description: input.description,
    required: input is Option && input.required,
    variadic: input is RepeatableOption,
  );

  String _entry({
    required String name,
    required String? description,
    required bool required,
    required bool variadic,
    String? short,
  }) {
    final displayName = short == null ? name : '$name |  $short'.bold;
    final variadicName = variadic ? '...$displayName' : displayName;
    final grammar = required
        ? '< $variadicName >'.red
        : '[ $variadicName ]'.dimGray;

    return '$grammar ${description ?? ''}'.brightYellow;
  }

  void _writeSection(StringBuffer buffer, String title, List<String> entries) {
    if (entries.isEmpty) return;
    buffer.writeln(title.brightGreen);
    for (final entry in entries) {
      buffer.writeln(entry);
    }
  }
}
