import 'dart:io';

import 'package:mamba/command.dart';
import 'package:yaml_writer/yaml_writer.dart';

/// Converts a validated [RegistryMap] into an integration-specific artifact.
abstract class RegistryMapConverter {
  RegistryMapConverter(this.registryMap);

  final RegistryMap registryMap;

  String convert();
}

/// Converts a [RegistryMap] into a Carapace completion spec.
///
/// The map carries all input semantics needed to reproduce the complete
/// Carapace output without retaining a live command definition.
final class CarapaceSpecConverter extends RegistryMapConverter {
  CarapaceSpecConverter(super.registryMap);

  @override
  String convert() {
    final map = {
      'name': _commandName(registryMap.map),
      ..._commandBody(registryMap.map, isRoot: true),
    };

    return YamlWriter().write(map);
  }

  /// Translates one command and its descendants into the Carapace command body.
  Map<String, dynamic> _commandBody(
    Map<String, dynamic> command, {
    required bool isRoot,
  }) {
    final flagEntries = <String, Object>{};
    final persistentEntries = <String, Object>{};
    final exclusiveGroups = <List<String>>[];

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

    void placeFlag(String name, Map<String, dynamic> flag, bool persistent) {
      final booleanFlag = flag.containsKey('default');
      placeEntry(
        name,
        persistent,
        _inputKey(
          name: name,
          short: flag['short'] as String?,
          repeatable: !booleanFlag,
          mandatory: false,
          hidden: flag['hidden'] as bool,
          takesValue: false,
        ),
        flag['description'] as String?,
        defaultValue: booleanFlag && flag['default'] == true ? true : null,
      );
    }

    void placeOption(
      String name,
      Map<String, dynamic> option,
      bool persistent, {
      bool? required,
      bool? hidden,
    }) {
      placeEntry(
        name,
        persistent,
        _inputKey(
          name: name,
          short: option['short'] as String?,
          repeatable: option['repeatable'] == true,
          mandatory: required ?? option['required'] as bool,
          hidden: hidden ?? option['hidden'] as bool,
          takesValue: true,
        ),
        option['description'] as String?,
        defaultValue: option['default'],
      );
    }

    void placeOptions(
      Map<String, dynamic>? options,
      bool persistent, {
      List<Map<String, dynamic>> optionGroups = const [],
    }) {
      if (options == null) return;
      final groupedMembers = {
        for (final group in optionGroups) ..._stringList(group['members']),
      };
      final pairedMembers = <String>{
        for (final value in options.values)
          if (value is Map) ..._stringList(_map(value)['pairedOptions']),
      };

      for (final entry in options.entries) {
        final name = entry.key;
        if (groupedMembers.contains(name)) continue;
        final option = _map(entry.value);
        final pairedOptions = _stringList(option['pairedOptions']);
        if (pairedOptions.isNotEmpty) {
          if (option['variant'] == true) {
            exclusiveGroups.add([name, ...pairedOptions]);
            continue;
          }
          placeOption(name, option, persistent);
          for (final pairName in pairedOptions) {
            final pairValue = options[pairName];
            if (pairValue is Map) {
              placeOption(
                pairName,
                _map(pairValue),
                persistent,
                required: option['required'] as bool,
                hidden: false,
              );
            }
          }
          continue;
        }
        if (pairedMembers.contains(name)) continue;
        placeOption(name, option, persistent);
      }

      for (final group in optionGroups) {
        final members = _stringList(group['members']);
        final mode = group['mode'] as String;
        final required = group['required'] as bool;
        for (final member in members) {
          final value = options[member];
          if (value is Map) {
            placeOption(
              member,
              _map(value),
              persistent,
              required: mode == 'all' && required,
            );
          }
        }
        if (mode == 'oneOf') exclusiveGroups.add(members);
      }
    }

    void placeFlags(Map<String, dynamic>? flags, bool persistent) {
      if (flags == null) return;
      for (final entry in flags.entries) {
        placeFlag(entry.key, _map(entry.value), persistent);
      }
    }

    final localFlags = _mapOrNull(command['flags']);
    final localOptions = _mapOrNull(command['options']);
    final optionGroups = _mapList(command['optionGroups']);
    final persistentFlags = _withoutLocalOverrides(
      _mapOrNull(command['persistentFlags']),
      localFlags?.keys,
    );
    final persistentOptions = _withoutLocalOverrides(
      _mapOrNull(command['persistentOptions']),
      localOptions?.keys,
    );
    placeFlags(localFlags, isRoot);
    placeFlags(persistentFlags, true);
    placeOptions(localOptions, isRoot, optionGroups: optionGroups);
    placeOptions(persistentOptions, true);
    for (final accessor in _accessorLeaves(_mapOrNull(command['accessors']))) {
      placeEntry(
        accessor.path,
        false,
        _inputKey(
          name: accessor.path,
          short: null,
          repeatable: false,
          mandatory: false,
          hidden: accessor.hidden,
          takesValue: true,
        ),
        accessor.value['description'] as String?,
        defaultValue: accessor.value['default'],
      );
    }

    final body = <String, dynamic>{
      'description': command['description'] as String,
    };
    final aliases = command['aliases'];
    if (aliases != null) body['aliases'] = _stringList(aliases);
    if (flagEntries.isNotEmpty) body['flags'] = flagEntries;
    if (persistentEntries.isNotEmpty) {
      body['persistentflags'] = persistentEntries;
    }
    if (exclusiveGroups.isNotEmpty) body['exclusiveflags'] = exclusiveGroups;

    final completion = _completionFor(command);
    if (completion.isNotEmpty) body['completion'] = completion;

    final commands = _mapOrNull(command['commands']);
    if (commands != null) {
      body['commands'] = [
        for (final child in commands.values)
          if (child is Map)
            {
              'name': _commandName(_map(child)),
              ..._commandBody(_map(child), isRoot: false),
            },
      ];
    }
    return body;
  }

