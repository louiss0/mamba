import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

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
