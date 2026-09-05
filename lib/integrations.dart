import 'dart:io';

import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:yaml_writer/yaml_writer.dart';

List<String> _steppedDoubleValuesFromMap(Map<String, dynamic> value) {
  final min = value['min'];
  final max = value['max'];
  final step = value['step'];
  if (value['valueType'] != 'double' ||
      min is! num ||
      max is! num ||
      step is! num) {
    return const [];
  }
  return _steppedDoubleValues(min.toDouble(), max.toDouble(), step.toDouble());
}

List<String> _steppedDoubleValues(double min, double max, double step) {
  final count = ((max - min) / step).round();
  final decimalPlaces = [min, max, step]
      .map(
        (value) => value.toString().split('.').elementAtOrNull(1)?.length ?? 0,
      )
      .fold(0, (current, value) => current > value ? current : value);
  return [
    for (var index = 0; index <= count; index++)
      double.parse(
        (index == count ? max : min + step * index).toStringAsFixed(
          decimalPlaces,
        ),
      ).toString(),
  ];
}

/// Converts a validated [RegistryMap] into an integration-specific artifact.
abstract class RegistryMapConverter {
  new(this.registryMap);

  final RegistryMap registryMap;

  String convert();
}

/// Compiles a registry map into a portable Bash completion script.
///
/// Bash associative-array values are strings, not arrays. Each option map
/// therefore points at an indexed array containing its finite value choices.
final class ToBashCompletionConverter extends RegistryMapConverter {
  new(super.registryMap);

  @override
  String convert() {
    final root = registryMap.map;
    final rootName = root['name'] as String;
    final lines = <String>[_filterFunction()];
    final rootFlags = _flagsFor(root);
    final rootOptions = _optionsFor(root);

    _writeInputTables(
      lines,
      root,
      [rootName],
      flags: rootFlags,
      options: rootOptions,
      global: true,
    );
    final commands = _mapOrNull(root['commands']);
    _writeRoutingTables(lines, root, [rootName]);
    if (commands != null) {
      for (final command in commands.values) {
        _writeCommand(lines, _map(command), [rootName], rootFlags, rootOptions);
      }
    }
    _writeRootHandler(lines, root, [rootName], rootOptions);
    _writeDispatcher(lines, rootName);
    lines.add('complete -F _${_identifier(rootName)}_completion $rootName');
    return '${lines.join('\n')}\n';
  }

  void _writeRoutingTables(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final rootName = path.first;
    final routes = <String>[];
    final valueOptions = <String>[];

    void collect(
      Map<String, dynamic> parent,
      List<String> parentPath,
      Map<String, dynamic> inheritedOptions, {
      required bool isRoot,
    }) {
      final persistentOptions =
          _mapOrNull(parent['persistentOptions']) ?? const <String, dynamic>{};
      final localOptions = _optionsFor(parent, includePersistent: false);
      final availableOptions = {
        ...inheritedOptions,
        ...persistentOptions,
        ...localOptions,
      };
      final parentIdentifier = _pathIdentifier(parentPath);
      for (final entry in availableOptions.entries) {
        final option = _map(entry.value);
        valueOptions.add('  [${_quote('$parentIdentifier|--${entry.key}')}]=1');
        if (option['short'] case final String short) {
          valueOptions.add('  [${_quote('$parentIdentifier|-$short')}]=1');
        }
      }

      final children = _mapOrNull(parent['commands']);
      if (children == null) return;
      final descendantOptions = isRoot
          ? availableOptions
          : {...inheritedOptions, ...persistentOptions};
      for (final child in children.values) {
        final childMap = _map(child);
        final childPath = [...parentPath, childMap['name'] as String];
        final handler = '_${_pathIdentifier(childPath)}_completion';
        for (final spelling in [
          childMap['name'] as String,
          ..._stringList(childMap['aliases']),
        ]) {
          routes.add(
            '  [${_quote('$parentIdentifier|$spelling')}]=${_quote(handler)}',
          );
        }
        collect(childMap, childPath, descendantOptions, isRoot: false);
      }
    }

    collect(command, path, const {}, isRoot: true);
    lines.addAll([
      'declare -A _${_identifier(rootName)}_command_routes=(',
      ...routes,
      ')',
      '',
      'declare -A _${_identifier(rootName)}_value_options=(',
      ...valueOptions,
      ')',
      '',
    ]);
  }

  void _writeDispatcher(List<String> lines, String rootName) {
    final rootIdentifier = _identifier(rootName);
    lines.addAll([
      '_${rootIdentifier}_completion() {',
      '  COMPREPLY=()',
      "  local path='$rootIdentifier'",
      "  local handler='_${rootIdentifier}_root_completion'",
      '  local index token route',
      '  local positional_index=0',
      '  local variadic_index=0',
      '  local after_separator=0',
      '',
      '  for ((index = 1; index < COMP_CWORD; index++)); do',
      r'    token="${COMP_WORDS[index]}"',
      '    if ((after_separator)); then',
      '      ((variadic_index++))',
      '      continue',
      '    fi',
      r'    if [[ "$token" == -- ]]; then',
      '      after_separator=1',
      '      continue',
      '    fi',
      '    if [[ -n "\${_${rootIdentifier}_value_options["\$path|\$token"]}" ]]; then',
      '      ((index++))',
      '      continue',
      '    fi',
      r'    if [[ "$token" == --*=* ]]; then',
      r'      local option="${token%%=*}"',
      '      if [[ -n "\${_${rootIdentifier}_value_options["\$path|\$option"]}" ]]; then',
      '        continue',
      '      fi',
      '    fi',
      '    route="\${_${rootIdentifier}_command_routes["\$path|\$token"]}"',
      r'    if [[ -n "$route" ]]; then',
      r'      handler="$route"',
      r'      path="${route#_}"',
      r'      path="${path%_completion}"',
      '      positional_index=0',
      '      continue',
      '    fi',
      r'    if [[ "$token" == -* ]]; then',
      '      continue',
      '    fi',
      '    ((positional_index++))',
      '  done',
      '',
      r'  _mamba_after_separator=$after_separator',
      r'  _mamba_positional_index=$positional_index',
      r'  _mamba_variadic_index=$variadic_index',
      r'  "$handler"',
      '}',
      '',
    ]);
  }

  String _filterFunction() => r'''_mamba_filter() {
  local current="$1"
  shift
  COMPREPLY=()

  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$current"* ]]; then
      COMPREPLY+=("$candidate")
    fi
  done
}

_mamba_filter_option() {
  local option="$1"
  local current="$2"
  shift 2
  COMPREPLY=()

  local value="${current#*=}"
  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$value"* ]]; then
      COMPREPLY+=("$option=$candidate")
    fi
  done
}
''';

  void _writeRootHandler(
    List<String> lines,
    Map<String, dynamic> root,
    List<String> path,
    Map<String, dynamic> options,
  ) {
    final function = '_${_pathIdentifier(path)}_root_completion';
    lines.addAll([
      '$function() {',
      r'  local current="${COMP_WORDS[COMP_CWORD]}"',
      r'  local previous="${COMP_WORDS[COMP_CWORD - 1]}"',
      '',
      r'  if [[ "$_mamba_after_separator" == 1 ]]; then',
      '    _complete_${_pathIdentifier(path)}_variadic "\$current"',
      '    return',
      '  fi',
      '',
      r'  case "$current" in',
      ..._inlineValueCases(options, path, '    '),
      '  esac',
      '',
      r'  case "$previous" in',
      ..._valueCases(options, path, '    '),
      '  esac',
      '',
      r'  case "$current" in',
      '    -*)',
      '      _mamba_filter "\$current" ${_arrayValues(_variable(path, 'flags'))} ${_arrayKeys(_variable(path, 'options'))}',
      '      ;;',
      '    *)',
      ..._commandCases(root, '      '),
      '      _complete_${_pathIdentifier(path)}_positional "\$current"',
      '      ;;',
      '  esac',
      '}',
      '',
    ]);
    _writePositionalHandler(lines, root, path);
    _writeVariadicHandler(lines, root, path);
  }

