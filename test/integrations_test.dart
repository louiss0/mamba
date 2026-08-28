import 'dart:io';

import 'package:mamba/command.dart';
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
  commands: commands,
);

/// Renders the Carapace spec exported by [registryMap].
String convertSpec(RegistryMap registryMap) =>
    CarapaceSpecConverter(registryMap).convert();

/// Compares specs after dropping trailing whitespace and the final newline so
/// block-scalar blank lines and EOF newlines do not affect expectations.
Matcher equalsYaml(String expected) => predicate<String>(
  (actual) => _normalizeYaml(actual) == _normalizeYaml(expected),
  'equals the expected Carapace spec:\n$expected',
);

String _normalizeYaml(String yaml) =>
    yaml.split('\n').map((line) => line.trimRight()).join('\n').trim();

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
  final lines = <String>['name: "spec"', 'description: "spec command"'];
  if (rootFlagEntries.isNotEmpty) {
    lines.add('persistentflags:');
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
  group('CarapaceSpecWriter', () {
    test('writes development specs below the system temp directory', () {
      final writer = CarapaceSpecWriter(
        CarapaceSpecConverter(
          RegistryMap(
            CommandRegistry.create('writer-fixture', 'writer command').toMap(),
          ),
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
        CarapaceSpecConverter(RegistryMap(specRegistry().toMap())),
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
  --retries!=: "Retry attempts."
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"'''),
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "sub"
    description: "a subcommand"
    aliases:
      - "s"
      - "b"'''),
        );
      });

      test("rendered with options", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', options: [IntOption('retries')]),
          ],
        );

        expect(
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      --retries?=: ""
    completion:
      flag:
        retries:
          - "\$carapace.number.Range({start: 0, end: 1000})"
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "sub"
    description: |-
      a subcommand

      does the subs work'''),
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --verbose*: "increase verbosity"'''),
          );
        });

        test("count flag rendered with short", () {
          final registry = specRegistry(
            flags: [CountFlag('verbose', short: 'v')],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --force: "overwrite existing files"
  --verbose*: "increase verbosity"'''),
          );
        });

        test("bool flag rendered with words", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --force: ""'''),
          );
        });

        test("bool flag rendered with short", () {
          final registry = specRegistry(
            flags: [BooleanFlag('force', short: 'f')],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -f, --force: ""'''),
          );
        });

        test("hidden count flag rendered", () {
          final registry = specRegistry(
            flags: [CountFlag('trace', hidden: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --trace*&: ""'''),
          );
        });

        test("hidden bool flag rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('quiet', hidden: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --quiet&: ""'''),
          );
        });

        // Mamba boolean flags cannot be required, so the spec must never add
        // the required `!` marker to one even when the TODO asks for it.
        test("required bool flag rendered", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --force: ""'''),
          );
        });
      });

      group("options", () {
        test("option rendered", () {
          final registry = specRegistry(options: [IntOption('retries')]);

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"
'''),
          );
        });

        test("option rendered with short", () {
          final registry = specRegistry(
            options: [IntOption('retries', short: 'r')],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -r, --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --retries?=: "attempts before giving up"
  --include*?=: "globs to include"
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"
    include:
      - "\$carapace.number.Range({start: 0, end: 1000})"'''),
          );
        });

        test("repeatable flag rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include')],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: 0, end: 1000})"'''),
          );
        });

        test("repeatable option rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -i, --include*?=: ""
completion:
  flag:
    include:
      - "\$carapace.number.Range({start: 0, end: 1000})"'''),
          );
        });

        test("hidden flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', hidden: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: 0, end: 1000})"
'''),
          );
        });

        test("hidden option rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', short: 'd', hidden: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -d, --debug-level?&=: ""
completion:
  flag:
    debug-level:
      - "\$carapace.number.Range({start: 0, end: 1000})"
'''),
          );
        });

        test("required flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', required: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: 0, end: 1000})"
'''),
          );
        });

        test("required option rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', short: 't', required: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -t, --token!=: ""
completion:
  flag:
    token:
      - "\$carapace.number.Range({start: 0, end: 1000})"
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --format?=:
    description: "output format"
    default: "json"'''),
          );
        });

        test("boolean flag default rendered", () {
          final registry = specRegistry(
            flags: [BooleanFlag('assumeyes', defaultValue: true)],
          );

          expect(
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
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
                      '      - "\$carapace.number.Range({start: 0, end: 1000})"\n'
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
              convertSpec(RegistryMap(registry.toMap())),
              equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
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

    group("numeric options", () {
      test("int options complete a bounded default range", () {
        final registry = specRegistry(options: [IntOption('retries')]);

        expect(
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --retries?=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"'''),
        );
      });
      test("double options complete money-style with two decimals", () {
        final registry = specRegistry(options: [DoubleOption('price')]);

        expect(
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --price?=: ""
completion:
  flag:
    price:
      - "\$carapace.number.Range({format: '%.2f', start: 0, end: 1000})"'''),
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -f, --force: ""
  --verbose*: ""
  -r, --retries!=: ""
completion:
  flag:
    retries:
      - "\$carapace.number.Range({start: 0, end: 1000})"
commands:
  - name: "push"
    description: "push changes"
  - name: "pull"
    description: "pull changes"'''),
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "container"
    description: "manage containers"
    persistentflags:
      --color: ""
      -v, --verbose*&: ""
      -n, --namespace!=: ""
    commands:
      - name: "list"
        description: "list containers"'''),
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -g, --global-flag: ""
commands:
  - name: "container"
    description: "manage containers"
    persistentflags:
      --color: ""
    commands:
      - name: "list"
        description: "list containers"'''),
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  --global-flag: ""
commands:
  - name: "child"
    description: "child command"
    flags:
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
              flags: [BooleanFlag('force', short: 'F')],
              options: [IntOption('retries', short: 'R')],
            ),
          ],
        );

        expect(
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "container"
    description: "manage containers"
    flags:
      -F, --force: ""
      -R, --retries?=: ""
    completion:
      flag:
        retries:
          - "\$carapace.number.Range({start: 0, end: 1000})"
    commands:
      - name: "list"
        description: "list containers"'''),
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -v, --verbose: "increase output"
  --trace*: ""
  -j, --jobs?=: ""
completion:
  flag:
    jobs:
      - "\$carapace.number.Range({start: 0, end: 1000})"
commands:
  - name: "remote"
    description: "manage remotes"
    persistentflags:
      --force: ""
      -d, --depth!=: ""
    commands:
      - name: "add"
        description: "add a remote"
      - name: "remove"
        description: "remove a remote"
  - name: "auth"
    description: "manage credentials"
    persistentflags:
      --attempts*: ""
    commands:
      - name: "login"
        description: "log in"'''),
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -v, --verbose: ""
  --debug: ""
  -o, --output?=: ""
  --subscription?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: 0, end: 1000})"
    subscription:
      - "\$files"
