import 'package:mamba/command.dart';

import 'errors.dart';

/// Properties accepted in a serialised [CommandRegistry] map.
///
/// Each property validates the shape written by [CommandRegistry.toMap]. The
/// optional [path] preserves the full location of malformed nested data in a
/// [MambaIntegrationException].
enum RegistryMapProps {
  name,
  description,
  flags,
  persistentFlags,
  persistentOptions,
  options,
  optionGroups,
  commands,
  accessors,
  aliases,
  positionals,
  variadic;

  Object? parse(Object? value, [String? path]) {
    final propertyPath = path ?? this.name;
    switch (this) {
      case RegistryMapProps.name:
      case RegistryMapProps.description:
        _expectString(value, propertyPath);
      case RegistryMapProps.flags:
      case RegistryMapProps.persistentFlags:
        _parseInputCollection(value, propertyPath, _parseFlag);
      case RegistryMapProps.options:
      case RegistryMapProps.persistentOptions:
        _parseInputCollection(value, propertyPath, _parseOption);
      case RegistryMapProps.optionGroups:
        _parseOptionGroups(value, propertyPath);
      case RegistryMapProps.commands:
        _parseCommands(value, propertyPath);
      case RegistryMapProps.accessors:
        _parseAccessors(value, propertyPath);
      case RegistryMapProps.aliases:
        _parseAliases(value, propertyPath);
      case RegistryMapProps.positionals:
        _parseInputCollection(value, propertyPath, _parsePositional);
      case RegistryMapProps.variadic:
        _parseVariadic(value, propertyPath);
    }
    return value;
  }
}

void _parseCommand(Map<Object?, Object?> value, String path) {
  final properties = _stringMap(value, path);
  _validateProperties(
    properties,
    path,
    RegistryMapProps.values.map((property) => property.name).toSet(),
    const {'name', 'description'},
  );

  for (final property in RegistryMapProps.values) {
    final propertyValue = properties[property.name];
    if (propertyValue != null || properties.containsKey(property.name)) {
      property.parse(propertyValue, _joinRegistryPath(path, property.name));
    }
  }
  _validateOptionGroupMembers(properties, path);
  _validateCommandSemantics(properties, path);
}

final RegExp _registryName = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$');
final RegExp _registryShortName = RegExp(r'^[A-Za-z]$');

void _validateCommandSemantics(Map<String, Object?> command, String path) {
  final namePath = _joinRegistryPath(path, 'name');
  _validateRegistryName(command['name'] as String, namePath);

  final descriptionPath = _joinRegistryPath(path, 'description');
  final description = command['description'] as String;
  if (description.isEmpty) {
    _invalid(description, descriptionPath, 'must not be empty');
  }
  // The serialized description starts with the live short description, which
  // live registration rejects when empty or longer than 150 characters.
  final shortDescription = description.split('\n\n').first;
  if (shortDescription.length > 150) {
    _invalid(
      shortDescription,
      descriptionPath,
      'must not exceed 150 characters before the long description',
    );
  }

  final inputCollections = [
    'flags',
    'persistentFlags',
    'options',
    'persistentOptions',
    'positionals',
    'accessors',
  ];
  // Positional names occupy a separate namespace: token syntax keeps their
  // values unambiguous, so live registration permits cross-category sharing.
  final positionalNames = <String>{};
  final localNames = <String>{};
  final persistentNames = <String>{};
  final localShorts = <String>{};
  final persistentShorts = <String>{};
  final negatedFlagNames = <String>{};
  for (final collectionName in inputCollections) {
    final value = command[collectionName];
    if (value is! Map) continue;
    final collection = _stringMap(
      value,
      _joinRegistryPath(path, collectionName),
    );
    for (final entry in collection.entries) {
      final inputPath = _joinRegistryPath(
        _joinRegistryPath(path, collectionName),
        entry.key,
      );
      _validateRegistryName(entry.key, inputPath);
      final isPositional = collectionName == 'positionals';
      final isPersistent =
          collectionName == 'persistentFlags' ||
          collectionName == 'persistentOptions';
      final names = isPositional
          ? positionalNames
          : isPersistent
          ? persistentNames
          : localNames;
      final shorts = isPersistent ? persistentShorts : localShorts;
      if (!names.add(entry.key)) {
        _invalid(
          entry.key,
          inputPath,
          'collides with another registered input',
        );
      }
      // The built-in help flag is the only input allowed to claim the
      // reserved help name or its -h short alias.
      final helpInput = entry.value is Map
          ? _map(entry.value, inputPath)
          : const <String, Object?>{};
      final isHelpFlagEntry =
          collectionName == 'flags' &&
          entry.key == 'help' &&
          helpInput['short'] == 'h' &&
          helpInput.containsKey('default') &&
          helpInput.containsKey('negatable');
      if (entry.key == 'help' && !isHelpFlagEntry) {
        _invalid(entry.key, inputPath, 'is reserved by the built-in help flag');
      }
      if (entry.value is Map) {
        final input = _map(entry.value, inputPath);
        final short = input['short'];
        if (short is String) {
          if (!_registryShortName.hasMatch(short)) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'must be a single letter',
            );
          }
          if (short == 'h' && !isHelpFlagEntry) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'is reserved by the built-in help flag',
            );
          }
          if (!shorts.add(short)) {
            _invalid(
              short,
              _joinRegistryPath(inputPath, 'short'),
              'collides with another short alias',
            );
          }
        }
        if (input['negatable'] == true) {
          negatedFlagNames.add('no-${entry.key}');
        }
      }
    }
  }
  // Local options may replace persistent options of the same name, but every
  // other local/persistent name collision is ambiguous in the live registry.
  final localOptions = command['options'] is Map
      ? _stringMap(command['options'], _joinRegistryPath(path, 'options'))
      : const <String, Object?>{};
  final persistentOptions = command['persistentOptions'] is Map
      ? _stringMap(
          command['persistentOptions'],
          _joinRegistryPath(path, 'persistentOptions'),
        )
      : const <String, Object?>{};
  final persistentFlags = command['persistentFlags'] is Map
      ? _stringMap(
          command['persistentFlags'],
          _joinRegistryPath(path, 'persistentFlags'),
        )
      : const <String, Object?>{};
  final localFlags = command['flags'] is Map
      ? _stringMap(command['flags'], _joinRegistryPath(path, 'flags'))
      : const <String, Object?>{};
  for (final name in localNames.intersection(persistentNames)) {
    if (localOptions.containsKey(name) && persistentOptions.containsKey(name)) {
      continue;
    }
    _invalid(name, path, 'collides between local and persistent inputs');
  }
  Map<String, String> shortNames(Map<String, Object?> inputs) => {
    for (final entry in inputs.entries)
      if (_map(entry.value, path)['short'] case final String short)
        short: entry.key,
  };
  final localShortNames = shortNames({...localFlags, ...localOptions});
  final persistentShortNames = shortNames({
    ...persistentFlags,
    ...persistentOptions,
  });
  for (final short in localShorts.intersection(persistentShorts)) {
    if (localShortNames[short] == persistentShortNames[short]) continue;
    _invalid(
      short,
      path,
      'collides between local and persistent short aliases',
    );
  }

  // Every map represents the live built-in help flag exactly, rather than a
  // caller-defined approximation of parser-owned behavior.
  final help = localFlags['help'];
  const helpDescription = 'Show this help message.';
  if ((help != null && help is! Map) ||
      persistentFlags.containsKey('help') ||
      (help is Map &&
          (_map(help, _joinRegistryPath(path, 'flags.help'))['short'] != 'h' ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['default'] !=
                  false ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['negatable'] !=
                  false ||
              _map(help, _joinRegistryPath(path, 'flags.help'))['hidden'] !=
                  false ||
              _map(
                    help,
                    _joinRegistryPath(path, 'flags.help'),
                  )['description'] !=
                  helpDescription))) {
    _invalid(
      help,
      _joinRegistryPath(path, 'flags.help'),
      'must be the canonical built-in help flag',
    );
  }

  // A negatable boolean flag also accepts --no-<name>; that synthesized
  // spelling belongs to the command token namespace and must not collide
  // with another registered input.
  final declaredNames = {...localNames, ...persistentNames};
  for (final negatedName in negatedFlagNames) {
    if (declaredNames.contains(negatedName)) {
      _invalid(
        negatedName,
        _joinRegistryPath(path, 'flags'),
        'collides with a synthesized negated flag spelling',
      );
    }
  }
  final positionals = command['positionals'];
  final commands = command['commands'];
  if (positionals is Map && commands is Map) {
    for (final name in positionals.keys) {
      if (commands.containsKey(name)) {
        _invalid(
          name,
          _joinRegistryPath(path, 'positionals'),
          'must not collide with a child command',
        );
      }
    }
  }
  final aliases = command['aliases'];
  if (aliases is List) {
    final registeredAliases = <String>{};
    for (final (index, alias) in aliases.indexed) {
      final aliasPath = _joinRegistryPath(
        _joinRegistryPath(path, 'aliases'),
        index.toString(),
      );
      _validateRegistryName(alias as String, aliasPath);
      if (alias == command['name'] || !registeredAliases.add(alias)) {
        _invalid(
          alias,
          aliasPath,
          'must be unique and differ from the command name',
        );
      }
    }
  }
}

