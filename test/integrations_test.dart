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
  List<PairedOption>? pairedOptions,
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

/// Renders the Carapace spec for [registry].
String convertSpec(CommandRegistry registry) =>
    CarapaceSpecConverter(registry).convert();

/// Compares specs after dropping trailing whitespace and the final newline so
/// block-scalar blank lines and EOF newlines do not affect expectations.
Matcher equalsYaml(String expected) => predicate<String>(
  (actual) => _normalizeYaml(actual) == _normalizeYaml(expected),
  'equals the expected Carapace spec:\n$expected',
);

String _normalizeYaml(String yaml) => yaml
    .split('\n')
    .map((line) => line.trimRight())
    .join('\n')
    .trim();

/// Modifier slots ordered `<key><repeatability><optionality><appearance><arity>`.
typedef ModifierCombo =
    ({bool repeatability, bool optionality, bool appearance, bool arity});

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
  List<PairedOption>? pairedOptions,
}) {
  List<Command> buildChain(int remaining) {
    if (remaining <= 1) return [TestCommand('leaf', 'leaf command')];
    final groupName = nestedGroupNames[depth - remaining];
    return [
      TestGroupCommand(groupName, buildChain(remaining - 1), '$groupName command'),
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
    '$indent  persistentflags:',
    ...[for (final entry in persistentEntries) '$indent    $entry'],
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
}) {
  final names = [
    for (var index = 0; index < depth - 1; index++) nestedGroupNames[index],
    'leaf',
  ];
  final lines = <String>['name: "spec"', 'description: "spec command"'];
  if (rootFlagEntries.isNotEmpty) {
    lines.add('flags:');
    lines.addAll([for (final entry in rootFlagEntries) '  $entry']);
  }
  lines.add('commands:');
  lines.addAll(
    nestedCommandLines(names.first, names.sublist(1), '  ', persistentEntries),
  );
  return lines.join('\n');
}

void main() {
  group("CarapaceSpecConverter", () {
    group("commands", () {
      test("rendered with flags", () {
        final registry = specRegistry(
          commands: [
            TestCommand('sub', 'a subcommand', flags: [BooleanFlag('force')]),
          ],
        );

        expect(
          convertSpec(registry),
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
          convertSpec(registry),
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
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      --retries?=: ""'''),
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
          convertSpec(registry),
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
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --verbose*: "increase verbosity"'''),
          );
        });

        test("count flag rendered with short", () {
          final registry = specRegistry(flags: [CountFlag('verbose', short: 'v')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -v, --verbose*: ""'''),
          );
        });

        test("bool flag rendered with words", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --force: ""'''),
          );
        });

        test("bool flag rendered with short", () {
          final registry = specRegistry(flags: [BooleanFlag('force', short: 'f')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -f, --force: ""'''),
          );
        });

        test("hidden count flag rendered", () {
          final registry = specRegistry(flags: [CountFlag('trace', hidden: true)]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --trace*&: ""'''),
          );
        });

        test("hidden bool flag rendered", () {
          final registry = specRegistry(flags: [BooleanFlag('quiet', hidden: true)]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --quiet&: ""'''),
          );
        });

        // Mamba boolean flags cannot be required, so the spec must never add
        // the required `!` marker to one even when the TODO asks for it.
        test("required bool flag rendered", () {
          final registry = specRegistry(flags: [BooleanFlag('force')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --force: ""'''),
          );
        });
      });

      group("options", () {
        test("option rendered", () {
          final registry = specRegistry(options: [IntOption('retries')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --retries?=: ""'''),
          );
        });

        test("option rendered with short", () {
          final registry = specRegistry(options: [IntOption('retries', short: 'r')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -r, --retries?=: ""'''),
          );
        });

        test("repeatable flag rendered", () {
          final registry = specRegistry(options: [RepeatableIntOption('include')]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --include*?=: ""'''),
          );
        });

        test("repeatable option rendered", () {
          final registry = specRegistry(
            options: [RepeatableIntOption('include', short: 'i')],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -i, --include*?=: ""'''),
          );
        });

        test("hidden flag rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', hidden: true)],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --debug-level?&=: ""'''),
          );
        });

        test("hidden option rendered", () {
          final registry = specRegistry(
            options: [IntOption('debug-level', short: 'd', hidden: true)],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -d, --debug-level?&=: ""'''),
          );
        });

        test("required flag rendered", () {
          final registry = specRegistry(options: [IntOption('token', required: true)]);

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --token!=: ""'''),
          );
        });

        test("required option rendered", () {
          final registry = specRegistry(
            options: [IntOption('token', short: 't', required: true)],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -t, --token!=: ""'''),
          );
        });
      });

      group("paired options", () {
        test("variant paired option renders exclusiveflags", () {
          final registry = specRegistry(
            pairedOptions: [
              PairedStringOption(
                'auth',
                description: 'credentials',
                variant: true,
                options: [
                  PairStringOption('user', short: 'u'),
                  PairIntOption('port'),
                ],
              ),
            ],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
exclusiveflags:
  - - "auth"
    - "user"
    - "port"'''),
          );
        });

        test("non-variant paired options are just rendered", () {
          final registry = specRegistry(
            pairedOptions: [
              PairedStringOption(
                'auth',
                description: 'credentials',
                options: [
                  PairStringOption('user', short: 'u'),
                  PairIntOption('port'),
                ],
              ),
            ],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --auth?=: "credentials"
  -u, --user?=: ""
  --port?=: ""'''),
          );
        });

        test("required paired options are all written as required", () {
          final registry = specRegistry(
            pairedOptions: [
              PairedStringOption(
                'conn',
                description: 'connection',
                required: true,
                options: [
                  PairStringOption('host'),
                  PairDoubleOption('timeout'),
                ],
              ),
            ],
          );

          expect(
            convertSpec(registry),
            equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --conn!=: "connection"
  --host!=: ""
  --timeout!=: ""'''),
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
              convertSpec(registry),
              equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --combo$suffix: ""'''),
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
          convertSpec(registry),
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

      test("repeated choice positionals are rendered", () {
        final registry = specRegistry(
          discretionaryPositionals: [
            RepeatedChoicePositional<_Format>('format', choices: _Format.values),
          ],
        );

        expect(
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
completion:
  positionalany:
    - "json"
    - "yaml"'''),
        );
      });
    });

    group("variadic", () {
      test("choice variadics are rendered", () {
        final registry = specRegistry(
          variadic: ChoiceVariadic<_Format>('extra', choices: _Format.values),
        );

        expect(
          convertSpec(registry),
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

      test("repeated choice variadics are rendered", () {
        final registry = specRegistry(
          variadic: RepeatedChoiceVariadic<_Format>(
            'extra',
            choices: _Format.values,
          ),
        );

        expect(
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
completion:
  dashany:
    - "json"
    - "yaml"'''),
        );
      });
    });

    group("inherited flags and options", () {
      test("global flags and options go to each child command", () {
        final registry = specRegistry(
          flags: [BooleanFlag('force', short: 'f'), CountFlag('verbose')],
          options: [IntOption('retries', short: 'r', required: true)],
          commands: [
            TestCommand('push', 'push changes'),
            TestCommand('pull', 'pull changes'),
          ],
        );

        expect(
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -f, --force: ""
  --verbose*: ""
  -r, --retries!=: ""
commands:
  - name: "push"
    description: "push changes"
    persistentflags:
      -f, --force: ""
      --verbose*: ""
      -r, --retries!=: ""
  - name: "pull"
    description: "pull changes"
    persistentflags:
      -f, --force: ""
      --verbose*: ""
      -r, --retries!=: ""'''),
        );
      });

      test("inherited options and flags go to each child's subcommand", () {
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
          convertSpec(registry),
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
        description: "list containers"
        persistentflags:
          --color: ""
          -v, --verbose*&: ""
          -n, --namespace!=: ""'''),
        );
      });

      test("a group publishes globals and its own inherited inputs alike", () {
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
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -g, --global-flag: ""
commands:
  - name: "container"
    description: "manage containers"
    persistentflags:
      -g, --global-flag: ""
      --color: ""
    commands:
      - name: "list"
        description: "list containers"
        persistentflags:
          -g, --global-flag: ""
          --color: ""'''),
        );
      });

      test("published inputs move to persistentflags while locals stay put", () {
        final registry = specRegistry(
          flags: [BooleanFlag('global-flag')],
          commands: [
            TestCommand('child', 'child command', flags: [BooleanFlag('own-flag')]),
          ],
        );

        expect(
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  --global-flag: ""
commands:
  - name: "child"
    description: "child command"
    flags:
      --own-flag: ""
    persistentflags:
      --global-flag: ""'''),
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
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -v, --verbose: "increase output"
  --trace*: ""
  -j, --jobs?=: ""
commands:
  - name: "remote"
    description: "manage remotes"
    persistentflags:
      -v, --verbose: "increase output"
      --force: ""
      --trace*: ""
      -j, --jobs?=: ""
      -d, --depth!=: ""
    commands:
      - name: "add"
        description: "add a remote"
        persistentflags:
          -v, --verbose: "increase output"
          --force: ""
          --trace*: ""
          -j, --jobs?=: ""
          -d, --depth!=: ""
      - name: "remove"
        description: "remove a remote"
        persistentflags:
          -v, --verbose: "increase output"
          --force: ""
          --trace*: ""
          -j, --jobs?=: ""
          -d, --depth!=: ""
  - name: "auth"
    description: "manage credentials"
    persistentflags:
      -v, --verbose: "increase output"
      --trace*: ""
      --attempts*: ""
      -j, --jobs?=: ""
    commands:
      - name: "login"
        description: "log in"
        persistentflags:
          -v, --verbose: "increase output"
          --trace*: ""
          --attempts*: ""
          -j, --jobs?=: ""'''),
        );
      });
    });

    group("real-world registries", () {
      // Modeled on the Azure CLI: documented globals (-v/--verbose, --debug,
      // -o/--output, --subscription) and a real four-group chain
      // (network > dns > record-set > a). Az scopes most flags per command,
      // so group-owned persistent inputs here adapt its conventions.
      test("an az-style tree carries persistent flags down four group levels", () {
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
                            TestCommand('remove-record', 'remove an a record'),
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
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -v, --verbose: ""
  --debug: ""
  -o, --output?=: ""
  --subscription?=: ""
commands:
  - name: "vm"
    description: "manage virtual machines"
    persistentflags:
      -v, --verbose: ""
      --debug: ""
      --no-wait: ""
      -o, --output?=: ""
      --subscription?=: ""
    commands:
      - name: "list"
        description: "list virtual machines"
        persistentflags:
          -v, --verbose: ""
          --debug: ""
          --no-wait: ""
          -o, --output?=: ""
          --subscription?=: ""
  - name: "storage"
    description: "manage storage accounts"
    persistentflags:
      -v, --verbose: ""
      --debug: ""
      --https-only: ""
      -o, --output?=: ""
      --subscription?=: ""
      --account-name?=: ""
    commands:
      - name: "check-name"
        description: "check name availability"
        persistentflags:
          -v, --verbose: ""
          --debug: ""
          --https-only: ""
          -o, --output?=: ""
          --subscription?=: ""
          --account-name?=: ""
  - name: "network"
    description: "manage networks"
    persistentflags:
      -v, --verbose: ""
      --debug: ""
      -o, --output?=: ""
      --subscription?=: ""
      --timeout?=: ""
    commands:
      - name: "dns"
        description: "manage dns zones"
        persistentflags:
          -v, --verbose: ""
          --debug: ""
          -o, --output?=: ""
          --subscription?=: ""
          --timeout?=: ""
          --zone-name?=: ""
        commands:
          - name: "record-set"
            description: "manage record sets"
            persistentflags:
              -v, --verbose: ""
              --debug: ""
              -o, --output?=: ""
              --subscription?=: ""
              --timeout?=: ""
              --zone-name?=: ""
              --relative-name?=: ""
            commands:
              - name: "a"
                description: "manage a record sets"
                persistentflags:
                  -v, --verbose: ""
                  --debug: ""
                  -o, --output?=: ""
                  --subscription?=: ""
                  --timeout?=: ""
                  --zone-name?=: ""
                  --relative-name?=: ""
                  --ttl?=: ""
                commands:
                  - name: "add-record"
                    description: "add an a record"
                    persistentflags:
                      -v, --verbose: ""
                      --debug: ""
                      -o, --output?=: ""
                      --subscription?=: ""
                      --timeout?=: ""
                      --zone-name?=: ""
                      --relative-name?=: ""
                      --ttl?=: ""
                  - name: "remove-record"
                    description: "remove an a record"
                    persistentflags:
                      -v, --verbose: ""
                      --debug: ""
                      -o, --output?=: ""
                      --subscription?=: ""
                      --timeout?=: ""
                      --zone-name?=: ""
                      --relative-name?=: ""
                      --ttl?=: ""'''),
        );
      });
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
                    RepeatedChoicePositional<_Sku>(
                      'sku',
                      choices: _Sku.values,
                    ),
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
          convertSpec(registry),
          equalsYaml('''
name: "spec"
description: "spec command"
flags:
  -v, --verbose: ""
  -o, --output?=: ""
commands:
  - name: "vm"
    description: "manage virtual machines"
    persistentflags:
      -v, --verbose: ""
      --no-wait: ""
      -o, --output?=: ""
    completion:
      positional:
        - - "basic"
          - "basic"
          - "standard"
          - "standard"
    commands:
      - name: "show"
        description: "show a virtual machine"
        persistentflags:
          -v, --verbose: ""
          --no-wait: ""
          -o, --output?=: ""
        completion:
          positionalany:
            - "basic"
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
            convertSpec(registry),
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
            convertSpec(registry),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: ['-i, --include*?=: ""'],
                persistentEntries: ['-i, --include*?=: ""'],
              ),
            ),
          );
        });
      }

      for (final depth in [2, 3, 4, 5]) {
        test("a paired option reaches $depth nested subcommands", () {
          final registry = nestedRegistry(
            depth,
            pairedOptions: [
              PairedStringOption(
                'auth',
                options: [
                  PairStringOption('user'),
                  PairIntOption('port'),
                ],
              ),
            ],
          );

          expect(
            convertSpec(registry),
            equalsYaml(
              nestedExpectation(
                depth: depth,
                rootFlagEntries: [
                  '--auth?=: ""',
                  '--user?=: ""',
                  '--port?=: ""',
                ],
                persistentEntries: [
                  '--auth?=: ""',
                  '--user?=: ""',
                  '--port?=: ""',
                ],
              ),
            ),
          );
        });
      }
    });
  });
}
