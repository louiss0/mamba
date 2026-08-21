import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum VariantChoice { one }

void main() {
  group('CommandRegistry', () {
    group("toMap", () {
      test("makes the map based on the inputs ", () {
        final color = BooleanFlag(name: 'color');
        final verbose = CountFlag(name: 'verbose');
        final name = StringOption(name: 'name', regex: RegExp(r'\S+'));
        final tag = RepeatableStringOption(name: 'tag');
        final source = Positional('source');
        final target = Positional('target');

        final profile = AccessorListOption(
          name: 'user',
          options: [AccessorStringOption(name: 'profile')],
        );

        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [color, verbose],
          options: [name, tag],
          accessors: [profile],
          mandatoryPositionals: [source],
          discretionaryPositionals: [target],
        );

        expect(
          registry.toMap(),
          equals({
            'name': "tool",
            'description': "Tool command.",
            'flags': {
              'color': {
                'short': null,
                'default': false,
                'negatable': true,
                'hidden': false,
                "description": null,
              },
              'verbose': {'hidden': false, "description": null},
            },
            'options': {
              'name': {
                'short': null,
                'required': false,
                'hidden': false,
                "description": null,
              },
              'tag': {
                'short': null,
                'required': false,
                'hidden': false,
                "description": null,
                'repeatable': true,
              },
            },
            'positionals': {
              'source': {'required': true, "description": null},
              'target': {'required': false, "description": null},
            },
            'accessors': {
              'user': {
                'description': null,
                'options': {
                  'profile': {'description': null},
                },
              },
            },
          }),
        );
      });

      test("When a long description is added it's added to the description", () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          longDescription: "This is a tool meant to be used to make ",
        );

        expect(
          registry.toMap(),
          equals({
            'name': 'tool',
            'description':
                'Tool command.\n\nThis is a tool meant to be used to make ',
          }),
        );

        test(
          "When a command is added it's added to a commands prop that's a map",
          () {
            final registry = CommandRegistry.create(
              'git',
              'Save snapshots of your code and be able to send them anywhere',
              commands: [
                TestCommand('add', 'Add a file to the staging area'),
                TestCommand('commit', 'Take a snapshot of your code'),
                TestGroupCommand(
                  "worktree",
                  [
                    TestCommand(
                      'add',
                      'Make a new work tree',
                      mandatoryPositionals: [
                        Positional(
                          'path',
                          description: 'The path to the work tree',
                        ),
                      ],
                      discretionaryPositionals: [
                        Positional(
                          "commit-ish",
                          description:
                              "Choosse a commit to use to scaffold the worktree",
                        ),
                      ],
                    ),
                    TestCommand('commit', 'Take a snapshot of your code'),
                  ],
                  "Place your code in separate repo that can be merged",
                ),
              ],
            );

            expect(
              registry.toMap(),
              equals({
                'name': 'git',
                'description':
                    'Save snapshots of your code and be able to send them anywhere',
                'commands': {
                  'add': {'description': 'Add a file to the staging area'},
                  'commit': {'description': 'Take a snapshot of your code'},
                  'worktree': {
                    'description':
                        'Place your code in separate repo that can be merged',
                    'commands': {
                      'add': {
                        'description': 'Make a new work tree',
                        'positionals': {
                          'path': {
                            'required': true,
                            'description': 'The path to the work tree',
                          },
                          'commit-ish': {
                            'required': false,
                            'description':
                                "Choosse a commit to use to scaffold the worktree",
                          },
                        },
                      },
                      'commit': {'description': 'Take a snapshot of your code'},
                    },
                  },
                },
              }),
            );
          },
        );
      });

      test("Adds commands recursively", () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('sub', 'Sub command.'),
            TestGroupCommand('dg1', [
              TestGroupCommand('dg2', [
                TestGroupCommand('dg3', [
                  TestGroupCommand('dg4', [
                    TestGroupCommand('dg5', [
                      TestCommand('sub', 'Sub command.'),
                    ], ''),
                  ], ''),
                ], ''),
              ], ''),
            ], ''),
          ],
        );

        expect(
          registry.toMap(),
          equals({
            'name': 'tool',
            'description': "Tool command",
            'commands': {
              'sub': {'description', "Sub command"},
              'dg1': {
                'commands': {
                  'dg2': {
                    'commands': {
                      'dg3': {
                        'commands': {
                          'dg4': {
                            'commands': {
                              'dg5': {
                                'description': 'dg5',
                                'commands': {
                                  'sub': {'description': 'Sub command'},
                                },
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          }),
        );
      });
    });

    test('indexes list-defined inputs by their names', () {
      final color = BooleanFlag(name: 'color');
      final verbose = CountFlag(name: 'verbose');
      final name = StringOption(name: 'name', regex: RegExp(r'\S+'));
      final tag = RepeatableStringOption(name: 'tag');
      final source = Positional('source');
      final target = Positional('target');
      final profile = AccessorStringOption(name: 'profile');

      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [color, verbose],
        options: [name, tag],
        accessors: [profile],
        mandatoryPositionals: [source],
        discretionaryPositionals: [target],
      );

      expect(registry.boolFlags, {'color': color});
      expect(registry.helpFlag.short, 'h');
      expect(registry.countFlags, {'verbose': verbose});
      expect(registry.singleOptions, {'name': name});
      expect(registry.repeatedOptions, {'tag': tag});
      expect(registry.mandatoryPositionals, {'source': source});
      expect(registry.discretionaryPositionals, {'target': target});
      expect(registry.accessors, {'profile': profile});
    });

    test('indexes paired options by their group name', () {
      final credentials = PairedStringOption(
        name: 'username',
        options: [PairStringOption(name: 'password')],
      );

      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        pairedOptions: [credentials],
      );

      expect(registry.pairedOptions, {'username': credentials});
    });

    test('defaults paired options to grouping', () {
      final credentials = PairedStringOption(
        name: 'username',
        options: [PairStringOption(name: 'password')],
      );

      expect(credentials.variant, isFalse);
    });

    test('supports variants for every paired option type', () {
      final variants = <PairedOption>[
        PairedStringOption(
          name: 'string',
          variant: true,
          options: [PairStringOption(name: 'stringPair')],
        ),
        PairedIntOption(
          name: 'int',
          variant: true,
          options: [PairIntOption(name: 'intPair')],
        ),
        PairedDoubleOption(
          name: 'double',
          variant: true,
          options: [PairDoubleOption(name: 'doublePair')],
        ),
        PairedChoiceOption<VariantChoice>(
          name: 'choice',
          choices: VariantChoice.values,
          variant: true,
          options: [
            PairChoiceOption<VariantChoice>(
              name: 'choicePair',
              choices: VariantChoice.values,
            ),
          ],
        ),
        RepeatablePairedStringOption(
          name: 'repeatedString',
          variant: true,
          options: [RepeatablePairStringOption(name: 'repeatedStringPair')],
        ),
        RepeatablePairedIntOption(
          name: 'repeatedInt',
          variant: true,
          options: [RepeatablePairIntOption(name: 'repeatedIntPair')],
        ),
        RepeatablePairedDoubleOption(
          name: 'repeatedDouble',
          variant: true,
          options: [RepeatablePairDoubleOption(name: 'repeatedDoublePair')],
        ),
      ];

      expect(variants.map((option) => option.variant), everyElement(isTrue));
    });

    test('rejects paired options without a paired member', () {
      expect(
        () => CommandRegistry.create(
          'login',
          'Authenticate a user.',
          pairedOptions: [PairedStringOption(name: 'username', options: [])],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('creates registries for list-defined child commands', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestCommand(
            'config',
            'Configure the tool.',
            accessors: [
              AccessorListOption(
                name: 'server',
                options: [AccessorIntOption(name: 'port')],
              ),
            ],
          ),
        ],
      );

      final config = registry.commandRegistries!.single;
      expect(config.name, 'config');
      expect(
        (config.accessors!['server']! as AccessorListOption)
            .options
            .single
            .name,
        'port',
      );
    });

    test('reserves the built-in help flag name and alias', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'help')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'custom', short: 'h')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('resolves the command whose help was requested', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [CountFlag(name: 'verbose', short: 'v')],
        commands: [TestGroupCommand('config', [], 'Configure the tool.')],
      );

      expect(registry.requestsHelp(['config', '--help']), isTrue);
      expect(registry.requestsHelp(['--', '--help']), isFalse);
      expect(
        registry.registryForArguments(['--verbose', 'config', '-h']).name,
        'config',
      );
    });

    test('group commands publish explicit inputs to descendants', () {
      final inheritedFlag = BooleanFlag(name: 'color');
      final inheritedOption = IntOption(name: 'retries');
      final localFlag = BooleanFlag(name: 'color', description: 'child');
      final localOption = IntOption(name: 'retries', description: 'child');
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestGroupCommand(
            'config',
            [
              TestCommand(
                'get',
                'Get configuration.',
                flags: [localFlag],
                options: [localOption],
              ),
            ],
            'Configure.',
            inheritedFlags: [inheritedFlag],
            inheritedOptions: [inheritedOption],
          ),
        ],
      );

      final group = registry.commandRegistries!.single;
      final child = group.commandRegistries!.single;
      expect(group.boolFlags!['color'], same(inheritedFlag));
      expect(group.singleOptions!['retries'], same(inheritedOption));
      expect(child.boolFlags!['color'], same(localFlag));
      expect(child.singleOptions!['retries'], same(localOption));
    });

    test('only group commands register child commands', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestGroupCommand(
            'config',
            [TestCommand('get', 'Get configuration.')],
            'Configure.',
            flags: [BooleanFlag(name: 'color')],
            options: [IntOption(name: 'retries')],
          ),
        ],
      );

      final group = registry.commandRegistries!.single;
      final child = group.commandRegistries!.single;
      expect(group.boolFlags, contains('color'));
      expect(group.singleOptions, contains('retries'));
      expect(child.boolFlags, isNull);
      expect(child.singleOptions, isNull);
    });

    test('distinguishes absent input collections from empty collections', () {
      final absent = CommandRegistry.create('tool', 'Tool command.');
      final empty = CommandRegistry.create(
        'tool',
        'Tool command.',
        options: const [],
      );

      expect(absent.singleOptions, isNull);
      expect(empty.singleOptions, isEmpty);
    });

    test('rejects invalid command and description boundaries', () {
      for (final name in ['', 'tool1', '_', '-', 'tool!']) {
        expect(
          () => CommandRegistry.create(name, 'Tool command.'),
          throwsA(anyOf(isA<MambaException>(), isA<MambaRegistryError>())),
        );
      }
      expect(
        () => CommandRegistry.create('tool', ''),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create('tool', 'x' * 150),
        throwsA(isA<MambaException>()),
      );
      expect(() => CommandRegistry.create('tool', 'x' * 149), returnsNormally);
    });

    test('accepts letter-led alphanumeric and hyphenated input names', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [
          BooleanFlag(name: 'verbose2', short: 'v'),
          BooleanFlag(name: 'dry-run'),
        ],
        options: [
          IntOption(name: 'retry2', short: 'r'),
          IntOption(name: 'back-off'),
        ],
      );

      expect(registry.boolFlags, contains('verbose2'));
      expect(registry.boolFlags, contains('dry-run'));
      expect(registry.singleOptions, contains('retry2'));
      expect(registry.singleOptions, contains('back-off'));
    });

    test('rejects input names outside the letter-led supported form', () {
      for (final name in ['2fast', 'dry_run', 'verbose!']) {
        expect(
          () => CommandRegistry.create(
            'tool',
            'Tool command.',
            flags: [BooleanFlag(name: name)],
          ),
          throwsA(isA<MambaRegistryError>()),
        );
        expect(
          () => CommandRegistry.create(
            'tool',
            'Tool command.',
            options: [IntOption(name: name)],
          ),
          throwsA(isA<MambaRegistryError>()),
        );
      }
    });

    test('rejects non-letter short aliases', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'verbose', short: '2')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [IntOption(name: 'retry', short: '-')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects invalid input and positional symbols', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [StringOption(name: 'bad!', regex: RegExp(r'.+'))],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('bad!')],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('recursively validates nested accessor names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              name: 'server',
              options: [
                AccessorListOption(
                  name: 'authentication',
                  options: [AccessorStringOption(name: 'help')],
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects collisions between accessors and other inputs', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [AccessorStringOption(name: 'profile')],
          flags: [BooleanFlag(name: 'profile')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [AccessorStringOption(name: 'profile')],
          options: [StringOption(name: 'profile', regex: RegExp(r'.+'))],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects positional collisions', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('source')],
          discretionaryPositionals: [Positional('source')],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('config')],
          commands: [TestCommand('config', 'Configure.')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects duplicate command names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('config', 'Configure.'),
            TestCommand('config', 'Configure again.'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects conflicting flag and option names', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'verbose')],
          options: [IntOption(name: 'verbose')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects conflicting short aliases', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'verbose', short: 'v')],
          options: [IntOption(name: 'version', short: 'v')],
        ),
        throwsA(isA<MambaException>()),
      );
    });

    test('rejects invalid and duplicate list definitions', () {
      expect(
        () => CommandRegistry.create('bad name', 'Tool command.'),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [
            BooleanFlag(name: 'verbose'),
            BooleanFlag(name: 'verbose'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [
            StringOption(name: 'name', regex: RegExp(r'\S+')),
            RepeatableStringOption(name: 'name'),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [
            AccessorListOption(
              name: 'remote',
              options: [
                AccessorStringOption(name: 'url'),
                AccessorStringOption(name: 'url'),
              ],
            ),
          ],
        ),
        throwsA(isA<MambaException>()),
      );
    });
  });

  group('processes aliases correctly', () {
    test('indexes command aliases by alias and command name', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          TestCommand('checkout', 'Checkout.', aliases: ['co', 'check']),
        ],
      );

      expect(registry.aliases, {'co': 'checkout', 'check': 'checkout'});
      expect(registry.registryForArguments(['co']).name, 'checkout');
      expect(registry.registryForArguments(['check']).name, 'checkout');
    });

    test('throws a Mamba error for duplicate aliases on one command', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['co', 'co']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    test('rejects an alias already registered by another command', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['co']),
            TestCommand('config', 'Configure.', aliases: ['co']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            allOf(contains('already registered'), contains('pick another one')),
          ),
        ),
      );
    });

    test('rejects an alias equal to its command name', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            TestCommand('checkout', 'Checkout.', aliases: ['checkout']),
          ],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    test('rejects an explicitly empty alias list', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [TestCommand('checkout', 'Checkout.', aliases: const [])],
        ),
        throwsA(
          isA<MambaException>().having(
            (error) => error.message,
            'message',
            contains('tool checkout'),
          ),
        ),
      );
    });

    for (final depth in [1, 2, 3, 4, 5]) {
      for (final violation in _AliasViolation.values) {
        test('reports the command path for $violation at depth $depth', () {
          final commandPath = ['tool', ..._groupNames.take(depth)];
          final invalidCommand = _nestedCommandWithAliasViolation(
            depth,
            violation,
          );
          final path = violation == _AliasViolation.duplicateAcrossCommands
              ? [...commandPath, 'second']
              : [...commandPath, 'leaf'];

          expect(
            () => CommandRegistry.create(
              'tool',
              'Tool command.',
              commands: [invalidCommand],
            ),
            throwsA(
              isA<MambaException>().having(
                (error) => error.message,
                'message',
                contains(path.join(' ')),
              ),
            ),
          );
        });
      }
    }
  });
}