void _validateRegistryName(String name, String path) {
  if (!_registryName.hasMatch(name)) {
    _invalid(
      name,
      path,
      'must contain letter-led words separated by hyphens or underscores',
    );
  }
}

void _validateOptionGroupMembers(
  Map<String, Object?> command,
  String commandPath,
) {
  final groups = command['optionGroups'];
  if (groups is! List) return;
  final options = command['options'] is Map
      ? _stringMap(
          command['options'],
          _joinRegistryPath(commandPath, 'options'),
        )
      : const <String, Object?>{};
  final groupedMembers = <Object?>{};
  for (final (groupIndex, entry) in groups.indexed) {
    final groupPath = _joinRegistryPath(
      _joinRegistryPath(commandPath, 'optionGroups'),
      groupIndex.toString(),
    );
    final group = _map(entry, groupPath);
    final members = group['members'] as List;
    for (final (memberIndex, member) in members.indexed) {
      final memberPath = _joinRegistryPath(
        _joinRegistryPath(groupPath, 'members'),
        memberIndex.toString(),
      );
      if (!groupedMembers.add(member)) {
        _invalid(member, memberPath, 'must belong to only one option group');
      }
      if (!options.containsKey(member)) {
        _invalid(member, memberPath, 'must reference a registered option');
      }
      final option = options[member];
      // Pair options never declare defaults, so no member of any option
      // group may carry serialized default metadata.
      if (option is Map && _map(option, memberPath).containsKey('default')) {
        _invalid(
          _map(option, memberPath)['default'],
          _joinRegistryPath(memberPath, 'default'),
          'must not be declared for pair options',
        );
      }
    }
  }
}

void _parseCommands(Object? value, String path) {
  final commands = _stringMap(value, path);
  final aliases = <String>{};
  for (final entry in commands.entries) {
    final commandPath = _joinRegistryPath(path, entry.key);
    final command = _map(entry.value, commandPath);
    _parseCommand(command, commandPath);
    if (command['name'] != entry.key) {
      _invalid(
        command['name'],
        _joinRegistryPath(commandPath, 'name'),
        'must match its command collection key',
      );
    }
    for (final alias in command['aliases'] as List? ?? const <Object?>[]) {
      final aliasPath = _joinRegistryPath(commandPath, 'aliases');
      if (commands.containsKey(alias) || !aliases.add(alias as String)) {
        _invalid(
          alias,
          aliasPath,
          'must not collide with a sibling command or alias',
        );
      }
    }
  }
}

void _parseInputCollection(
  Object? value,
  String path,
  void Function(Map<String, Object?> value, String path) parseInput,
) {
  final inputs = _stringMap(value, path);
  for (final entry in inputs.entries) {
    final inputPath = _joinRegistryPath(path, entry.key);
    parseInput(_map(entry.value, inputPath), inputPath);
  }
}

void _parseFlag(Map<String, Object?> value, String path) {
  const commonProperties = {'hidden', 'description'};
  const booleanProperties = {'short', 'default', 'negatable'};
  final isBoolean =
      value.containsKey('default') || value.containsKey('negatable');
  _validateProperties(
    value,
    path,
    {...commonProperties, ...booleanProperties},
    isBoolean ? {...commonProperties, ...booleanProperties} : commonProperties,
  );

  _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );

  if (isBoolean) {
    _expectString(
      value['short'],
      _joinRegistryPath(path, 'short'),
      nullable: true,
    );
    _expectBool(value['default'], _joinRegistryPath(path, 'default'));
    _expectBool(value['negatable'], _joinRegistryPath(path, 'negatable'));
  } else if (value.containsKey('short')) {
    _expectString(value['short'], _joinRegistryPath(path, 'short'));
  }
}

