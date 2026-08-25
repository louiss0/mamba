import 'package:mamba/command.dart';
import 'package:mamba/registry.dart';
import 'package:yaml_writer/yaml_writer.dart';

abstract class RegistryMapConverter {
  final CommandRegistry registry;
  RegistryMapConverter(this.registry);

  Map<String, dynamic> get registryMap => registry.toMap();

  String convert();
}

/// Converts a validated [CommandRegistry] into a Carapace completion spec.
///
/// The spec renders every named input under `flags:` using the modifier order
/// `<key><repeatability><optionality><appearance><arity>` applied to the long
/// flag, publishes ancestor-owned inputs under each descendant's
/// `persistentflags:`, renders variant paired options as `exclusiveflags:`,
/// and exposes choice positionals and variadics through `completion:`.
final class CarapaceSpecConverter extends RegistryMapConverter {
  CarapaceSpecConverter(super.registry);

  @override
  String convert() => YamlWriter().write(_specFor(registry));
}

/// Renders [registry] as the spec map for one command level.
///
/// The root level contributes only `name` plus the shared command body;
/// descendants repeat that shape nested under `commands:`.
Map<String, dynamic> _specFor(CommandRegistry registry) => {
  'name': registry.name,
  ..._commandBody(registry, const [], const []),
};

/// Combines short and long descriptions exactly like the registry export.
String _descriptionFor(CommandRegistry registry) =>
    registry.longDescription == null
    ? registry.shortDescription
    : '${registry.shortDescription}\n\n${registry.longDescription}';

/// Builds the ordered Carapace key for one named input.
///
/// Modifiers follow `<key><repeatability><optionality><appearance><arity>`
/// and always attach to the long flag; the optional short alias is prefixed.
/// Value-taking inputs fill the optionality slot with `!` when required and
/// `?` otherwise, while flags carry no optionality or arity.
String _inputKey({
  required String name,
  required String? short,
  required bool repeatable,
  required bool mandatory,
  required bool hidden,
  required bool takesValue,
}) =>
    '${short == null ? '' : '-$short, '}--$name'
    '${repeatable ? '*' : ''}'
    '${takesValue ? (mandatory ? '!' : '?') : ''}'
    '${hidden ? '&' : ''}'
    '${takesValue ? '=' : ''}';

/// Wraps a description and optional default into the entry value.
///
/// Entries with a default render as an object so Carapace can complete the
/// fallback; everything else stays a bare description string.
Object _entryValue(String? description, Object? defaultValue) =>
    defaultValue == null
    ? (description ?? '')
    : {'description': description ?? '', 'default': defaultValue};

/// Extracts the registered choice default from any input that carries one.
Object? _choiceDefault(NamedInput input) => switch (input) {
  ChoiceOption(:final defaultValue) ||
  PairedChoiceOption(:final defaultValue) ||
  PairChoiceOption(:final defaultValue) => defaultValue?.name,
  _ => null,
};

