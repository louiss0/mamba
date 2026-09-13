import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../fixtures/rig/rig.dart';

enum Mode { json, text }

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
      defaultValue: null,
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
    description: 'Manage releases.\nUse responsibly.',
    commands: [child],
    variadic: (
      description: 'Root files.',
      choices: const <String>[],
      defaultValue: null,
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
      (required: true, members: ['input', 'output']),
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
  group('completion converters', () {
    test('consume uniqueness metadata', () {
      final record = CommandRegistry.create(
        'tool',
        'Tool.',
        options: [
          RepeatableChoiceOption<Mode>('format', Mode.values, unique: true),
        ],
      ).toMap();
      expect(
        ToFishCompletionConverter(record).convert(),
        contains('__mamba_unique_choices format _ json text'),
      );
      expect(CarapaceSpecConverter(record).convert(), contains('format'));
    });

    test('render rich command metadata for every shell', () {
      final record = _complexRecord();
      final bash = ToBashCompletionConverter(record).convert();
      final zsh = ToZshCompletionConverter(record).convert();
      final fish = ToFishCompletionConverter(record).convert();
      final powerShell = ToPowerShellCompletionConverter(record).convert();

      expect(bash, allOf(contains('--no-colour'), contains("'0.1'")));
      expect(bash, contains('_mamba_tool_deploy_status_completion'));
      expect(
        zsh,
        allOf(
          contains("'--no-colour[Use colour.]'"),
          contains('_numbers -l 1 -m 3'),
        ),
      );
      expect(zsh, contains("'1:workspace:(core docs)'"));
      expect(fish, contains("complete -c mamba-tool -s C -l colour"));
      expect(fish, contains('__mamba_unique_choices format F json text'));
      expect(fish, isNot(contains('-l internal.token')));
      expect(powerShell, contains("'ship' = 'deploy'"));
      expect(powerShell, contains("'root.deploy.--ratio'"));
      expect(powerShell, contains("'0.5'"));
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
    test('maps paired, grouped, persistent, and accessor inputs', () {
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
    test('checked-in rig completions match generated artifacts', () {
      expect(RigCommand.format.isRequired, isTrue);
      final record = CommandRegistry.create(
        'rig',
        'Completion fixture.',
        options: [RigCommand.format],
      ).toMap();
      expect(record.options?.first.required, isTrue);
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
          reason: 'Regenerate fixtures/rig/completions/${entry.key}.',
        );
      }
    });
  });
}
