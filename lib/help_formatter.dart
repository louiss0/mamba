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
  new(String string) : this._(_parse(string));

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
  new(String string) : this._(FormattedString('< ${_parse(string)} >'));

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
  new(String string) : this._(FormattedString('[ ${_parse(string)} ]'));

  static String _parse(String string) {
    final unformatted = string.replaceAll(FormattedString._ansiColorRegex, '');
    if (unformatted.contains('[') || unformatted.contains(']')) {
      throw FormatException('Optional strings must not contain [ or ]', string);
    }
    return string;
  }
}

/// Joins members that must be supplied together.
extension type PairString._(FormattedString string) implements FormattedString {
  new(String primaryMember, Iterable<String> pairMembers)
    : this._(
        FormattedString(
          MambaColors.bright([primaryMember, ...pairMembers].join(' & ')),
        ),
      );
}

/// Joins mutually exclusive alternatives.
extension type OrString._(FormattedString string) implements FormattedString {
  new(String primaryMember, Iterable<String> alternativeMembers)
    : this._(
        FormattedString(
          MambaColors.mid([primaryMember, ...alternativeMembers].join('|')),
        ),
      );
}

/// Joins members that can be selected independently.
extension type SelectionString._(FormattedString string)
    implements FormattedString {
  new(String primaryMember, Iterable<String> selectableMembers)
    : this._(
        FormattedString(
          MambaColors.mid([primaryMember, ...selectableMembers].join(' * ')),
        ),
      );
}

/// A green title for a help section.
extension type SectionTitleString._(FormattedString string)
    implements FormattedString {
  new(String string) : this._(FormattedString(MambaColors.deep(string)));
}

/// A yellow description for a help entry.
extension type EntryDescriptionString._(FormattedString string)
    implements FormattedString {
  new(String string) : this._(FormattedString(MambaColors.yellow(string)));
}

/// The customization boundary for rendering a [CommandRegistry] as help text.
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

  SelectionString formatIntoSelectionString(
    String primaryMember,
    Iterable<String> selectableMembers,
  ) => SelectionString(primaryMember, selectableMembers);

  /// Writes a registry long description into [buffer].
  void formatLongDescription(StringBuffer buffer, String longDescription);

  /// Renders all visible help for [registry].
  String format(CommandRegistry registry);
}

