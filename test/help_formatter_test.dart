import 'package:chalkdart/chalkstrings.dart';
import 'package:mamba/command.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

String _withoutAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

void main() {
  test('restores styled command and long-description output', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      longDescription: 'A longer description.',
    );

    final lines = MambaHelpFormatter().format(registry).split('\n');

    expect(lines[0], MambaColors.primary("tool  'Tool command.'"));
    expect(lines[1], isEmpty);
    expect(lines[2], MambaColors.mid('-' * 10));
    expect(lines[3], MambaColors.primary('A longer description.'));
    expect(lines[4], MambaColors.mid('-' * 10));
    expect(_withoutAnsi(lines.join('\n')), contains('Flags'));
    expect('styled'.red, isNot('styled'));
  });

  group('formatted grammar fragments', () {
    test('wraps required and optional values', () {
      expect(() => RequiredString('value'), throwsFormatException);
      expect(() => OptionalString('[value]'.red), throwsFormatException);
      expect(
        RequiredString('value'.red),
        FormattedString('< ${'value'.red} >'),
      );
      expect(
        OptionalString('value'.red),
        FormattedString('[ ${'value'.red} ]'),
      );
    });

    test('joins paired, alternative, and selectable members', () {
      expect(
        PairString('--user', ['--password']),
        FormattedString(MambaColors.bright('--user & --password')),
      );
      expect(
        OrString('--json', ['--yaml']),
        FormattedString(MambaColors.mid('--json|--yaml')),
      );
      expect(
        SelectionString('--host', ['--port']),
        FormattedString(MambaColors.mid('--host * --port')),
      );
    });
  });

  test('renders current flag and option variants', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      flags: [
        BooleanFlag('color', short: 'c', negatable: true),
        CountFlag('verbose', short: 'v'),
      ],
      options: [
        IntOption.required('count'),
        ChoiceOption.withDefault(
          'format',
          choices: _OutputFormat.values,
          defaultValue: _OutputFormat.json,
        ),
        RepeatableChoiceOption('tag', _Tag.values, short: 't', unique: true),
      ],
    );

    final help = _withoutAnsi(MambaHelpFormatter().format(registry));

    expect(help, contains('[ -c|--color|--no-color ]'));
    expect(help, contains('[ -v|--verbose ]'));
    expect(help, contains('< --count COUNT >'));
    expect(help, contains('[ --format (json|yaml) ]'));
    expect(help, contains('[ (-t|--tag (release|preview))+ ]'));
  });

  test('renders positional cardinality and variadic arguments', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      mandatoryPositionals: [
        ChoicePositional<_Mode>('mode', choices: _Mode.values),
        RepeatedChoicePositional<_Mode>(
          'modes',
          choices: _Mode.values,
          times: 2,
        ),
      ],
      discretionaryPositionals: [
        RepeatedStringPositional.optional('files', times: 2),
      ],
      variadic: NormalVariadic(
        description: 'Forward arguments to the child process.',
      ),
    );

    final help = _withoutAnsi(MambaHelpFormatter().format(registry));

    expect(
      help,
      startsWith(
        'tool < auto|always > < (auto|always){1,2} > '
        '[ files{1,2} ] -- ...',
      ),
    );
    expect(
      help,
      contains('Arguments\n\n-- ... Forward arguments to the child process.'),
    );
  });

  test('renders choice variadics without implying repetition', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      variadic: ChoiceVariadic<_OutputFormat>(choices: _OutputFormat.values),
    );

    final help = _withoutAnsi(MambaHelpFormatter().format(registry));

    expect(help, startsWith('tool -- (json|yaml)'));
    expect(help, isNot(contains('Arguments')));
  });

  test('renders paired and selected option semantics', () {
    final user = PairStringOption('user');
    final password = PairStringOption('password');
    final json = PairStringOption('json');
    final yaml = PairStringOption('yaml');
    final host = PairStringOption('host');
    final port = PairIntOption('port');
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      pairedOptions: [
        PairedOptions<String>.required([
          user,
          password,
        ], description: 'Login credentials.'),
      ],
      selectedOptionses: [
        SelectedOptions<String>.single([
          json,
          yaml,
        ], description: 'One output format.'),
        SelectedOptions<Object>.required([
          host,
          port,
        ], description: 'At least one endpoint setting.'),
      ],
    );

    final help = _withoutAnsi(MambaHelpFormatter().format(registry));

    expect(help, contains('< --user USER & --password PASSWORD >'));
    expect(help, contains('Login credentials.'));
    expect(help, contains('[ --json JSON|--yaml YAML ]'));
    expect(help, contains('One output format.'));
    expect(help, contains('< --host HOST * --port PORT >'));
    expect(help, contains('At least one endpoint setting.'));
  });

  group('accessor flags', () {
    test('renders nested, required, and choice leaves', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        accessors: [
          AccessorListOption('server', [
            AccessorStringOption.required('host', description: 'Server host.'),
            AccessorListOption('output', [
              AccessorChoiceOption<_OutputFormat>(
                'format',
                choices: _OutputFormat.values,
                description: 'Output format.',
              ),
            ]),
          ]),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('Accessor flags'));
      expect(help, contains('< --server.host SERVER_HOST >'));
      expect(help, contains('Server host.'));
      expect(help, contains('[ --server.output.format (json|yaml) ]'));
    });

    test('hides every descendant of a hidden accessor list', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        accessors: [
          AccessorListOption('public', [
            AccessorStringOption('value', description: 'Visible value.'),
          ]),
          AccessorListOption('internal', [
            AccessorListOption('credentials', [
              AccessorStringOption('token', description: 'Secret token.'),
            ]),
          ], hidden: true),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('--public.value PUBLIC_VALUE'));
      expect(help, isNot(contains('internal')));
      expect(help, isNot(contains('Secret token.')));
    });
  });

  test('omits hidden flags and options', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      flags: [BooleanFlag('debug', description: 'Debug output.', hidden: true)],
      options: [
        StringOption('secret', description: 'Internal value.', hidden: true),
        RepeatableIntOption(
          'internal-port',
          description: 'Internal port.',
          hidden: true,
        ),
      ],
    );

    final help = _withoutAnsi(MambaHelpFormatter().format(registry));

    expect(help, isNot(contains('debug')));
    expect(help, isNot(contains('secret')));
    expect(help, isNot(contains('internal-port')));
  });

  test('renders child commands and separates every visible entry', () {
    final registry = CommandRegistry.create(
      'tool',
      'Tool command.',
      flags: [BooleanFlag('verbose', description: 'Show details.')],
      commands: [
        _HelpCommand('config', 'Configure the tool.'),
        _HelpCommand('run', 'Run the tool.'),
      ],
    );
    final lines = MambaHelpFormatter().format(registry).split('\n');
    final verboseIndex = lines.indexWhere(
      (line) => _withoutAnsi(line).contains('--verbose'),
    );

    expect(verboseIndex, isNonNegative);
    expect(
      lines[verboseIndex + 1],
      MambaColors.black('_' * _withoutAnsi(lines[verboseIndex]).length),
    );
    expect(_withoutAnsi(lines.join('\n')), contains('Commands'));
    expect(
      _withoutAnsi(lines.join('\n')),
      contains('config Configure the tool.'),
    );
    expect(_withoutAnsi(lines.join('\n')), contains('run Run the tool.'));
  });
}

enum _OutputFormat { json, yaml }

enum _Tag { release, preview }

enum _Mode { auto, always }

final class _HelpCommand extends Command {
  new(this.name, this.shortDescription);

  @override
  final String name;

  @override
  final String shortDescription;

  @override
  String run(ParsedInputs inputs, List<String> args) => '';
}
