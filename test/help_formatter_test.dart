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
      expect(OrString('--token', ['--api-key']).string, '--token | --api-key');
    });

    test('preserves ANSI-styled members', () {
      final primaryMember = '--token'.bold;
      final alternativeMember = '--api-key'.red;

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
            options: [
              PairStringOption(name: 'api-key', description: 'API key'),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('[ --token | --api-key ] Token; API key'));
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
            name: 'client-id',
            required: true,
            description: 'Client ID',
            options: [
              PairStringOption(
                name: 'client-secret',
                description: 'Client secret',
              ),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('< --client-id & --client-secret > Client ID; Client secret'),
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
              PairStringOption(name: 'request-id', description: 'Request ID'),
            ],
          ),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(
        help,
        contains('[ ...--header | -H & --request-id ] Header; Request ID'),
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
