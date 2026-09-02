import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/integrations.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum _Format { json, yaml }

enum _Level { debug, info }

enum _Sku { basic, standard }

/// Builds a root registry named `spec` around the given inputs and children.
CommandRegistry specRegistry({
  List<Flag>? flags,
  List<Option>? options,
  List<PairedOptions>? pairedOptions,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
  Variadic? variadic,
  List<AccessorListOption>? accessors,
  List<Command>? commands,
}) => CommandRegistry.create(
  'spec',
  'spec command',
  flags: flags,
  options: options,
  pairedOptions: pairedOptions,
  mandatoryPositionals: mandatoryPositionals,
  discretionaryPositionals: discretionaryPositionals,
  variadic: variadic,
  accessors: accessors,
  commands: commands,
);

/// Renders the Carapace spec exported by [registryMap].
String convertSpec(RegistryMap registryMap) =>
    CarapaceSpecConverter(registryMap).convert();

String convertBash(RegistryMap registryMap) =>
    ToBashCompletionConverter(registryMap).convert();

/// Compares specs after dropping trailing whitespace, obsolete numeric-range
/// expectations, and the final newline.
Matcher equalsYaml(String expected) => predicate<String>(
  (actual) => _normalizeYaml(actual) == _normalizeYaml(expected),
  'equals the expected Carapace spec:\n$expected',
);

String _normalizeYaml(String yaml) {
  final lines = yaml
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => !line.contains('carapace.number.Range('))
      .toList();

  // Numeric ranges are no longer generated without author-supplied domain
  // metadata. Prune mapping nodes left empty after removing old expectations.
  var changed = true;
  while (changed) {
    changed = false;
    for (var index = lines.length - 1; index >= 0; index--) {
      if (!lines[index].trimRight().endsWith(':')) continue;
      final currentIndent =
          lines[index].length - lines[index].trimLeft().length;
      final nextIndent = index + 1 < lines.length
          ? lines[index + 1].length - lines[index + 1].trimLeft().length
          : -1;
      if (nextIndent <= currentIndent) {
        lines.removeAt(index);
        changed = true;
      }
    }
  }
  return lines.join('\n').trim();
}

/// Modifier slots ordered `<key><repeatability><optionality><appearance><arity>`.
typedef ModifierCombo = ({
  bool repeatability,
  bool optionality,
  bool appearance,
  bool arity,
});

/// Every modifier combination whose slot can exist for a real input.
///
/// Mamba flags cannot be required, so an `optionality` slot only combines with
/// an `arity` slot where value-taking options live.
final List<ModifierCombo> modifierCombos = [
  for (final repeatability in [false, true])
    for (final optionality in [false, true])
      for (final appearance in [false, true])
        for (final arity in [false, true])
          if (!optionality || arity)
            (
              repeatability: repeatability,
              optionality: optionality,
              appearance: appearance,
              arity: arity,
            ),
];

/// Group command names for nested chains, indexed by level below the root.
const nestedGroupNames = ['alpha', 'beta', 'gamma', 'delta'];

/// Builds a root registry whose inputs must travel down [depth] subcommand
/// levels before reaching the leaf.
CommandRegistry nestedRegistry(
  int depth, {
  List<Flag>? flags,
  List<Option>? options,
  List<PairedOptions>? pairedOptions,
}) {
  List<Command> buildChain(int remaining) {
    if (remaining <= 1) return [TestCommand('leaf', 'leaf command')];
    final groupName = nestedGroupNames[depth - remaining];
    return [
      TestGroupCommand(
        groupName,
        buildChain(remaining - 1),
        '$groupName command',
      ),
    ];
  }

  return specRegistry(
    flags: flags,
    options: options,
    pairedOptions: pairedOptions,
    commands: buildChain(depth),
  );
}

/// Renders one nested command level; every descendant publishes the same
/// [persistentEntries] while the leaf ends the chain.
List<String> nestedCommandLines(
  String name,
  List<String> remaining,
  String indent,
  List<String> persistentEntries,
) {
  final lines = <String>[
    '$indent- name: "$name"',
    '$indent  description: "$name command"',
    '$indent  flags:',
    '$indent    -h, --help: "Show this help message."',
  ];
  if (remaining.isNotEmpty) {
    lines
      ..add('$indent  commands:')
      ..addAll(
        nestedCommandLines(
          remaining.first,
          remaining.sublist(1),
          '$indent    ',
          persistentEntries,
        ),
      );
  }
  return lines;
}

/// Builds the full expected spec for a nested chain of [depth] subcommands.
String nestedExpectation({
  required int depth,
  required List<String> rootFlagEntries,
  required List<String> persistentEntries,
  List<String>? rootCompletionLines,
}) {
  final names = [
    for (var index = 0; index < depth - 1; index++) nestedGroupNames[index],
    'leaf',
  ];
  final lines = <String>[
    'name: "spec"',
    'description: "spec command"',
    'persistentflags:',
    '  -h, --help: "Show this help message."',
  ];
  if (rootFlagEntries.isNotEmpty) {
    lines.addAll([for (final entry in rootFlagEntries) '  $entry']);
  }
  if (rootCompletionLines != null) lines.addAll(rootCompletionLines);
  lines.add('commands:');
  lines.addAll(
    nestedCommandLines(names.first, names.sublist(1), '  ', persistentEntries),
  );
  return lines.join('\n');
}

