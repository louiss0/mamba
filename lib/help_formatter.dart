import 'package:chalkdart/chalkstrings.dart';

import 'command.dart';
import 'registry.dart';

/// An ANSI-styled fragment that a help formatter can compose safely.
///
/// The base type rejects unstyled content so delimiter wrappers cannot be
/// confused with an unformatted command grammar.
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

/// A styled help fragment enclosed in required angle brackets.
final class RequiredString extends FormattedString {
  RequiredString(String string) : super('< ${_parse(string)} >');

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('<') || unformatted.contains('>')) {
      throw FormatException('Required strings must not contain < or >');
    }
    return string;
  }
}

/// A styled help fragment enclosed in optional square brackets.
final class OptionalString extends FormattedString {
  OptionalString(String string) : super('[ ${_parse(string)} ]');

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('[') || unformatted.contains(']')) {
      throw FormatException('Optional strings must not contain [ or ]', string);
    }
    return string;
  }
}

/// Joins a primary help member with members that must be supplied with it.
final class PairString extends FormattedString {
  PairString(String primaryMember, Iterable<String> pairMembers)
    : super._([primaryMember, ...pairMembers].join(' & '));
}

/// Joins a primary help member with mutually exclusive alternatives.
final class OrString extends FormattedString {
  OrString(String primaryMember, Iterable<String> alternativeMembers)
    : super._([primaryMember, ...alternativeMembers].join(' | '));
}

/// A bright-green title for a help section.
final class SectionTitleString extends FormattedString {
  SectionTitleString(String string) : super(string.brightGreen);
}

/// A bright-yellow description for a help entry.
final class EntryDescriptionString extends FormattedString {
  EntryDescriptionString(String string) : super(string.brightYellow);
}

/// The customization boundary for rendering a [CommandRegistry] as help text.
///
/// Implement [format] to render a registry and [formatLongDescription] to
/// control its long-description block. The other methods construct the styled
/// grammar fragments used by [MambaHelpFormatter].
abstract class HelpFormatter {
  RequiredString formatIntoRequiredString(String string) =>
      RequiredString(string.red);

  OptionalString formatIntoOptionalString(String string) =>
      OptionalString(string.dimGray);

  SectionTitleString formatIntoSectionTitle(String string) =>
      SectionTitleString(string);

  EntryDescriptionString formatIntoEntryDescription(String string) =>
      EntryDescriptionString(string);

  OrString formatIntoOrString(
    String primaryMember,
    Iterable<String> alternativeMembers,
  ) => OrString(primaryMember, alternativeMembers);

  PairString formatIntoPairString(
    String primaryMember,
    Iterable<String> pairMembers,
  ) => PairString(primaryMember, pairMembers);

  /// Writes a registry long description into [buffer].
  void formatLongDescription(StringBuffer buffer, String longDescription);

  /// Renders all visible help for [registry].
  String format(CommandRegistry registry);
}

/// Renders a [CommandRegistry] as ANSI-styled command-line help text.
///
/// The output contains usage, an optional long description, and non-empty
/// Flags, Accessor flags, Options, and Commands sections. Hidden inputs are
/// accepted by Mamba but omitted from this formatter's output.
final class MambaHelpFormatter extends HelpFormatter {
  @override
  void formatLongDescription(StringBuffer buffer, String longDescription) {
    buffer
      ..writeln('-' * 10)
      ..writeln(longDescription)
      ..writeln('-' * 10);
  }

  @override
  String format(CommandRegistry registry) {
    final buffer = StringBuffer();
    final positionals = [
      ...?registry.mandatoryPositionals?.values.map(_requiredPositional),
      ...?registry.discretionaryPositionals?.values.map(_optionalPositional),
    ];
    final commandLine =
        '${registry.name}${positionals.isEmpty ? '' : ' ${positionals.map((positional) => positional.string).join(' ')}'}';

    buffer.writeln("$commandLine  '${registry.shortDescription}'");

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      formatLongDescription(buffer, longDescription);
      buffer.writeln();
    }