  void _writeCommand(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> parentPath,
    Map<String, dynamic> inheritedFlags,
    Map<String, dynamic> inheritedOptions,
  ) {
    final path = [...parentPath, command['name'] as String];
    final persistentFlags =
        _mapOrNull(command['persistentFlags']) ?? const <String, dynamic>{};
    final persistentOptions =
        _mapOrNull(command['persistentOptions']) ?? const <String, dynamic>{};
    final flags = {
      ...inheritedFlags,
      ...persistentFlags,
      ...?_mapOrNull(command['flags']),
    };
    final options = {
      ...inheritedOptions,
      ...persistentOptions,
      ..._optionsFor(command, includePersistent: false),
    };
    _writeInputTables(lines, command, path, flags: flags, options: options);
    final children = _mapOrNull(command['commands']);
    if (children != null) {
      final descendantFlags = {...inheritedFlags, ...persistentFlags};
      final descendantOptions = {...inheritedOptions, ...persistentOptions};
      for (final child in children.values) {
        _writeCommand(
          lines,
          _map(child),
          path,
          descendantFlags,
          descendantOptions,
        );
      }
    }

    final function = '_${_pathIdentifier(path)}_completion';
    lines.addAll([
      '$function() {',
      r'  local current="${COMP_WORDS[COMP_CWORD]}"',
      r'  local previous="${COMP_WORDS[COMP_CWORD - 1]}"',
      '',
      r'  if [[ "$_mamba_after_separator" == 1 ]]; then',
      '    _complete_${_pathIdentifier(path)}_variadic "\$current"',
      '    return',
      '  fi',
      '',
      r'  case "$current" in',
      ..._inlineValueCases(options, path, '    '),
      '  esac',
      '',
      r'  case "$previous" in',
      ..._valueCases(options, path, '    '),
      '  esac',
      '',
      r'  case "$current" in',
      '    -*)',
      '      _mamba_filter "\$current" ${_arrayValues(_variable(path, 'flags'))} ${_arrayKeys(_variable(path, 'options'))}',
      '      ;;',
      '    *)',
      ..._commandCases(command, '      '),
      '      _complete_${_pathIdentifier(path)}_positional "\$current"',
      '      ;;',
      '  esac',
      '}',
      '',
    ]);
    _writePositionalHandler(lines, command, path);
    _writeVariadicHandler(lines, command, path);
  }

  void _writeInputTables(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path, {
    required Map<String, dynamic> flags,
    required Map<String, dynamic> options,
    bool global = false,
  }) {
    _writeDescription(lines, command['description'] as String);
    final visibleFlags = <String>[];
    for (final entry in flags.entries) {
      final flag = _map(entry.value);
      if (flag['hidden'] == true) continue;
      final short = flag['short'] as String?;
      if (short != null) visibleFlags.add('-$short');
      visibleFlags.add('--${entry.key}');
      if (flag['negatable'] == true) visibleFlags.add('--no-${entry.key}');
    }
    final flagVariable = _variable(path, 'flags');
    lines.addAll([
      global
          ? '# Global inputs for ${path.first}'
          : '# Inputs for ${path.skip(1).join(' ')}',
      '$flagVariable=(',
      for (final flag in visibleFlags) '  ${_quote(flag)}',
      ')',
      '',
    ]);

    final optionVariable = _variable(path, 'options');
    final optionEntries = <String>[];
    for (final entry in options.entries) {
      final option = _map(entry.value);
      if (option['hidden'] == true) continue;
      final valuesVariable = _variable(path, '${entry.key}_values');
      final choices = _stringList(option['choices']);
      final steppedValues = _steppedDoubleValuesFromMap(option);
      lines.addAll([
        '$valuesVariable=(',
        for (final choice in [...choices, ...steppedValues])
          '  ${_quote(choice)}',
        ')',
        '',
      ]);
      optionEntries.add(
        '  [${_quote('--${entry.key}')}]=${_quote(valuesVariable)}',
      );
      if (option['short'] case final String short) {
        optionEntries.add('  [${_quote('-$short')}]=${_quote(valuesVariable)}');
      }
    }
    lines.addAll(['declare -A $optionVariable=(', ...optionEntries, ')', '']);
  }

  List<String> _valueCases(
    Map<String, dynamic> options,
    List<String> path,
    String indent,
  ) {
    return [
      for (final entry in options.entries)
        if (_stringList(_map(entry.value)['choices']).isNotEmpty ||
            _steppedDoubleValuesFromMap(_map(entry.value)).isNotEmpty) ...[
          '$indent${_optionPattern(entry)})',
          '$indent  _mamba_filter "\$current" ${_arrayValues(_variable(path, '${entry.key}_values'))}',
          '$indent  return',
          '$indent  ;;',
        ],
    ];
  }

  List<String> _inlineValueCases(
    Map<String, dynamic> options,
    List<String> path,
    String indent,
  ) {
    return [
      for (final entry in options.entries)
        if (_stringList(_map(entry.value)['choices']).isNotEmpty ||
            _steppedDoubleValuesFromMap(_map(entry.value)).isNotEmpty) ...[
          '$indent--${entry.key}=*)',
          '$indent  _mamba_filter_option ${_quote('--${entry.key}')} "\$current" ${_arrayValues(_variable(path, '${entry.key}_values'))}',
          '$indent  return',
          '$indent  ;;',
        ],
    ];
  }

  List<String> _commandCases(Map<String, dynamic> command, String indent) {
    final commands = _mapOrNull(command['commands']);
    if (commands == null) return const [];
    return [
      '${indent}_mamba_filter "\$current" ${[
        for (final child in commands.values) ...[_quote(_map(child)['name'] as String), for (final alias in _stringList(_map(child)['aliases'])) _quote(alias)],
      ].join(' ')}',
    ];
  }

  void _writePositionalHandler(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final positionals = _mapOrNull(command['positionals']);
    final function = '_complete_${_pathIdentifier(path)}_positional';
    lines.addAll(['$function() {', r'  local current="$1"']);
    if (positionals != null) {
      lines.addAll([
        r'  local index=$_mamba_positional_index',
        r'  case "$index" in',
      ]);
      var index = 0;
      for (final positional in positionals.values) {
        final map = _map(positional);
        final choices = _stringList(map['choices']);
        final times = map['repeatable'] == true ? map['times'] as int : 0;
        if (choices.isNotEmpty) {
          final indexes = [
            for (var slot = 0; slot <= times; slot++) index + slot,
          ].join('|');
          lines.addAll([
            '    $indexes)',
            '      _mamba_filter "\$current" ${choices.map(_quote).join(' ')}',
            '      ;;',
          ]);
        }
        index += times + 1;
      }
      lines.addAll(['  esac']);
    }
    lines.addAll(['}', '']);
  }

  void _writeVariadicHandler(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final variadic = _mapOrNull(command['variadic']);
    final choices = variadic == null
        ? const <String>[]
        : _stringList(variadic['choices']);
    final function = '_complete_${_pathIdentifier(path)}_variadic';
    lines.addAll(['$function() {', r'  local current="$1"']);
    if (choices.isNotEmpty) {
      if (variadic!['repeatable'] == true) {
        lines.add(
          '  _mamba_filter "\$current" ${choices.map(_quote).join(' ')}',
        );
      } else {
        lines.addAll([
          r'  if [[ "$_mamba_variadic_index" == 0 ]]; then',
          '    _mamba_filter "\$current" ${choices.map(_quote).join(' ')}',
          '  fi',
        ]);
      }
    }
    lines.addAll(['}', '']);
  }

  void _writeDescription(List<String> lines, String description) {
    lines.addAll([
      for (final line in description.split('\n'))
        line.isEmpty ? '#' : '# $line',
    ]);
  }

  String _optionPattern(MapEntry<String, dynamic> entry) {
    final short = _map(entry.value)['short'] as String?;
    return '--${entry.key}${short == null ? '' : '|-$short'}';
  }

  String _arrayValues(String variable) => r'"${' + variable + r'[@]}"';

  String _arrayKeys(String variable) => r'"${!' + variable + r'[@]}"';

  String _variable(List<String> path, String suffix) =>
      '_${_pathIdentifier(path)}_${_identifier(suffix)}';

  String _pathIdentifier(Iterable<String> path) =>
      path.map(_identifier).join('_');

  String _identifier(String value) =>
      value.replaceAll('-', '_').replaceAll('.', '_');

  String _quote(String value) => "'${value.replaceAll("'", "'\\\"'\\\"")}'";

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? _map(value) : null;

  List<String> _stringList(Object? value) => switch (value) {
    List() => value.cast<String>(),
    _ => const [],
  };

  Iterable<({String path, Map<String, dynamic> value})> _accessorLeaves(
    Map<String, dynamic>? accessors, {
    String? parentPath,
  }) sync* {
    if (accessors == null) return;
    for (final entry in accessors.entries) {
      final path = parentPath == null ? entry.key : '$parentPath.${entry.key}';
      final value = _map(entry.value);
      if (value['kind'] == 'group') {
        yield* _accessorLeaves(_mapOrNull(value['options']), parentPath: path);
      } else {
        yield (path: path, value: value);
      }
    }
  }

  Map<String, dynamic> _flagsFor(Map<String, dynamic> command) => {
    ...?_mapOrNull(command['persistentFlags']),
    ...?_mapOrNull(command['flags']),
  };

  Map<String, dynamic> _optionsFor(
    Map<String, dynamic> command, {
    bool includePersistent = true,
  }) => {
    if (includePersistent) ...?_mapOrNull(command['persistentOptions']),
    ...?_mapOrNull(command['options']),
    for (final accessor in _accessorLeaves(_mapOrNull(command['accessors'])))
      accessor.path: accessor.value,
  };
}