/// Collects the rendered body shared by every spec level.
///
/// [inheritedFlags] and [inheritedOptions] carry every ancestor-published
/// input accumulated from the root; this level's own published inputs are
/// appended so they render persistently here and travel down the subtree.
Map<String, dynamic> _commandBody(
  CommandRegistry registry,
  List<Flag> inheritedFlags,
  List<Option> inheritedOptions,
) {
  final persistentFlags = [...inheritedFlags, ...?registry.publishedFlags];
  final persistentOptions = [
    ...inheritedOptions,
    ...?registry.publishedOptions,
  ];
  final persistentFlagNames = {for (final flag in persistentFlags) flag.name};
  final persistentOptionNames = {
    for (final option in persistentOptions) option.name,
  };

  final localFlagNames = {
    ...?registry.boolFlags?.keys,
    ...?registry.countFlags?.keys,
  };
  // A local same-name definition replaces the inherited input entirely.
  final effectivePersistentFlags = persistentFlags
      .where((flag) => !localFlagNames.contains(flag.name))
      .toList();

  final localOptionNames = {
    ...?registry.singleOptions?.keys,
    ...?registry.repeatedOptions?.keys,
    ...?registry.pairedOptions?.keys,
  };
  final effectivePersistentOptions = persistentOptions
      .where((option) => !localOptionNames.contains(option.name))
      .toList();

  final boolFlags = [
    ...effectivePersistentFlags.whereType<BooleanFlag>(),
    ...?registry.boolFlags?.values,
  ];
  final countFlags = [
    ...effectivePersistentFlags.whereType<CountFlag>(),
    ...?registry.countFlags?.values,
  ];
  final singleOptions = [
    ...effectivePersistentOptions.whereType<SingleOption>(),
    ...?registry.singleOptions?.values,
  ];
  final repeatedOptions = [
    ...effectivePersistentOptions.whereType<RepeatableOption>(),
    ...?registry.repeatedOptions?.values,
  ];
  final pairedOptions = [
    ...effectivePersistentOptions.whereType<PairedOption>(),
    ...?registry.pairedOptions?.values,
  ];

  final flagEntries = <String, Object>{};
  final persistentEntries = <String, Object>{};
  final exclusiveGroups = <List<String>>[];

  // Ancestor-published inputs complete from the descendant's
  // persistentflags; locally declared inputs stay in flags.
  void placeEntry(
    String name,
    bool persistent,
    String key,
    String? description, {
    Object? defaultValue,
  }) {
    (persistent ? persistentEntries : flagEntries)[key] = _entryValue(
      description,
      defaultValue,
    );
  }

  void placeOption(Option option, {required bool repeatable}) {
    placeEntry(
      option.name,
      persistentOptionNames.contains(option.name),
      _inputKey(
        name: option.name,
        short: option.short,
        repeatable: repeatable,
        mandatory: option.required,
        hidden: option.hidden,
        takesValue: true,
      ),
      option.description,
      defaultValue: _choiceDefault(option),
    );
  }

  // Pair members inherit their group's placement, so a published paired
  // option keeps its members beside it under persistentflags.
  void placePairedGroup(PairedOption paired, {required bool repeatable}) {
    final persistent = persistentOptionNames.contains(paired.name);
    placeEntry(
      paired.name,
      persistent,
      _inputKey(
        name: paired.name,
        short: paired.short,
        repeatable: repeatable,
        mandatory: paired.required,
        hidden: paired.hidden,
        takesValue: true,
      ),
      paired.description,
      defaultValue: _choiceDefault(paired),
    );
    for (final member in paired.options) {
      placeEntry(
        member.name,
        persistent,
        _inputKey(
          name: member.name,
          short: member.short,
          repeatable: member is RepeatablePairOption,
          mandatory: paired.required,
          hidden: false,
          takesValue: true,
        ),
        member.description,
        defaultValue: _choiceDefault(member),
      );
    }
  }

  for (final flag in [...boolFlags, ...countFlags]) {
    placeEntry(
      flag.name,
      persistentFlagNames.contains(flag.name),
      _inputKey(
        name: flag.name,
        short: flag.short,
        repeatable: flag is CountFlag,
        mandatory: false,
        hidden: flag.hidden,
        takesValue: false,
      ),
      flag.description,
      // Only a flipped boolean default is worth publishing; the parser
      // already treats absent flags as false.
      defaultValue: flag is BooleanFlag && flag.defaultValue == true
          ? true
          : null,
    );
  }

  for (final option in [...singleOptions, ...repeatedOptions]) {
    placeOption(option, repeatable: option is RepeatableOption);
  }

  // Variant paired options are alternatives, so they render as exclusive
  // groups instead of ordinary entries; required-together groups render all
  // members as plain entries sharing the group's requiredness.
  for (final paired in pairedOptions) {
    if (paired.variant) {
      exclusiveGroups.add([
        paired.name,
        for (final member in paired.options) member.name,
      ]);
      continue;
    }
    placePairedGroup(paired, repeatable: paired is RepeatablePairedOption);
  }

  final body = <String, dynamic>{'description': _descriptionFor(registry)};
  if (registry.commandAliases case final aliases?) body['aliases'] = aliases;
  if (flagEntries.isNotEmpty) body['flags'] = flagEntries;
  if (persistentEntries.isNotEmpty) body['persistentflags'] = persistentEntries;
  if (exclusiveGroups.isNotEmpty) body['exclusiveflags'] = exclusiveGroups;

  final completion = _completionFor(registry);
  if (completion.isNotEmpty) body['completion'] = completion;

  if (registry.commandRegistries case final children?) {
    body['commands'] = [
      for (final child in children)
        {
          'name': child.name,
          ..._commandBody(child, persistentFlags, persistentOptions),
        },
    ];
  }
  return body;
}

/// Exposes choice positionals and variadics through Carapace completion.
///
/// Choice positionals fill `positional`; a repeated choice positional fills
/// one bounded slot per accepted value (its `times` repetitions plus the
/// original) because Mamba has no unbounded positional. String options fill
/// `completion.flag`, and every remaining ordinary positional or variadic
/// completes `$files` by default.
Map<String, dynamic> _completionFor(CommandRegistry registry) {
  final positionalChoices = <List<String>>[];
  final flagChoices = <String, List<String>>{};
  const paginatedNumberChoices = [
    '-',
    r"$carapace.number.Range({format: '${C_VALUE}%d', start: 0, end: 9})",
    r'$nospace(*)',
  ];

  for (final positional in [
    ...?registry.mandatoryPositionals?.values,
    ...?registry.discretionaryPositionals?.values,
  ]) {
    switch (positional) {
      case RepeatedChoicePositional(:final choices, :final times):
        for (var slot = 0; slot <= times; slot++) {
          positionalChoices.add(_choicePairs(choices));
        }
      case ChoicePositional(:final choices):
        positionalChoices.add(_choicePairs(choices));
      case RepeatedPositional(times: final times):
        for (var slot = 0; slot <= times; slot++) {
          positionalChoices.add(const [r'$files']);
        }
      default:
        positionalChoices.add(const [r'$files']);
    }
  }

  // Each completion request expands one decimal digit so the finite Carapace
  // action can cover an unbounded numeric domain without command execution.
  for (final option
      in registry.singleOptions?.values ?? const <SingleOption>[]) {
    switch (option) {
      case StringOption():
        flagChoices[option.name] = const [r'$files'];
      case IntOption() || DoubleOption():
        flagChoices[option.name] = paginatedNumberChoices;
      default:
        break;
    }
  }

  // Repeated choice variadics must be tested before their base class or the
  // ChoiceVariadic pattern would absorb them.
  final dashChoices = <List<String>>[];
  final dashAnyChoices = <String>[];
  switch (registry.variadic) {
    case RepeatedChoiceVariadic(:final choices):
      dashAnyChoices.addAll(choices.map((choice) => choice.name));
    case ChoiceVariadic(:final choices):
      dashChoices.add(_choicePairs(choices));
    case NormalVariadic():
      dashChoices.add(const [r'$files']);
    default:
      break;
  }

  return {
    if (positionalChoices.isNotEmpty) 'positional': positionalChoices,
    if (flagChoices.isNotEmpty) 'flag': flagChoices,
    if (dashChoices.isNotEmpty) 'dash': dashChoices,
    if (dashAnyChoices.isNotEmpty) 'dashany': dashAnyChoices,
  };
}

/// Repeats each enum choice as its own completion value and description.
List<String> _choicePairs(List<Enum> choices) => [
  for (final choice in choices) ...[choice.name, choice.name],
];