    _writeSection(buffer, 'Flags', [
      _flag(registry.helpFlag),
      ...?registry.boolFlags?.values.where((flag) => !flag.hidden).map(_flag),
      ...?registry.countFlags?.values.where((flag) => !flag.hidden).map(_flag),
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
      ...?registry.singleOptions?.values
          .where((option) => !option.hidden)
          .map(_option),
      ...?registry.repeatedOptions?.values
          .where((option) => !option.hidden)
          .map(_option),
      ...?registry.pairedOptions?.values.map(_pairedOption),
    ]);
    _writeSection(
      buffer,
      'Commands',
      registry.commandRegistries
              ?.map(
                (command) =>
                    '${command.name} '
                    '${formatIntoEntryDescription(command.shortDescription).string}',
              )
              .toList() ??
          const [],
      includeEntrySpacing: false,
    );

    return buffer.toString();
  }

  RequiredString _requiredPositional(Positional positional) =>
      formatIntoRequiredString(positional.name);

  OptionalString _optionalPositional(Positional positional) =>
      formatIntoOptionalString(positional.name);

  String _flag(Flag flag) => _entry(
    name: flag.name,
    short: flag.short,
    description: flag.description,
    required: false,
  );

  String _option(Option option) => _entry(
    name: option.name,
    short: option.short,
    description: option.description,
    required: option.required,
    repeatable: option is RepeatableOption,
  );

  String _pairedOption(PairedOption option) {
    final members = [option, ...option.options];
    final membersAfterPrimary = members.skip(1).map(_pairedMember);
    final expression = option.variant
        ? formatIntoOrString(_pairedMember(members.first), membersAfterPrimary)
        : formatIntoPairString(
            _pairedMember(members.first),
            membersAfterPrimary,
          );
    final grammar = option.required
        ? formatIntoRequiredString(expression.string)
        : formatIntoOptionalString(expression.string);
    final description = members
        .map((member) => member.description ?? '')
        .join('; ');

    return '${grammar.string} ${formatIntoEntryDescription(description).string}';
  }

  String _pairedMember(NamedInput option) {
    final longName = '--${option.name}';
    final short = switch (option) {
      Option(short: final short) || PairOption(short: final short) => short,
      _ => null,
    };
    final displayName = short == null ? longName : '$longName | -$short'.bold;
    return _isRepeatablePairMember(option) ? '...$displayName' : displayName;
  }

  bool _isRepeatablePairMember(NamedInput option) => switch (option) {
    RepeatablePairedOption() || RepeatablePairOption() => true,
    _ => false,
  };

  List<String> _accessors(CommandRegistry registry) {
    final values = <String>[];

    final accessors = registry.accessors;
    if (accessors == null) return values;

    for (final entry in accessors.entries) {
      _writeAccessorEntries(values, entry.key, entry.value);
    }

    return values;
  }

  void _writeAccessorEntries(
    List<String> values,
    String path,
    AccessorOption accessor,
  ) {
    switch (accessor) {
      case AccessorPrimitiveOption():
        values.add(_accessorEntry(path, accessor));
      case AccessorListOption(hidden: true):
        return;
      case AccessorListOption(options: final options):
        for (final option in options) {
          _writeAccessorEntries(values, '$path.${option.name}', option);
        }
    }
  }

  String _accessorEntry(String name, AccessorOption option) =>
      _entry(name: name, description: option.description, required: false);

  String _entry({
    required String name,
    required String? description,
    required bool required,
    bool repeatable = false,
    String? short,
  }) {
    final displayName = short == null ? name : '$name |  $short'.bold;
    final repeatableName = repeatable ? '...$displayName' : displayName;
    final grammar = required
        ? formatIntoRequiredString(repeatableName)
        : formatIntoOptionalString(repeatableName);

    return '${grammar.string} ${formatIntoEntryDescription(description ?? '').string}';
  }

  void _writeSection(
    StringBuffer buffer,
    String title,
    List<String> entries, {
    bool includeEntrySpacing = true,
  }) {
    if (entries.isEmpty) return;
    buffer.writeln(formatIntoSectionTitle(title).string);
    if (includeEntrySpacing) buffer.writeln();
    for (final entry in entries) {
      buffer.writeln(entry);
    }
  }
}
