import 'package:chalkdart/chalkstrings.dart';

import 'registry.dart';

abstract class FormattedString {
  final String string;
  FormattedString(String string) : string = _parse(string);
  FormattedString._(this.string);

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

final class VariadicString extends FormattedString {
  VariadicString(String string) : super('...${_parse(string)}');
  VariadicString._formatted(String string) : super._('...$string');

  factory VariadicString.format(String string) =>
      VariadicString._formatted(string);

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('...')) {
      throw FormatException('Variadic strings must not contain ...');
    }
    return string;
  }
}

final class RequiredString extends FormattedString {
  RequiredString(String string) : super('< ${_parse(string)} >');
  RequiredString._formatted(String string) : super._('< $string >'.red);

  factory RequiredString.format(String string) =>
      RequiredString._formatted(string);

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('<') || unformatted.contains('>')) {
      throw FormatException('Required strings must not contain < or >');
    }
    return string;
  }
}

final class OptionalString extends FormattedString {
  OptionalString(String string) : super('[ ${_parse(string)} ]');
  OptionalString._formatted(String string) : super._('[ $string ]'.dimGray);

  factory OptionalString.format(String string) =>
      OptionalString._formatted(string);

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('[') || unformatted.contains(']')) {
      throw FormatException('Optional strings must not contain [ or ]', string);
    }
    return string;
  }
}

final class SectionTitleString extends FormattedString {
  SectionTitleString(String string) : super(string.brightGreen);
}

final class EntryDescriptionString extends FormattedString {
  EntryDescriptionString(String string) : super(string.brightYellow);
}

/// Renders a [CommandRegistry] as ANSI-styled command-line help text.
class HelpFormatter {
  RequiredString requiredFormatter(String string) =>
      RequiredString.format(string);

  OptionalString optionalFormatter(String string) =>
      OptionalString.format(string);

  VariadicString variadicFormatter(String string) =>
      VariadicString.format(string);

  SectionTitleString sectionTitleFormater(String string) =>
      SectionTitleString(string);

  EntryDescriptionString entryDescriptionFormatter(String string) =>
      EntryDescriptionString(string);

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
        '${registry.name}${positionals.isEmpty ? '' : ' ${positionals.map((positional) => positional.string).join(' ')}'}';

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
                    '${entryDescriptionFormatter(command.shortDescription).string}',
              )
              .toList() ??
          const [],
      includeEntrySpacing: false,
    );

    return buffer.toString();
  }

  RequiredString _requiredPositional(Positional positional) =>
      requiredFormatter(positional.name);

  OptionalString _optionalPositional(Positional positional) =>
      optionalFormatter(positional.name);

  OptionalString _variadicPositional(Variadic positional) =>
      optionalFormatter(variadicFormatter(positional.name).string);

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

    for (final accessor in accessorSchema) {
      switch (accessor) {
        case AccessorPrimitiveOption():
          values.add(_accessorEntry(accessor.name, accessor));
        case AccessorListOption(options: final flags):
          for (final flag in flags) {
            values.add(_accessorEntry('${accessor.name}.${flag.name}', flag));
          }
      }
    }

    return values;
  }

  String _accessorEntry(String name, AccessorOption option) => _entry(
    name: name,
    description: option.description,
    required: false,
    variadic: false,
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
        ? variadicFormatter(displayName).string
        : displayName;
    final grammar = required
        ? requiredFormatter(variadicName)
        : optionalFormatter(variadicName);

    return '${grammar.string} ${entryDescriptionFormatter(description ?? '').string}';
  }

  void _writeSection(
    StringBuffer buffer,
    String title,
    List<String> entries, {
    bool includeEntrySpacing = true,
  }) {
    if (entries.isEmpty) return;
    buffer.writeln(sectionTitleFormater(title).string);
    if (includeEntrySpacing) buffer.writeln();
    for (final entry in entries) {
      buffer.writeln(entry);
    }
  }
}
