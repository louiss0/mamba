import 'package:chalkdart/chalkstrings.dart';

import 'command.dart';
import 'registry.dart';

abstract final class MambaColors {
  static final yellow = chalk.hex('#D3C85E');
  static final bright = chalk.hex('#B3CD58');
  static final primary = chalk.hex('#92C362');
  static final mid = chalk.hex('#81AC4E');
  static final deep = chalk.hex('#50631F');
  static final black = chalk.hex('#11130A');
}

/// An ANSI-styled fragment that a help formatter can compose safely.
///
/// The base type rejects unstyled content so delimiter wrappers cannot be
/// confused with an unformatted command grammar.
extension type FormattedString._(String string) {
  FormattedString(String string) : this._(_parse(string));

  static final _ansiColorRegex = RegExp(r'\x1B\[[0-9;]*m');

  static String _parse(String string) {
    if (!_ansiColorRegex.hasMatch(string)) {
      throw FormatException(
        'Formatted strings must contain SGR (Select Graphic Rendition)',
      );
    }
    return string;
  }
}

/// A styled help fragment that must be supplied.
extension type RequiredString._(FormattedString string)
    implements FormattedString {
  RequiredString(String string)
    : this._(FormattedString('< ${_parse(string)} >'));

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('<') || unformatted.contains('>')) {
      throw FormatException('Required strings must not contain < or >', string);
    }
    return string;
  }
}

/// A styled help fragment enclosed in optional square brackets.
extension type OptionalString._(FormattedString string)
    implements FormattedString {
  OptionalString(String string)
    : this._(FormattedString('[ ${_parse(string)} ]'));

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('[') || unformatted.contains(']')) {
      throw FormatException('Optional strings must not contain [ or ]', string);
    }
    return string;
  }
}

/// Joins a primary help member with members that must be supplied with it.
extension type PairString._(FormattedString string) implements FormattedString {
  PairString(String primaryMember, Iterable<String> pairMembers)
    : this._(
        FormattedString(
          MambaColors.bright([primaryMember, ...pairMembers].join(' & ')),
        ),
      );
}

/// Joins a primary help member with mutually exclusive alternatives.
extension type OrString._(FormattedString string) implements FormattedString {
  OrString(String primaryMember, Iterable<String> alternativeMembers)
    : this._(
        FormattedString(
          MambaColors.mid([primaryMember, ...alternativeMembers].join('|')),
        ),
      );
}

/// A bright-green title for a help section.
extension type SectionTitleString._(FormattedString string)
    implements FormattedString {
  SectionTitleString(String string)
    : this._(FormattedString(MambaColors.deep(string)));
}