const _groupNames = ['one', 'two', 'three', 'four', 'five'];

enum _AliasViolation {
  duplicateOnCommand,
  duplicateAcrossCommands,
  sameAsCommand,
  empty,
}

Command _nestedCommandWithAliasViolation(int depth, _AliasViolation violation) {
  final groupNames = _groupNames.take(depth).toList();
  final command = switch (violation) {
    _AliasViolation.duplicateAcrossCommands => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('first', 'First.', aliases: ['shared']),
        TestCommand('second', 'Second.', aliases: ['shared']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.duplicateOnCommand => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('leaf', 'Leaf.', aliases: ['leaf-alias', 'leaf-alias']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.sameAsCommand => TestGroupCommand(
      groupNames.last,
      [
        TestCommand('leaf', 'Leaf.', aliases: ['leaf']),
      ],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
    _AliasViolation.empty => TestGroupCommand(
      groupNames.last,
      [TestCommand('leaf', 'Leaf.', aliases: const [])],
      'Group.',
      aliases: ['group-alias-${groupNames.last}'],
    ),
  };

  var nested = command;
  for (var index = depth - 2; index >= 0; index--) {
    nested = TestGroupCommand(
      groupNames[index],
      [nested],
      'Group.',
      aliases: ['group-alias-${groupNames[index]}'],
    );
  }
  return nested;
}
