import 'package:mamba/command.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/registry.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'package:test/test.dart';

String _withoutAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

final _hiddenInputRegistry = CommandRegistry.create(
  'tool',
  'Tool command.',
  options: [
    StringOption(
      'secret',
      description: 'Internal value.',
      regex: RegExp(r'\S+'),
      hidden: true,
    ),
  ],
);

void main() {
  group('Formatted strings', () {
    test('renders required strings in angle brackets', () {
      expect(() => RequiredString('value'), throwsFormatException);
      expect(
        RequiredString('value'.red),
        FormattedString('< ${'value'.red} >'),
      );
    });

    test('renders optional strings in square brackets', () {
      expect(() => OptionalString('[value]'.red), throwsFormatException);
      expect(() => OptionalString('value]'.red), throwsFormatException);
      expect(
        OptionalString('value'.red),
        FormattedString('[ ${'value'.red} ]'),
      );
    });
  });

  group('PairDSL', () {
    test('joins a primary member with paired members', () {
      expect(
        PairString('--username', ['--password']),
        FormattedString(MambaColors.bright('--username & --password')),
      );
    });

    test('preserves ANSI-styled members', () {
      final primaryMember = '--username'.bold;
      final pairMember = '--password'.red;

      expect(
        PairString(primaryMember, [pairMember]),
        FormattedString(MambaColors.bright('$primaryMember & $pairMember')),
      );
    });

    test(
      'preserves the primary member when no paired members are supplied',
      () {
        expect(
          PairString('--username', const []),
          FormattedString(MambaColors.bright('--username')),
        );
      },
    );
  });

  group('OrDSL', () {
    test('joins a primary member with alternative members', () {
      expect(
        OrString('--token', ['--apiKey']),
        FormattedString(MambaColors.mid('--token|--apiKey')),
      );
    });

    test('preserves ANSI-styled members', () {
      final primaryMember = '--token'.bold;
      final alternativeMember = '--apiKey'.red;

      expect(
        OrString(primaryMember, [alternativeMember]),
        FormattedString(MambaColors.mid('$primaryMember|$alternativeMember')),
      );
    });

    test('preserves the primary member when no alternatives are supplied', () {
      expect(
        OrString('--token', const []),
        FormattedString(MambaColors.mid('--token')),
      );
    });
  });

  group('Hidden inputs', () {
    final formatter = MambaHelpFormatter();

    test('does not display a hidden option from a top-level registry', () {
      final help = _withoutAnsi(formatter.format(_hiddenInputRegistry));

      expect(help, isNot(contains('secret')));
      expect(help, isNot(contains('Internal value.')));
    });

    for (final (:type, :flag) in <({String type, Flag flag})>[
      (
        type: 'boolean flag',
        flag: BooleanFlag(
          'debug',
          description: 'Enable debugging.',
          hidden: true,
        ),
      ),
      (
        type: 'count flag',
        flag: CountFlag(
          'verbose',
          description: 'Increase verbosity.',
          hidden: true,
        ),
      ),
    ]) {
      test('does not display a hidden $type', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          flags: [flag],
        );

        final help = _withoutAnsi(formatter.format(registry));

        expect(help, isNot(contains(flag.name)));
        expect(help, isNot(contains(flag.description)));
      });
    }

    for (final (:type, :option) in <({String type, Option option})>[
      (
        type: 'string option',
        option: StringOption(
          'token',
          description: 'Authentication token.',
          regex: RegExp(r'\S+'),
          hidden: true,
        ),
      ),
      (
        type: 'integer option',
        option: IntOption('retries', description: 'Retry count.', hidden: true),
      ),
      (
        type: 'double option',
        option: DoubleOption(
          'ratio',
          description: 'Sampling ratio.',
          hidden: true,
        ),
      ),
      (
        type: 'choice option',
        option: ChoiceOption(
          'format',
          description: 'Output format.',
          choices: _OutputFormat.values,
          hidden: true,
        ),
      ),
    ]) {
      test('does not display a hidden $type', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [option],
        );

        final help = _withoutAnsi(formatter.format(registry));

        expect(help, isNot(contains(option.name)));
        expect(help, isNot(contains(option.description)));
      });
    }

    for (final (:type, :accessor)
        in <({String type, AccessorListOption accessor})>[
          (
            type: 'accessor list option',
            accessor: AccessorListOption(
              'credentials',
              [AccessorStringOption('token')],
              description: 'Internal credentials.',
              hidden: true,
            ),
          ),
        ]) {
      test('does not display a hidden $type', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          accessors: [accessor],
        );

        final help = _withoutAnsi(formatter.format(registry));

        expect(help, isNot(contains(accessor.name)));
        expect(help, isNot(contains(accessor.description)));
      });
    }

    for (final (:type, :option) in <({String type, RepeatableOption option})>[
      (
        type: 'repeatable string option',
        option: RepeatableStringOption(
          'header',
          description: 'Additional header.',
          hidden: true,
        ),
      ),
      (
        type: 'repeatable integer option',
        option: RepeatableIntOption(
          'port',
          description: 'Additional port.',
          hidden: true,
        ),
      ),
      (
        type: 'repeatable double option',
        option: RepeatableDoubleOption(
          'weight',
          description: 'Additional weight.',
          hidden: true,
        ),
      ),
    ]) {
      test('does not display a hidden $type', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [option],
        );

        final help = _withoutAnsi(formatter.format(registry));

        expect(help, isNot(contains(option.name)));
        expect(help, isNot(contains(option.description)));
      });
    }
  });

  group('Nested hidden accessor lists', () {
    final formatter = MambaHelpFormatter();

    CommandRegistry createRegistryWithHiddenAccessorList(String? hiddenList) =>
        CommandRegistry.create(
          'platformctl',
          'Manage platform deployments.',
          accessors: [
            AccessorListOption('deployment', [
              AccessorListOption('runtime', [
                AccessorListOption('network', [
                  AccessorListOption('tls', [
                    AccessorListOption('client', [
                      AccessorStringOption(
                        'certificate',
                        description: 'mTLS client certificate.',
                      ),
                    ], hidden: hiddenList == 'client'),
                  ], hidden: hiddenList == 'tls'),
                ], hidden: hiddenList == 'network'),
              ], hidden: hiddenList == 'runtime'),
            ], hidden: hiddenList == 'deployment'),
          ],
        );

    test('renders a five-level accessor path when no list is hidden', () {
      final registry = createRegistryWithHiddenAccessorList(null);

      final help = _withoutAnsi(formatter.format(registry));

      expect(
        help,
        contains('deployment.runtime.network.tls.client.certificate'),
      );
      expect(help, contains('mTLS client certificate.'));
    });

    for (final hiddenList in [
      'deployment',
      'runtime',
      'network',
      'tls',
      'client',
    ]) {
      test('does not display descendants of hidden $hiddenList accessors', () {
        final registry = createRegistryWithHiddenAccessorList(hiddenList);

        final help = _withoutAnsi(formatter.format(registry));

        expect(
          help,
          isNot(contains('deployment.runtime.network.tls.client.certificate')),
        );
        expect(help, isNot(contains('mTLS client certificate.')));
      });
    }
  });

  group('HelpFormatter', () {
    test('styles descriptions and separates section titles from entries', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        longDescription: 'A longer description.',
        accessors: [
          AccessorListOption('config', [AccessorStringOption('path')]),
        ],
        commands: [_HelpCommand('run', 'Run the tool.')],
      );
      final lines = MambaHelpFormatter().format(registry).split('\n');
      final accessorTitleIndex = lines.indexOf(
        MambaColors.deep('Accessor flags'),
      );
      final commandTitleIndex = lines.indexOf(MambaColors.deep('Commands'));

      expect(lines[0], MambaColors.primary("tool  'Tool command.'"));
      expect(lines[1], isEmpty);
      expect(lines[2], MambaColors.mid('-' * 10));
      expect(lines[3], MambaColors.primary('A longer description.'));
      expect(lines[4], MambaColors.mid('-' * 10));
      expect(accessorTitleIndex, isNonNegative);
      expect(lines[accessorTitleIndex + 1], isEmpty);
      expect(commandTitleIndex, isNonNegative);
      expect(lines[commandTitleIndex + 1], isEmpty);
    });

    test('adds a black separator after every visible entry', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [BooleanFlag('verbose')],
      );
      final lines = MambaHelpFormatter().format(registry).split('\n');
      final entryIndex = lines.indexWhere(
        (line) => _withoutAnsi(line).contains('--verbose'),
      );
      expect(entryIndex, isNonNegative);
      final entry = lines[entryIndex];
      expect(
        lines[entryIndex + 1],
        MambaColors.black('_' * _withoutAnsi(entry).length),
      );
    });

    group('positional usage', () {
      test(
        'renders the names of choices for single and repeated positionals',
        () {
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
              RepeatedStringPositional('files', times: 1),
            ],
          );

          final help = _withoutAnsi(MambaHelpFormatter().format(registry));

          expect(
            help,
            startsWith(
              'tool < auto|always > < (auto|always){1,3} > [ files{1,2} ]',
            ),
          );
        },
      );

      test('renders a dash variadic after every bounded positional', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          mandatoryPositionals: [Positional('source')],
          discretionaryPositionals: [Positional('target')],
          variadic: NormalVariadic(),
        );

        final help = _withoutAnsi(MambaHelpFormatter().format(registry));

        expect(help, startsWith('tool < source > [ target ] [ -- ... ]'));
      });

      test('renders choice names for a choice variadic', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          variadic: ChoiceVariadic<_OutputFormat>(
            choices: _OutputFormat.values,
          ),
        );

        final help = _withoutAnsi(MambaHelpFormatter().format(registry));

        expect(help, startsWith('tool [ -- (json|yaml) ]'));
      });

      test('renders an ellipsis after repeated choice variadics', () {
        final registry = CommandRegistry.create(
          'tool',
          'Tool command.',
          variadic: RepeatedChoiceVariadic<_OutputFormat>(
            choices: _OutputFormat.values,
          ),
        );

        final help = _withoutAnsi(MambaHelpFormatter().format(registry));

        expect(help, startsWith('tool [ -- (json|yaml)... ]'));
      });
    });

    test('renders flags and value-taking options with literal tokens', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [BooleanFlag('verbose', short: 'v')],
        options: [
          StringOption('config-file', short: 'c', regex: RegExp(r'\S+')),
          RepeatableStringOption('tag', short: 't'),
        ],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('[ -v|--verbose ]'));
      expect(help, contains('[ -c|--config-file CONFIG_FILE ]'));
      expect(help, contains('[ (-t|--tag TAG)+ ]'));
    });

    test('renders required ordinary options with required grammar', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        options: [IntOption('count', required: true)],
      );

      final help = _withoutAnsi(MambaHelpFormatter().format(registry));

      expect(help, contains('< --count COUNT >'));
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
        flags: [BooleanFlag('verbose', short: 'v')],
        options: [
          StringOption('output', short: 'o', regex: RegExp(r'\S+')),
          RepeatableStringOption('header', short: 'H'),
        ],
        accessors: [
          AccessorListOption('tls', [AccessorStringOption('cert')]),
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

enum _OutputFormat { json, yaml }

enum _Mode { auto, always }

class _HelpCommand extends Command {
  new(this.name, this.shortDescription);

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