/// Compiles a registry map into a native Zsh completion function.
final class ToZshCompletionConverter extends RegistryMapConverter {
  new(super.registryMap);

  @override
  String convert() {
    final root = _map(registryMap.map);
    final rootName = root['name'] as String;
    final lines = <String>['#compdef $rootName', ''];
    _writeCommand(lines, root, [rootName], const {}, const {});
    lines.add('compdef _${_pathIdentifier([rootName])} $rootName');
    return '${lines.join('\n')}\n';
  }

  void _writeCommand(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path,
    Map<String, dynamic> inheritedFlags,
    Map<String, dynamic> inheritedOptions,
  ) {
    final flags = {
      ...inheritedFlags,
      ...?_mapOrNull(command['persistentFlags']),
      ...?_mapOrNull(command['flags']),
    };
    final options = {
      ...inheritedOptions,
      ...?_mapOrNull(command['persistentOptions']),
      ...?_mapOrNull(command['options']),
      for (final accessor in _accessorLeaves(_mapOrNull(command['accessors'])))
        if (!accessor.hidden) accessor.path: accessor.value,
    };
    final children = _mapOrNull(command['commands']);
    if (children != null) {
      for (final child in children.values) {
        final childMap = _map(child);
        _writeCommand(
          lines,
          childMap,
          [...path, childMap['name'] as String],
          flags,
          options,
        );
      }
    }

    final function = '_${_pathIdentifier(path)}';
    lines.addAll(['$function() {']);
    if (path.length > 1) {
      lines.addAll([
        '  local -a words',
        r'  words=("${words[@]:2}")',
        '  (( CURRENT -= 1 ))',
      ]);
    }
    if (children != null) {
      lines.addAll([
        r'  case "$words[2]" in',
        for (final child in children.values) ...[
          '    ${_commandPatterns(_map(child))})',
          '      _${_pathIdentifier([...path, _map(child)['name'] as String])}',
          '      return',
          '      ;;',
        ],
        '  esac',
      ]);
    }
    lines.addAll([
      '  local context state state_descr line',
      '  typeset -A opt_args',
      r'  if (( ${words[(I:--)]} )); then',
      ..._variadicLines(command, '    '),
      '    return',
      '  fi',
      '  _arguments -S \\',
      ..._argumentSpecs(flags, options, command, children),
      r'  case $state in',
    ]);
    if (children != null) {
      lines.addAll([
        '    command)',
        '      local -a commands',
        '      commands=(',
        for (final child in children.values) ..._commandCandidates(_map(child)),
        '      )',
        "      _describe 'command' commands",
        '      ;;',
      ]);
    }
    lines.addAll(['  esac', '}', '']);
  }

  List<String> _argumentSpecs(
    Map<String, dynamic> flags,
    Map<String, dynamic> options,
    Map<String, dynamic> command,
    Map<String, dynamic>? children,
  ) {
    final specs = <String>[
      for (final entry in flags.entries)
        if (_map(entry.value)['hidden'] != true)
          ..._flagSpecs(entry.key, _map(entry.value)),
      for (final entry in options.entries)
        if (_map(entry.value)['hidden'] != true)
          _optionSpec(entry.key, _map(entry.value)),
      ..._positionalSpecs(command),
      if (children != null) "'1:command:->command'",
      "'*::argument:'",
    ];
    return [
      for (var index = 0; index < specs.length; index++)
        '    ${specs[index]}${index == specs.length - 1 ? '' : ' \\'}',
    ];
  }

  List<String> _flagSpecs(String name, Map<String, dynamic> flag) {
    final description = _description(flag['description'] as String?);
    final short = flag['short'] as String?;
    final repeatable = flag.containsKey('default') ? '' : '*';
    final primary = short == null
        ? "'$repeatable--$name[$description]'"
        : "'$repeatable{-$short,--$name}[$description]'";
    return [
      primary,
      if (flag['negatable'] == true) "'--no-$name[$description]'",
    ];
  }

  String _optionSpec(String name, Map<String, dynamic> option) {
    final repeatable = option['repeatable'] == true ? '*' : '';
    final short = option['short'] as String?;
    final spelling = short == null ? '--$name' : '{-$short,--$name}';
    final valueName = _escape(name);
    return "'$repeatable$spelling[${_description(option['description'] as String?)}]:$valueName:${_valueAction(option)}'";
  }

  List<String> _positionalSpecs(Map<String, dynamic> command) {
    final positionals = _mapOrNull(command['positionals']);
    if (positionals == null) return const [];
    final specs = <String>[];
    var index = 1;
    for (final entry in positionals.entries) {
      final positional = _map(entry.value);
      final repetitions = positional['repeatable'] == true
          ? positional['times'] as int? ?? 0
          : 0;
      for (var count = 0; count <= repetitions; count++) {
        final optional = positional['required'] == true && count == 0
            ? ':'
            : '::';
        specs.add(
          "'$index$optional${_escape(entry.key)}:${_valueAction(positional)}'",
        );
        index++;
      }
    }
    return specs;
  }

  List<String> _variadicLines(Map<String, dynamic> command, String indent) {
    final variadic = _mapOrNull(command['variadic']);
    if (variadic == null) return ['$indent:'];
    final choices = _stringList(variadic['choices']);
    return choices.isEmpty
        ? ['$indent:']
        : [
            "${indent}_values 'value' ${choices.map(_quote).join(' ')}",
          ];
  }

  String _valueAction(Map<String, dynamic> value) {
    final choices = _stringList(value['choices']);
    final steppedValues = _steppedDoubleValuesFromMap(value);
    if (choices.isNotEmpty || steppedValues.isNotEmpty) {
      return '(${[...choices, ...steppedValues].map(_escape).join(' ')})';
    }
    final minimum = value['min'] as num?;
    final maximum = value['max'] as num?;
    final bounds = [
      if (minimum != null) '-l $minimum',
      if (maximum != null) '-m $maximum',
    ].join(' ');
    return switch (value['valueType']) {
      'int' => '_numbers${bounds.isEmpty ? '' : ' $bounds'}',
      'double' => '_numbers -f${bounds.isEmpty ? '' : ' $bounds'}',
      _ => '',
    };
  }

  String _commandPatterns(Map<String, dynamic> command) => [
    command['name'] as String,
    ..._stringList(command['aliases']),
  ].map(_escape).join('|');

  List<String> _commandCandidates(Map<String, dynamic> command) {
    final description = _escape(
      (command['description'] as String).split('\n').first,
    );
    return [
      "        '${_escape(command['name'] as String)}:$description'",
      for (final alias in _stringList(command['aliases']))
        "        '${_escape(alias)}:Alias for ${_escape(command['name'] as String)}'",
    ];
  }

  String _description(String? value) => _escape(value?.split('\n').first ?? '');

  String _escape(String value) => value
      .replaceAll(r'\\', r'\\\\')
      .replaceAll('[', r'\\[')
      .replaceAll(']', r'\\]')
      .replaceAll(':', r'\\:')
      .replaceAll("'", r"'\\''");