  /// Builds completion values from semantic metadata carried by one map level.
  Map<String, dynamic> _completionFor(Map<String, dynamic> command) {
    final positionalChoices = <List<String>>[];
    final flagChoices = <String, List<String>>{};
    const intRange = [r'$carapace.number.Range({start: 0, end: 1000})'];
    const doubleRange = [
      r"$carapace.number.Range({format: '%.2f', start: 0, end: 1000})",
    ];

    List<String> choicePairs(List<String> choices) => [
      for (final choice in choices) ...[choice, choice],
    ];
    final positionals = _mapOrNull(command['positionals']);
    if (positionals != null) {
      for (final positionalValue in positionals.values) {
        final positional = _map(positionalValue);
        final choices = _stringList(positional['choices']);
        final values = choices.isEmpty
            ? const [r'$files']
            : choicePairs(choices);
        final times = positional['repeatable'] == true
            ? positional['times'] as int? ?? 0
            : 0;
        for (var slot = 0; slot <= times; slot++) {
          positionalChoices.add(values);
        }
      }
    }

    // Paired option completions are intentionally unchanged from the
    // registry-backed converter: only ordinary local options publish values.
    final options = _mapOrNull(command['options']);
    if (options != null) {
      final groupedMembers = {
        for (final group in _mapList(command['optionGroups']))
          ..._stringList(group['members']),
      };
      final pairedMembers = <String>{
        for (final value in options.values)
          if (value is Map) ..._stringList(_map(value)['pairedOptions']),
      };
      for (final entry in options.entries) {
        final option = _map(entry.value);
        if (groupedMembers.contains(entry.key) ||
            option.containsKey('pairedOptions') ||
            pairedMembers.contains(entry.key)) {
          continue;
        }
        switch (option['valueType']) {
          case 'string':
            flagChoices[entry.key] = const [r'$files'];
          case 'int':
            flagChoices[entry.key] = intRange;
          case 'double':
            flagChoices[entry.key] = doubleRange;
        }
      }
    }

    final dashChoices = <List<String>>[];
    final dashAnyChoices = <String>[];
    final variadic = _mapOrNull(command['variadic']);
    if (variadic != null) {
      final choices = _stringList(variadic['choices']);
      if (choices.isEmpty) {
        dashChoices.add(const [r'$files']);
      } else if (variadic['repeatable'] == true) {
        dashAnyChoices.addAll(choices);
      } else {
        dashChoices.add(choicePairs(choices));
      }
    }

    for (final accessor in _accessorLeaves(_mapOrNull(command['accessors']))) {
      final value = accessor.value;
      switch (value['valueType']) {
        case 'string':
          flagChoices[accessor.path] = const [r'$files'];
        case 'int':
          flagChoices[accessor.path] = intRange;
        case 'double':
          flagChoices[accessor.path] = doubleRange;
        case 'choice':
          flagChoices[accessor.path] = _stringList(value['choices']);
      }
    }

    return {
      if (positionalChoices.isNotEmpty) 'positional': positionalChoices,
      if (flagChoices.isNotEmpty) 'flag': flagChoices,
      if (dashChoices.isNotEmpty) 'dash': dashChoices,
      if (dashAnyChoices.isNotEmpty) 'dashany': dashAnyChoices,
    };
  }