commands:
  - name: "vm"
    description: "manage virtual machines"
    persistentflags:
      --no-wait: ""
    commands:
      - name: "list"
        description: "list virtual machines"
  - name: "storage"
    description: "manage storage accounts"
    persistentflags:
      --https-only: ""
      --account-name?=: ""
    commands:
      - name: "check-name"
        description: "check name availability"
  - name: "network"
    description: "manage networks"
    persistentflags:
      --timeout?=: ""
    commands:
      - name: "dns"
        description: "manage dns zones"
        persistentflags:
          --zone-name?=: ""
        commands:
          - name: "record-set"
            description: "manage record sets"
            persistentflags:
              --relative-name?=: ""
            commands:
              - name: "a"
                description: "manage a record sets"
                persistentflags:
                  --ttl?=: ""
                commands:
                  - name: "add-record"
                    description: "add an a record"
                  - name: "remove-record"
                    description: "remove an a record"'''),
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
          convertSpec(RegistryMap(registry.toMap())),
          equalsYaml('''
name: "spec"
description: "spec command"
persistentflags:
  -v, --verbose: ""
  -o, --output?=: ""
completion:
  flag:
    output:
      - "\$carapace.number.Range({start: 0, end: 1000})"
commands:
  - name: "vm"
    description: "manage virtual machines"
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
            convertSpec(RegistryMap(registry.toMap())),
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
            convertSpec(RegistryMap(registry.toMap())),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-i, --include*?=: ""'],
                persistentEntries: ['-i, --include*?=: ""'],
                rootCompletionLines: [
                  'completion:',
                  '  flag:',
                  '    include:',
                  '      - "\$carapace.number.Range({start: 0, end: 1000})"',
                ],
              ),
            ),
          );
        });
      }
    });
  });
}