  String _quote(String value) => "'${_escape(value)}'";

  String _pathIdentifier(Iterable<String> path) =>
      path.map(_identifier).join('_');

  String _identifier(String value) =>
      value.replaceAll('-', '_').replaceAll('.', '_');

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? _map(value) : null;

  List<String> _stringList(Object? value) => switch (value) {
    List() => value.cast<String>(),
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
      final value = _map(entry.value);
      final hidden = ancestorHidden || value['hidden'] == true;
      if (value['kind'] == 'group') {
        yield* _accessorLeaves(
          _mapOrNull(value['options']),
          parentPath: path,
          ancestorHidden: hidden,
        );
      } else {
        yield (path: path, value: value, hidden: hidden);
      }
    }
  }
}

/// Compiles a registry map into Fish `complete` declarations.
///
/// The generated helpers route rules to the selected command path and keep
/// positional and post-`--` choices separate. Parser validation remains in
/// Mamba; Fish only advertises the static command grammar.
final class ToFishCompletionConverter extends RegistryMapConverter {
  new(super.registryMap);

  @override
  String convert() {
    final root = _map(registryMap.map);
    final rootName = root['name'] as String;
    final lines = <String>[
      '# Completion for $rootName: ${_summary(root['description'] as String)}',
      _helpers(),
      '',
    ];
    _writeCommand(lines, root, [rootName], const [], const {}, const {});
    return '${lines.join('\n')}\n';
  }

  String _helpers() => r'''function __mamba_segment_field
    set -l fields (string split '|' -- $argv[1])
    string split ',' -- $fields[$argv[2]]
end

function __mamba_input_width
    set -l spec $argv[1]
    set -l token $argv[2]
    if string match -q -- '--*' $token
        set -l long (string replace -r '^--' '' -- $token)
        set -l parts (string split -m 1 '=' -- $long)
        if contains -- $parts[1] (__mamba_segment_field $spec 4)
            if test (count $parts) -eq 1
                echo 2
            else
                echo 1
            end
            return
        end
        if contains -- $parts[1] (__mamba_segment_field $spec 2)
            echo 1
            return
        end
        echo 0
        return
    end
    if string match -q -- '-*' $token
        set -l short (string sub -s 2 -- $token)
        if test (string length -- $short) -eq 1; and contains -- $short (__mamba_segment_field $spec 5)
            echo 2
            return
        end
        for name in (string split '' -- $short)
            if not contains -- $name (__mamba_segment_field $spec 3)
                echo 0
                return
            end
        end
        if test -n "$short"
            echo 1
            return
        end
    end
    echo 0
end

function __mamba_path_state
    set -l mode $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l selecting true
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            set selecting false
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l width (__mamba_input_width $specs[$depth] $token)
        if test $width -gt 0
            if test $width -eq 2; and test $offset -eq (count $tokens)
                set selecting false
            end
            set offset (math $offset + $width)
            continue
        end
        set selecting false
        break
    end
    if test $depth -ne (count $specs)
        return 1
    end
    if test "$mode" = selecting
        test "$selecting" = true
        return
    end
    return 0
end

function __mamba_at_path
    __mamba_path_state path $argv
end

function __mamba_selecting_child
    __mamba_path_state selecting $argv
end

function __mamba_after_double_dash
    contains -- -- (commandline -xpc)
end

function __mamba_option_available
    set -l option --$argv[1]
    set -l short $argv[2]
    set -l repeatable $argv[3]
    if test "$repeatable" = true
        return 0
    end
    set -l tokens (commandline -xpc)
    for index in (seq (count $tokens))
        set -l token $tokens[$index]
        if string match -q -- "$option=*" $token
            return 1
        end
        if test "$token" = "$option"
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
        if test "$short" != _; and test "$token" = -$short
            if test $index -lt (count $tokens)
                return 1
            end
            return 0
        end
    end
    return 0
end

function __mamba_positional_slot
    set -l target $argv[1]
    set -e argv[1]
    set -l specs $argv
    set -l tokens (commandline -xpc)
    set -e tokens[1]
    set -l depth 1
    set -l offset 1
    set -l count 0
    while test $offset -le (count $tokens)
        set -l token $tokens[$offset]
        if test "$token" = --
            break
        end
        if test $depth -lt (count $specs)
            set -l next_depth (math $depth + 1)
            if contains -- $token (__mamba_segment_field $specs[$next_depth] 1)
                set depth $next_depth
                set offset (math $offset + 1)
                continue
            end
        end
        if contains -- $token (__mamba_segment_field $specs[$depth] 6)
            return 1
        end
        set -l width (__mamba_input_width $specs[$depth] $token)
        if test $width -gt 0
            set offset (math $offset + $width)
            continue
        end
        if test $depth -lt (count $specs)
            return 1
        end
        set count (math $count + 1)
        set offset (math $offset + 1)
    end
    test $depth -eq (count $specs); and test $count -eq $target
end

function __mamba_variadic_available
    if test "$argv[1]" = true
        return 0
    end
    set -l after_separator false
    set -l count 0
    for token in (commandline -xpc)
        if test "$after_separator" = true
            set count (math $count + 1)
        else if test "$token" = --
            set after_separator true
        end
    end
    test $count -eq 0
end''';

  void _writeCommand(
    List<String> lines,
    Map<String, dynamic> command,
    List<String> path,
    List<String> ancestorSpecs,
    Map<String, dynamic> inheritedFlags,
    Map<String, dynamic> inheritedOptions,
  ) {
    final persistentFlags = {
      ...inheritedFlags,
      ...?_mapOrNull(command['persistentFlags']),
    };
    final flags = {...persistentFlags, ...?_mapOrNull(command['flags'])};
    final persistentOptions = {
      ...inheritedOptions,
      ...?_mapOrNull(command['persistentOptions']),
    };
    final options = {...persistentOptions, ...?_mapOrNull(command['options'])};
    final children = _mapOrNull(command['commands']);
    final spec = _commandSpec(
      command,
      flags,
      options,
      _mapOrNull(command['accessors']),
      children,
    );
    final specs = [...ancestorSpecs, spec];
    final condition = path.length == 1
        ? ''
        : _helperCondition('__mamba_at_path', specs);
    _writeInputs(
      lines,
      path.first,
      condition,
      flags,
      options,
      _mapOrNull(command['accessors']),
    );
    _writePositionals(lines, path.first, command, condition, specs);
    _writeVariadic(lines, path.first, command, condition);

    if (children == null) return;
    final childCondition = _helperCondition('__mamba_selecting_child', specs);
    for (final child in children.values) {
      final childMap = _map(child);
      final names = [
        childMap['name'] as String,
        ..._stringList(childMap['aliases']),
      ];
      lines.add(
        "complete -c ${_quoteBare(path.first)}${_conditionArgument(childCondition)} -f -a ${_quote(names.join(' '))} -d ${_quote(_summary(childMap['description'] as String))}",
      );
      _writeCommand(
        lines,
        childMap,
        [...path, childMap['name'] as String],
        specs,
        path.length == 1 ? flags : persistentFlags,
        path.length == 1 ? options : persistentOptions,
      );
    }
  }

  void _writeInputs(
    List<String> lines,
    String executable,
    String condition,
    Map<String, dynamic> flags,
    Map<String, dynamic> options,
    Map<String, dynamic>? accessors,
  ) {
    for (final entry in flags.entries) {
      final flag = _map(entry.value);
      if (flag['hidden'] == true) continue;
      final switches = <String>['-l ${_quoteBare(entry.key)}'];
      if (flag['short'] case final String short) {
        switches.insert(0, '-s $short');
      }
      lines.add(
        'complete -c $executable${_conditionArgument(condition)} ${switches.join(' ')}${_description(flag['description'])}',
      );
      if (flag['negatable'] == true) {
        lines.add(
          'complete -c $executable${_conditionArgument(condition)} -l no-${_quoteBare(entry.key)}${_description(flag['description'])}',
        );
      }
    }
    final accessorOptions = _accessorLeaves(accessors);
    final mergedOptions = <String, Map<String, dynamic>>{
      for (final entry in options.entries) entry.key: _map(entry.value),
      for (final leaf in accessorOptions) leaf.path: leaf.value,
    };
    for (final entry in mergedOptions.entries) {
      final option = entry.value;
      if (option['hidden'] == true) continue;
      final short = option['short'] as String?;
      final type = option['valueType'] as String?;
      final choices = _stringList(option['choices']);
      final steppedValues = _steppedDoubleValuesFromMap(option);
      final completionValues = [...choices, ...steppedValues];
      final switches = <String>[
        if (short != null) '-s $short',
        '-l ${_quoteBare(entry.key)}',
        choices.isNotEmpty || type == 'int' || type == 'double' ? '-x' : '-r',
        if (completionValues.isNotEmpty)
          '-a ${_quote(completionValues.join(' '))}',
      ];
      final available =
          '__mamba_option_available ${_quoteBare(entry.key)} ${short ?? '_'} ${option['repeatable'] == true}';
      final availability = condition.isEmpty
          ? available
          : '$condition; and $available';
      lines.add(
        'complete -c $executable -n ${_quote(availability)} ${switches.join(' ')}${_description(option['description'])}',
      );
    }
  }