  /// Builds the ordered Carapace key for one named input.
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

  /// Wraps a description and optional default into the Carapace entry shape.
  Object _entryValue(String? description, Object? defaultValue) =>
      defaultValue == null
      ? (description ?? '')
      : {'description': description ?? '', 'default': defaultValue};

  String _commandName(Map<String, dynamic> command) =>
      command['name'] as String;

  Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? _map(value) : null;

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  List<Map<String, dynamic>> _mapList(Object? value) => switch (value) {
    List() => value.map(_map).toList(),
    _ => const [],
  };

  Iterable<({String path, Map<String, dynamic> value, bool hidden})>
  _accessorLeaves(
    Map<String, dynamic>? accessors, {
    String? parentPath,
    bool ancestorHidden = false,
  }) sync* {
    if (accessors == null) return;
    for (final entry in accessors.entries) {
      final path = parentPath == null ? entry.key : '$parentPath.${entry.key}';
      if (entry.value is! Map) {
        yield (
          path: path,
          value: <String, dynamic>{
            'kind': 'value',
            'valueType': 'string',
            'description': entry.value,
          },
          hidden: ancestorHidden,
        );
        continue;
      }
      final value = _map(entry.value);
      final hidden = ancestorHidden || value['hidden'] == true;
      if (value['kind'] == 'group') {
        yield* _accessorLeaves(
          _mapOrNull(value['options']),
          parentPath: path,
          ancestorHidden: hidden,
        );
        continue;
      }
      if (value['kind'] == 'value') {
        yield (path: path, value: value, hidden: hidden);
        continue;
      }
      if (value['options'] is Map) {
        yield* _accessorLeaves(
          _mapOrNull(value['options']),
          parentPath: path,
          ancestorHidden: hidden,
        );
        continue;
      }
      if (value.keys.length == 1 && value.containsKey('description')) {
        yield (
          path: path,
          value: <String, dynamic>{
            'kind': 'value',
            'valueType': 'string',
            'description': value['description'],
          },
          hidden: hidden,
        );
        continue;
      }
      yield* _accessorLeaves(
        {
          for (final child in value.entries)
            if (!(child.key == 'hidden' && child.value is bool))
              child.key: child.value,
        },
        parentPath: path,
        ancestorHidden: hidden,
      );
    }
  }

  Map<String, dynamic>? _withoutLocalOverrides(
    Map<String, dynamic>? persistentInputs,
    Iterable<String>? localNames,
  ) {
    if (persistentInputs == null) return null;
    final localNameSet = localNames?.toSet() ?? const <String>{};
    return {
      for (final entry in persistentInputs.entries)
        if (!localNameSet.contains(entry.key)) entry.key: entry.value,
    };
  }

  List<String> _stringList(Object? value) => switch (value) {
    List() => value.cast<String>(),
    _ => const [],
  };
}

/// Writes a map-derived Carapace spec to the platform's spec directory.
///
/// Production writers use the operating system's Carapace configuration
/// directory. Development writers use a matching directory below the system
/// temp directory so local runs do not modify the user's installed specs.
final class CarapaceSpecWriter {
  CarapaceSpecWriter(
    this.converter, {
    this.development = false,
    String? outputPath,
  }) : path =
           outputPath ??
           _carapaceSpecPath(converter.registryMap.map['name'], development);

  final CarapaceSpecConverter converter;
  final bool development;
  final String path;

  /// Writes the converted registry map and returns the created file.
  File write() {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(converter.convert());
    return file;
  }

  static String _carapaceSpecPath(String name, bool development) {
    final baseDirectory = development
        ? Directory.systemTemp.path
        : _carapaceConfigDirectory();
    return [
      baseDirectory,
      'carapace',
      'specs',
      '$name.yaml',
    ].join(Platform.pathSeparator);
  }

  static String _carapaceConfigDirectory() {
    final environment = Platform.environment;
    final directory = switch (Platform.operatingSystem) {
      'windows' => environment['APPDATA'],
      'macos' => _joinHome(
        environment['HOME'],
        'Library',
        'Application Support',
      ),
      _ =>
        environment['XDG_CONFIG_HOME'] ??
            _joinHome(environment['HOME'], '.config'),
    };
    if (directory == null) {
      throw StateError(
        'Unable to locate the Carapace configuration directory.',
      );
    }
    return directory;
  }

  static String? _joinHome(String? home, String first, [String? second]) {
    if (home == null) return null;
    return [home, first, ?second].join(Platform.pathSeparator);
  }
}
