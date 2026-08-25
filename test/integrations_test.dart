import 'package:mamba/command.dart';
import 'package:mamba/integrations.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum _Format { json, yaml }

enum _Level { debug, info }

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
name: "command"
description: "the command"
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
name: "command"
description: "the command"
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
name: "command"
description: "the command"
commands:
  - name: "sub"
    description: "a subcommand"
    flags:
      --retries=: ""'''),
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
name: "command"
description: "the command"
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
  --trace&*: ""'''),
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
  --retries=: ""'''),
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
  -r, --retries=: ""'''),
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
  --include*=: ""'''),
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
  -i, --include*=: ""'''),
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
  --debug-level&=: ""'''),
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
  -d, --debug-level&=: ""'''),
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
  --auth=: "credentials"
  -u, --user=: ""
  --port=: ""'''),
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
          final suffix =
              '${combo.repeatability ? '*' : ''}'
              '${combo.optionality ? '!' : ''}'
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
    flags:
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
  });
}