/// A bright-yellow description for a help entry.
extension type EntryDescriptionString._(FormattedString string)
    implements FormattedString {
  EntryDescriptionString(String string)
    : this._(FormattedString(MambaColors.yellow(string)));
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
      ..writeln(MambaColors.mid('-' * 10))
      ..writeln(MambaColors.primary(longDescription))
      ..writeln(MambaColors.mid('-' * 10));
  }

  @override
  String format(CommandRegistry registry) {
    final buffer = StringBuffer();
    final positionals = <FormattedString>[
      ...?registry.mandatoryPositionals?.values.map(_requiredPositional),
      ...?registry.discretionaryPositionals?.values.map(_optionalPositional),
      if (registry.variadic case final variadic?) _variadic(variadic),
    ];
    final positionalExpression = positionals
        .map((positional) => positional.string)
        .join(' ');
    final commandLine =
        '${registry.fullPath.join(' ')}${positionals.isEmpty ? '' : ' $positionalExpression'}';

    buffer.writeln(
      MambaColors.primary("$commandLine  '${registry.shortDescription}'"),
    );

    buffer.writeln();

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      formatLongDescription(buffer, longDescription);
      buffer.writeln();
    }

    _writeSection(buffer, 'Flags', [
      _flag(registry.helpFlag),
      ...?registry.boolFlags?.values
          .where((flag) => flag.name != registry.helpFlag.name && !flag.hidden)
          .map(_flag),
      ...?registry.countFlags?.values.where((flag) => !flag.hidden).map(_flag),
    ]);
    buffer.writeln();
    _writeSection(buffer, 'Accessor flags', _accessors(registry));
    buffer.writeln();
    _writeSection(buffer, 'Options', [
      ...?registry.singleOptions?.values
          .where((option) => !option.hidden)
          .map(_option),
      ...?registry.repeatedOptions?.values
          .where((option) => !option.hidden)
          .map(_option),
      ...?registry.pairedOptionGroups?.map(_pairedOptions),
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
    );

    return buffer.toString();
  }

  RequiredString _requiredPositional(Positional positional) =>
      formatIntoRequiredString(_positionalExpression(positional));

  OptionalString _optionalPositional(Positional positional) =>
      formatIntoOptionalString(_positionalExpression(positional));

  OptionalString _variadic(Variadic variadic) => formatIntoOptionalString(
    '-- ${switch (variadic) {
      ChoiceVariadic(:final choices) => '(${_choiceExpression(choices)})',
      NormalVariadic() => variadic.name,
    }}*',
  );

  String _positionalExpression(Positional positional) {
    final name = switch (positional) {
      RepeatedChoicePositional(:final choices) =>
        '(${_choiceExpression(choices)})',
      ChoicePositional(:final choices) => _choiceExpression(choices),
      _ => positional.name,
    };
    return positional is RepeatedPositional
        ? '$name{1,${positional.times + 1}}'
        : name;
  }

  String _choiceExpression(Iterable<Enum> choices) =>
      choices.map((choice) => choice.name).join('|');

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
    takesValue: true,
    choices: switch (option) {
      ChoiceOption(:final choices) => choices,
      _ => null,
    },
  );

  String _pairedOptions(PairedOptions group) {
    final members = group.options;
    final membersAfterFirst = members.skip(1).map(_pairedMember);
    final expression = group.variant
        ? formatIntoOrString(_pairedMember(members.first), membersAfterFirst)
        : formatIntoPairString(_pairedMember(members.first), membersAfterFirst);
    final grammar = group.required
        ? formatIntoRequiredString(expression.string)
        : formatIntoOptionalString(expression.string);
    final description =
        group.description ??
        members.map((member) => member.description ?? '').join('; ');

    return '${grammar.string} ${formatIntoEntryDescription(description).string}';
  }

  String _pairedMember(NamedInput option) {
    final short = switch (option) {
      Option(short: final short) || PairOption(short: final short) => short,
      _ => null,
    };
    final choices = switch (option) {
      PairChoiceOption(:final choices) => choices,
      _ => null,
    };
    final expression = _valueTakingInput(
      option.name,
      short: short,
      choices: choices,
    );
    return _isRepeatablePairMember(option) ? '($expression)+' : expression;
  }

  bool _isRepeatablePairMember(NamedInput option) =>
      option is RepeatablePairOption;

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

  String _accessorEntry(String name, AccessorOption option) => _entry(
    name: name,
    description: option.description,
    required: false,
    takesValue: true,
    choices: switch (option) {
      AccessorChoiceOption(:final choices) => choices,
      _ => null,
    },
  );

  String _entry({
    required String name,
    required String? description,
    required bool required,
    bool repeatable = false,
    bool takesValue = false,
    Iterable<Enum>? choices,
    String? short,
  }) {
    final expression = takesValue
        ? _valueTakingInput(name, short: short, choices: choices)
        : _namedInput(name, short: short);
    final repeatedExpression = repeatable ? '($expression)+' : expression;
    final grammar = required
        ? formatIntoRequiredString(repeatedExpression)
        : formatIntoOptionalString(repeatedExpression);

    return '${grammar.string} ${formatIntoEntryDescription(description ?? '').string}';
  }

  String _valueTakingInput(
    String name, {
    String? short,
    Iterable<Enum>? choices,
  }) {
    final value = choices == null
        ? _valuePlaceholder(name)
        : '(${_choiceExpression(choices)})';
    return '${_namedInput(name, short: short)} $value';
  }

  String _namedInput(String name, {String? short}) {
    final long = '--$name';
    return short == null ? long : '-$short|$long';
  }

  String _valuePlaceholder(String name) => name
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'[-.]'), '_')
      .toUpperCase();

  void _writeSection(StringBuffer buffer, String title, List<String> entries) {
    if (entries.isEmpty) return;
    buffer.writeln(formatIntoSectionTitle(title).string);
    buffer.writeln();
    for (final entry in entries) {
      buffer.writeln(entry);
      final visibleEntry = entry.replaceAll(
        FormattedString._ansiColorRegex,
        '',
      );
      buffer.writeln(MambaColors.black('_' * visibleEntry.length));
    }
  }
}
