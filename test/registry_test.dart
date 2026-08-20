import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum VariantChoice { one }

void main() {
  group('CommandRegistry', () {
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
}
