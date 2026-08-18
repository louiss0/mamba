import 'package:arg_parser/command.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';
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

    test('inherits parent flags while allowing local overrides', () {
      final inherited = BooleanFlag(name: 'color', description: 'parent');
      final local = BooleanFlag(name: 'color', description: 'child');
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [inherited],
        inheritFlags: true,
        commands: [
          TestCommand('config', 'Configure.', flags: [local]),
        ],
      );

      expect(
        registry.commandRegistries!.single.boolFlags!['color'],
        same(local),
      );
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

    test(
      'accepts alphanumeric option and flag names starting with a letter',
      () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [BooleanFlag(name: 'verbose2', short: 'v')],
          options: [IntOption(name: 'retry2', short: 'r')],
        );

        expect(registry.boolFlags, contains('verbose2'));
        expect(registry.singleOptions, contains('retry2'));
      },
    );

    test(
      'rejects option and flag names that are not letter-led alphanumeric',
      () {
        for (final name in ['2fast', 'dry-run', 'dry_run', 'verbose!']) {
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
      },
    );

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
