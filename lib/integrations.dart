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
  ..._commandBody(registry),
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
}) => '${short == null ? '' : '-$short, '}--$name'
  '${repeatable ? '*' : ''}'
  '${takesValue ? (mandatory ? '!' : '?') : ''}'
  '${hidden ? '&' : ''}'
  '${takesValue ? '=' : ''}';

/// Collects the rendered body shared by every spec level.
Map<String, dynamic> _commandBody(CommandRegistry registry) {
  final persistentFlagNames = registry.persistentFlagNames ?? const <String>{};
  final persistentOptionNames =
      registry.persistentOptionNames ?? const <String>{};

  final flagEntries = <String, String>{};
  final persistentEntries = <String, String>{};
  final exclusiveGroups = <List<String>>[];

  // Ancestor-published inputs complete from the descendant's
  // persistentflags; locally declared inputs stay in flags.
  void placeEntry(String name, bool persistent, String key, String? description) {
    (persistent ? persistentEntries : flagEntries)[key] = description ?? '';
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
      );
    }
  }

  for (final flag in [
    ...?registry.boolFlags?.values,
    ...?registry.countFlags?.values,
  ]) {
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
    );
  }

  for (final option in [
    ...?registry.singleOptions?.values,
    ...?registry.repeatedOptions?.values,
  ]) {
    placeOption(option, repeatable: option is RepeatableOption);
  }

  // Variant paired options are alternatives, so they render as exclusive
  // groups instead of ordinary entries; required-together groups render all
  // members as plain entries sharing the group's requiredness.
  for (final paired in [...?registry.pairedOptions?.values]) {
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
      for (final child in children) {'name': child.name, ..._commandBody(child)},
    ];
  }
  return body;
}

/// Exposes choice positionals and variadics through Carapace completion.
///
/// Single choice positionals fill `positional`, repeated ones fill
/// `positionalany`; choice variadics fill `dash` while repeated choice
/// variadics fill `dashany`.
Map<String, dynamic> _completionFor(CommandRegistry registry) {
  final positionalChoices = <List<String>>[];
  final positionalAnyChoices = <String>[];

  for (final positional in [
    ...?registry.mandatoryPositionals?.values,
    ...?registry.discretionaryPositionals?.values,
  ]) {
    switch (positional) {
      case ChoicePositional(:final choices):
        positionalChoices.add(_choicePairs(choices));
      case RepeatedChoicePositional(:final choices):
        positionalAnyChoices.addAll(choices.map((choice) => choice.name));
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
    default:
      break;
  }

  return {
    if (positionalChoices.isNotEmpty) 'positional': positionalChoices,
    if (positionalAnyChoices.isNotEmpty) 'positionalany': positionalAnyChoices,
    if (dashChoices.isNotEmpty) 'dash': dashChoices,
    if (dashAnyChoices.isNotEmpty) 'dashany': dashAnyChoices,
  };
}

/// Repeats each enum choice as its own completion value and description.
List<String> _choicePairs(List<Enum> choices) => [
  for (final choice in choices) ...[choice.name, choice.name],
];
