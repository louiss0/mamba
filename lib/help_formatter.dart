import 'package:chalkdart/chalkstrings.dart';

import 'registry.dart';

abstract class FormattedString {
  final String string;
  FormattedString(String string) : string = _parse(string);

  static final _ansiColorRegex = RegExp(r'\x1B\[[0-9;]*m');

  static String _parse(String string) {
    if (!_ansiColorRegex.hasMatch(string)) {
      throw FormatException(
        'Formatted strings must not contain SGR (Select Graphic Rendition)',
      );
    }
    return string;
  }
}

class VariadicString extends FormattedString {
  VariadicString(String string) : super('...${_parse(string)}');

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('...')) {
      throw FormatException('Variadic strings must not contain ...');
    }
    return string;
  }
}

class RequiredString extends FormattedString {
  RequiredString(String string) : super('< ${_parse(string)} >');

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('<') || unformatted.contains('>')) {
      throw FormatException('Required strings must not contain < or >');
    }
    return string;
  }
}

class OptionalString extends FormattedString {
  OptionalString(String string) : super('[ ${_parse(string)} ]');

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('[') || unformatted.contains(']')) {
      throw FormatException('Optional strings must not contain [ or ]', string);
    }
    return string;
  }
}

/// Renders a [CommandRegistry] as ANSI-styled command-line help text.
class HelpFormatter {
  String requiredFormatter(String string) => '< $string >'.red;

  String optionalFormatter(String string) => '[ $string ]'.dimGray;

  String variadicFormatter(String string) => '...$string';

  String sectionTitleFormater(String string) => string.brightGreen;

  String entryDescriptionFormatter(String string) => string.brightYellow;

  void longDescriptionFormater(StringBuffer buffer, String longDescription) {
    buffer
      ..writeln('-' * 10)
      ..writeln(longDescription)
      ..writeln('-' * 10);
  }

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
      longDescriptionFormater(buffer, longDescription);
      buffer.writeln();
    }

    _writeSection(buffer, 'Flags', [
      ...?registry.boolFlags?.values.map(_flag),
      ...?registry.countFlags?.values.map(_flag),
    ]);
    buffer.writeln();
    _writeSection(
      buffer,
      'Accessor flags',
      _accessors(registry),
      includeEntrySpacing: false,
    );
    buffer.writeln();
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
                    '${command.name} '
                    '${entryDescriptionFormatter(command.shortDescription)}',
              )
              .toList() ??
          const [],
      includeEntrySpacing: false,
    );

    return buffer.toString();
  }

  String _requiredPositional(Positional positional) =>
      requiredFormatter(positional.name);

  String _optionalPositional(Positional positional) =>
      optionalFormatter(positional.name);

  String _variadicPositional(Variadic positional) =>
      optionalFormatter(variadicFormatter(positional.name));

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

    final accessorSchema = registry.accessorSchema;
    if (accessorSchema == null) return values;

    for (final entry in accessorSchema.entries) {
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
    final variadicName = variadic
        ? variadicFormatter(displayName)
        : displayName;
    final grammar = required
        ? requiredFormatter(variadicName)
        : optionalFormatter(variadicName);

    return '$grammar ${entryDescriptionFormatter(description ?? '')}';
  }

  void _writeSection(
    StringBuffer buffer,
    String title,
    List<String> entries, {
    bool includeEntrySpacing = true,
  }) {
    if (entries.isEmpty) return;
    buffer.writeln(sectionTitleFormater(title));
    if (includeEntrySpacing) buffer.writeln();
    for (final entry in entries) {
      buffer.writeln(entry);
    }
  }
}