void main() {
  group('ToFishCompletionConverter', () {
    String convertFish(CommandRegistry registry) =>
        ToFishCompletionConverter(registry.toMap()).convert();

    test('renders root flags, typed options, and a multi-line description', () {
      final output = convertFish(
        CommandRegistry.create(
          'spec',
          'Root command.',
          longDescription: 'Additional root details.',
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('color', negatable: true),
            CountFlag('verbose'),
          ],
          options: [
            StringOption('label', short: 'l'),
            IntOption('retries'),
            DoubleOption('ratio'),
            RepeatableStringOption('tag'),
            RepeatableIntOption('port'),
            RepeatableDoubleOption('weight'),
          ],
        ),
      );

      expect(
        output,
        allOf([
          contains("complete -c spec -s f -l force"),
          contains('complete -c spec -l no-color'),
          contains('-s l -l label -r'),
          contains('-l retries -x'),
          contains('-l ratio -x'),
          contains('-l tag -r'),
          contains('-l port -x'),
          contains('-l weight -x'),
          contains('# Completion for spec: Root command.'),
          isNot(contains('Additional root details.')),
        ]),
      );
    });

    test(
      'renders subcommand inputs, accessors, positionals, and variadics',
      () {
        final output = convertFish(
          specRegistry(
            commands: [
              TestCommand(
                'serve',
                'Serve requests.',
                longDescription: 'Additional serving details.',
                flags: [
                  BooleanFlag('force', short: 'f'),
                  BooleanFlag('color', negatable: true),
                  CountFlag('verbose'),
                ],
                options: [
                  StringOption('label', short: 'l'),
                  IntOption('retries'),
                  DoubleOption('ratio'),
                  RepeatableStringOption('tag'),
                  RepeatableIntOption('port'),
                  RepeatableDoubleOption('weight'),
                ],
                accessors: [
                  AccessorListOption(
                    'server',
                    options: [
                      AccessorStringOption('host'),
                      AccessorIntOption('port'),
                      AccessorDoubleOption('ratio'),
                    ],
                  ),
                  AccessorListOption(
                    'one',
                    options: [
                      AccessorListOption(
                        'two',
                        options: [AccessorStringOption('three')],
                      ),
                    ],
                  ),
                  AccessorListOption(
                    'a',
                    options: [
                      AccessorListOption(
                        'b',
                        options: [
                          AccessorListOption(
                            'c',
                            options: [
                              AccessorListOption(
                                'd',
                                options: [
                                  AccessorListOption(
                                    'e',
                                    options: [AccessorStringOption('value')],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                mandatoryPositionals: [
                  ChoicePositional<_Format>('format', choices: _Format.values),
                ],
                discretionaryPositionals: [
                  RepeatedChoicePositional<_Level>(
                    'level',
                    choices: _Level.values,
                    times: 2,
                  ),
                ],
                variadic: RepeatedChoiceVariadic<_Sku>(
                  'extra',
                  choices: _Sku.values,
                ),
              ),
            ],
          ),
        );

        expect(
          output,
          allOf([
            contains("-a 'serve' -d 'Serve requests.'"),
            contains(
              "complete -c spec -n '__mamba_at_path spec serve' -s f -l force",
            ),
            contains(
              'complete -c spec -n \'__mamba_at_path spec serve\' -l no-color',
            ),
            contains('-s l -l label -r'),
            contains('-l retries -x'),
            contains('-l server.host'),
            contains('-l server.port'),
            contains('-l server.ratio'),
            contains('-l one.two.three'),
            contains('-l a.b.c.d.e.value'),
            contains("-a 'json yaml'"),
            contains("-a 'debug info'"),
            contains("-a 'basic standard'"),
            contains('__mamba_after_double_dash'),
            isNot(contains('Additional serving details.')),
          ]),
        );
      },
    );
  });
  group("ToZshCompletionConverter", () {});
  group('ToBashCompletionConverter', () {
    test('places root flags and typed options in reusable global tables', () {
      final completion = convertBash(
        specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('color', negatable: true),
            CountFlag('verbose'),
          ],
          options: [
            StringOption('name', short: 'n'),
            IntOption('retries'),
            DoubleOption('ratio'),
            RepeatableStringOption('include'),
            RepeatableIntOption('attempt'),
            RepeatableDoubleOption('weight'),
            ChoiceOption<_Format>('format', choices: _Format.values),
          ],
        ).toMap(),
      );

      expect(
        completion,
        allOf([
          contains('# Global inputs for spec'),
          contains("  '-f'"),
          contains("  '--color'"),
          contains("  '--no-color'"),
          contains("  '--verbose'"),
          contains('_spec_format_values=(\n  \'json\'\n  \'yaml\'\n)'),
          contains("['--format']='_spec_format_values'"),
          contains("['-n']='_spec_name_values'"),
          contains('declare -A _spec_options=('),
          endsWith('complete -F _spec_completion spec\n'),
        ]),
      );
    });

    test('creates nested handlers before their alias case dispatchers', () {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestGroupCommand('config', [
              TestCommand(
                'set',
                'Set configuration.',
                aliases: ['s'],
                flags: [
                  BooleanFlag('force', short: 'f'),
                  BooleanFlag('color', negatable: true),
                  CountFlag('verbose'),
                ],
                options: [
                  StringOption('name', short: 'n'),
                  IntOption('retries'),
                  DoubleOption('ratio'),
                  RepeatableStringOption('include'),
                  RepeatableIntOption('attempt'),
                  RepeatableDoubleOption('weight'),
                  ChoiceOption<_Format>('format', choices: _Format.values),
                ],
                mandatoryPositionals: [
                  ChoicePositional<_Level>('level', choices: _Level.values),
                ],
                discretionaryPositionals: [
                  RepeatedChoicePositional<_Sku>(
                    'sku',
                    choices: _Sku.values,
                    times: 2,
                  ),
                ],
                variadic: RepeatedChoiceVariadic<_Format>(
                  'extra',
                  choices: _Format.values,
                ),
                accessors: [
                  AccessorListOption(
                    'server',
                    options: [
                      AccessorStringOption('host'),
                      AccessorIntOption('port'),
                      AccessorDoubleOption('ratio'),
                    ],
                  ),
                  AccessorListOption(
                    'profile',
                    options: [
                      AccessorListOption(
                        'cloud',
                        options: [
                          AccessorListOption(
                            'credentials',
                            options: [
                              AccessorChoiceOption<_Format>(
                                'format',
                                choices: _Format.values,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  AccessorListOption(
                    'database',
                    options: [AccessorStringOption('url')],
                  ),
                ],
              ),
            ], 'Configure the application.'),
          ],
        ).toMap(),
      );

      expect(
        completion,
        allOf([
          contains('_spec_config_set_completion()'),
          contains('_spec_config_completion()'),
          contains('set|s)'),
          contains('_spec_config_set_server_host_values=('),
          contains("['--server.host']='_spec_config_set_server_host_values'"),
          contains(
            "['--profile.cloud.credentials.format']='_spec_config_set_profile_cloud_credentials_format_values'",
          ),
          contains('0)'),
          contains('1|2|3)'),
          contains("_mamba_filter \"\$current\" 'debug' 'info'"),
          contains("_mamba_filter \"\$current\" 'basic' 'standard'"),
          endsWith('complete -F _spec_completion spec\n'),
        ]),
      );
      expect(
        completion.indexOf('_spec_config_set_completion()'),
        lessThan(completion.indexOf('set|s)')),
      );
    });

    test('lists only visible short inputs for a short prefix', () {
      final completion = convertBash(
        specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            BooleanFlag('secret', short: 's', hidden: true),
          ],
        ).toMap(),
      );

      expect(completion, contains("  '-f'"));
      expect(completion, isNot(contains("  '-s'")));
    });

    test('lists visible long inputs for a long prefix', () {
      final completion = convertBash(
        specRegistry(flags: [BooleanFlag('force')]).toMap(),
      );

      expect(completion, contains("  '--force'"));
      expect(completion, contains('case "\$current" in\n    -*)'));
    });

    test('emits the negated spelling only for negatable flags', () {
      final completion = convertBash(
        specRegistry(
          flags: [BooleanFlag('color', negatable: true), BooleanFlag('force')],
        ).toMap(),
      );

      expect(completion, contains("  '--no-color'"));
      expect(completion, isNot(contains('--no-force')));
    });

    test('routes every command alias through its canonical handler', () {
      final completion = convertBash(
        specRegistry(
          commands: [
            TestCommand('commit', 'Commit changes.', aliases: ['ci']),
          ],
        ).toMap(),
      );

      expect(completion, contains('commit|ci)'));
      expect(completion, contains('_spec_commit_completion'));
    });

    test('checks option values before command routing', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          commands: [TestCommand('json', 'Print JSON.')],
        ).toMap(),
      );

      expect(
        completion.indexOf('    --format)'),
        lessThan(completion.indexOf('      json)')),
      );
    });

    test('maps choice options to their finite value array', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
        ).toMap(),
      );

      expect(completion, contains("['--format']='_spec_format_values'"));
      expect(completion, contains("  'json'"));
      expect(completion, contains("  'yaml'"));
    });

    test('does not invent values for a negative integer option', () {
      final completion = convertBash(
        specRegistry(options: [IntOption('offset')]).toMap(),
      );

      expect(completion, contains('_spec_offset_values=(\n)'));
      expect(completion, isNot(contains('_mamba_integer_range')));
    });

    test('does not invent a finite completion list for double bounds', () {
      final completion = convertBash(
        specRegistry(
          options: [DoubleOption('ratio', min: 0.0, max: 1.0)],
        ).toMap(),
      );

      expect(completion, contains('_spec_ratio_values=(\n)'));
      expect(completion, isNot(contains("  '0.0'")));
    });

    test(
      'keeps an unconstrained positional slot before a choice positional',
      () {
        final completion = convertBash(
          specRegistry(
            mandatoryPositionals: [
              NormalPositional('path'),
              ChoicePositional<_Format>('format', choices: _Format.values),
            ],
          ).toMap(),
        );

        expect(completion, contains('    1)'));
        expect(
          completion,
          contains("_mamba_filter \"\$current\" 'json' 'yaml'"),
        );
      },
    );

    test('limits repeated positional choices to times plus one slots', () {
      final completion = convertBash(
        specRegistry(
          mandatoryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains('    0|1|2)'));
      expect(completion, isNot(contains('0|1|2|3)')));
    });

    test('keeps a completed separator ahead of other value cases', () {
      final completion = convertBash(
        specRegistry(
          options: [ChoiceOption<_Format>('format', choices: _Format.values)],
          variadic: ChoiceVariadic<_Level>('extra', choices: _Level.values),
        ).toMap(),
      );

      expect(
        completion.indexOf('    --)'),
        lessThan(completion.indexOf('    --format)')),
      );
    });

    test('emits choices for a single-value variadic', () {
      final completion = convertBash(
        specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        ).toMap(),
      );

      expect(completion, contains("_mamba_filter \"\$current\" 'json' 'yaml'"));
    });

    test('emits choices for a repeated variadic', () {
      final completion = convertBash(
        specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        ).toMap(),
      );

      expect(completion, contains('    --)'));
      expect(completion, contains("_mamba_filter \"\$current\" 'json' 'yaml'"));
    });

    test('omits hidden inputs while retaining visible input tables', () {
      final completion = convertBash(
        specRegistry(
          flags: [BooleanFlag('internal', hidden: true)],
          options: [StringOption('token', hidden: true)],
        ).toMap(),
      );

      expect(completion, isNot(contains('--internal')));
      expect(completion, isNot(contains("['--token']")));
      expect(completion, contains("  '--help'"));
    });

    test('flattens nested accessor leaves into dotted option keys', () {
      final completion = convertBash(
        specRegistry(
          accessors: [
            AccessorListOption(
              'database',
              options: [
                AccessorListOption(
                  'connection',
                  options: [
                    AccessorChoiceOption<_Format>(
                      'format',
                      choices: _Format.values,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ).toMap(),
      );

      expect(completion, contains("['--database.connection.format']"));
      expect(completion, contains('_spec_database_connection_format_values='));
    });
  });

  group('CarapaceSpecWriter', () {
    test('writes development specs below the system temp directory', () {
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(
          CommandRegistry.create('writer-fixture', 'writer command').toMap(),
        ),
        development: true,
      );
      final file = writer.write();
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      expect(file.path, startsWith(Directory.systemTemp.path));
      expect(
        file.path,
        endsWith(
          [
            'carapace',
            'specs',
            'writer-fixture.yaml',
          ].join(Platform.pathSeparator),
        ),
      );
      expect(file.readAsStringSync(), contains('name: "writer-fixture"'));
    });

    test('writes to an explicit path and creates missing directories', () {
      final directory = Directory.systemTemp.createTempSync('mamba-spec-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = [
        directory.path,
        'nested',
        'spec.yaml',
      ].join(Platform.pathSeparator);
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(specRegistry().toMap()),
        development: false,
        outputPath: path,
      );

      final file = writer.write();

      expect(file.path, path);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('name: "spec"'));
    });
  });

  group("CarapaceSpecConverter", () {
    test('emits negated boolean flag forms', () {
      final registry = specRegistry(
        flags: [BooleanFlag('color', negatable: true)],
      );

      expect(convertSpec(registry.toMap()), contains('--no-color: ""'));
    });

    test('renders a RegistryMap without a CommandRegistry', () {
      final registryMap = RegistryMap({
        'name': 'from-map',
        'description': 'A map-defined command.',
        'flags': {
          'force': {
            'short': 'f',
            'default': false,
            'negatable': false,
            'hidden': false,
            'description': null,
          },
        },
        'options': {
          'retries': {
            'short': null,
            'required': true,
            'hidden': false,
            'description': 'Retry attempts.',
            'valueType': 'int',
          },
        },
      });

      expect(
        CarapaceSpecConverter(registryMap).convert(),
        equalsYaml('''
name: "from-map"
description: "A map-defined command."
persistentflags:
  -f, --force: ""
  -h, --help: "Show this help message."
  --retries!=: "Retry attempts."'''),
      );
    });

    test('preserves required paired options through registry conversion', () {
      final registry = specRegistry(
        pairedOptions: [
          PairedOptions(
            required: true,
            options: [
              PairStringOption('username', description: 'Account name.'),
              PairIntOption('port', description: 'Server port.'),
            ],
          ),
        ],
      );

      expect(
        convertSpec(registry.toMap()),
        equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --username!=: "Account name."
  --port!=: "Server port."
completion:
  flag:
    port:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
      );
    });

    test('renders every variant option and marks the group exclusive', () {
      final registry = specRegistry(
        pairedOptions: [
          PairedOptions(
            variant: true,
            options: [
              PairStringOption('json', description: 'Write JSON.'),
              PairStringOption('yaml', description: 'Write YAML.'),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--json?=: "Write JSON."'),
          contains('--yaml?=: "Write YAML."'),
          contains('exclusiveflags:'),
          contains('- "json"'),
          contains('- "yaml"'),
        ),
      );
    });

    test('renders typed accessor flags and their value completions', () {
      final registry = specRegistry(
        commands: [
          TestCommand(
            'serve',
            'Serve requests.',
            accessors: [
              AccessorListOption(
                'server',
                options: [
                  AccessorIntOption('port', description: 'Server port.'),
                  AccessorChoiceOption<_Sku>(
                    'sku',
                    description: 'Server size.',
                    choices: _Sku.values,
                    defaultValue: _Sku.basic,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--server.port?=: "Server port."'),
          contains('--server.sku?=:'),
          contains('description: "Server size."'),
          contains('default: "basic"'),
          isNot(contains(r'$carapace.number.Range(')),
          allOf(
            contains('server.sku:'),
            contains('- "basic"'),
            contains('- "standard"'),
          ),
        ),
      );
    });

    test('renders accessor paths with five dots and shared branches', () {
      final registry = specRegistry(
        accessors: [
          AccessorListOption(
            'profile',
            options: [AccessorStringOption('name')],
          ),
          AccessorListOption(
            'cloud',
            options: [
              AccessorListOption(
                'provider',
                options: [
                  AccessorListOption(
                    'credentials',
                    options: [
                      AccessorListOption(
                        'oauth',
                        options: [
                          AccessorListOption(
                            'client',
                            options: [
                              AccessorStringOption('token'),
                              AccessorIntOption('timeout'),
                            ],
                          ),
                        ],
                      ),
                      AccessorStringOption('region'),
                    ],
                  ),
                  AccessorStringOption('endpoint'),
                ],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains('--profile.name?=: ""'),
          contains('--cloud.provider.endpoint?=: ""'),
          contains('--cloud.provider.credentials.region?=: ""'),
          contains('--cloud.provider.credentials.oauth.client.token?=: ""'),
          contains('--cloud.provider.credentials.oauth.client.timeout?=: ""'),
        ),
      );
    });

    test('propagates hidden accessor groups to descendant flags', () {
      final registry = specRegistry(
        commands: [
          TestCommand(
            'publish',
            'Publish output.',
            accessors: [
              AccessorListOption(
                'internal',
                hidden: true,
                options: [AccessorStringOption('token')],
              ),
            ],
          ),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(spec, contains('--internal.token?&='));
    });

    test('rejects legacy description-only accessor maps', () {
      expect(
        () => RegistryMap({
          'name': 'legacy',
          'description': 'Legacy map.',
          'accessors': {
            'profile': {
              'description': 'Profile settings.',
              'options': {
                'name': {'description': 'Profile name.'},
              },
            },
          },
        }),
        throwsA(isA<MambaIntegrationException>()),
      );
    });

    group("commands", () {
      test("rendered with flags", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', flags: [BooleanFlag('force')]),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      -h, --help: "Show this help message."
      --force: ""'''),
        );
      });

      test("rendered with aliases", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', aliases: ['s', 'b']),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    aliases:
      - "s"
      - "b"
    flags:
      -h, --help: "Show this help message."'''),
        );
      });

      test("rendered with options", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', options: [IntOption('retries')]),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      -h, --help: "Show this help message."
      --retries?=: ""
    completion:
      flag:
        retries:
          - "\$carapace.number.Range({start: -10, end: 10})"
'''),
        );
      });

      test("rendered with description", () {
        final registry = specRegistry(
          commands: [
            TestCommand(
              'sub',
              'a subcommand',
              longDescription: 'does the subs work',
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "sub"
    description: |-
      a subcommand

      does the subs work
    flags:
      -h, --help: "Show this help message."'''),
        );
      });
    });

    group("flags", () {
      group("count versus bool flags", () {
        test("count flag rendered", () {
          final registry = specRegistry(
            flags: [CountFlag('verbose', description: 'increase verbosity')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --verbose*: "increase verbosity"'''),
          );
        });

        test("count flag rendered with short", () {
          final registry = specRegistry(
            flags: [CountFlag('verbose', short: 'v')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose*: ""'''),
          );
        });

        test("count and bool flag descriptions are rendered", () {
          final registry = specRegistry(
            flags: [
              CountFlag('verbose', description: 'increase verbosity'),
              BooleanFlag('force', description: 'overwrite existing files'),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: "overwrite existing files"
  --verbose*: "increase verbosity"'''),
          );
        });

        test("bool flag rendered with words", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: ""'''),
          );
        });

        test("bool flag rendered with short", () {
          final registry = specRegistry(
            flags: [BooleanFlag('force', short: 'f')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -f, --force: ""'''),
          );
        });

        test("hidden count flag rendered", () {
          final registry = specRegistry(
            flags: [CountFlag('trace', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --trace*&: ""'''),
          );
        });

        test("hidden bool flag rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('quiet', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --quiet&: ""'''),
          );
        });

        // Mamba boolean flags cannot be required, so the spec must never add
        // the required `!` marker to one even when the TODO asks for it.
        test("required bool flag rendered", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --force: ""'''),
          );
        });
      });

      group("options", () {
        test("option rendered", () {
          final registry = specRegistry(options: [IntOption('retries')]);

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("option rendered with short", () {
          final registry = specRegistry(
            options: [IntOption('retries', short: 'r')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -r, --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("option and repeated option descriptions are rendered", () {
          final registry = specRegistry(
            options: [
              IntOption('retries', description: 'attempts before giving up'),
              RepeatableIntOption('include', description: 'globs to include'),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: "attempts before giving up"
  --include*?=: "globs to include"
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("repeatable flag rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("repeatable option rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -i, --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
          );
        });

        test("hidden flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("hidden option rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', short: 'd', hidden: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -d, --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("required flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', required: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });

        test("required option rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', short: 't', required: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -t, --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: -10, end: 10})"
'''),
          );
        });
      });

      group("defaults", () {
        test("choice option default rendered", () {
          final registry = specRegistry(
            options: [
              ChoiceOption<_Format>(
                'format',
                choices: _Format.values,
                defaultValue: _Format.json,
                description: 'output format',
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --format?=:
    description: "output format"
    default: "json"
completion:
  flag:
    format:
      - "json"
      - "yaml"'''),
          );
        });

        test("boolean flag default rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('assumeyes', defaultValue: true)],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --assumeyes:
    description: ""
    default: true'''),
          );
        });
      });

      group("modifier combos", () {
        for (final combo in modifierCombos) {
          // Optionality fills with ! or ? only on value-taking options; flags
          // carry neither optionality nor arity.
          final suffix =
              '${combo.repeatability ? '*' : ''}'
              '${combo.arity ? (combo.optionality ? '!' : '?') : ''}'
              '${combo.appearance ? '&' : ''}'
              '${combo.arity ? '=' : ''}';

          test("long flag renders --combo$suffix", () {
            // Value-taking options carry the arity slot while flags cannot;
            // optionality additionally requires an option to be expressible.
            final completion = combo.arity
                ? '\ncompletion:\n'
                      '  flag:\n'
                      '    combo:\n'
                      '      - "\$carapace.number.Range({start: -10, end: 10})"\n'
                : '';
            final registry = combo.arity
                ? specRegistry(
                    options: [
                      if (combo.repeatability)
                        RepeatableIntOption(
                          'combo',
                          required: combo.optionality,
                          hidden: combo.appearance,
                        )
                      else
                        IntOption(
                          'combo',
                          required: combo.optionality,
                          hidden: combo.appearance,
                        ),
                    ],
                  )
                : specRegistry(
                    flags: [
                      if (combo.repeatability)
                        CountFlag('combo', hidden: combo.appearance)
                      else
                        BooleanFlag('combo', hidden: combo.appearance),
                    ],
                  );

            expect(
              convertSpec(registry.toMap()),
              equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --combo$suffix: ""$completion'''),
            );
          });
        }
      });
    });

    group("positionals", () {
      test("choice positionals are rendered", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
          discretionaryPositionals: [
            ChoicePositional<_Level>('level', choices: _Level.values),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "debug"
      - "debug"
      - "info"
      - "info"'''),
        );
      });

      test("unconstrained positionals preserve later choice slots", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            NormalPositional('path'),
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - []
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });

      test("repeated choice positionals render bounded slots", () {
        final registry = specRegistry(
          discretionaryPositionals: [
            RepeatedChoicePositional<_Format>(
              'format',
              choices: _Format.values,
              times: 2,
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });
    });

    group("variadic", () {
      test("choice variadics complete the first argument after --", () {
        final registry = specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  dash:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"'''),
        );
      });

      test("repeated choice variadics complete every argument after --", () {
        final registry = specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  dashany:
    - "json"
    - "yaml"'''),
        );
      });

      test("keeps ordinary and dash completions separate", () {
        final registry = specRegistry(
          mandatoryPositionals: [
            ChoicePositional<_Format>('format', choices: _Format.values),
          ],
          variadic: ChoiceVariadic<_Level>('extra', choices: _Level.values),
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
completion:
  positional:
    - - "json"
      - "json"
      - "yaml"
      - "yaml"
  dash:
    - - "debug"
      - "debug"
      - "info"
      - "info"'''),
        );
      });
    });

    test('renders bounded numeric options as Carapace ranges', () {
      final registry = specRegistry(
        options: [
          IntOption('retries', min: 1, max: 3),
          DoubleOption('ratio', min: 0.5, max: 1.5),
        ],
      );

      final spec = convertSpec(registry.toMap());

      expect(
        spec,
        allOf(
          contains(r'$carapace.number.Range({start: 1, end: 3})'),
          contains(r'$carapace.number.Range({start: 0.5, end: 1.5})'),
        ),
      );
    });

    group("numeric options", () {
      test("int options no longer invent a bounded completion range", () {
        final registry = specRegistry(options: [IntOption('retries')]);

        expect(
          convertSpec(registry.toMap()),
          isNot(contains('carapace.number.Range(')),
        );
        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"'''),
        );
      });
      test("double options do not invent a completion range", () {
        final registry = specRegistry(options: [DoubleOption('price')]);

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --price?=: ""
completion:
  flag:
    price:
      - "\$carapace.number.Range({format: '%.2f', start: -10, end: 10})"'''),
        );
      });
    });

    group("inherited flags and options", () {
      test("root inputs render as persistentflags once", () {
        final registry = specRegistry(
          flags: [
            BooleanFlag('force', short: 'f'),
            CountFlag('verbose'),
          ],
          options: [IntOption('retries', short: 'r', required: true)],
          commands: [
            TestCommand('push', 'push changes'),
            TestCommand('pull', 'pull changes'),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -f, --force: ""
  --verbose*: ""
  -r, --retries!=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "push"
    description: "push changes"
    flags:
      -h, --help: "Show this help message."
  - name: "pull"
    description: "pull changes"
    flags:
      -h, --help: "Show this help message."'''),
        );
      });

      test("a group's inherited inputs render once on the group", () {
        final registry = specRegistry(
          commands: [
            TestGroupCommand(
              'container',
              [TestCommand('list', 'list containers')],
              'manage containers',
              inheritedFlags: [
                BooleanFlag('color'),
                CountFlag('verbose', short: 'v', hidden: true),
              ],
              inheritedOptions: [
                IntOption('namespace', short: 'n', required: true),
              ],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --color: ""
      -v, --verbose*&: ""
      -n, --namespace!=: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });

      test(
        "groups merge ancestor globals with their own persistent inputs",
        () {
          final registry = specRegistry(
            flags: [BooleanFlag('global-flag', short: 'g')],
            commands: [
              TestGroupCommand(
                'container',
                [TestCommand('list', 'list containers')],
                'manage containers',
                inheritedFlags: [BooleanFlag('color')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -g, --global-flag: ""
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --color: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
          );
        },
      );

      test(
        "published inputs move to persistentflags while locals stay put",
        () {
          final registry = specRegistry(
            flags: [BooleanFlag('global-flag')],
            commands: [
              TestCommand(
                'child',
                'child command',
                flags: [BooleanFlag('own-flag')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  --global-flag: ""
commands:
  - name: "child"
    description: "child command"
    flags:
      -h, --help: "Show this help message."
      --own-flag: ""'''),
          );
        },
      );

      test('local inputs replace a group\'s published inputs', () {
        final registry = specRegistry(
          commands: [
            TestGroupCommand(
              'container',
              [TestCommand('list', 'list containers')],
              'manage containers',
              inheritedFlags: [BooleanFlag('force', short: 'f')],
              inheritedOptions: [IntOption('retries', short: 'r')],
              flags: [BooleanFlag('local-force', short: 'F')],
              options: [IntOption('retries', short: 'R')],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -h, --help: "Show this help message."
      -F, --local-force: ""
      -R, --retries?=: ""
    persistentflags:
      -f, --force: ""
    commands:
      - name: "list"
        description: "list containers"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });
    });

    group("persistent flag registries", () {
      test("root globals and each group's own inputs render persistently", () {
        final registry = specRegistry(
          flags: [
            BooleanFlag('verbose', short: 'v', description: 'increase output'),
            CountFlag('trace'),
          ],
          options: [IntOption('jobs', short: 'j')],
          commands: [
            TestGroupCommand(
              'remote',
              [
                TestCommand('add', 'add a remote'),
                TestCommand('remove', 'remove a remote'),
              ],
              'manage remotes',
              inheritedFlags: [BooleanFlag('force')],
              inheritedOptions: [
                IntOption('depth', short: 'd', required: true),
              ],
            ),
            TestGroupCommand(
              'auth',
              [TestCommand('login', 'log in')],
              'manage credentials',
              inheritedFlags: [CountFlag('attempts')],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: "increase output"
  --trace*: ""
  -j, --jobs?=: ""
completion:
  flag:
    jobs:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "remote"
    description: "manage remotes"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --force: ""
      -d, --depth!=: ""
    commands:
      - name: "add"
        description: "add a remote"
        flags:
          -h, --help: "Show this help message."
      - name: "remove"
        description: "remove a remote"
        flags:
          -h, --help: "Show this help message."
  - name: "auth"
    description: "manage credentials"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --attempts*: ""
    commands:
      - name: "login"
        description: "log in"
        flags:
          -h, --help: "Show this help message."'''),
        );
      });
    });

    group("real-world registries", () {
      // Modeled on the Azure CLI: documented globals (-v/--verbose, --debug,
      // -o/--output, --subscription) and a real four-group chain
      // (network > dns > record-set > a). Az scopes most flags per command,
      // so group-owned persistent inputs here adapt its conventions.
      test(
        "an az-style tree carries persistent flags down four group levels",
        () {
          final registry = specRegistry(
            flags: [
              BooleanFlag('verbose', short: 'v'),
              BooleanFlag('debug'),
            ],
            options: [
              IntOption('output', short: 'o'),
              StringOption('subscription', regex: RegExp(r'\S+')),
            ],
            commands: [
              TestGroupCommand(
                'vm',
                [TestCommand('list', 'list virtual machines')],
                'manage virtual machines',
                inheritedFlags: [BooleanFlag('no-wait')],
              ),
              TestGroupCommand(
                'storage',
                [TestCommand('check-name', 'check name availability')],
                'manage storage accounts',
                inheritedFlags: [BooleanFlag('https-only')],
                inheritedOptions: [
                  StringOption('account-name', regex: RegExp(r'\S+')),
                ],
              ),
              TestGroupCommand(
                'network',
                [
                  TestGroupCommand(
                    'dns',
                    [
                      TestGroupCommand(
                        'record-set',
                        [
                          TestGroupCommand(
                            'a',
                            [
                              TestCommand('add-record', 'add an a record'),
                              TestCommand(
                                'remove-record',
                                'remove an a record',
                              ),
                            ],
                            'manage a record sets',
                            inheritedOptions: [DoubleOption('ttl')],
                          ),
                        ],
                        'manage record sets',
                        inheritedOptions: [
                          StringOption('relative-name', regex: RegExp(r'\S+')),
                        ],
                      ),
                    ],
                    'manage dns zones',
                    inheritedOptions: [
                      StringOption('zone-name', regex: RegExp(r'\S+')),
                    ],
                  ),
                ],
                'manage networks',
                inheritedOptions: [IntOption('timeout')],
              ),
            ],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: ""
  --debug: ""
  -o, --output?=: ""
  --subscription?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "vm"
    description: "manage virtual machines"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --no-wait: ""
    commands:
      - name: "list"
        description: "list virtual machines"
        flags:
          -h, --help: "Show this help message."
  - name: "storage"
    description: "manage storage accounts"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --https-only: ""
      --account-name?=: ""
    commands:
      - name: "check-name"
        description: "check name availability"
        flags:
          -h, --help: "Show this help message."
  - name: "network"
    description: "manage networks"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --timeout?=: ""
    commands:
      - name: "dns"
        description: "manage dns zones"
        flags:
          -h, --help: "Show this help message."
        persistentflags:
          --zone-name?=: ""
        commands:
          - name: "record-set"
            description: "manage record sets"
            flags:
              -h, --help: "Show this help message."
            persistentflags:
              --relative-name?=: ""
            commands:
              - name: "a"
                description: "manage a record sets"
                flags:
                  -h, --help: "Show this help message."
                persistentflags:
                  --ttl?=: ""
                commands:
                  - name: "add-record"
                    description: "add an a record"
                    flags:
                      -h, --help: "Show this help message."
                  - name: "remove-record"
                    description: "remove an a record"
                    flags:
                      -h, --help: "Show this help message."'''),
          );
        },
      );
      test("choice inputs complete locally while their flags publish", () {
        final registry = specRegistry(
          flags: [BooleanFlag('verbose', short: 'v')],
          options: [IntOption('output', short: 'o')],
          commands: [
            TestGroupCommand(
              'vm',
              [
                TestCommand(
                  'show',
                  'show a virtual machine',
                  discretionaryPositionals: [
                    RepeatedChoicePositional<_Sku>('sku', choices: _Sku.values),
                  ],
                  variadic: RepeatedChoiceVariadic<_Format>(
                    'extra',
                    choices: _Format.values,
                  ),
                ),
              ],
              'manage virtual machines',
              inheritedFlags: [BooleanFlag('no-wait')],
              mandatoryPositionals: [
                ChoicePositional<_Sku>('sku', choices: _Sku.values),
              ],
            ),
          ],
        );

        expect(
          convertSpec(registry.toMap()),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -h, --help: "Show this help message."
  -v, --verbose: ""
  -o, --output?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: -10, end: 10})"
commands:
  - name: "vm"
    description: "manage virtual machines"
    flags:
      -h, --help: "Show this help message."
    persistentflags:
      --no-wait: ""
    completion:
      positional:
        - - "basic"
          - "basic"
          - "standard"
          - "standard"
    commands:
      - name: "show"
        description: "show a virtual machine"
        flags:
          -h, --help: "Show this help message."
        completion:
          positional:
            - - "basic"
              - "basic"
              - "standard"
              - "standard"
            - - "basic"
              - "basic"
              - "standard"
              - "standard"
          dashany:
            - "json"
            - "yaml"'''),
        );
      });
    });

    group("nested subcommands", () {
      for (final depth in [2, 3, 4, 5]) {
        test("a single flag reaches $depth nested subcommands", () {
          final registry = nestedRegistry(
            depth,
            flags: [BooleanFlag('force', short: 'f')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-f, --force: ""'],
                persistentEntries: ['-f, --force: ""'],
              ),
            ),
          );
        });
      }

      for (final depth in [2, 3, 4, 5]) {
        test("a repeated option reaches $depth nested subcommands", () {
          final registry = nestedRegistry(
            depth,
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(registry.toMap()),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-i, --include*?=: ""'],
                persistentEntries: ['-i, --include*?=: ""'],
                rootCompletionLines: [
                  'completion:',
                  '  flag:',
                  '    include:',
                  '      - "\$carapace.number.Range({start: -10, end: 10})"',
                ],
              ),
            ),
          );
        });
      }
    });
  });
}