  void _writePositionals(
    List<String> lines,
    String executable,
    Map<String, dynamic> command,
    String condition,
    List<String> specs,
  ) {
    final positionals = _mapOrNull(command['positionals']);
    if (positionals == null) return;
    var slot = 0;
    for (final value in positionals.values) {
      final positional = _map(value);
      final choices = _stringList(positional['choices']);
      final times = positional['repeatable'] == true
          ? (positional['times'] as int)
          : 0;
      for (var occurrence = 0; occurrence <= times; occurrence++, slot++) {
        if (choices.isEmpty) continue;
        final positionalCondition = _joinConditions([
          condition,
          'not __mamba_after_double_dash',
          _helperCondition('__mamba_positional_slot $slot', specs),
        ]);
        lines.add(
          "complete -c ${_quoteBare(executable)} -n ${_quote(positionalCondition)} -f -a ${_quote(choices.join(' '))}${_description(positional['description'])}",
        );
      }
    }
  }

  void _writeVariadic(
    List<String> lines,
    String executable,
    Map<String, dynamic> command,
    String condition,
  ) {
    final variadic = _mapOrNull(command['variadic']);
    if (variadic == null) return;
    final choices = _stringList(variadic['choices']);
    if (choices.isEmpty) return;
    final variadicCondition = _joinConditions([
      condition,
      '__mamba_after_double_dash',
      '__mamba_variadic_available ${variadic['repeatable'] == true}',
    ]);
    lines.add(
      "complete -c ${_quoteBare(executable)} -n ${_quote(variadicCondition)} -f -a ${_quote(choices.join(' '))}${_description(variadic['description'])}",
    );
  }

  String _commandSpec(
    Map<String, dynamic> command,
    Map<String, dynamic> flags,
    Map<String, dynamic> options,
    Map<String, dynamic>? accessors,
    Map<String, dynamic>? children,
  ) {
    final longFlags = <String>[];
    final shortFlags = <String>[];
    for (final entry in flags.entries) {
      final flag = _map(entry.value);
      longFlags.add(entry.key);
      if (flag['negatable'] == true) longFlags.add('no-${entry.key}');
      if (flag['short'] case final String short) shortFlags.add(short);
    }
    final mergedOptions = <String, Map<String, dynamic>>{
      for (final entry in options.entries) entry.key: _map(entry.value),
      for (final leaf in _accessorLeaves(accessors, includeHidden: true))
        leaf.path: leaf.value,
    };
    final longOptions = mergedOptions.keys.toList();
    final shortOptions = [
      for (final option in mergedOptions.values)
        if (option['short'] case final String short) short,
    ];
    final childNames = [
      for (final child in children?.values ?? const <dynamic>[]) ...[
        _map(child)['name'] as String,
        ..._stringList(_map(child)['aliases']),
      ],
    ];
    return [
      [command['name'] as String, ..._stringList(command['aliases'])].join(','),
      longFlags.join(','),
      shortFlags.join(','),
      longOptions.join(','),
      shortOptions.join(','),
      childNames.join(','),
    ].join('|');
  }

  String _helperCondition(String helper, List<String> specs) =>
      '$helper ${specs.map(_conditionQuote).join(' ')}';
  String _conditionQuote(String value) => "'$value'";
  String _joinConditions(Iterable<String> conditions) =>
      conditions.where((condition) => condition.isNotEmpty).join('; and ');
  String _conditionArgument(String condition) =>
      condition.isEmpty ? '' : ' -n ${_quote(condition)}';
  String _summary(String description) => description.split('\n').first;
  String _description(Object? description) =>
      description is String ? ' -d ${_quote(_summary(description))}' : '';
  String _quoteBare(String value) => value;
  String _quote(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);
  Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? _map(value) : null;
  List<String> _stringList(Object? value) =>
      value is List ? value.cast<String>() : const [];

  Iterable<({String path, Map<String, dynamic> value})> _accessorLeaves(
    Map<String, dynamic>? accessors, {
    String? parent,
    bool includeHidden = false,
  }) sync* {
    if (accessors == null) return;
    for (final entry in accessors.entries) {
      final path = parent == null ? entry.key : '$parent.${entry.key}';
      final value = _map(entry.value);
      if (value['kind'] == 'group') {
        if (!includeHidden && value['hidden'] == true) continue;
        yield* _accessorLeaves(
          _mapOrNull(value['options']),
          parent: path,
          includeHidden: includeHidden,
        );
      } else {
        yield (path: path, value: value);
      }
    }
  }
}

