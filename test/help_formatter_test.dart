import 'package:arg_parser/command.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:test/test.dart';

String _withoutAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

void main() {
  group('Formatted strings', () {
    test('requires ANSI styling and valid delimiters', () {
      expect(() => RequiredString('value'), throwsFormatException);
      expect(() => RequiredString('< value >'.red), throwsFormatException);
      expect(RequiredString('value'.red).string, contains('value'));
    });

    test('rejects optional delimiters after removing ANSI styling', () {
      expect(() => OptionalString('[value]'.red), throwsFormatException);
      expect(() => OptionalString('value]'.red), throwsFormatException);
      expect(OptionalString('value'.red).string, contains('value'));
    });
  });

  group('PairDSL', () {
    test('joins a primary member with paired members', () {
      expect(
        PairString('--username', ['--password']).string,
        '--username & --password',
      );
    });

    test('preserves ANSI-styled members', () {
      final primaryMember = '--username'.bold;
      final pairMember = '--password'.red;

      expect(
        PairString(primaryMember, [pairMember]).string,
        '$primaryMember & $pairMember',
      );
    });

    test(
      'preserves the primary member when no paired members are supplied',
      () {
        expect(PairString('--username', const []).string, '--username');
      },
    );
  });

  group('OrDSL', () {
    test('joins a primary member with alternative members', () {
      expect(OrString('--token', ['--apiKey']).string, '--token | --apiKey');
    });

    test('preserves ANSI-styled members', () {
      final primaryMember = '--token'.bold;
      final alternativeMember = '--apiKey'.red;

      expect(
        OrString(primaryMember, [alternativeMember]).string,
        '$primaryMember | $alternativeMember',
      );
    });

    test('preserves the primary member when no alternatives are supplied', () {
      expect(OrString('--token', const []).string, '--token');
    });
  });

  group('HelpFormatter', () {
    test('renders optional paired options as one PairDSL expression', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          PairedStringOption(
            name: 'username',
            short: 'u',
            description: 'Username',
            options: [
              PairStringOption(
                name: 'password',
                short: 'p',
                description: 'Password',
              ),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('[ --username | -u & --password | -p ] Username; Password'),
      );
    });

    test('renders variants as one OrDSL expression', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          PairedStringOption(
            name: 'token',
            variant: true,
            description: 'Token',
            options: [PairStringOption(name: 'apiKey', description: 'API key')],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('[ --token | --apiKey ] Token; API key'));
    });

    test('renders required ordinary options with required grammar', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        options: [IntOption(name: 'count', required: true)],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('< count >'));
    });

    test('renders paired groups after ordinary options', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        options: [StringOption(name: 'region', regex: RegExp(r'\S+'))],
        pairedOptions: [
          PairedStringOption(
            name: 'username',
            options: [PairStringOption(name: 'password')],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('[ region ]'));
      expect(help, contains('--username'));
      expect(help.indexOf('[ region ]'), lessThan(help.indexOf('--username')));
    });

    test('keeps empty description slots for paired members', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          PairedStringOption(
            name: 'username',
            description: 'Username',
            options: [
              PairStringOption(name: 'password'),
              PairStringOption(name: 'tenant', description: 'Tenant'),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('[ --username & --password & --tenant ] Username; ; Tenant'),
      );
    });

    test('renders required paired options as one required expression', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          PairedStringOption(
            name: 'clientId',
            required: true,
            description: 'Client ID',
            options: [
              PairStringOption(
                name: 'clientSecret',
                description: 'Client secret',
              ),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('< --clientId & --clientSecret > Client ID; Client secret'),
      );
    });

    test('marks a repeatable paired primary member', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          RepeatablePairedStringOption(
            name: 'header',
            short: 'H',
            description: 'Header',
            options: [
              PairStringOption(name: 'requestId', description: 'Request ID'),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('[ ...--header | -H & --requestId ] Header; Request ID'),
      );
    });

    test('marks a repeatable paired child member', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          PairedStringOption(
            name: 'session',
            description: 'Session',
            options: [
              RepeatablePairStringOption(
                name: 'header',
                short: 'H',
                description: 'Header',
              ),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('[ --session & ...--header | -H ] Session; Header'),
      );
    });

    test('marks int and double repeatable paired members', () {
      final registry = CommandRegistry.create(
        'login',
        'Authenticate a user.',
        pairedOptions: [
          RepeatablePairedIntOption(
            name: 'port',
            description: 'Port',
            options: [
              RepeatablePairDoubleOption(name: 'weight', description: 'Weight'),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('[ ...--port & ...--weight ] Port; Weight'));
    });

    test('renders child commands with their descriptions', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        commands: [
          _HelpCommand('config', 'Configure the tool.'),
          _HelpCommand('run', 'Run the tool.'),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('Commands'));
      expect(help, contains('config Configure the tool.'));
      expect(help, contains('run Run the tool.'));
    });

    test('formats list-defined command inputs and nested accessors', () {
      final registry = CommandRegistry.create(
        'curl',
        'Transfer data.',
        longDescription: 'A compact HTTP client.',
        flags: [BooleanFlag(name: 'verbose', short: 'v')],
        options: [
          StringOption(name: 'output', short: 'o', regex: RegExp(r'\S+')),
          RepeatableStringOption(name: 'header', short: 'H'),
        ],
        accessors: [
          AccessorListOption(
            name: 'tls',
            options: [AccessorStringOption(name: 'cert')],
          ),
        ],
        mandatoryPositionals: [Positional('url')],
        discretionaryPositionals: [Positional('output')],
      );

      final help = MambaHelpFormatter().format(registry);

      expect(help, contains('curl'));
      expect(help, contains('url'));
      expect(help, isNot(contains('arguments')));
      expect(help, contains('verbose'));
      expect(help, contains('output'));
      expect(help, contains('header'));
      expect(help, contains('tls.cert'));
    });
  });
}

class _HelpCommand extends Command {
  _HelpCommand(this.name, this.shortDescription);

  @override
  final String name;

  @override
  final String shortDescription;

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => '';
}
