import 'package:arg_parser/errors.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

enum FactoryMode { first, second }

final class GroupCoverageCommand extends GroupCommand {
  GroupCoverageCommand()
    : super(
        'group',
        'Group command.',
        defaultSubCommandPath: null,
        longDescription: null,
        positionalSchema: null,
        accessorSchema: null,
        flagSchema: null,
        optionSchema: null,
        commands: null,
      );
}

void main() {
  group('Value object coverage', () {
    test('formats exception messages', () {
      expect(MambaException('message').toString(), 'MambaException message');
      expect(MambaRegistryError('message').message, 'message');
    });

    test('validates direct variadic formatting', () {
      expect(VariadicString('item'.red).string, contains('...'));
      expect(() => VariadicString('...item'.red), throwsFormatException);
    });

    test('formats every positional and accessor shape', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        positionalSchema: TestPositionalSchema.create(
          [Positional('source')],
          discretionary: [Positional('target')],
          variadic: Variadic('rest'),
        ),
        accessorSchema: TestAccessorOptionSchema.create([
          AccessorStringOption(name: 'user', description: 'User name.'),
        ]),
        optionSchema: TestOptionSchema.create([
          StringOption(name: 'required', required: true, regex: RegExp(r'\S+')),
          RepeatableStringOption(name: 'tags', required: true),
        ]),
      );

      final help = HelpFormatter().formatHelp(registry);

      expect(help, contains('source'));
      expect(help, contains('target'));
      expect(help, contains('rest'));
      expect(help, contains('user'));
      expect(help, contains('required'));
      expect(help, contains('tags'));
    });

    test('constructs option factories and default regular expressions', () {
      final singleString = Option.stringOption('string', RegExp(r'^value$'));
      final singleInt = Option.intOption('integer');
      final singleDouble = Option.doubleOption('double');
      final choice = Option.choiceOption('mode', FactoryMode.values);
      final repeatedInt = RepeatableOption.intOption(name: 'integers');
      final repeatedDouble = RepeatableOption.doubleOption(name: 'doubles');
      final repeatedString = RepeatableOption.stringOption(
        name: 'strings',
        regex: RegExp(r'^value$'),
      );

      expect(singleString.regex.hasMatch('value'), isTrue);
      expect(singleInt.name, 'integer');
      expect(singleDouble.name, 'double');
      expect(choice.choices, FactoryMode.values);
      expect(repeatedInt.name, 'integers');
      expect(repeatedDouble.name, 'doubles');
      expect(repeatedString.regex.hasMatch('value'), isTrue);
      expect(
        RepeatableStringOption(name: 'default').regex.hasMatch('value'),
        isTrue,
      );
      expect(AccessorIntOption(name: 'port').regex.hasMatch('80'), isTrue);
      expect(
        AccessorDoubleOption(name: 'timeout').regex.hasMatch('1.5'),
        isTrue,
      );
    });

    test('runs the default group command handler', () {
      final command = GroupCoverageCommand();

      command.run((
        flags: null,
        options: null,
        positionals: null,
        acessors: null,
        variadic: const [],
      ), const []);
    });
  });
}