/// Converts a [RegistryMap] into a Carapace completion spec.
///
/// The map carries all input semantics needed to reproduce the complete
/// Carapace output without retaining a live command definition.
final class CarapaceSpecConverter extends RegistryMapConverter {
  new(super.registryMap);

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
      if (booleanFlag && flag['negatable'] == true) {
        placeEntry(
          'no-$name',
          persistent,
          _inputKey(
            name: 'no-$name',
            short: null,
            repeatable: false,
            mandatory: false,
            hidden: flag['hidden'] as bool,
            takesValue: false,
          ),
          flag['description'] as String?,
        );
      }
    }

    void placeOption(
      String name,
      Map<String, dynamic> option,
      bool persistent, {
      bool? required,
      bool? hidden,
      String? description,
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
        description ?? option['description'] as String?,
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
        final requirement = mode == 'oneOf' && required
            ? 'Runtime requires exactly one of: ${members.map((member) => '--$member').join(', ')}.'
            : null;
        for (final member in members) {
          final value = options[member];
          if (value is Map) {
            final option = _map(value);
            placeOption(
              member,
              option,
              persistent,
              required: mode == 'all' && required,
              description: requirement == null
                  ? null
                  : '${option['description'] ?? ''} $requirement',
            );
          }
        }
        // Carapace expresses exclusivity but not the at-least-one part of a
        // required variant group, so retain the runtime constraint in each
        // generated member description.
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

    List<String> choicePairs(List<String> choices) => [
      for (final choice in choices) ...[choice, choice],
    ];
    final positionals = _mapOrNull(command['positionals']);
    if (positionals != null) {
      for (final positionalValue in positionals.values) {
        final positional = _map(positionalValue);
        final values = _stringList(positional['choices']);
        final times = positional['repeatable'] == true
            ? positional['times'] as int? ?? 0
            : 0;
        for (var slot = 0; slot <= times; slot++) {
          positionalChoices.add(values);
        }
      }
    }

    final options = _mapOrNull(command['options']);
    if (options != null) {
      for (final entry in options.entries) {
        final option = _map(entry.value);
        switch (option['valueType']) {
          case 'choice':
            flagChoices[entry.key] = _stringList(option['choices']);
          case 'int':
            final min = option['min'];
            final max = option['max'];
            if (min is num && max is num) {
              flagChoices[entry.key] = [
                r'$carapace.number.Range({start: '
                    '$min, end: $max})',
              ];
            }
          case 'double':
            final values = _steppedDoubleValuesFromMap(option);
            if (values.isNotEmpty) flagChoices[entry.key] = values;
        }
      }
    }

    final dashChoices = <List<String>>[];
    final dashAnyChoices = <String>[];
    final variadic = _mapOrNull(command['variadic']);
    if (variadic != null) {
      final values = _stringList(variadic['choices']);
      if (values.isNotEmpty && variadic['repeatable'] == true) {
        dashAnyChoices.addAll(values);
      } else if (values.isNotEmpty) {
        dashChoices.add(choicePairs(values));
      }
    }

    for (final accessor in _accessorLeaves(_mapOrNull(command['accessors']))) {
      final value = accessor.value;
      switch (value['valueType']) {
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
      // RegistryMap validation guarantees every accessor is a canonical group
      // or value node, so no legacy fallback conversion is required.
      throw StateError('Unsupported canonical accessor kind');
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

/// Compiles a registry map into a native PowerShell argument completer.
///
/// The generated script registers a single `Register-ArgumentCompleter -Native`
/// handler and resolves every element strictly left of the cursor against
/// one of three small PowerShell maps emitted from the registry:
/// - Spelled-name table (`$script:MambaSpellingFor`) mapping every visible
///   spelling (long, short, negated, accessor) to its canonical owning
///   command.
/// - Per-command tables (split into command-specific helper functions) for
///   commands, choice options, repeated positionals, and variadics.
/// - Lookup tables to identify when a long/short spelling must consult a
///   value handler before emitting flag candidates.
///
/// All candidate `CompletionResult` objects flow out individually through the
/// success pipeline so PowerShell presents them as separate entries.
/// The emitted syntax targets Windows PowerShell 5.1 and PowerShell 7 or newer.
final class ToPowerShellCompletionConverter extends RegistryMapConverter {
  new(super.registryMap);

  /// Upper bound on the inclusive integer range Mamba emits for an option
  /// with both `min` and `max` bounds. Wider intervals stay unbound.
  static const int _maxStaticRangeSize = 64;

  /// Uses the root command name to isolate each generated artifact's
  /// PowerShell variables and helper functions.
  String get _powerShellNamespace {
    final root = _map(registryMap.map);
    return 'Mamba${_pascalCase(root['name'] as String)}';
  }

  String _state(String name) => r'$script:' + _powerShellNamespace + name;

  String _pascalCase(String name) => name
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join();

  @override
  String convert() {
    final root = _map(registryMap.map);
    final rootName = root['name'] as String;
    final lines = <String>[
      ..._header(rootName, root['description'] as String),
      ..._native(root),
      ..._tableInitializers(),
      ..._recurse(root, ['root'], const {}, const {}, const {}, isRoot: true),
      ..._runtimeHelpers(),
      ..._register(rootName),
    ];
    return '${lines.join('\n')}\n';
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  List<String> _header(String name, String description) => [
    '<#',
    ' PowerShell completion for $name.',
    r''' Generated; do not edit by hand.''',
    '',
    for (final line in description.split('\n')) line.isEmpty ? '' : ' $line',
    '',
    ' To show a completion menu instead of cycling candidates:',
    ' Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete',
    '#>',
  ];

  // ---------------------------------------------------------------------
  // Top-level tables
  // ---------------------------------------------------------------------

  /// Global lookup from canonical command name to canonical command name; the
  /// resolver flattens an alias token into its canonical spelling using this
  /// map before resolving the rest of the command line.
  List<String> _native(Map<String, dynamic> root) {
    final entries = <String>["    'root' = 'root'"];
    void walk(Map<String, dynamic>? commands) {
      if (commands == null) return;
      for (final entry in commands.entries) {
        final child = _map(entry.value);
        entries.add("    ${_psQuote(entry.key)} = ${_psQuote(entry.key)}");
        for (final alias in _stringList(child['aliases'])) {
          entries.add("    ${_psQuote(alias)} = ${_psQuote(entry.key)}");
        }
        walk(_mapOrNull(child['commands']));
      }
    }

    walk(_mapOrNull(root['commands']));
    return ['${_state('NativeCommands')} = @{', ...entries, '}', ''];
  }

  List<String> _tableInitializers() => [
    '${_state('Inputs')} = @{}',
    '${_state('Children')} = @{}',
    '${_state('PositionalSlots')} = @{}',
    '${_state('ValueHandlers')} = @{}',
    '${_state('VariadicHandlers')} = @{}',
    '',
  ];

  // ---------------------------------------------------------------------
  // Per-path emission
  // ---------------------------------------------------------------------

  /// Per-path input set combining inherited and local inputs, accessor leaves
  /// flattened into dotted spellings, and the built-in help.
  List<String> _nativeInputSets(
    List<String> path,
    Map<String, dynamic> flags,
    Map<String, dynamic> options,
    Map<String, _AccessorLeaf> accessors,
  ) {
    final entries = <String>[];
    // Always include --help and -h first. The registry's help entry is
    // skipped below so it cannot be emitted twice.
    entries.addAll(
      _flagInputsFor('help', {
        'description': 'Show this help message.',
        'short': 'h',
      }, help: true),
    );

    for (final entry in flags.entries) {
      if (entry.key == 'help') continue;
      final flag = _map(entry.value);
      if (flag['hidden'] == true) continue;
      // Count flags omit the boolean-only default and negatable properties.
      final isCount = !flag.containsKey('default');
      entries.add(_row('--${entry.key}', flag, isFlag: true, isCount: isCount));
      if (flag['short'] case final String short) {
        entries.add(_row('-$short', flag, isFlag: true, isCount: isCount));
      }
      if (!isCount && flag['negatable'] == true) {
        entries.add(_row('--no-${entry.key}', flag, isFlag: true));
      }
    }

    for (final entry in options.entries) {
      final option = _map(entry.value);
      if (option['hidden'] == true) continue;
      final isRepeatable = option['repeatable'] == true;
      entries.add(_row('--${entry.key}', option, isRepeatable: isRepeatable));
      if (option['short'] case final String short) {
        entries.add(_row('-$short', option, isRepeatable: isRepeatable));
      }
    }
    for (final leaf in accessors.values) {
      entries.add(
        _row('--${leaf.path}', {
          'description': leaf.description,
        }, isAccessor: true),
      );
    }
    final pathKey = path.join('.');
    return [
      "${_state('Inputs')}[${_psQuote(pathKey)}] = @(",
      ...entries,
      '    )',
    ];
  }

  List<String> _flagInputsFor(
    String name,
    Map<String, dynamic> flag, {
    required bool help,
  }) {
    final entries = <String>[_row('--$name', flag, isFlag: true, help: help)];
    if (flag['short'] case final String short) {
      entries.add(_row('-$short', flag, isFlag: true, help: help));
    }
    return entries;
  }

  String _row(
    String spelling,
    Map<String, dynamic> descriptor, {
    bool isFlag = false,
    bool isCount = false,
    bool isRepeatable = false,
    bool isAccessor = false,
    bool help = false,
  }) =>
      '    [PSCustomObject]@{'
      ' Spelling = ${_psQuote(spelling)};'
      ' Description = ${_psQuoteOrNull(descriptor['description'] as String?)};'
      ' IsFlag = ${_psBool(isFlag)};'
      ' IsCount = ${_psBool(isCount)};'
      ' IsRepeatable = ${_psBool(isRepeatable)};'
      ' IsAccessor = ${_psBool(isAccessor)};'
      ' IsHelp = ${_psBool(help)}'
      ' }';

  /// Subcommand candidates at the given path.
  List<String> _nativeChildren(
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final children = _mapOrNull(command['commands']);
    final entries = <String>[];
    if (children != null) {
      for (final entry in children.entries) {
        final child = _map(entry.value);
        final description = _summary(child['description'] as String?);
        entries.add(
          '    [PSCustomObject]@{'
          ' Name = ${_psQuote(entry.key)};'
          ' Description = ${_psQuoteOrNull(description)}'
          ' }',
        );
        for (final alias in _stringList(child['aliases'])) {
          entries.add(
            '    [PSCustomObject]@{'
            ' Name = ${_psQuote(alias)};'
            ' Description = ${_psQuoteOrNull('Alias for ${entry.key}. ${description ?? ''}')}'
            ' }',
          );
        }
      }
    }
    final pathKey = path.join('.');
    return [
      "${_state('Children')}[${_psQuote(pathKey)}] = @(",
      ...entries,
      '    )',
    ];
  }

  /// Positional slot table for the given path. Each slot exposes its finite
  /// choice list and description for the dispatcher to consult.
  List<String> _nativePositionals(
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final positionals = _mapOrNull(command['positionals']);
    if (positionals == null || positionals.isEmpty) {
      return [
        "${_state('PositionalSlots')}[${_psQuote(path.join('.'))}] = @{}",
      ];
    }
    final lines = <String>[
      "${_state('PositionalSlots')}[${_psQuote(path.join('.'))}] = @{",
    ];
    var slot = 0;
    for (final entry in positionals.entries) {
      final positional = _map(entry.value);
      final choices = _stringList(positional['choices']);
      final times = positional['repeatable'] == true
          ? positional['times'] as int? ?? 0
          : 0;
      for (var occurrence = 0; occurrence <= times; occurrence++, slot++) {
        if (choices.isEmpty) continue;
        lines.add(
          '    $slot = [PSCustomObject]@{'
          ' Choices = @(${choices.map(_psQuote).join(', ')});'
          ' Description = ${_psQuoteOrNull(positional['description'] as String?)}'
          ' }',
        );
      }
    }
    lines.add('    }');
    return lines;
  }

  /// Value-handler arrays for choice options and accessor choice leaves.
  List<String> _nativeValueHandlers(
    List<String> path,
    Map<String, dynamic> options,
    Map<String, _AccessorLeaf> accessors,
  ) {
    final lines = <String>[];
    for (final entry in options.entries) {
      final option = _map(entry.value);
      if (option['hidden'] == true) continue;
      final values = _staticValuesFor(option);
      if (values.isEmpty) continue;
      final longKey = '${path.join('.')}.--${entry.key}';
      lines.add(
        "${_state('ValueHandlers')}[${_psQuote(longKey)}] = @(${values.map(_psQuote).join(', ')})",
      );
      if (option['short'] case final String short) {
        final shortKey = '${path.join('.')}.-$short';
        lines.add(
          "${_state('ValueHandlers')}[${_psQuote(shortKey)}] = ${_state('ValueHandlers')}[${_psQuote(longKey)}]",
        );
      }
    }
    for (final leaf in accessors.values) {
      if (leaf.choices.isEmpty) continue;
      final key = '${path.join('.')}.--${leaf.path}';
      lines.add(
        "${_state('ValueHandlers')}[${_psQuote(key)}] = @(${leaf.choices.map(_psQuote).join(', ')})",
      );
    }
    return lines;
  }

  /// Variadic handler for a command. The handler stores its choice list and
  /// repeatability flag; the dispatcher reads both to decide whether to
  /// emit candidates after `--`.
  List<String> _nativeVariadic(
    Map<String, dynamic> command,
    List<String> path,
  ) {
    final variadic = _mapOrNull(command['variadic']);
    if (variadic == null) return const [];
    final choices = _stringList(variadic['choices']);
    return [
      "${_state('VariadicHandlers')}[${_psQuote(path.join('.'))}] = [PSCustomObject]@{"
          ' Choices = @(${choices.map(_psQuote).join(', ')});'
          ' Repeatable = ${_psBool(variadic['repeatable'] == true)}'
          ' }',
    ];
  }

  // ---------------------------------------------------------------------
  // Walks down to descendents
  // ---------------------------------------------------------------------

  List<String> _recurse(
    Map<String, dynamic> command,
    List<String> path,
    Map<String, dynamic> inheritedFlags,
    Map<String, dynamic> inheritedOptions,
    Map<String, _AccessorLeaf> inheritedAccessors, {
    required bool isRoot,
  }) {
    final children =
        _mapOrNull(command['commands']) ?? const <String, dynamic>{};
    final persistentFlags =
        _mapOrNull(command['persistentFlags']) ?? const <String, dynamic>{};
    final persistentOptions =
        _mapOrNull(command['persistentOptions']) ?? const <String, dynamic>{};
    final flags = {
      ...inheritedFlags,
      ...persistentFlags,
      ...?_mapOrNull(command['flags']),
    };
    final options = {
      ...inheritedOptions,
      ...persistentOptions,
      ...?_mapOrNull(command['options']),
    };
    final localAccessors = {
      for (final leaf in _accessorLeaves(_mapOrNull(command['accessors'])))
        leaf.path: leaf,
    };
    final accessors = {...inheritedAccessors, ...localAccessors};
    final lines = <String>[
      ..._nativeInputSets(path, flags, options, accessors),
      ..._nativeChildren(command, path),
      ..._nativePositionals(command, path),
      ..._nativeValueHandlers(path, options, accessors),
      ..._nativeVariadic(command, path),
    ];
    final descendantFlags = isRoot
        ? flags
        : {...inheritedFlags, ...persistentFlags};
    final descendantOptions = isRoot
        ? options
        : {...inheritedOptions, ...persistentOptions};
    final descendantAccessors = isRoot ? accessors : inheritedAccessors;
    for (final entry in children.entries) {
      final child = _map(entry.value);
      lines.addAll(
        _recurse(
          child,
          [...path, entry.key],
          descendantFlags,
          descendantOptions,
          descendantAccessors,
          isRoot: false,
        ),
      );
    }
    return lines;
  }

  // ---------------------------------------------------------------------
  // Runtime helpers
  // ---------------------------------------------------------------------

  List<String> _runtimeHelpers() {
    const helpers = r'''function Update-MambaStateObject {
    param(
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$Element
    )
    $extent = $Element.Extent
    if ($null -eq $extent) { return $false }
    if ($extent.StartOffset -ge $CursorPosition) { return $false }
    if ($extent.EndOffset -gt $CursorPosition) { return $false }
    return $true
}

function Find-MambaInput {
    param(
        [Parameter(Mandatory)][string]$PathKey,
        [Parameter(Mandatory)][string]$Spelling
    )
    $inputs = $script:MambaInputs[$PathKey]
    if ($null -eq $inputs) { return $null }
    foreach ($input in $inputs) {
        if ($input.Spelling -ceq $Spelling) { return $input }
    }
    return $null
}

function Resolve-MambaState {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$WordToComplete,
        [Parameter(Mandatory)][int]$CursorPosition,
        [Parameter(Mandatory)]$CommandAst
    )
    $resolved = @('root')
    $pendingValueOwner = $null
    $afterDoubleDash = $false
    $positionalIndex = -1
    $usedNonRepeatable = @{}
    $elements = @($CommandAst.CommandElements)
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if (-not (Update-MambaStateObject -CursorPosition $CursorPosition -Element $el)) { continue }
        $isLastElement = ($i -eq $elements.Count - 1)
        $tokenText = $el.Extent.Text
        # The last AST element is the completion word only while the cursor
        # is inside it or immediately after it; a trailing space means the
        # last element has already been supplied.
        $isWord = $isLastElement -and ($el.Extent.EndOffset -ge $CursorPosition)

        if ($isWord) { continue }

        # A value belongs to the preceding option even when it looks like a
        # command, another option, or the variadic separator.
        if ($null -ne $pendingValueOwner) {
            $usedNonRepeatable[$pendingValueOwner] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($afterDoubleDash) {
            $positionalIndex = $positionalIndex + 1
            continue
        }

        if ($tokenText -eq '--') {
            $afterDoubleDash = $true
            continue
        }

        $pathKey = $resolved -join '.'
        $children = @($script:MambaChildren[$pathKey])
        $canonical = $null
        foreach ($child in $children) {
            if ($child.Name -ceq $tokenText) {
                $canonical = $script:MambaNativeCommands[$child.Name]
                break
            }
        }
        if ($null -ne $canonical) {
            $resolved += ,$canonical
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('--', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 2) {
            $tail = $tokenText.Substring(2)
            if ($tail.Contains('=')) {
                $eqIndex = $tail.IndexOf('=')
                $owner = '--' + $tail.Substring(0, $eqIndex)
                $input = Find-MambaInput -PathKey $pathKey -Spelling $owner
                if ($null -ne $input -and -not $input.IsFlag) {
                    $usedNonRepeatable[$owner] = $true
                }
                continue
            }
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            $pendingValueOwner = $null
            continue
        }

        if ($tokenText.StartsWith('-', [System.StringComparison]::Ordinal) -and $tokenText.Length -gt 1) {
            $input = Find-MambaInput -PathKey $pathKey -Spelling $tokenText
            if ($null -ne $input -and -not $input.IsFlag) {
                $pendingValueOwner = $tokenText
                continue
            }
            $usedNonRepeatable[$tokenText] = $true
            continue
        }

        $positionalIndex = $positionalIndex + 1
    }

    return [PSCustomObject]@{
        ResolvedPath = $resolved
        PendingValueOwner = $pendingValueOwner
        AfterDoubleDash = $afterDoubleDash
        PositionalIndex = $positionalIndex
        UsedNonRepeatable = $usedNonRepeatable
        WordToComplete = $WordToComplete
    }
}

function Write-MambaCompletionResult {
    param(
        [Parameter(Mandatory)][string]$CompletionText,
        [Parameter(Mandatory)][string]$ListItemText,
        [Parameter(Mandatory)][string]$ResultType,
        [string]$Description
    )
    if ([string]::IsNullOrEmpty($Description)) { $Description = ' ' }
    [System.Management.Automation.CompletionResult]::new(
        $CompletionText,
        $ListItemText,
        $ResultType,
        $Description
    ) | Write-Output
}''';
    return [helpers.replaceAll('Mamba', _powerShellNamespace)];
  }

  // ---------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------

  List<String> _register(String rootName) {
    const body = r'''Register-ArgumentCompleter -Native -CommandName '__ROOT__' -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    try {
        $state = Resolve-MambaState -WordToComplete $wordToComplete -CursorPosition $cursorPosition -CommandAst $commandAst
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
        return
    }
    try {
        $pathKey = ($state.ResolvedPath -join '.')
        if ($state.AfterDoubleDash) {
            $handler = $script:MambaVariadicHandlers[$pathKey]
            if ($null -eq $handler) { return }
            $emit = $handler.Repeatable -or ($state.PositionalIndex -lt 0)
            if (-not $emit) { return }
            foreach ($choice in $handler.Choices) {
                if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                    Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                }
            }
            return
        }
        if ($null -ne $state.PendingValueOwner) {
            $handler = $script:MambaValueHandlers["$pathKey.$($state.PendingValueOwner)"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $currentWord = $state.WordToComplete
        if ($currentWord.StartsWith('--', [System.StringComparison]::Ordinal) -and $currentWord.Contains('=')) {
            $equalsIndex = $currentWord.IndexOf('=')
            $owner = $currentWord.Substring(0, $equalsIndex)
            $valuePrefix = $currentWord.Substring($equalsIndex + 1)
            $handler = $script:MambaValueHandlers["$pathKey.$owner"]
            if ($null -ne $handler) {
                foreach ($choice in $handler) {
                    if ($choice.StartsWith($valuePrefix, [System.StringComparison]::Ordinal)) {
                        $completionText = "$owner=$choice"
                        Write-MambaCompletionResult -CompletionText $completionText -ListItemText $completionText -ResultType 'ParameterValue' -Description ''
                    }
                }
            }
            return
        }
        $inputs = $script:MambaInputs[$pathKey]
        $wantLong = $currentWord.StartsWith('--', [System.StringComparison]::Ordinal)
        $wantShort = (-not $wantLong) -and $currentWord.StartsWith('-', [System.StringComparison]::Ordinal)
        if (($wantLong -or $wantShort) -and $null -ne $inputs) {
            foreach ($input in $inputs) {
                $spelling = $input.Spelling
                if ($wantLong -and -not $spelling.StartsWith('--', [System.StringComparison]::Ordinal)) { continue }
                if ($wantShort -and (-not $spelling.StartsWith('-', [System.StringComparison]::Ordinal) -or $spelling.StartsWith('--', [System.StringComparison]::Ordinal))) { continue }
                if (-not $spelling.StartsWith($currentWord, [System.StringComparison]::Ordinal)) { continue }
                if (-not $input.IsFlag -and -not $input.IsRepeatable -and -not $input.IsAccessor -and -not $input.IsHelp) {
                    if ($state.UsedNonRepeatable.ContainsKey($spelling)) { continue }
                }
                Write-MambaCompletionResult -CompletionText $spelling -ListItemText $spelling -ResultType 'ParameterName' -Description $input.Description
            }
        }
        if (-not $wantLong -and -not $wantShort) {
            $commands = $script:MambaChildren[$pathKey]
            if ($null -ne $commands) {
                foreach ($command in $commands) {
                    if ($command.Name.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                        Write-MambaCompletionResult -CompletionText $command.Name -ListItemText $command.Name -ResultType 'Command' -Description $command.Description
                    }
                }
            }
            $positionals = $script:MambaPositionalSlots[$pathKey]
            if ($null -ne $positionals) {
                $entry = $positionals[($state.PositionalIndex + 1)]
                if ($null -ne $entry) {
                    foreach ($choice in $entry.Choices) {
                        if ($choice.StartsWith($wordToComplete, [System.StringComparison]::Ordinal)) {
                            Write-MambaCompletionResult -CompletionText $choice -ListItemText $choice -ResultType 'ParameterValue' -Description $entry.Description
                        }
                    }
                }
            }
        }
    } catch {
        if ($env:MAMBA_COMPLETION_DEBUG) { Write-Error $_ }
    }
}''';
    return body
        .replaceAll('Mamba', _powerShellNamespace)
        .split('\n')
        .map((line) => line.replaceAll('__ROOT__', rootName))
        .toList();
  }

  // ---------------------------------------------------------------------
  // Lower-level utilities
  // ---------------------------------------------------------------------

  String _psQuote(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }

  String _psBool(bool value) => value ? r'$true' : r'$false';

  String _psQuoteOrNull(String? value) =>
      value == null ? r'$null' : _psQuote(value);

  String? _summary(Object? value) {
    if (value is! String) return null;
    if (value.isEmpty) return value;
    return value.split('\n').first;
  }

  List<String> _staticValuesFor(Map<String, dynamic> option) {
    return [
      ..._stringList(option['choices']),
      ..._integerRangeValues(option),
      ..._steppedDoubleValuesFromMap(option),
    ];
  }

  List<String> _integerRangeValues(Map<String, dynamic> option) {
    if (option['valueType'] != 'int') return const [];
    final min = option['min'];
    final max = option['max'];
    if (min is! int || max is! int) return const [];
    final size = max - min + 1;
    if (size <= 0 || size > _maxStaticRangeSize) return const [];
    return [for (var n = min; n <= max; n++) n.toString()];
  }

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  Map<String, dynamic>? _mapOrNull(Object? value) =>
      value is Map ? _map(value) : null;

  Iterable<_AccessorLeaf> _accessorLeaves(
    Map<String, dynamic>? accessors, {
    String parent = '',
    bool ancestorHidden = false,
  }) sync* {
    if (accessors == null) return;
    for (final entry in accessors.entries) {
      final value = _map(entry.value);
      final path = parent.isEmpty ? entry.key : '$parent.${entry.key}';
      if (value['kind'] == 'group') {
        final hidden = ancestorHidden || value['hidden'] == true;
        if (hidden) continue;
        yield* _accessorLeaves(
          _mapOrNull(value['options']),
          parent: path,
          ancestorHidden: hidden,
        );
        continue;
      }
      yield _AccessorLeaf(
        path: path,
        description: value['description'] as String?,
        choices: value['valueType'] == 'choice'
            ? _stringList(value['choices'])
            : const <String>[],
      );
    }
  }

  List<String> _stringList(Object? value) =>
      value is List ? value.cast<String>() : const [];
}

class _AccessorLeaf({
  required final String path,
  required final String? description,
  required final List<String> choices,
});

/// Writes a map-derived Carapace spec to the platform's spec directory.
///
/// Production writers use the operating system's Carapace configuration
/// directory. Development writers use a matching directory below the system
/// temp directory so local runs do not modify the user's installed specs.
final class CarapaceSpecWriter {
  new(this.converter, {this.development = false, String? outputPath})
    : path =
          outputPath ??
          _carapaceSpecPath(converter.registryMap.map['name'], development);

  final CarapaceSpecConverter converter;
  final bool development;
  final String path;

  /// Writes the converted registry map and returns the created file.
  File write() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(converter.convert());
      return file;
    } on FileSystemException catch (error) {
      throw MambaIntegrationException(
        'Unable to write Carapace spec to $path: ${error.message}',
      );
    }
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
      throw const MambaIntegrationException(
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