void _parseOption(Map<String, Object?> value, String path) {
  const requiredProperties = {
    'short',
    'required',
    'hidden',
    'description',
    'valueType',
  };
  const optionalProperties = {
    'repeatable',
    'variant',
    'choices',
    'default',
    'pairedOptions',
    'pattern',
    'min',
    'max',
    'step',
  };
  _validateProperties(value, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);

  _expectString(
    value['short'],
    _joinRegistryPath(path, 'short'),
    nullable: true,
  );
  _expectBool(value['required'], _joinRegistryPath(path, 'required'));
  _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );

  if (value.containsKey('repeatable')) {
    _expectBool(value['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (value.containsKey('variant')) {
    _expectBool(value['variant'], _joinRegistryPath(path, 'variant'));
  }
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  _expectValueType(value['valueType'], _joinRegistryPath(path, 'valueType'));
  if (value['valueType'] == 'choice' && !value.containsKey('choices')) {
    _invalid(value, choicesPath, 'is required for a choice option');
  }
  if (value.containsKey('choices')) {
    _parseNonEmptyStringList(value['choices'], choicesPath);
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], defaultPath);
    if (value['valueType'] != 'choice') {
      _invalid(
        value['default'],
        defaultPath,
        'is only supported for choice options',
      );
    }
    if (value['required'] == true) {
      _invalid(
        value['default'],
        defaultPath,
        'must not be declared for a required option',
      );
    }
    if (value['valueType'] == 'choice' &&
        value['choices'] is List &&
        !(value['choices'] as List).contains(value['default'])) {
      _invalid(value['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (value.containsKey('pairedOptions')) {
    final pairedOptionsPath = _joinRegistryPath(path, 'pairedOptions');
    _parseStringList(value['pairedOptions'], pairedOptionsPath);
    if (value['pairedOptions'] is List &&
        (value['pairedOptions'] as List).isNotEmpty &&
        value.containsKey('default')) {
      _invalid(
        value['default'],
        _joinRegistryPath(path, 'default'),
        'must not be declared for pair options',
      );
    }
  }
  if (value.containsKey('pattern')) {
    _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
  }
  _validateNumericRangeProperties(value, path);
}

void _validateNumericRangeProperties(Map<String, Object?> value, String path) {
  final valueType = value['valueType'];
  final min = value['min'];
  final max = value['max'];
  final step = value['step'];
  if (min == null && max == null && step == null) return;
  if (valueType != 'int' && valueType != 'double') {
    _invalid(value, path, 'numeric bounds require an int or double value type');
  }
  final isInt = valueType == 'int';
  for (final entry in {'min': min, 'max': max}.entries) {
    if (entry.value != null &&
        (entry.value is! num || (isInt && entry.value is! int))) {
      _invalid(
        entry.value,
        _joinRegistryPath(path, entry.key),
        'must match the numeric value type',
      );
    }
  }
  if (min is num && max is num && min > max) {
    _invalid(max, _joinRegistryPath(path, 'max'), 'must not be less than min');
  }
  if (step == null) return;
  if (valueType != 'double') {
    _invalid(
      step,
      _joinRegistryPath(path, 'step'),
      'requires a double value type',
    );
  }
  if (step is! num || !step.isFinite || step <= 0) {
    _invalid(
      step,
      _joinRegistryPath(path, 'step'),
      'must be a finite number greater than zero',
    );
  }
  if (min is! num || max is! num) {
    _invalid(
      step,
      _joinRegistryPath(path, 'step'),
      'requires both min and max',
    );
  }
  if (!min.isFinite || !max.isFinite) {
    _invalid(
      step,
      _joinRegistryPath(path, 'step'),
      'requires finite min and max values',
    );
  }
  final increments = (max - min) / step;
  if ((increments - increments.round()).abs() > 1e-12) {
    _invalid(
      step,
      _joinRegistryPath(path, 'step'),
      'must evenly divide the range from $min to $max',
    );
  }
}

void _parseOptionGroups(Object? value, String path) {
  if (value is! List) {
    _invalid(value, path, 'must be a List of option groups');
  }
  for (final (index, entry) in value.indexed) {
    final groupPath = _joinRegistryPath(path, index.toString());
    final group = _map(entry, groupPath);
    const properties = {'mode', 'required', 'members'};
    _validateProperties(group, groupPath, properties, properties);
    final modePath = _joinRegistryPath(groupPath, 'mode');
    _expectString(group['mode'], modePath);
    if (group['mode'] != 'all' && group['mode'] != 'oneOf') {
      _invalid(group['mode'], modePath, 'must be all or oneOf');
    }
    _expectBool(group['required'], _joinRegistryPath(groupPath, 'required'));
    final membersPath = _joinRegistryPath(groupPath, 'members');
    _parseStringList(group['members'], membersPath);
    if (group['members'] case List(isEmpty: true)) {
      _invalid(group['members'], membersPath, 'must not be empty');
    }
  }
}

void _parsePositional(Map<String, Object?> value, String path) {
  const requiredProperties = {'required', 'description'};
  const optionalProperties = {
    'choices',
    'default',
    'repeatable',
    'times',
    'pattern',
  };
  _validateProperties(value, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);
  _expectBool(value['required'], _joinRegistryPath(path, 'required'));
  _expectString(
    value['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  if (value.containsKey('choices')) {
    _parseNonEmptyStringList(value['choices'], choicesPath);
  }
  if (value.containsKey('default')) {
    _expectString(value['default'], defaultPath);
    if (!value.containsKey('choices')) {
      _invalid(
        value['default'],
        defaultPath,
        'is only supported for choice positionals',
      );
    }
    if (value['required'] == true) {
      _invalid(
        value['default'],
        defaultPath,
        'must not be declared for a required positional',
      );
    }
    if (value['choices'] is List &&
        !(value['choices'] as List).contains(value['default'])) {
      _invalid(value['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (value.containsKey('repeatable')) {
    _expectBool(value['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (value.containsKey('times')) {
    final timesPath = _joinRegistryPath(path, 'times');
    _expectNonNegativeInt(value['times'], timesPath);
    if (value['repeatable'] != true) {
      _invalid(
        value['times'],
        timesPath,
        'requires repeatable positional metadata',
      );
    }
  }
  if (value['repeatable'] == true && !value.containsKey('times')) {
    _invalid(
      value,
      _joinRegistryPath(path, 'times'),
      'is required for a repeated positional',
    );
  }
  if (value.containsKey('pattern')) {
    _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
  }
}

void _parseVariadic(Object? value, String path) {
  final variadic = _map(value, path);
  const requiredProperties = {'description'};
  const optionalProperties = {'choices', 'default', 'repeatable', 'pattern'};
  _validateProperties(variadic, path, {
    ...requiredProperties,
    ...optionalProperties,
  }, requiredProperties);
  _expectString(
    variadic['description'],
    _joinRegistryPath(path, 'description'),
    nullable: true,
  );
  final choicesPath = _joinRegistryPath(path, 'choices');
  final defaultPath = _joinRegistryPath(path, 'default');
  if (variadic.containsKey('choices')) {
    _parseNonEmptyStringList(variadic['choices'], choicesPath);
  }
  if (variadic.containsKey('default')) {
    _expectString(variadic['default'], defaultPath);
    if (!variadic.containsKey('choices')) {
      _invalid(
        variadic['default'],
        defaultPath,
        'is only supported for choice variadics',
      );
    }
    if (variadic['choices'] is List &&
        !(variadic['choices'] as List).contains(variadic['default'])) {
      _invalid(variadic['default'], defaultPath, 'must be a registered choice');
    }
  }
  if (variadic.containsKey('repeatable')) {
    _expectBool(variadic['repeatable'], _joinRegistryPath(path, 'repeatable'));
  }
  if (variadic.containsKey('pattern')) {
    _expectString(variadic['pattern'], _joinRegistryPath(path, 'pattern'));
  }
}

void _parseAliases(Object? value, String path) => _parseStringList(value, path);

void _parseAccessors(Object? value, String path) {
  final accessors = _stringMap(value, path);
  for (final entry in accessors.entries) {
    _parseAccessorRoot(
      _map(entry.value, _joinRegistryPath(path, entry.key)),
      _joinRegistryPath(path, entry.key),
    );
  }
}

void _parseAccessorRoot(Map<String, Object?> value, String path) =>
    _parseTypedAccessor(value, path);

void _parseTypedAccessor(Map<String, Object?> value, String path) {
  final kindPath = _joinRegistryPath(path, 'kind');
  _expectString(value['kind'], kindPath);
  switch (value['kind']) {
    case 'group':
      const properties = {'kind', 'hidden', 'description', 'options'};
      _validateProperties(value, path, properties, properties);
      _expectBool(value['hidden'], _joinRegistryPath(path, 'hidden'));
      _expectString(
        value['description'],
        _joinRegistryPath(path, 'description'),
        nullable: true,
      );
      final optionsPath = _joinRegistryPath(path, 'options');
      final options = _stringMap(value['options'], optionsPath);
      for (final entry in options.entries) {
        final optionPath = _joinRegistryPath(optionsPath, entry.key);
        _validateRegistryName(entry.key, optionPath);
        if (entry.key == 'help') {
          _invalid(
            entry.key,
            optionPath,
            'is reserved by the built-in help flag',
          );
        }
        _parseTypedAccessor(_map(entry.value, optionPath), optionPath);
      }
    case 'value':
      const properties = {
        'kind',
        'valueType',
        'description',
        'choices',
        'default',
        'pattern',
      };
      const requiredProperties = {'kind', 'valueType', 'description'};
      _validateProperties(value, path, properties, requiredProperties);
      _expectValueType(
        value['valueType'],
        _joinRegistryPath(path, 'valueType'),
      );
      final choicesPath = _joinRegistryPath(path, 'choices');
      if (value['valueType'] == 'choice' && !value.containsKey('choices')) {
        _invalid(value, choicesPath, 'is required for a choice accessor');
      }
      _expectString(
        value['description'],
        _joinRegistryPath(path, 'description'),
        nullable: true,
      );
      if (value.containsKey('choices')) {
        _parseNonEmptyStringList(value['choices'], choicesPath);
      }
      if (value.containsKey('pattern')) {
        _expectString(value['pattern'], _joinRegistryPath(path, 'pattern'));
      }
      if (value.containsKey('default')) {
        final defaultPath = _joinRegistryPath(path, 'default');
        _expectString(value['default'], defaultPath);
        if (value['valueType'] != 'choice') {
          _invalid(
            value['default'],
            defaultPath,
            'is only supported for choice accessors',
          );
        }
        final choices = value['choices'];
        if (value['valueType'] == 'choice' &&
            choices is List &&
            !choices.contains(value['default'])) {
          _invalid(
            value['default'],
            defaultPath,
            'must be a registered accessor choice',
          );
        }
      }
    default:
      _invalid(value['kind'], kindPath, 'must be group or value');
  }
}

void _validateProperties(
  Map<String, Object?> value,
  String path,
  Set<String> allowedProperties,
  Set<String> requiredProperties,
) {
  for (final entry in value.entries) {
    if (!allowedProperties.contains(entry.key)) {
      _invalid(
        entry.value,
        _joinRegistryPath(path, entry.key),
        'is not a supported registry property',
      );
    }
  }
  for (final property in requiredProperties) {
    if (!value.containsKey(property)) {
      _invalid(value, _joinRegistryPath(path, property), 'is required');
    }
  }
}

Map<String, Object?> _map(Object? value, String path) =>
    _stringMap(value, path);

Map<String, Object?> _stringMap(Object? value, String path) {
  if (value is! Map) {
    _invalid(value, path, 'must be a map with String keys');
  }
  final parsed = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) {
      _invalid(key, path, 'map keys must be non-empty Strings');
    }
    parsed[key] = entry.value;
  }
  return parsed;
}

void _parseStringList(Object? value, String path) {
  if (value is! List) {
    _invalid(value, path, 'must be a List<String>');
  }
  for (final (index, entry) in value.indexed) {
    _expectString(entry, _joinRegistryPath(path, index.toString()));
  }
}

void _parseNonEmptyStringList(Object? value, String path) {
  _parseStringList(value, path);
  if (value case List(isEmpty: true)) {
    _invalid(value, path, 'must not be empty');
  }
}

Map<String, dynamic> _freezeMap(Map<Object?, Object?> source) =>
    Map<String, dynamic>.unmodifiable({
      for (final entry in source.entries)
        entry.key as String: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) => switch (value) {
  Map() => _freezeMap(value),
  List() => List<Object?>.unmodifiable(value.map(_freezeValue)),
  _ => value,
};

void _expectString(Object? value, String path, {bool nullable = false}) {
  if (value == null && nullable) return;
  if (value is! String) _invalid(value, path, 'must be a String');
}

void _expectBool(Object? value, String path) {
  if (value is! bool) _invalid(value, path, 'must be a bool');
}

void _expectNonNegativeInt(Object? value, String path) {
  if (value is! int || value < 0) {
    _invalid(value, path, 'must be a non-negative int');
  }
}

void _expectValueType(Object? value, String path) {
  const valueTypes = {'string', 'int', 'double', 'choice'};
  if (value is! String || !valueTypes.contains(value)) {
    _invalid(value, path, 'must be a supported option value type');
  }
}

String _joinRegistryPath(String parent, String property) =>
    parent.isEmpty ? property : '$parent.$property';

Never _invalid(Object? value, String path, String message) =>
    throw MambaIntegrationException('$path $message (value: $value)');

/// A validated serialisable representation of a command registry.
///
/// The root map and every nested command must contain a string `name` and
/// `description`. All other registry properties are optional.
extension type RegistryMap._(Map<String, dynamic> map)
    implements Map<String, dynamic> {
  new(Map<String, dynamic> map) : this._(_parse(map));

  static Map<String, dynamic> _parse(Map<String, dynamic> map) {
    // Validate the caller's original map first so diagnostics preserve the
    // malformed value rather than an implementation-added help entry.
    _parseCommand(map, '');
    final normalizedMap = _withBuiltInHelp(map);
    _parseCommand(normalizedMap, '');
    return _freezeMap(normalizedMap);
  }

  /// Makes parser-owned help metadata available to every map-defined command.
  /// Callers cannot omit or redefine behavior that the parser always owns.
  static Map<String, dynamic> _withBuiltInHelp(Map<String, dynamic> command) {
    final normalized = Map<String, dynamic>.from(command);
    final flags = normalized['flags'];
    if (flags == null) {
      normalized['flags'] = {'help': _builtInHelpMap()};
    } else if (flags is Map) {
      normalized['flags'] = {
        ...Map<Object?, Object?>.from(flags),
        if (!flags.containsKey('help')) 'help': _builtInHelpMap(),
      };
    }
    final commands = normalized['commands'];
    if (commands is Map) {
      normalized['commands'] = {
        for (final entry in commands.entries)
          entry.key: entry.value is Map
              ? _withBuiltInHelp(Map<String, dynamic>.from(entry.value))
              : entry.value,
      };
    }
    return normalized;
  }

  static Map<String, dynamic> _builtInHelpMap() => {
    'short': 'h',
    'default': false,
    'negatable': false,
    'hidden': false,
    'description': 'Show this help message.',
  };
}

/// Reports a command name that is not a child of the selected command path.
final class MambaCommandNotFoundException extends MambaException {
  new(String name, List<String> parentPath, List<String> availableCommands)
    : super(
        "Command $name was not found under ${parentPath.join(' ')}. "
        "${availableCommands.isEmpty ? 'This command has no subcommands.' : 'Available commands: ${availableCommands.join(', ')}'}",
      );
}

/// A validated, name-indexed view of one command and its descendants.
///
/// A registry separates each input kind into its own map so callers can look up
/// a definition by name while preserving its input semantics. Each registry
/// holds only its locally declared inputs; inputs inherited from the root and
/// enclosing groups stay at the declaring level through [publishedFlags] and
/// [publishedOptions], and consumers resolve them by walking the [parent]
/// chain from the root.
final class CommandRegistry {
  static final BooleanFlag _helpFlag = BooleanFlag(
    'help',
    short: 'h',
    description: 'Show this help message.',
  );

  new _({
    required this.name,
    required this.shortDescription,
    required this.helpFlag,
    this.longDescription,
    this.aliases,
    this.commandAliases,
    this.boolFlags,
    this.countFlags,
    this.singleOptions,
    this.repeatedOptions,
    this.pairedOptionGroups,
    this.mandatoryPositionals,
    this.discretionaryPositionals,
    this.variadic,
    this.accessors,
    this.parent,
    this.publishedFlags,
    this.publishedOptions,
    List<Command>? commands,
    List<CommandRegistry>? childRegistries,
    List<String> parentPath = const <String>[],
    List<Flag>? descendantFlags,
    List<Option>? descendantOptions,
  }) {
    // Children are built in the body so they can point back at this registry
    // while the inheritance chain is resolved from the root downward.
    commandRegistries =
        childRegistries ??
        commands
            ?.map(
              (command) => _fromCommand(
                command,
                parent: this,
                parentPath: parentPath,
                inheritedFlags: descendantFlags,
                inheritedOptions: descendantOptions,
              ),
            )
            .toList();
  }

  final String name;
  final String shortDescription;
  final BooleanFlag helpFlag;
  final String? longDescription;

  /// Maps each registered child alias to that child's canonical name.
  final Map<String, String>? aliases;

  /// Alternative names used to select this command among its siblings.
  final List<String>? commandAliases;
  final Map<String, CountFlag>? countFlags;
  final Map<String, BooleanFlag>? boolFlags;
  final Map<String, SingleOption>? singleOptions;
  final Map<String, RepeatableOption>? repeatedOptions;

  /// Pair groups registered directly on this level; pair groups are not
  /// inherited.
  final List<PairedOptions>? pairedOptionGroups;
  final Map<String, Positional>? mandatoryPositionals;
  final Map<String, Positional>? discretionaryPositionals;

  /// Input validating and naming values supplied after `--`.
  final Variadic? variadic;
  final Map<String, AccessorListOption>? accessors;
  late final List<CommandRegistry>? commandRegistries;

  /// The enclosing registry, or `null` on the root.
  final CommandRegistry? parent;

  /// Flags and options this level publishes to its descendants.
  ///
  /// The root publishes its own flags and options; a group publishes its
  /// declared inheritedFlags and inheritedOptions. They are not merged into
  /// descendant tables; the parser collects them by walking from the root.
  final List<Flag>? publishedFlags;
  final List<Option>? publishedOptions;

  /// Builds and validates a root registry from a list-defined command surface.
  ///
  /// The factory indexes inputs by name, supplies the built-in help flag, and
  /// creates child registries for [commands]. It rejects ambiguous names,
  /// aliases, positional definitions, and invalid input definitions.
  factory create(
    String name,
    String shortDescription, {
    String? longDescription,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
  }) {
    _validateDefinition(
      name,
      shortDescription,
      null,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      flags,
      options,
      pairedOptions,
      accessors,
      commands,
      [name],
    );

    final copiedMandatoryPositionals = _copyList(mandatoryPositionals);
    final copiedDiscretionaryPositionals = _copyList(discretionaryPositionals);
    final copiedFlags = _copyList(flags);
    final copiedOptions = _copyList(options);
    final copiedPairedOptions = _copyList(pairedOptions);
    final copiedAccessors = _copyList(accessors);
    final copiedCommands = _copyList(commands);

    return CommandRegistry._(
      name: name,
      shortDescription: shortDescription,
      helpFlag: _helpFlag,
      longDescription: longDescription,
      aliases: _indexAliases(copiedCommands),
      boolFlags: _indexByName<BooleanFlag>(
        copiedFlags?.whereType<BooleanFlag>(),
      ),
      countFlags: _indexByName<CountFlag>(copiedFlags?.whereType<CountFlag>()),
      singleOptions: _indexByName<SingleOption>(
        copiedOptions?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        copiedOptions?.whereType<RepeatableOption>(),
      ),
      pairedOptionGroups: copiedPairedOptions,
      mandatoryPositionals: _indexByName<Positional>(
        copiedMandatoryPositionals,
      ),
      discretionaryPositionals: _indexByName<Positional>(
        copiedDiscretionaryPositionals,
      ),
      variadic: variadic,
      accessors: _indexByName<AccessorListOption>(copiedAccessors),
      parent: null,
      publishedFlags: copiedFlags,
      publishedOptions: copiedOptions,
      commands: copiedCommands,
      parentPath: [name],
      descendantFlags: copiedFlags,
      descendantOptions: copiedOptions,
    );
  }

  static CommandRegistry _fromCommand(
    Command command, {
    required CommandRegistry parent,
    List<String> parentPath = const <String>[],
    List<Flag>? inheritedFlags,
    List<Option>? inheritedOptions,
  }) {
    final group = command is GroupCommand ? command : null;
    final childCommands = group?.commands;
    // Inputs this level contributes to its descendants; they stay here and are
    // resolved by walking from the root rather than being merged downward.
    final ownPublishedFlags = group?.inheritedFlags;
    final ownPublishedOptions = group?.inheritedOptions;
    _validateGlobalFlagOverrides(inheritedFlags, ownPublishedFlags);
    _validateGlobalFlagOverrides(inheritedFlags, command.flags);
    _validateGlobalFlagOverrides(ownPublishedFlags, command.flags);
    final publishedFlags = _mergeByName(inheritedFlags, ownPublishedFlags);
    final publishedOptions = _mergeByName(
      inheritedOptions,
      ownPublishedOptions,
    );
    final localOptions = command.options;
    final standalonePairGroups = command.pairedOptions;
    // Inherited inputs join the validation surface so conflicts with local
    // declarations are still reported at the level that would collide.
    final registeredFlags = _mergeByName(publishedFlags, command.flags);
    final registeredOptions = _mergeByName(publishedOptions, localOptions);
    final registeredPairGroups = [...?standalonePairGroups];

    final commandPath = [...parentPath, command.name];
    _validateDefinition(
      command.name,
      command.shortDescription,
      command.aliases,
      command.mandatoryPositionals,
      command.discretionaryPositionals,
      command.variadic,
      registeredFlags,
      registeredOptions,
      registeredPairGroups,
      command.accessors,
      childCommands,
      commandPath,
      inheritedInputs: [...?publishedFlags, ...?publishedOptions],
    );

    return CommandRegistry._(
      name: command.name,
      shortDescription: command.shortDescription,
      helpFlag: _helpFlag,
      longDescription: command.longDescription,
      aliases: _indexAliases(childCommands),
      commandAliases: command.aliases,
      boolFlags: _indexByName<BooleanFlag>(
        command.flags?.whereType<BooleanFlag>(),
      ),
      countFlags: _indexByName<CountFlag>(
        command.flags?.whereType<CountFlag>(),
      ),
      singleOptions: _indexByName<SingleOption>(
        localOptions?.whereType<SingleOption>(),
      ),
      repeatedOptions: _indexByName<RepeatableOption>(
        localOptions?.whereType<RepeatableOption>(),
      ),
      pairedOptionGroups: standalonePairGroups,
      mandatoryPositionals: _indexByName<Positional>(
        command.mandatoryPositionals,
      ),
      discretionaryPositionals: _indexByName<Positional>(
        command.discretionaryPositionals,
      ),
      variadic: command.variadic,
      accessors: _indexByName<AccessorListOption>(command.accessors),
      parent: parent,
      publishedFlags: ownPublishedFlags,
      publishedOptions: ownPublishedOptions,
      commands: childCommands,
      parentPath: [...parentPath, command.name],
      descendantFlags: publishedFlags,
      descendantOptions: publishedOptions,
    );
  }

  /// Exports this registry as a serializable command description.
  ///
  /// Includes input kinds, pairing, repetition, and published inputs so map
  /// consumers can reproduce the complete command surface.
  RegistryMap toMap() {
    final description = longDescription == null
        ? shortDescription
        : '$shortDescription\n\n$longDescription';
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      if (commandAliases != null) 'aliases': commandAliases,
    };

    final registeredBooleanFlags = boolFlags;
    final registeredCountFlags = countFlags;
    map['flags'] = _mapFlags([
      helpFlag,
      ...?registeredBooleanFlags?.values,
    ], registeredCountFlags?.values);

    final localOptions = <Option>[
      ...?singleOptions?.values,
      ...?repeatedOptions?.values,
    ];
    if (localOptions.isNotEmpty ||
        singleOptions != null ||
        repeatedOptions != null ||
        pairedOptionGroups != null) {
      map['options'] = _mapOptions([
        ...localOptions,
        ...?pairedOptionGroups?.expand((group) => group.options),
      ]);
    }

    final registeredPairedOptionGroups = pairedOptionGroups;
    if (registeredPairedOptionGroups != null) {
      map['optionGroups'] = [
        for (final group in registeredPairedOptionGroups)
          {
            'mode': group.variant ? 'oneOf' : 'all',
            'required': group.required,
            'members': [for (final option in group.options) option.name],
          },
      ];
    }

    final registeredMandatoryPositionals = mandatoryPositionals;
    final registeredDiscretionaryPositionals = discretionaryPositionals;
    if (registeredMandatoryPositionals != null ||
        registeredDiscretionaryPositionals != null) {
      map['positionals'] = {
        for (final positional
            in registeredMandatoryPositionals?.values ?? const <Positional>[])
          positional.name: _mapPositional(positional, true),
        for (final positional
            in registeredDiscretionaryPositionals?.values ??
                const <Positional>[])
          positional.name: _mapPositional(positional, false),
      };
    }

    final registeredVariadic = variadic;
    if (registeredVariadic != null) {
      map['variadic'] = _mapVariadic(registeredVariadic);
    }

    final registeredAccessors = accessors;
    if (registeredAccessors != null) {
      map['accessors'] = {
        for (final entry in registeredAccessors.entries)
          entry.key: _mapAccessorList(entry.value),
      };
    }

    // Root inputs are already represented by flags and options. Only groups
    // need separate published collections to retain the distinction between
    // local and descendant-published inputs.
    if (parent != null) {
      final persistentFlags = publishedFlags;
      if (persistentFlags != null) {
        map['persistentFlags'] = _mapFlags(
          persistentFlags.whereType<BooleanFlag>(),
          persistentFlags.whereType<CountFlag>(),
        );
      }
      final persistentOptions = publishedOptions;
      if (persistentOptions != null) {
        map['persistentOptions'] = _mapOptions(persistentOptions);
      }
    }

    final registeredCommands = commandRegistries;
    if (registeredCommands != null) {
      map['commands'] = {
        for (final command in registeredCommands) command.name: command.toMap(),
      };
    }
    return RegistryMap(map);
  }

  static Map<String, dynamic> _mapFlags(
    Iterable<BooleanFlag>? booleanFlags,
    Iterable<CountFlag>? countFlags,
  ) => {
    for (final flag in booleanFlags ?? const <BooleanFlag>[])
      flag.name: _mapBooleanFlag(flag),
    for (final flag in countFlags ?? const <CountFlag>[])
      flag.name: _mapCountFlag(flag),
  };

  static Map<String, dynamic> _mapBooleanFlag(BooleanFlag flag) => {
    'short': flag.short,
    'default': flag.defaultValue,
    'negatable': flag.negatable,
    'hidden': flag.hidden,
    'description': flag.description,
  };

  static Map<String, dynamic> _mapCountFlag(CountFlag flag) => {
    if (flag.short != null) 'short': flag.short,
    'hidden': flag.hidden,
    'description': flag.description,
  };

  static Map<String, dynamic> _mapOptions(Iterable<NamedInput> options) => {
    for (final option in options) option.name: _mapOption(option),
  };

  static Map<String, dynamic> _mapOption(NamedInput input) {
    final (
      short,
      required,
      hidden,
      description,
      repeatable,
      variant,
      choiceData,
    ) = switch (input) {
      Option(
        short: final short,
        required: final required,
        hidden: final hidden,
        description: final description,
      ) =>
        (
          short,
          required,
          hidden,
          description,
          input is RepeatableOption,
          false,
          _mapChoiceData(input),
        ),
      PairOption(short: final short, description: final description) => (
        short,
        false,
        false,
        description,
        input is RepeatablePairOption,
        false,
        _mapChoiceData(input),
      ),
      _ => throw ArgumentError('Expected an option input'),
    };
    return {
      'short': short,
      'required': required,
      'hidden': hidden,
      'description': description,
      if (repeatable) 'repeatable': true,
      if (variant) 'variant': true,
      ...choiceData,
      'valueType': _mapOptionValueType(input),
      if (input is RegExpValidated)
        'pattern': (input as RegExpValidated).regex.pattern,
      if (input case NumericRangeValidated(:final min?)) 'min': min,
      if (input case NumericRangeValidated(:final max?)) 'max': max,
      if (input case NumericStepValidated(:final step?)) 'step': step,
    };
  }

  static Map<String, dynamic> _mapChoiceData(NamedInput input) =>
      switch (input) {
        ChoiceOption(choices: final choices, defaultValue: final value) ||
        ChoicePositional(choices: final choices, defaultValue: final value) ||
        RepeatedChoicePositional(
          choices: final choices,
          defaultValue: final value,
        ) => {
          'choices': choices.map((choice) => choice.name).toList(),
          if (value != null) 'default': value.name,
        },
        PairChoiceOption(:final choices) => {
          'choices': choices.map((choice) => choice.name).toList(),
        },
        _ => const <String, dynamic>{},
      };

  static String _mapOptionValueType(NamedInput input) => switch (input) {
    StringOption() ||
    RepeatableStringOption() ||
    PairStringOption() ||
    RepeatablePairStringOption() => 'string',
    IntOption() ||
    RepeatableIntOption() ||
    PairIntOption() ||
    RepeatablePairIntOption() => 'int',
    DoubleOption() ||
    RepeatableDoubleOption() ||
    PairDoubleOption() ||
    RepeatablePairDoubleOption() => 'double',
    ChoiceOption() || PairChoiceOption() => 'choice',
    _ => throw ArgumentError('Expected an option input'),
  };

  static Map<String, dynamic> _mapPositional(
    Positional positional,
    bool required,
  ) => {
    'required': required,
    'description': positional.description,
    'pattern': positional.regex.pattern,
    ..._mapChoiceData(positional),
    if (positional is RepeatedPositional) ...{
      'repeatable': true,
      'times': positional.times,
    },
  };

  static Map<String, dynamic> _mapVariadic(Variadic variadic) {
    final map = switch (variadic) {
      ChoiceVariadic(:final description, :final choices, :final defaultValue) =>
        {
          'description': description,
          'choices': choices.map((choice) => choice.name).toList(),
          'default': ?defaultValue?.name,
        },
      NormalVariadic(:final description, :final regex) => {
        'description': description,
        'pattern': regex.pattern,
      },
    };
    if (variadic is RepeatedChoiceVariadic) {
      map['repeatable'] = true;
    }
    return map;
  }

  static Object _mapAccessorList(AccessorListOption accessor) =>
      _mapAccessor(accessor);

  static Map<String, dynamic> _mapAccessor(AccessorOption accessor) =>
      switch (accessor) {
        AccessorListOption(:final hidden, :final description, :final options) =>
          {
            'kind': 'group',
            'hidden': hidden,
            'description': description,
            'options': {
              for (final option in options) option.name: _mapAccessor(option),
            },
          },
        AccessorStringOption(:final description) => {
          'kind': 'value',
          'valueType': 'string',
          'description': description,
          'pattern': accessor.regex.pattern,
        },
        AccessorIntOption(:final description) => {
          'kind': 'value',
          'valueType': 'int',
          'description': description,
          'pattern': accessor.regex.pattern,
        },
        AccessorDoubleOption(:final description) => {
          'kind': 'value',
          'valueType': 'double',
          'description': description,
          'pattern': accessor.regex.pattern,
        },
        AccessorChoiceOption(
          :final description,
          :final choices,
          :final defaultValue,
        ) =>
          {
            'kind': 'value',
            'valueType': 'choice',
            'description': description,
            'choices': [for (final choice in choices) choice.name],
            if (defaultValue != null) 'default': defaultValue.name,
          },
      };

  /// Flags and options published by this level and every ancestor, ordered
  /// from the root down so nearer declarations replace earlier ones.
  List<Flag> get _inheritableFlags => [
    for (final level in _ancestorChain) ...?level.publishedFlags,
  ];

  List<Option> get _inheritableOptions => [
    for (final level in _ancestorChain) ...?level.publishedOptions,
  ];

  Iterable<CommandRegistry> get _ancestorChain sync* {
    final chain = <CommandRegistry>[];
    for (CommandRegistry? level = this; level != null; level = level.parent) {
      chain.add(level);
    }
    yield* chain.reversed;
  }

  /// The registry names from the root down to this level, so command-not-found
  /// diagnostics can report the exact location of a failed lookup.
  List<String> get fullPath => [for (final level in _ancestorChain) level.name];

  static Map<String, T>? _combineWithInherited<T extends NamedInput>(
    Iterable<T> inherited,
    Map<String, T>? local,
  ) {
    if (local == null && inherited.isEmpty) return null;
    return {for (final input in inherited) input.name: input, ...?local};
  }

  /// Boolean flags available here: the built-in help flag plus inherited and
  /// local declarations, with local same-name definitions taking precedence.
  Map<String, BooleanFlag> get applicableBoolFlags => {
    helpFlag.name: helpFlag,
    ...?_combineWithInherited(
      _inheritableFlags.whereType<BooleanFlag>(),
      boolFlags,
    ),
  };

  /// Count flags available here, including inherited ones.
  Map<String, CountFlag>? get applicableCountFlags => _combineWithInherited(
    _inheritableFlags.whereType<CountFlag>(),
    countFlags,
  );

  /// Local option declarations with single and repeatable shapes combined.
  List<Option>? get _localOptions =>
      singleOptions == null && repeatedOptions == null
      ? null
      : [...?singleOptions?.values, ...?repeatedOptions?.values];

  /// Every option available here, resolved across the root-to-leaf chain so
  /// a nearer same-name definition fully replaces shadowed ones regardless
  /// of single/repeatable cardinality. Resolving before splitting keeps a
  /// type-changing override from resurrecting the shadowed definition in the
  /// other cardinality map.
  Map<String, Option> get _resolvedApplicableOptions => {
    for (final option in [..._inheritableOptions, ...?_localOptions])
      option.name: option,
  };

  bool _hasInheritedOption<T extends Option>() =>
      _inheritableOptions.any((option) => option is T);

  /// Single options available here, including inherited ones.
  Map<String, SingleOption>? get applicableSingleOptions {
    if (singleOptions == null && !_hasInheritedOption<SingleOption>()) {
      return null;
    }
    return {
      for (final option in _resolvedApplicableOptions.values)
        if (option is SingleOption) option.name: option,
    };
  }

  /// Repeatable options available here, including inherited ones.
  Map<String, RepeatableOption>? get applicableRepeatedOptions {
    if (repeatedOptions == null && !_hasInheritedOption<RepeatableOption>()) {
      return null;
    }
    return {
      for (final option in _resolvedApplicableOptions.values)
        if (option is RepeatableOption) option.name: option,
    };
  }

  /// Pair groups registered on this level.
  List<PairedOptions>? get applicablePairedOptionGroups => pairedOptionGroups;

  /// A copy of this registry whose input tables include every flag and option
  /// inherited from the root and enclosing groups.
  ///
  /// Local definitions win over inherited same-name inputs. Positionals,
  /// accessors, variadics, and child registries are never inherited and stay
  /// untouched.
  CommandRegistry withInheritedInputs() => CommandRegistry._(
    name: name,
    shortDescription: shortDescription,
    helpFlag: helpFlag,
    longDescription: longDescription,
    aliases: aliases,
    commandAliases: commandAliases,
    boolFlags: applicableBoolFlags,
    countFlags: applicableCountFlags,
    singleOptions: applicableSingleOptions,
    repeatedOptions: applicableRepeatedOptions,
    pairedOptionGroups: pairedOptionGroups,
    mandatoryPositionals: mandatoryPositionals,
    discretionaryPositionals: discretionaryPositionals,
    variadic: variadic,
    accessors: accessors,
    parent: parent,
    childRegistries: commandRegistries,
  );

  /// Returns the deepest registered command named by [args].
  ///
  /// Registered flags and the root name do not advance the command path. Help
  /// and the end-of-options separator stop traversal.
  CommandRegistry registryForArguments(List<String> args) {
    var registry = this;
    var helpRequested = false;
    var offset = 0;
    while (offset < args.length) {
      final token = args[offset];
      if (token == '--') break;
      if (token == registry.name && identical(registry, this)) {
        offset++;
        continue;
      }
      final inputLength = registry.registeredInputTokenLength(token);
      if (inputLength != null) {
        helpRequested = helpRequested || _containsHelpFlagToken(token);
        offset += inputLength;
        continue;
      }
      if (helpRequested) {
        offset++;
        continue;
      }

      final children = registry.commandRegistries ?? const <CommandRegistry>[];
      final commandName = registry.aliases?[token] ?? token;
      final command = children
          .where((candidate) => candidate.name == commandName)
          .firstOrNull;
      if (command == null) {
        // A leaf command's remaining bare tokens belong to its positional
        // parser, not to a nonexistent child command. Leave them in place so
        // Parser can validate the command's positionals and report any extra
        // values with the correct command context.
        if (children.isEmpty) break;
        if (helpRequested) break;
        throw MambaCommandNotFoundException(
          token,
          registry.fullPath,
          children.map((child) => child.name).toList(),
        );
      }
      registry = command;
      offset++;
    }
    return registry;
  }

  bool _containsHelpFlagToken(String token) =>
      token == '--help' ||
      (token.startsWith('-') &&
          !token.startsWith('--') &&
          token.substring(1).contains('h'));

  /// Whether [token] is a registered boolean or count flag.
  ///
  /// The check recognizes long names, valid negated boolean names, short
  /// names, and bundles of registered short flags, including built-in help.
  bool isRegisteredFlagToken(String token) {
    final boolFlags = applicableBoolFlags;
    final countFlags = applicableCountFlags;
    if (token.startsWith('--') && token.length > 2) {
      final name = token.substring(2).split('=').first;
      final negativeName = name.startsWith('no-') ? name.substring(3) : null;
      return boolFlags.containsKey(name) ||
          countFlags?.containsKey(name) == true ||
          (negativeName != null && boolFlags.containsKey(negativeName));
    }
    if (!token.startsWith('-') || token.length <= 1) return false;
    return token
        .substring(1)
        .split('')
        .every(
          (name) =>
              boolFlags.values.any((flag) => flag.short == name) ||
              countFlags?.values.any((flag) => flag.short == name) == true,
        );
  }

  /// Number of argument tokens occupied by a registered flag or option token.
  ///
  /// Inline long-option values occupy one token; other value-taking inputs
  /// occupy the option token and the following value token.
  int? registeredInputTokenLength(String token) {
    if (token.startsWith('--') && token.length > 2) {
      final separatorIndex = token.indexOf('=');
      final name = separatorIndex < 0
          ? token.substring(2)
          : token.substring(2, separatorIndex);
      if (_hasValueInput(name)) return separatorIndex < 0 ? 2 : 1;
    }
    if (token.startsWith('-') && token.length > 1) {
      final short = token.substring(1);
      if (_hasValueInput(short, byShortAlias: true)) return 2;
    }
    return isRegisteredFlagToken(token) ? 1 : null;
  }

  /// Options available here, including inherited ones.
  Iterable<NamedInput> _valueOptions() sync* {
    for (final option in [
      ...?applicableSingleOptions?.values,
      ...?applicableRepeatedOptions?.values,
      ...?applicablePairedOptionGroups?.expand((group) => group.options),
    ]) {
      yield option;
    }
  }

  bool _hasValueInput(String name, {bool byShortAlias = false}) {
    bool hasAccessorPath() {
      final segments = name.split('.');
      AccessorOption? accessor = accessors?[segments.first];
      for (final segment in segments.skip(1)) {
        if (accessor is! AccessorListOption) return false;
        accessor = accessor.options
            .where((option) => option.name == segment)
            .firstOrNull;
      }
      return accessor is AccessorPrimitiveOption;
    }

    final ordinaryOptions = <NamedInput>[..._valueOptions()];
    bool hasShort(NamedInput option) => switch (option) {
      Flag(short: final short) ||
      Option(short: final short) ||
      PairOption(short: final short) => short == name,
      _ => false,
    };
    if (byShortAlias) {
      return ordinaryOptions.any(hasShort);
    }
    return ordinaryOptions.any((option) => option.name == name) ||
        hasAccessorPath();
  }

  static void _validateGlobalFlagOverrides(
    List<Flag>? globalFlags,
    List<Flag>? descendantFlags,
  ) {
    if (globalFlags == null || descendantFlags == null) return;
    final globalNames = globalFlags.map((flag) => flag.name).toSet();
    for (final flag in descendantFlags) {
      if (globalNames.contains(flag.name)) {
        throw MambaRegistryError(
          'Global flag --${flag.name} cannot be overridden by a descendant.',
        );
      }
    }
  }

  static List<T>? _mergeByName<T extends NamedInput>(
    List<T>? inherited,
    List<T>? local,
  ) {
    if (inherited == null && local == null) return null;
    final localNames = local?.map((input) => input.name).toSet();
    return [
      ...?inherited?.where(
        (input) => !(localNames?.contains(input.name) ?? false),
      ),
      ...?local,
    ];
  }

  static final RegExp _inputName = RegExp(r'^[A-Za-z]+(?:[-_][A-Za-z]+)*$');
  static final RegExp _shortInputName = RegExp(r'^[A-Za-z]$');

  static List<T>? _copyList<T>(List<T>? inputs) =>
      inputs == null ? null : List.unmodifiable(inputs);

  static Map<String, T>? _indexByName<T extends NamedInput>(
    Iterable<T>? inputs,
  ) => inputs == null ? null : {for (final input in inputs) input.name: input};

  static Map<String, String>? _indexAliases(List<Command>? commands) =>
      commands == null
      ? null
      : {
          for (final command in commands)
            for (final alias in command.aliases ?? const <String>[])
              alias: command.name,
        };

  static void _validateDefinition(
    String name,
    String shortDescription,
    List<String>? aliases,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<AccessorListOption>? accessors,
    List<Command>? commands,
    List<String> commandPath, {
    Iterable<NamedInput> inheritedInputs = const <NamedInput>[],
  }) {
    _validateCommandName(name);
    _validateShortDescription(shortDescription);
    _validateAliases(name, aliases, commandPath);
    _validateNamedInputs(options, 'Option');
    _validatePairedOptions(pairedOptions);
    _validateNamedInputs(flags, 'Flag');
    _validateAccessors(accessors);
    _validatePositionals(mandatoryPositionals, discretionaryPositionals);
    _validateNumericRanges([
      ...?options,
      ...?pairedOptions?.expand((group) => group.options),
    ]);
    _validateChoiceDefaults(
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
      variadic,
      accessors,
    );
    _validateDuplicates(
      accessors,
      flags,
      options,
      pairedOptions,
      mandatoryPositionals,
      discretionaryPositionals,
      commands,
      commandPath,
      inheritedInputsByName: {
        for (final input in inheritedInputs) input.name: input,
      },
    );
  }

  static void _validateAliases(
    String commandName,
    List<String>? aliases,
    List<String> commandPath,
  ) {
    if (aliases == null) return;
    final path = commandPath.join(' ');
    if (aliases.isEmpty) {
      throw MambaRegistryError(
        'Aliases for command path $path must not be empty.',
      );
    }
    final registered = <String>{};
    for (final alias in aliases) {
      if (alias.isEmpty || alias.startsWith('-')) {
        throw MambaRegistryError(
          'Alias $alias is not a usable command token for command path $path.',
        );
      }
      _validateCommandName(alias);
      if (!registered.add(alias)) {
        throw MambaRegistryError(
          'Alias $alias is registered more than once for command path $path.',
        );
      }
      if (alias == commandName) {
        throw MambaRegistryError(
          'Alias $alias cannot be the same as command path $path.',
        );
      }
    }
  }

  static void _validateCommandName(String name) {
    if (_inputName.hasMatch(name)) return;
    throw MambaRegistryError(
      'Command names must contain letter-led words separated by hyphens or underscores.',
    );
  }

  static void _validateShortDescription(String shortDescription) {
    if (shortDescription.isEmpty) {
      throw MambaRegistryError("Short description can't be empty");
    }
    if (shortDescription.length > 150) {
      throw MambaRegistryError(
        "Short description can't exceed 150 characters.",
      );
    }
  }

  static void _validateNamedInputs(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) return;
    for (final input in inputs) {
      if (input.name == 'help' ||
          (input is Flag && input.short == 'h') ||
          (input is Option && input.short == 'h') ||
          (input is PairOption && input.short == 'h')) {
        throw MambaRegistryError(
          'The help flag and -h alias are reserved by the executor',
        );
      }
      if (!_inputName.hasMatch(input.name)) {
        throw MambaRegistryError(
          '$inputKind names must contain letter-led words separated by hyphens or underscores.',
        );
      }
      final short = switch (input) {
        Flag(short: final short) || Option(short: final short) => short,
        PairOption(short: final short) => short,
        _ => null,
      };
      if (short != null && !_shortInputName.hasMatch(short)) {
        throw MambaRegistryError(
          '$inputKind short aliases must be a single letter',
        );
      }
    }
  }

  static void _validatePairedOptions(List<PairedOptions>? pairedOptions) {
    final groups = pairedOptions ?? const <PairedOptions>[];
    for (final group in groups) {
      if (group.options.isEmpty) {
        throw MambaRegistryError(
          'Paired options must contain at least one pair option',
        );
      }
    }
    _validateNamedInputs(
      groups.expand((group) => group.options),
      'Pair option',
    );
    _validateDuplicateNames(
      groups.expand((group) => group.options),
      'pair option',
    );
  }

  static void _validateAccessors(List<AccessorListOption>? accessors) {
    if (accessors != null) _validateAccessorLevel(accessors, 'accessor');
  }

  static void _validateAccessorLevel(
    List<AccessorOption> accessors,
    String inputKind,
  ) {
    _validateDuplicateNames(accessors, inputKind);
    for (final accessor in accessors) {
      if (accessor.name == 'help') {
        throw MambaRegistryError('The help flag is reserved by the executor');
      }
      _validatePositionalName(accessor.name);
      if (accessor case AccessorListOption(options: final options)) {
        _validateAccessorLevel(options, 'accessor option');
      }
    }
  }

  static void _validatePositionals(
    List<Positional>? mandatory,
    List<Positional>? discretionary,
  ) {
    for (final positional in [...?mandatory, ...?discretionary]) {
      _validatePositionalName(positional.name);
    }
  }

  static void _validatePositionalName(String name) {
    if (!_inputName.hasMatch(name)) {
      throw MambaRegistryError(
        'Positional names must contain letter-led words separated by hyphens or underscores.',
      );
    }
  }

  static void _validateNumericRanges(Iterable<NamedInput> inputs) {
    for (final input in inputs) {
      if (input is! NumericRangeValidated) continue;
      final range = input as NumericRangeValidated;
      final min = range.min;
      final max = range.max;
      if (min != null && max != null && min > max) {
        throw MambaRegistryError(
          'Minimum $min for ${input.name} must not exceed maximum $max.',
        );
      }
      if (input case NumericStepValidated(:final step?)) {
        if (!step.isFinite || step <= 0) {
          throw MambaRegistryError(
            'Step $step for ${input.name} must be greater than zero.',
          );
        }
        if (min == null || max == null) {
          throw MambaRegistryError(
            'Step for ${input.name} requires both a minimum and maximum.',
          );
        }
        if (!min.isFinite || !max.isFinite) {
          throw MambaRegistryError(
            'Step for ${input.name} requires finite minimum and maximum values.',
          );
        }
        final increments = (max - min) / step;
        if ((increments - increments.round()).abs() > 1e-12) {
          throw MambaRegistryError(
            'Step $step for ${input.name} must evenly divide the range from $min to $max.',
          );
        }
      }
    }
  }

  static void _validateChoiceDefaults(
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<Positional>? mandatoryPositionals,
    List<Positional>? discretionaryPositionals,
    Variadic? variadic,
    List<AccessorListOption>? accessors,
  ) {
    void validate(Iterable<Enum> choices, Enum? defaultValue, String name) {
      if (choices.isEmpty) {
        throw MambaRegistryError('Choices for $name must not be empty.');
      }
      if (defaultValue != null && !choices.contains(defaultValue)) {
        throw MambaRegistryError(
          'Default ${defaultValue.name} is not a registered choice for $name',
        );
      }
    }

    void validateInput(NamedInput input) {
      switch (input) {
        case ChoiceOption(:final choices, :final defaultValue) ||
            ChoicePositional(:final choices, :final defaultValue) ||
            RepeatedChoicePositional(:final choices, :final defaultValue) ||
            AccessorChoiceOption(:final choices, :final defaultValue):
          validate(choices, defaultValue, input.name);
        case PairChoiceOption(:final choices):
          validate(choices, null, input.name);
        default:
      }
    }

    void validateAccessor(AccessorOption accessor) {
      validateInput(accessor);
      if (accessor case AccessorListOption(:final options)) {
        options.forEach(validateAccessor);
      }
    }

    for (final option in options ?? const <Option>[]) {
      if (option is ChoiceOption &&
          option.required &&
          option.defaultValue != null) {
        throw MambaRegistryError(
          'Required choice option ${option.name} must not declare a default.',
        );
      }
      validateInput(option);
    }
    for (final positional in mandatoryPositionals ?? const <Positional>[]) {
      if ((positional is ChoicePositional && positional.defaultValue != null) ||
          (positional is RepeatedChoicePositional &&
              positional.defaultValue != null)) {
        throw MambaRegistryError(
          'Required choice positional ${positional.name} must not declare a default.',
        );
      }
      validateInput(positional);
    }
    void validateVariadic(Variadic input) {
      if (input case ChoiceVariadic(:final choices, :final defaultValue)) {
        validate(choices, defaultValue, 'variadic');
      }
    }

    [
      ...?pairedOptions?.expand((option) => option.options),
      ...?discretionaryPositionals,
    ].forEach(validateInput);
    if (variadic != null) validateVariadic(variadic);
    accessors?.forEach(validateAccessor);
  }

  static void _validateDuplicates(
    List<AccessorListOption>? accessors,
    List<Flag>? flags,
    List<Option>? options,
    List<PairedOptions>? pairedOptions,
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    List<Command>? commands,
    List<String> commandPath, {
    Map<String, NamedInput> inheritedInputsByName =
        const <String, NamedInput>{},
  }) {
    final registeredOptions = <NamedInput>[
      ...?options,
      ...?pairedOptions?.expand((pairedOption) => pairedOption.options),
    ];
    _validateDuplicateNames(registeredOptions, 'option');
    _validateDuplicateNames(flags, 'flag');
    _validateDuplicateNames([...?flags, ...registeredOptions], 'input');
    _validateDuplicateShortAliases([
      ...?flags,
      ...registeredOptions,
    ], inheritedInputsByName: inheritedInputsByName);
    _validateNegatableSpellings(flags, registeredOptions, accessors);
    _validateDuplicateCommandNames(commands);
    _validateDuplicateAliases(commands, commandPath);

    for (final accessor in accessors ?? const <AccessorOption>[]) {
      final flagIndex =
          flags?.indexWhere((flag) => flag.name == accessor.name) ?? -1;
      if (flagIndex >= 0) {
        throw MambaRegistryError(
          'This accessor ${accessor.name} has the same name as a flag at index $flagIndex',
        );
      }
      final optionIndex = registeredOptions.indexWhere(
        (option) => option.name == accessor.name,
      );
      if (optionIndex >= 0) {
        throw MambaRegistryError(
          'This accessor ${accessor.name} has the same name as an option at index $optionIndex',
        );
      }
    }

    final positionals = [...?mandatory, ...?discretionary];
    final names = <String>{};
    for (final positional in positionals) {
      if (!names.add(positional.name)) {
        throw MambaRegistryError(
          "A positional can't have the same name as another positional",
        );
      }
    }
    final commandNames = commands?.map((command) => command.name).toList();
    for (final positional in positionals) {
      final commandIndex = commandNames?.indexOf(positional.name) ?? -1;
      if (commandIndex >= 0) {
        throw MambaRegistryError(
          'This positional message has the same name as a command at index $commandIndex',
        );
      }
    }
  }

  static void _validateDuplicateShortAliases(
    Iterable<NamedInput> inputs, {
    Map<String, NamedInput> inheritedInputsByName =
        const <String, NamedInput>{},
  }) {
    final names = <String, String>{};
    for (final input in inputs) {
      final short = switch (input) {
        Flag(short: final short) ||
        Option(short: final short) ||
        PairOption(short: final short) => short,
        _ => null,
      };
      if (short == null) continue;
      final previousName = names[short];
      if (previousName != null) {
        // A local option may intentionally shadow an inherited global short
        // alias. This lets a command keep its established shorthand while
        // still allowing the global input before the command path.
        if (inheritedInputsByName[previousName] is Flag && input is Option) {
          names[short] = input.name;
          continue;
        }
        throw MambaRegistryError(
          'The short alias -$short is assigned to both $previousName and ${input.name}',
        );
      }
      names[short] = input.name;
    }
  }

  static void _validateNegatableSpellings(
    List<Flag>? flags,
    List<NamedInput> registeredOptions,
    List<AccessorListOption>? accessors,
  ) {
    // A negatable boolean flag also accepts --no-<name>; that synthesized
    // spelling belongs to the command token namespace and must not collide
    // with another registered input.
    final declaredNames = {
      for (final input in [...?flags, ...registeredOptions]) input.name,
      for (final accessor in accessors ?? const <AccessorListOption>[])
        accessor.name,
    };
    for (final flag in [...?flags]) {
      if (flag is! BooleanFlag || !flag.negatable) continue;
      final negatedName = 'no-${flag.name}';
      if (declaredNames.contains(negatedName)) {
        throw MambaRegistryError(
          'Flag spelling --$negatedName collides with a registered input.',
        );
      }
    }
  }

  static void _validateDuplicateCommandNames(List<Command>? commands) {
    final names = <String>{};
    for (final command in commands ?? const <Command>[]) {
      if (!names.add(command.name)) {
        throw MambaRegistryError(
          'There are duplicate command names: ${command.name}',
        );
      }
    }
  }

  static void _validateDuplicateAliases(
    List<Command>? commands,
    List<String> parentPath,
  ) {
    final registered = <String, String>{};
    final commandNames = {
      for (final command in commands ?? const <Command>[]) command.name,
    };
    for (final command in commands ?? const <Command>[]) {
      final commandPath = [...parentPath, command.name];
      _validateAliases(command.name, command.aliases, commandPath);
      for (final alias in command.aliases ?? const <String>[]) {
        if (commandNames.contains(alias)) {
          throw MambaRegistryError(
            'Alias $alias is the same as a command in command path ${commandPath.join(' ')}.',
          );
        }
        final registeredCommand = registered[alias];
        if (registeredCommand != null) {
          throw MambaRegistryError(
            'Alias $alias is already registered for a command; pick another one. Command path: ${commandPath.join(' ')}.',
          );
        }
        registered[alias] = command.name;
      }
    }
  }

  static void _validateDuplicateNames(
    Iterable<NamedInput>? inputs,
    String inputKind,
  ) {
    if (inputs == null) return;
    final names = <String, int>{};
    for (final (index, input) in inputs.indexed) {
      final duplicateIndex = names[input.name];
      if (duplicateIndex != null) {
        throw MambaRegistryError(
          'There are duplicate $inputKind names at index $duplicateIndex and $index',
        );
      }
      names[input.name] = index;
    }
  }
}
