import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../fixtures/rig/rig.dart';
import 'fixtures.dart';
import 'shell_support.dart';

enum Mode { json, text }

enum const FishLiteral(@override final String value) implements MambaEnumValue {
  newline('one\ntwo'),
  dashNewline('--one\ntwo'),
  tab('one\ttwo'),
  ordinary('plain'),
}

/// Decodes Fish's public single-quoted argument syntax, not generator tables.
(String, int) _fishQuoted(String script, int start) {
  final value = StringBuffer();
  var index = start + 1;
  while (index < script.length) {
    final char = script[index++];
    if (char == "'") return (value.toString(), index);
    if (char == r'\' &&
        index < script.length &&
        (script[index] == r'\' || script[index] == "'")) {
      value.write(script[index++]);
    } else {
      value.write(char);
    }
  }
  throw FormatException('Unclosed Fish string literal');
}

final first = BooleanFlag('first');
final second = BooleanFlag('second');

/// The parse errors PowerShell's own parser reports for [script].
///
/// Returns null when no PowerShell is installed, so the check runs wherever a
/// shell exists and skips itself elsewhere instead of failing the build.
List<String>? _parseErrorsInPowerShell(String script) {
  final shell = _powershellShell();
  if (shell == null) return null;
  final file = File(
    '${Directory.systemTemp.path}/mamba-completion-${DateTime.now().microsecondsSinceEpoch}.ps1',
  );
  try {
    file.writeAsStringSync(script);
    final escaped = file.path.replaceAll("'", "''");
    final result = Process.runSync(shell, [
      '-NoProfile',
      '-Command',
      "\$e = \$null; "
          '[void][System.Management.Automation.Language.Parser]::'
          "ParseFile('$escaped', [ref]\$null, [ref]\$e); "
          r'$e | ForEach-Object { $_.Message }',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return '${result.stdout}'
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

String? _powershellShell() => firstShellOnPath(['pwsh', 'powershell.exe']);

final class _TestDirectory extends Mock implements Directory;

final class _TestFile extends Mock implements File;

RegistryFlag _flag(
  String name, {
  String? short,
  bool? defaultValue,
  bool? negatable,
  bool hidden = false,
  String? description,
}) => (
  name: name,
  short: short,
  defaultValue: defaultValue,
  negatable: negatable,
  hidden: hidden,
  description: description,
);

RegistryOption _option(
  String name, {
  String? short,
  bool required = false,
  bool hidden = false,
  String? description,
  String valueType = 'string',
  bool? repeatable,
  bool? unique,
  List<String>? choices,
  String? defaultValue,
  String? pattern,
  num? min,
  num? max,
  num? step,
  List<String>? pairedOptions,
}) => (
  name: name,
  short: short,
  required: required,
  hidden: hidden,
  description: description,
  valueType: valueType,
  repeatable: repeatable,
  unique: unique,
  choices: choices,
  defaultValue: defaultValue,
  pattern: pattern,
  min: min,
  max: max,
  step: step,
  pairedOptions: pairedOptions,
);

RegistryRecord _complexRecord() {
  final persistentFlags = [
    _flag(
      'verbose',
      short: 'v',
      defaultValue: false,
      negatable: true,
      description: 'Write extra detail.',
    ),
  ];
  final persistentOptions = [
    _option(
      'config',
      short: 'c',
      description: 'Configuration file.',
      defaultValue: 'mamba.yaml',
    ),
  ];
  final child = RegistryCommand(
    name: 'deploy',
    description: 'Deploy a release.\nWith care.',
    aliases: ['ship'],
    flags: [
      _flag('force', short: 'f', defaultValue: true, description: 'Force it.'),
      _flag('attempts', short: 'a', description: 'Count attempts.'),
      _flag('private', hidden: true, description: 'Do not show.'),
    ],
    persistentFlags: persistentFlags,
    options: [
      _option(
        'region',
        short: 'r',
        required: true,
        description: 'Release region.',
        valueType: 'choice',
        choices: ['eu', 'us'],
      ),
      _option(
        'retries',
        description: 'Retry count.',
        valueType: 'int',
        min: 1,
        max: 3,
      ),
      _option(
        'ratio',
        description: 'Rollout ratio.',
        valueType: 'double',
        min: 0.0,
        max: 1.0,
        step: 0.5,
      ),
    ],
    persistentOptions: persistentOptions,
    positionals: [
      (
        name: 'target',
        required: true,
        description: 'Target environment.',
        choices: ['stage', 'production'],
        defaultValue: null,
        repeatable: true,
        times: 1,
        pattern: null,
      ),
      (
        name: 'note',
        required: false,
        description: null,
        choices: null,
        defaultValue: null,
        repeatable: null,
        times: null,
        pattern: null,
      ),
    ],
    variadic: (
      description: 'Files to deploy.',
      choices: ['one.dart', 'two.dart'],
      pattern: null,
    ),
    accessors: [
      RegistryAccessor.group(
        name: 'remote',
        hidden: false,
        description: 'Remote configuration.',
        options: [
          RegistryAccessor.value(
            name: 'kind',
            valueType: 'choice',
            description: 'Remote kind.',
            choices: ['ssh', 'https'],
          ),
        ],
      ),
      RegistryAccessor.group(
        name: 'internal',
        hidden: true,
        options: [
          RegistryAccessor.value(
            name: 'token',
            valueType: 'string',
            description: 'Internal token.',
          ),
        ],
      ),
    ],
    commands: [
      RegistryCommand(
        name: 'status',
        description: 'Show deployment status.',
        aliases: ['state'],
        options: [_option('watch', description: 'Watch for changes.')],
      ),
    ],
  );

  return (
    name: 'mamba-tool',
    conflicts: const {},
    defaultCommandPath: null,
    description: 'Manage releases.\nUse responsibly.',
    commands: [child],
    variadic: (
      description: 'Root files.',
      choices: const <String>[],
      pattern: null,
    ),
    positionals: [
      (
        name: 'workspace',
        required: true,
        description: 'Workspace name.',
        choices: ['core', 'docs'],
        defaultValue: null,
        repeatable: false,
        times: null,
        pattern: null,
      ),
    ],
    flags: [
      _flag(
        'colour',
        short: 'C',
        defaultValue: true,
        negatable: true,
        description: 'Use colour.',
      ),
      _flag('quiet', short: 'q', description: 'Reduce output.'),
      _flag('plain', description: 'Use the default mode.'),
      _flag('hidden-flag', hidden: true, description: 'Do not show.'),
    ],
    persistentFlags: persistentFlags,
    options: [
      _option(
        'format',
        short: 'F',
        required: true,
        description: 'Output format.',
        valueType: 'choice',
        repeatable: true,
        unique: true,
        choices: ['json', 'text'],
      ),
      _option(
        'limit',
        short: 'l',
        description: 'Result limit.',
        valueType: 'int',
        min: 1,
        max: 3,
      ),
      _option(
        'scale',
        description: 'Scale factor.',
        valueType: 'double',
        min: 0.1,
        max: 0.3,
        step: 0.1,
      ),
      _option('path', description: 'Source path.', defaultValue: 'src'),
      _option('hidden-option', hidden: true, description: 'Do not show.'),
      _option(
        'credentials',
        required: true,
        description: 'Credential pair.',
        pairedOptions: ['secret'],
      ),
      _option('secret', hidden: true, description: 'Credential secret.'),
      _option('json', description: 'JSON mode.', valueType: 'choice'),
      _option('text', description: 'Text mode.', valueType: 'choice'),
      _option('input', description: 'Input file.', valueType: 'choice'),
      _option('output', description: 'Output file.', valueType: 'choice'),
    ],
    persistentOptions: persistentOptions,
    optionGroups: [
      (required: true, single: false, members: ['input', 'output']),
    ],
    accessors: [
      RegistryAccessor.group(
        name: 'network',
        hidden: false,
        description: 'Network settings.',
        options: [
          RegistryAccessor.value(
            name: 'protocol',
            valueType: 'choice',
            description: 'Network protocol.',
            choices: ['http', 'https'],
            defaultValue: 'https',
          ),
        ],
      ),
    ],
  );
}

RegistryRecord _emptyRecord() => (
  name: 'empty',
  conflicts: const {},
  defaultCommandPath: null,
  description: 'Empty command.',
  commands: null,
  variadic: null,
  positionals: null,
  flags: null,
  persistentFlags: null,
  options: null,
  persistentOptions: null,
  optionGroups: null,
  accessors: null,
);

void main() {
  test('Fish static choices preserve newlines and omit native tab-description values', () {
    final option = RepeatableChoiceOption(
      'format',
      FishLiteral.values,
      unique: true,
    );
    final registry = CommandRegistry.create(
      'probe',
      'Literal choices.',
      options: [option],
    );
    final script = ToFishCompletionConverter(registry.toRecord()).convert();
    final candidates = <String>{};
    for (final match in RegExp("\\s-a\\s+'").allMatches(script)) {
      final (argument, _) = _fishQuoted(script, match.end - 1);
      if (argument.startsWith("'")) candidates.add(_fishQuoted(argument, 0).$1);
    }
    expect(candidates, {'one\ntwo', '--one\ntwo', 'plain'});
    expect(Parser(registry).parse(['--format=one\ttwo']).$2(option), [
      FishLiteral.tab,
    ]);
    expect(script, isNot(contains('one\ttwo')));
    for (final candidate in candidates) {
      expect(
        () => Parser(registry).parse(['--format=$candidate']),
        returnsNormally,
      );
    }
  });
  test('Fish static choices with short option cover short alias branch', () {
    final option = RepeatableChoiceOption(
      'format',
      FishLiteral.values,
      unique: true,
      short: 'f',
    );
    final registry = CommandRegistry.create(
      'probe',
      'Literal choices.',
      options: [option],
    );
    final script = ToFishCompletionConverter(registry.toRecord()).convert();
    expect(script, contains('-s f'));
    expect(script, isNot(contains('one\ttwo')));
  });
  test('Fish omits native tab-description choices across named, accessor, positional and trailing shapes', () {
    final record = CommandRegistry.create(
      'probe',
      'Tabs.',
      options: [
        ChoiceOption('format', choices: [FishLiteral.tab]),
      ],
      accessors: [
        AccessorListOption('settings', [
          AccessorChoiceOption('format', choices: [FishLiteral.tab]),
        ]),
      ],
      variadic: ChoiceVariadic(choices: [FishLiteral.tab]),
      commands: [
        TestCommand(
          'run',
          'Run.',
          mandatoryPositionals: [
            ChoicePositional('format', choices: [FishLiteral.tab]),
          ],
        ),
      ],
    ).toRecord();
    final script = ToFishCompletionConverter(record).convert();
    expect(script, isNot(contains('one\ttwo')));
    expect(record.options!.single.choices, ['one\ttwo']);
    expect(record.variadic!.choices, ['one\ttwo']);
    expect(record.commands!.single.positionals!.single.choices, ['one\ttwo']);
  });
  test('finite decimal artifacts contain only parser-accepted candidates in every converter', () {
    for (final (option, expected) in [
      (
        DoubleOption('ratio', min: 0, max: 1, step: 0.3),
        ['0.0', '0.3', '0.6', '0.9'],
      ),
      (
        DoubleOption('tiny', min: 1e-7, max: 3e-7, step: 1e-7),
        ['0.0000001', '0.0000002', '0.0000003'],
      ),
      (DoubleOption('shifted', min: 1, max: 1.0000002, step: 1e-7), ['1.0']),
    ]) {
      final registry = CommandRegistry.create(
        'probe',
        'Finite decimals.',
        options: [option],
      );
      final record = registry.toRecord();
      for (final converter in [
        ToBashCompletionConverter(record),
        ToZshCompletionConverter(record),
        ToFishCompletionConverter(record),
        ToPowerShellCompletionConverter(record),
        CarapaceSpecConverter(record),
      ]) {
        // With one numeric declaration, standalone quoted decimals are its
        // static value literals. Fish additionally escapes their closing quote
        // inside the complete argument. Decode the logical numeric text without
        // depending on generated handler names, arrays, or table layouts.
        final candidates = RegExp(r'''(["'])([+-]?[0-9]+\.[0-9]+)(?:\\)?\1''')
            .allMatches(converter.convert())
            .map((match) => match.group(2)!)
            .toSet();
        expect(
          candidates,
          unorderedEquals(expected),
          reason: '${converter.runtimeType}: ${option.name}',
        );
        for (final candidate in candidates) {
          expect(
            () => Parser(registry).parse(['--${option.name}=$candidate']),
            returnsNormally,
            reason: '${converter.runtimeType}: $candidate',
          );
        }
      }
    }
  });
  test(
    'static decimal candidates reject invalid manually assembled ranges',
    () {
      final RegistryRecord record = (
        name: 'app',
        description: 'App.',
        conflicts: const {},
        defaultCommandPath: null,
        commands: null,
        variadic: null,
        positionals: null,
        flags: null,
        persistentFlags: null,
        persistentOptions: null,
        optionGroups: null,
        accessors: null,
        options: [
          _option(
            'ratio',
            valueType: 'double',
            min: 0,
            max: 1,
            step: double.nan,
          ),
        ],
      );
      for (final converter in [
        ToBashCompletionConverter(record),
        ToZshCompletionConverter(record),
        ToFishCompletionConverter(record),
        ToPowerShellCompletionConverter(record),
        CarapaceSpecConverter(record),
      ]) {
        expect(converter.convert, throwsA(isA<MambaIntegrationException>()));
      }
    },
  );
  test(
    'required accessor metadata and hidden containers survive flattening',
    () {
      final record = CommandRegistry.create(
        'probe',
        'Accessors.',
        accessors: [
          AccessorListOption('config', [AccessorStringOption.required('host')]),
          AccessorListOption('secret', [
            AccessorStringOption('token'),
          ], hidden: true),
        ],
      ).toRecord();
      expect(
        CarapaceSpecConverter(record).convert(),
        contains('config.host!='),
      );
      expect(
        CarapaceSpecConverter(record).convert(),
        contains('--secret.token?&='),
      );
      for (final converter in <RegistryRecordConverter>[
        ToBashCompletionConverter(record),
        ToZshCompletionConverter(record),
        ToFishCompletionConverter(record),
        ToPowerShellCompletionConverter(record),
      ]) {
        expect(converter.convert(), isNot(contains('--secret.token')));
      }
    },
  );
  group('completion converters', () {
    test('carries a selected group and whether it is exclusive', () {
      final record = CommandRegistry.create(
        'tool',
        'Tool.',
        selectedOptions: [
          SelectedOptions<String>([
            PairStringOption('json'),
            PairStringOption('text'),
          ]),
          SelectedOptions<String>.required([
            PairStringOption('all'),
            PairStringOption('none'),
          ], single: true),
        ],
      ).toRecord();

      expect(
        record.optionGroups!.map((group) => (group.required, group.single)),
        [(false, false), (true, true)],
      );
      expect(record.optionGroups!.map((group) => group.members), [
        ['json', 'text'],
        ['all', 'none'],
      ]);
      expect(record.options!.map((option) => option.pairedOptions), [
        <String>[],
        <String>[],
        <String>[],
        <String>[],
      ]);
      expect(() => record.optionGroups!.clear(), throwsUnsupportedError);
      expect(
        () => record.optionGroups!.first.members.clear(),
        throwsUnsupportedError,
      );
    });

    test('consume uniqueness metadata', () {
      final record = CommandRegistry.create(
        'tool',
        'Tool.',
        options: [
          RepeatableChoiceOption<Mode>('format', Mode.values, unique: true),
        ],
      ).toRecord();
      expect(
        ToFishCompletionConverter(record).convert(),
        contains('__mamba_unique_choices format _ json text'),
      );
      expect(CarapaceSpecConverter(record).convert(), contains('format'));
    });

    test('keep distinct names in distinct generated identifiers', () {
      final record = CommandRegistry.create(
        'probe',
        'Collision probe.',
        commands: [
          TestCommand('foo-bar', 'Hyphenated.', flags: [first]),
          TestCommand('foo_bar', 'Underscored.', flags: [second]),
        ],
      ).toRecord();

      final bash = ToBashCompletionConverter(record).convert();

      expect(bash, contains('--first'));
      expect(bash, contains('--second'));
      final identifiers = RegExp(r'_probe_foo_(2D|5F)bar_completion')
          .allMatches(bash)
          .map((match) => match.group(0))
          .toSet();
      expect(identifiers, hasLength(2), reason: bash);
    });

    test('give every generated PowerShell script a parsable syntax', () {
      final record = CommandRegistry.create(
        'probe',
        'Scoped names.',
        commands: [
          TestGroupCommand('admin', [
            TestCommand('status', 'Show admin status.', aliases: ['st']),
          ], 'Admin.'),
          TestGroupCommand('server', [
            TestCommand('status', 'Show server status.', aliases: ['st']),
          ], 'Server.'),
        ],
      ).toRecord();

      final script = ToPowerShellCompletionConverter(record).convert();

      final errors = _parseErrorsInPowerShell(script);
      if (errors != null) expect(errors, isEmpty);
    }, skip: _powershellShell() == null ? 'PowerShell is not installed' : null);

    test('keep nested paths whose flattened identifiers could collide', () {
      final record = CommandRegistry.create(
        'probe',
        'Nested collisions.',
        commands: [
          TestGroupCommand('a-b', [
            TestCommand('c', 'Leaf of a-b.'),
          ], 'Group a-b.'),
          TestGroupCommand('a', [TestCommand('b-c', 'Leaf of a.')], 'Group a.'),
        ],
      ).toRecord();

      final bash = ToBashCompletionConverter(record).convert();

      expect(
        bash,
        allOf(
          contains('_probe_a_2Db_c_completion'),
          contains('_probe_a_b_2Dc_completion'),
        ),
      );
    });

    test('read one integer syntax in every input shape', () {
      final pair = PairedOptions<int>([
        PairIntOption('host'),
        PairIntOption('port'),
      ]);
      final registry = CommandRegistry.create(
        'probe',
        'Integer shapes.',
        options: [RepeatableIntOption('retries'), IntOption('count')],
        pairedOptions: [pair],
        accessors: [
          AccessorListOption('limits', [AccessorIntOption.required('max')]),
        ],
      );

      for (final args in [
        ['--retries', '0x10'],
        ['--retries=0x10'],
        ['--count', '0x10'],
        ['--host', '0x10', '--port', '80'],
        ['--limits.max', '0x10'],
      ]) {
        expect(
          () => Parser(registry).parse(args),
          throwsA(
            isA<MambaParseException>().having(
              (error) => error.message,
              'message',
              contains('must be a signed decimal integer'),
            ),
          ),
          reason: 'accepted $args',
        );
      }
    });

    test('tell an unsupported bash why the completion cannot load', () {
      final script = ToBashCompletionConverter(_complexRecord()).convert();

      expect(script, contains(r'((BASH_VERSINFO[0] < 4))'));
      expect(
        script,
        contains('mamba-tool: completion requires bash 4 or newer'),
      );
      expect(
        script.indexOf('BASH_VERSINFO'),
        lessThan(script.indexOf('declare -A')),
        reason: 'the guard has to run before anything the old bash rejects',
      );
    });

    test('render rich command metadata for every shell', () {
      final record = _complexRecord();
      final bash = ToBashCompletionConverter(record).convert();
      final zsh = ToZshCompletionConverter(record).convert();
      final fish = ToFishCompletionConverter(record).convert();
      final powerShell = ToPowerShellCompletionConverter(record).convert();

      expect(bash, allOf(contains('--no-colour'), contains("'0.1'")));
      expect(bash, contains('_mamba_2Dtool_deploy_status_completion'));
      expect(
        zsh,
        allOf(
          contains("'--no-colour[Use colour.]'"),
          contains('_numbers -l 1 -m 3'),
        ),
      );
      expect(zsh, contains("'1:workspace:"));
      expect(zsh, contains("compadd -- 'core' 'docs'"));
      expect(fish, contains("complete -c mamba-tool -s C -l colour"));
      expect(fish, contains('__mamba_unique_choices format F json text'));
      expect(fish, isNot(contains('-l internal.token')));
      expect(
        powerShell,
        allOf(contains("Name = 'ship'"), contains("Canonical = 'deploy'")),
      );
      expect(powerShell, contains("'root.deploy.--ratio'"));
      expect(powerShell, contains("'0.5'"));
    });

    test('respects repeated positional maximum in every shell', () {
      final record = _complexRecord();
      final bash = ToBashCompletionConverter(record).convert();
      final zsh = ToZshCompletionConverter(record).convert();
      final fish = ToFishCompletionConverter(record).convert();
      final powerShell = ToPowerShellCompletionConverter(record).convert();
      final carapace = CarapaceSpecConverter(record).convert();
      expect(bash, contains('    0)'));
      expect(bash, isNot(contains('    0|1)')));
      expect(zsh, contains("'1:target:"));
      expect(zsh, isNot(contains("'2:target:")));
      expect(fish, contains('__mamba_positional_slot 0'));
      expect(fish, isNot(contains('__mamba_positional_slot 1')));
      expect(powerShell, contains('    0 = [PSCustomObject]@{'));
      expect(powerShell, isNot(contains('    1 = [PSCustomObject]@{')));
      expect(RegExp(r'- - "stage"').allMatches(carapace), hasLength(1));
    });

    test('render empty command records', () {
      final record = _emptyRecord();

      expect(
        ToBashCompletionConverter(record).convert(),
        contains('complete -F _empty_completion empty'),
      );
      expect(
        ToZshCompletionConverter(record).convert(),
        contains('compdef _empty empty'),
      );
      expect(
        ToFishCompletionConverter(record).convert(),
        contains('# Completion for empty: Empty command.'),
      );
      expect(
        ToPowerShellCompletionConverter(record).convert(),
        contains("-CommandName 'empty'"),
      );
    });
  });

  group('Carapace conversion', () {
    test('does not require every member of a required selected group', () {
      final record = CommandRegistry.create(
        'tool',
        'Tool.',
        pairedOptions: [
          PairedOptions<String>.required([
            PairStringOption('host'),
            PairStringOption('port'),
          ]),
        ],
        selectedOptions: [
          SelectedOptions<String>.required([
            PairStringOption('json'),
            PairStringOption('text'),
          ], single: true),
          SelectedOptions<String>.required([
            PairStringOption('log'),
            PairStringOption('report'),
          ]),
        ],
      ).toRecord();
      final completion = CarapaceSpecConverter(record).convert();

      expect(completion, contains('--host!='));
      expect(completion, contains('--port!='));
      for (final name in ['json', 'text', 'log', 'report']) {
        expect(completion, contains('--$name?='));
        expect(completion, isNot(contains('--$name!=')));
      }
    });
    test('uses times as the maximum number of positional slots', () {
      final completion = CarapaceSpecConverter(_complexRecord()).convert();
      expect(RegExp(r'- - "stage"').allMatches(completion), hasLength(1));
      expect(completion, contains('        - []'));
    });
    test('maps paired, grouped, persistent, and accessor valueOf', () {
      final completion = CarapaceSpecConverter(_complexRecord()).convert();

      expect(completion, contains('persistentflags:'));
      expect(completion, contains('--no-colour'));
      expect(completion, contains('--credentials!='));
      expect(completion, contains('--secret!='));
      expect(completion, contains('--input!='));
      expect(completion, contains('network.protocol'));
      expect(
        completion,
        contains(r'$carapace.number.Range({start: 1, end: 3})'),
      );
      expect(completion, contains('dashany:'));
    });
  });

  group('Carapace spec writer', () {
    test('resolves both development and platform spec paths', () {
      final converter = CarapaceSpecConverter(_emptyRecord());
      final development = CarapaceSpecWriter(converter, development: true);
      final platform = CarapaceSpecWriter(converter);

      expect(
        development.path,
        contains(
          '${Platform.pathSeparator}carapace${Platform.pathSeparator}specs${Platform.pathSeparator}empty.yaml',
        ),
      );
      expect(platform.path, endsWith('${Platform.pathSeparator}empty.yaml'));
    });

    test('writes a spec through the file-system boundary', () {
      final directory = _TestDirectory();
      final file = _TestFile();
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(_emptyRecord()),
        outputPath: 'nested${Platform.pathSeparator}empty.yaml',
      );
      when(() => file.parent).thenReturn(directory);
      when(() => directory.createSync(recursive: true)).thenReturn(null);
      when(() => file.writeAsStringSync(any())).thenReturn(null);

      String? createdPath;
      final written = IOOverrides.runZoned(
        writer.write,
        createFile: (path) {
          createdPath = path;
          return file;
        },
      );

      expect(createdPath, 'nested${Platform.pathSeparator}empty.yaml');
      expect(written, same(file));
      verify(() => directory.createSync(recursive: true)).called(1);
      final content =
          verify(() => file.writeAsStringSync(captureAny())).captured.single
              as String;
      expect(content, contains('name: "empty"'));
    });

    test('wraps file-system failures in an integration exception', () {
      final directory = _TestDirectory();
      final file = _TestFile();
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(_emptyRecord()),
        outputPath: 'nested${Platform.pathSeparator}empty.yaml',
      );
      when(() => file.parent).thenReturn(directory);
      when(() => directory.createSync(recursive: true))
          .thenThrow(FileSystemException('cannot create directory'));

      String? createdPath;
      expect(
        () => IOOverrides.runZoned(
          writer.write,
          createFile: (path) {
            createdPath = path;
            return file;
          },
        ),
        throwsA(isA<MambaIntegrationException>()),
      );
      expect(createdPath, 'nested${Platform.pathSeparator}empty.yaml');
    });
  });

  group('completion fixtures', () {
    test('the checked-in PowerShell fixture parses', () {
      final checkedIn = File('fixtures/rig/completions/rig.ps1')
          .readAsStringSync();
      final errors = _parseErrorsInPowerShell(checkedIn);

      if (errors != null) expect(errors, isEmpty);
    }, skip: _powershellShell() == null ? 'PowerShell is not installed' : null);

    test('checked-in rig completions match generated artifacts', () {
      final record = CommandRegistry.create(
        'rig',
        'Completion fixture.',
        commands: [RigCommand()],
      ).toRecord();

      // The fixtures only earn their keep if the record is a real one, so the
      // shapes every converter has to render are asserted before comparing.
      final root = record.commands!.single;
      expect(root.name, 'rig');
      final deploy = root.commands!.singleWhere((c) => c.name == 'deploy');
      expect(root.commands!.map((command) => command.name), [
        'deploy',
        'status',
      ]);
      expect(
        deploy.options!.where((option) => option.required).map((o) => o.name),
        containsAll(['format', 'token']),
      );
      expect(
        deploy.options!
            .where((option) => option.repeatable == true)
            .map((o) => o.name),
        ['tag'],
      );
      expect(
        deploy.flags!.where((flag) => flag.hidden).map((flag) => flag.name),
        ['quiet'],
      );
      // Both kinds of group reach `optionGroups`, so a selected group no longer
      // arrives as members that happen to be independent.
      expect(deploy.optionGroups!.map((group) => group.members), [
        ['host', 'port'],
        ['log', 'report'],
      ]);
      expect(
        deploy.options!.map((option) => option.name),
        containsAll(['log', 'report']),
      );
      expect(deploy.accessors!.map((accessor) => accessor.name), ['database']);
      expect(deploy.variadic, isNotNull);
      expect(
        root.commands!
            .singleWhere((c) => c.name == 'status')
            .positionals!
            .single
            .times,
        3,
      );

      final completions = <String, String>{
        'rig.bash': ToBashCompletionConverter(record).convert(),
        '_rig': ToZshCompletionConverter(record).convert(),
        'rig.fish': ToFishCompletionConverter(record).convert(),
        'rig.ps1': ToPowerShellCompletionConverter(record).convert(),
        'rig.yaml': CarapaceSpecConverter(record).convert(),
      };
      for (final entry in completions.entries) {
        expect(
          File('fixtures/rig/completions/${entry.key}').readAsStringSync(),
          entry.value,
          reason:
              'Run `dart run tool/regenerate_fixtures.dart` to refresh '
              'fixtures/rig/completions/${entry.key}.',
        );
      }
    });
  });
}