/// Renders a [CommandRegistry] as ANSI-styled command-line help text.
///
/// The output contains usage, an optional long description, and non-empty
/// Arguments, Flags, Accessor flags, Options, and Commands sections. Hidden
/// inputs are accepted by Mamba but omitted from this formatter's output.
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
      ...registry.mandatoryPositionals.map(_requiredPositional),
      ...registry.discretionaryPositionals.map(_optionalPositional),
      if (registry.variadic case final variadic?) _variadic(variadic),
    ];
    final positionalExpression = positionals
        .map((positional) => positional.string)
        .join(' ');
    final commandLine =
        '${registry.fullPath.join(' ')}${positionals.isEmpty ? '' : ' $positionalExpression'}';

    buffer
      ..writeln(
        MambaColors.primary("$commandLine  '${registry.shortDescription}'"),
      )
      ..writeln();

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      formatLongDescription(buffer, longDescription);
      buffer.writeln();
    }

    final variadic = registry.variadic;
    final variadicDescription = variadic?.description;
    if (variadic != null && variadicDescription != null) {
      _writeSection(buffer, 'Arguments', [
        _variadicEntry(variadic, variadicDescription),
      ]);
      buffer.writeln();
    }

    _writeSection(
      buffer,
      'Flags',
      registry.applicableFlags
          .where((flag) => !flag.hidden)
          .map(_flag)
          .toList(),
    );
    buffer.writeln();
    _writeSection(buffer, 'Accessor flags', _accessors(registry));
    buffer.writeln();
    _writeSection(buffer, 'Options', [
      ...registry.applicableOptions
          .where((option) => !option.hidden)
          .map(_option),
      ...registry.pairedOptionGroups.map(_pairedOptions),
      ...registry.selectedOptions.map(_selectedOptions),
    ]);
    _writeSection(
      buffer,
      'Commands',
      registry.commandRegistries
          .map(
            (command) =>
                '${command.name} ${formatIntoEntryDescription(command.shortDescription).string}',
          )
          .toList(),
    );

    return buffer.toString();
  }

  String _variadicEntry(Variadic variadic, String description) =>
      '${_variadic(variadic).string} '
      '${formatIntoEntryDescription(description).string}';

  RequiredString _requiredPositional(Positional positional) =>
      formatIntoRequiredString(_positionalExpression(positional));

  OptionalString _optionalPositional(Positional positional) =>
      formatIntoOptionalString(_positionalExpression(positional));

  FormattedString _variadic(Variadic variadic) {
    final expression = switch (variadic) {
      ChoiceVariadic(:final choices) => '(${_choiceExpression(choices)})',
      NormalVariadic() => '...',
    };
    return FormattedString('-- $expression'.dimGray);
  }

  String _positionalExpression(Positional positional) {
    final expression = positional is ChoiceValidated
        ? _choiceExpression(
            (positional as ChoiceValidated).choices.cast<Enum>(),
          )
        : positional.name;
    if (positional is! RepeatedPositionalDefinition) return expression;
    final repeatedExpression = positional is ChoiceValidated
        ? '($expression)'
        : expression;
    final times = (positional as RepeatedPositionalDefinition).times;
    return '$repeatedExpression{1,$times}';
  }

  String _choiceExpression(Iterable<Enum> choices) =>
      choices.map((choice) => choice.name).join('|');

  String _flag(Flag flag) => _entry(
    name: flag.name,
    short: flag.short,
    description: flag.description,
    required: false,
    negatable: flag is BooleanFlag && flag.negatable,
  );

  String _option(Option option) => _entry(
    name: option.name,
    short: option.short,
    description: option.description,
    required: option.isRequired,
    repeatable: option is RepeatableOptionDefinition,
    takesValue: true,
    choices: option is ChoiceValidated
        ? (option as ChoiceValidated).choices.cast<Enum>()
        : null,
  );

  String _pairedOptions(PairedOptionsDefinition group) {
    final members = group.options;
    final expression = formatIntoPairString(
      _groupMember(members.first),
      members.skip(1).map(_groupMember),
    );
    return _groupEntry(expression, group.required, group.description, members);
  }

  String _selectedOptions(SelectedOptions group) {
    final members = group.options;
    final expression = group.single
        ? formatIntoOrString(
            _groupMember(members.first),
            members.skip(1).map(_groupMember),
          )
        : formatIntoSelectionString(
            _groupMember(members.first),
            members.skip(1).map(_groupMember),
          );
    return _groupEntry(expression, group.required, group.description, members);
  }

  String _groupEntry(
    FormattedString expression,
    bool required,
    String? description,
    List<PairOption> members,
  ) {
    final grammar = required
        ? formatIntoRequiredString(expression.string)
        : formatIntoOptionalString(expression.string);
    final resolvedDescription =
        description ??
        members
            .map((member) => member.description)
            .whereType<String>()
            .join('; ');
    return '${grammar.string} '
        '${formatIntoEntryDescription(resolvedDescription).string}';
  }

  String _groupMember(PairOption option) {
    final choices = option is ChoiceValidated
        ? (option as ChoiceValidated).choices.cast<Enum>()
        : null;
    final expression = _valueTakingInput(
      option.name,
      short: option.short,
      choices: choices,
    );
    return option is RepeatablePairOption ? '($expression)+' : expression;
  }

  List<String> _accessors(CommandRegistry registry) {
    final entries = <String>[];
    for (final accessor in registry.applicableAccessors) {
      _writeAccessorEntries(entries, accessor.name, accessor);
    }
    return entries;
  }

  void _writeAccessorEntries(
    List<String> entries,
    String path,
    AccessorOption accessor,
  ) {
    switch (accessor) {
      case AccessorPrimitiveOption():
        entries.add(_accessorEntry(path, accessor));
      case AccessorListOption(hidden: true):
        return;
      case AccessorListOption(:final options):
        for (final option in options) {
          _writeAccessorEntries(entries, '$path.${option.name}', option);
        }
    }
  }

  String _accessorEntry(String name, AccessorPrimitiveOption option) => _entry(
    name: name,
    description: option.description,
    required: option is RequiredInput,
    takesValue: true,
    choices: option is ChoiceValidated
        ? (option as ChoiceValidated).choices.cast<Enum>()
        : null,
  );

  String _entry({
    required String name,
    required String? description,
    required bool required,
    bool repeatable = false,
    bool takesValue = false,
    bool negatable = false,
    Iterable<Enum>? choices,
    String? short,
  }) {
    final expression = takesValue
        ? _valueTakingInput(name, short: short, choices: choices)
        : _namedInput(name, short: short, negatable: negatable);
    final repeatedExpression = repeatable ? '($expression)+' : expression;
    final grammar = required
        ? formatIntoRequiredString(repeatedExpression)
        : formatIntoOptionalString(repeatedExpression);

    return '${grammar.string} '
        '${formatIntoEntryDescription(description ?? '').string}';
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

  String _namedInput(String name, {String? short, bool negatable = false}) {
    final long = negatable ? '--$name|--no-$name' : '--$name';
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
    buffer
      ..writeln(formatIntoSectionTitle(title).string)
      ..writeln();
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
