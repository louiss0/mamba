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
          options: [PairStringOption(name: 'string-pair')],
        ),
        PairedIntOption(
          name: 'int',
          variant: true,
          options: [PairIntOption(name: 'int-pair')],
        ),
        PairedDoubleOption(
          name: 'double',
          variant: true,
          options: [PairDoubleOption(name: 'double-pair')],
        ),
        PairedChoiceOption<VariantChoice>(
          name: 'choice',
          choices: VariantChoice.values,
          variant: true,
          options: [
            PairChoiceOption<VariantChoice>(
              name: 'choice-pair',
              choices: VariantChoice.values,
            ),
          ],
        ),
        PairedRepeatableStringOption(
          name: 'repeated-string',
          variant: true,
          options: [PairRepeatableStringOption(name: 'repeated-string-pair')],
        ),
        PairedRepeatableIntOption(
          name: 'repeated-int',
          variant: true,
          options: [PairRepeatableIntOption(name: 'repeated-int-pair')],
        ),
        PairedRepeatableDoubleOption(
          name: 'repeated-double',
          variant: true,
          options: [PairRepeatableDoubleOption(name: 'repeated-double-pair')],
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
