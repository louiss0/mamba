import 'package:mamba/command.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<AccessorOption>? accessors,
  List<PairedOption>? pairedOptions,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
  List<Command>? commands,
}) => Parser(
  CommandRegistry.create(
    'tool',
    'Coverage command.',
    flags: flags,
    options: options,
    accessors: accessors,
    pairedOptions: pairedOptions,
    mandatoryPositionals: mandatoryPositionals,
    discretionaryPositionals: discretionaryPositionals,
    commands: commands,
  ),
);

void expectParseError(Parser subject, List<String> args) {
  expect(() => subject.parse(args), throwsA(isA<MambaParseException>()));
}

void main() {
  group('Parser output', () {
    test('returns separate, typed maps for every input category', () {
      final subject = parser(
        flags: [
          BooleanFlag(name: 'color', negatable: true),
          CountFlag(name: 'verbose', short: 'v'),
        ],
        options: [
          StringOption(name: 'name', regex: RegExp(r'^Ada$')),
          IntOption(name: 'retries'),
          DoubleOption(name: 'ratio'),
          ChoiceOption<Mode>(
            name: 'mode',
            choices: Mode.values,
            defaultValue: Mode.auto,
          ),
          RepeatableStringOption(name: 'tag', regex: RegExp(r'^\w+$')),
          RepeatableIntOption(name: 'port'),
          RepeatableDoubleOption(name: 'weight'),
        ],
        accessors: [
          AccessorListOption(
            name: 'server',
            options: [
              AccessorIntOption(name: 'port'),
              AccessorDoubleOption(name: 'timeout'),
            ],
          ),
        ],
        mandatoryPositionals: [Positional('source')],
        discretionaryPositionals: [Positional('target')],
      );

      final result = subject.parse([
        'input.txt',
        'output.txt',
        '--no-color',
        '-vv',
        '--name=Ada',
        '--retries',
        '2',
        '--ratio',
        '1.5',
        '--tag',
        'first',
        '--tag=second',
        '--port',
        '80',
        '--port=443',
        '--weight',
        '0.5',
        '--weight=1.5',
        '--server.port',
        '8080',
        '--server.timeout=2.5',
      ]);
      final inputs = result.$3;

      expect(inputs.boolFlags, {'color': false});
      expect(inputs.countFlags, {'verbose': 2});
      expect(inputs.stringOptions, {'name': 'Ada', 'mode': 'auto'});
      expect(inputs.intOptions, {'retries': 2});
      expect(inputs.doubleOptions, {'ratio': 1.5});
      expect(inputs.repeatedStringOptions, {
        'tag': ['first', 'second'],
      });
      expect(inputs.repeatedIntOptions, {
        'port': [80, 443],
      });
      expect(inputs.repeatedDoubleOptions, {
        'weight': [0.5, 1.5],
      });
      expect(inputs.accessors, {
        'server': {'port': 8080, 'timeout': 2.5},
      });
      expect(result.$2, {'source': 'input.txt', 'target': 'output.txt'});
    });

    test('returns nullable maps according to registered content', () {
      final result = parser().parse([]);
      final inputs = result.$3;

      expect(inputs.boolFlags, isNull);
      expect(inputs.countFlags, isNull);
      expect(inputs.stringOptions, isNull);
      expect(inputs.intOptions, isNull);
      expect(inputs.doubleOptions, isNull);
      expect(inputs.repeatedStringOptions, isNull);
      expect(inputs.repeatedIntOptions, isNull);
      expect(inputs.repeatedDoubleOptions, isNull);
      expect(inputs.accessors, isNull);
      expect(result.$2, isNull);
    });

    test('returns choice options in the string option map', () {
      final inputs = parser(
        options: [
          ChoiceOption<Mode>(
            name: 'mode',
            choices: Mode.values,
            defaultValue: Mode.auto,
          ),
        ],
      ).parse([]).$3;

      expect(inputs.stringOptions, {'mode': 'auto'});
    });

    test('adds Boolean defaults only to Boolean flag maps', () {
      final inputs = parser(
        flags: [
          BooleanFlag(name: 'color', defaultValue: true),
          CountFlag(name: 'verbose'),
        ],
      ).parse([]).$3;

      expect(inputs.boolFlags, {'color': true});
      expect(inputs.countFlags, isEmpty);
    });

    test('collects arguments after -- separately from inputs', () {
      final result = parser().parse(['--', '--unknown', '-x']);

      expect(result.$2, isNull);
      expect(result.$1, isEmpty);
      expect(result.$3.accessors, isNull);
      expect(result.$4, ['--unknown', '-x']);
    });

    test('does not parse arguments after -- as options or positionals', () {
      final result = parser(
        mandatoryPositionals: [Positional('source')],
      ).parse(['source', '--', '--unknown', 'extra']);

      expect(result.$2, {'source': 'source'});
      expect(result.$4, ['--unknown', 'extra']);
    });
  });

  group('Parser definitions', () {
    test('accepts accessor lists at the root and at nested paths', () {
      final subject = parser(
        accessors: [
          AccessorStringOption(name: 'profile', regex: RegExp(r'^ada$')),
          AccessorListOption(
            name: 'remote',
            options: [
              AccessorListOption(
                name: 'origin',
                options: [AccessorStringOption(name: 'url')],
              ),
            ],
          ),
        ],
      );

      final inputs = subject.parse([
        '--profile',
        'ada',
        '--remote.origin.url',
        'https://example.com',
      ]).$3;

      expect(inputs.accessors, {
        'profile': 'ada',
        'remote': {
          'origin': {'url': 'https://example.com'},
        },
      });
    });

    test('renders list-defined inputs in help', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [BooleanFlag(name: 'verbose')],
        options: [StringOption(name: 'name', regex: RegExp(r'\S+'))],
        accessors: [AccessorStringOption(name: 'profile')],
        mandatoryPositionals: [Positional('source')],
      );

      final help = MambaHelpFormatter().format(registry);

      expect(
        help,
        allOf(contains('verbose'), contains('name'), contains('profile')),
      );
    });
  });

  group('Paired options', () {
    test('parses paired string, int, and double options', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            name: 'firstName',
            options: [PairStringOption(name: 'lastName')],
          ),
          PairedIntOption(
            name: 'minimum',
            options: [PairIntOption(name: 'maximum')],
          ),
          PairedDoubleOption(
            name: 'minimumRatio',
            options: [PairDoubleOption(name: 'maximumRatio')],
          ),
        ],
      );

      final inputs = subject.parse([
        '--firstName',
        'Ada',
        '--lastName',
        'Lovelace',
        '--minimum',
        '1',
        '--maximum',
        '2',
        '--minimumRatio',
        '0.5',
        '--maximumRatio',
        '1.5',
      ]).$3;

      expect(inputs.stringOptions, {
        'firstName': 'Ada',
        'lastName': 'Lovelace',
      });
      expect(inputs.intOptions, {'minimum': 1, 'maximum': 2});
      expect(inputs.doubleOptions, {'minimumRatio': 0.5, 'maximumRatio': 1.5});
    });

    test('parses paired repeatable string, int, and double options', () {
      final subject = parser(
        pairedOptions: [
          RepeatablePairedStringOption(
            name: 'name',
            options: [RepeatablePairStringOption(name: 'value')],
          ),
          RepeatablePairedIntOption(
            name: 'minimum',
            options: [RepeatablePairIntOption(name: 'maximum')],
          ),
          RepeatablePairedDoubleOption(
            name: 'minimumWeight',
            options: [RepeatablePairDoubleOption(name: 'maximumWeight')],
          ),
        ],
      );

      final inputs = subject.parse([
        '--name',
        'Accept',
        '--value',
        'application/json',
        '--name',
        'Cache-Control',
        '--value',
        'no-cache',
        '--minimum',
        '1',
        '--maximum',
        '2',
        '--minimum',
        '3',
        '--maximum',
        '4',
        '--minimumWeight',
        '0.5',
        '--maximumWeight',
        '1.5',
        '--minimumWeight',
        '2.5',
        '--maximumWeight',
        '3.5',
      ]).$3;

      expect(inputs.repeatedStringOptions, {
        'name': ['Accept', 'Cache-Control'],
        'value': ['application/json', 'no-cache'],
      });
      expect(inputs.repeatedIntOptions, {
        'minimum': [1, 3],
        'maximum': [2, 4],
      });
      expect(inputs.repeatedDoubleOptions, {
        'minimumWeight': [0.5, 2.5],
        'maximumWeight': [1.5, 3.5],
      });
    });

    test('rejects a partially passed repeatable pair', () {
      final subject = parser(
        pairedOptions: [
          RepeatablePairedStringOption(
            name: 'name',
            options: [RepeatablePairStringOption(name: 'value')],
          ),
        ],
      );

      expectParseError(subject, [
        '--name',
        'Accept',
        '--name',
        'Cache-Control',
      ]);
    });

    final pairCases = [
      (
        description: 'string and int options',
        group: PairedStringOption(
          name: 'host',
          options: [PairIntOption(name: 'port')],
        ),
        arguments: ['--host', 'localhost', '--port', '8080'],
        missingArguments: ['--host', 'localhost'],
      ),
      (
        description: 'string and double options',
        group: PairedStringOption(
          name: 'label',
          options: [PairDoubleOption(name: 'value')],
        ),
        arguments: ['--label', 'warning', '--value', '0.8'],
        missingArguments: ['--value', '0.8'],
      ),
      (
        description: 'int and double options',
        group: PairedIntOption(
          name: 'retries',
          options: [PairDoubleOption(name: 'delay')],
        ),
        arguments: ['--retries', '3', '--delay', '1.5'],
        missingArguments: ['--retries', '3'],
      ),
    ];

    for (final (:description, :group, :arguments, :missingArguments)
        in pairCases) {
      test('parses $description when both options are passed', () {
        expect(
          () => parser(pairedOptions: [group]).parse(arguments),
          returnsNormally,
        );
      });

      test('rejects $description when one option is missing', () {
        expectParseError(parser(pairedOptions: [group]), missingArguments);
      });
    }
  });

  group('Paired option variants', () {
    test('accepts one optional variant member', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            name: 'token',
            variant: true,
            options: [PairStringOption(name: 'apiKey')],
          ),
        ],
      );

      expect(() => subject.parse(['--token', 'secret']), returnsNormally);
    });

    test('rejects multiple variant members', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            name: 'token',
            variant: true,
            options: [PairStringOption(name: 'apiKey')],
          ),
        ],
      );

      expectParseError(subject, ['--token', 'secret', '--apiKey', 'key']);
    });

    test('accepts one repeatable variant member', () {
      final subject = parser(
        pairedOptions: [
          RepeatablePairedStringOption(
            name: 'tag',
            variant: true,
            options: [RepeatablePairStringOption(name: 'label')],
          ),
        ],
      );

      expect(() => subject.parse(['--tag', 'first']), returnsNormally);
    });

    test('requires one member for a required variant', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            name: 'token',
            required: true,
            variant: true,
            options: [PairStringOption(name: 'apiKey')],
          ),
        ],
      );

      expectParseError(subject, []);
    });
  });

  group('Parser command discovery', () {
    test('parses root-qualified commands around inherited inputs', () {
      final config = _ParserGroupCommand(
        'config',
        inheritedFlags: [BooleanFlag(name: 'verbose', short: 'v')],
        inheritedOptions: [IntOption(name: 'retries')],
        [_ParserCommand('get')],
      );
      final subject = Parser(
        CommandRegistry.create('tool', 'Tool command.', commands: [config]),
      );

      final result = subject.parse([
        'tool',
        'config',
        '-v',
        'get',
        '--retries',
        '2',
      ]);

      expect(result.$1, ['tool', 'config', 'get']);
      expect(result.$3.boolFlags, {'verbose': true});
      expect(result.$3.intOptions, {'retries': 2});
    });

    test('discovers command aliases as canonical command paths', () {
      final result = parser(
        commands: [
          _ParserCommand('checkout', aliases: ['co']),
        ],
      ).parse(['co']);

      expect(result.$1, ['checkout']);
    });

    test('stops command discovery at the trailing argument separator', () {
      final result = parser(
        commands: [_ParserCommand('config')],
      ).parse(['--', 'config']);

      expect(result.$1, isEmpty);
      expect(result.$4, ['config']);
    });

    test(
      'discovers descendants after inherited options before the command',
      () {
        final subject = Parser(
          CommandRegistry.create(
            'tool',
            'Tool command.',
            commands: [
              _ParserGroupCommand(
                'config',
                inheritedOptions: [IntOption(name: 'retries')],
                [_ParserCommand('get')],
              ),
            ],
          ),
        );

        final result = subject.parse(['config', '--retries', '2', 'get']);

        expect(result.$1, ['config', 'get']);
        expect(result.$3.intOptions, {'retries': 2});
      },
    );

    test('discovers descendants after a negated inherited flag', () {
      final subject = Parser(
        CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            _ParserGroupCommand(
              'config',
              inheritedFlags: [BooleanFlag(name: 'color', negatable: true)],
              [_ParserCommand('get')],
            ),
          ],
        ),
      );

      final result = subject.parse(['config', '--no-color', 'get']);

      expect(result.$1, ['config', 'get']);
      expect(result.$3.boolFlags, {'color': false});
    });
  });

  group('Parser option forms', () {
    test('parses short aliases for every ordinary option category', () {
      final inputs = parser(
        options: [
          StringOption(name: 'name', short: 'n', regex: RegExp(r'.+')),
          IntOption(name: 'count', short: 'c'),
          DoubleOption(name: 'ratio', short: 'r'),
        ],
      ).parse(['-n', 'Ada', '-c', '2', '-r', '1.5']).$3;

      expect(inputs.stringOptions, {'name': 'Ada'});
      expect(inputs.intOptions, {'count': 2});
      expect(inputs.doubleOptions, {'ratio': 1.5});
    });

    test('keeps equals signs after the first inline separator', () {
      final inputs = parser(
        options: [StringOption(name: 'query', regex: RegExp(r'.+'))],
      ).parse(['--query=a=b']).$3;

      expect(inputs.stringOptions, {'query': 'a=b'});
    });

    test('rejects values attached to flags and unknown accessor paths', () {
      final subject = parser(
        flags: [BooleanFlag(name: 'color')],
        accessors: [
          AccessorListOption(
            name: 'server',
            options: [AccessorIntOption(name: 'port')],
          ),
        ],
      );

      expectParseError(subject, ['--color=true']);
      expectParseError(subject, ['--server.missing', '1']);
      expectParseError(subject, ['--server', '1']);
    });

    test('rejects missing option values', () {
      final subject = parser(options: [IntOption(name: 'count')]);

      expectParseError(subject, ['--count']);
      expectParseError(subject, ['--count', '--other']);
    });

    test('parses count bundles and rejects unknown short members', () {
      final subject = parser(
        flags: [
          CountFlag(name: 'verbose', short: 'v'),
          BooleanFlag(name: 'quiet', short: 'q'),
        ],
      );

      expect(subject.parse(['-vvq']).$3.countFlags, {'verbose': 2});
      expectParseError(subject, ['-vx']);
    });

    test('increments repeated long count flags', () {
      final inputs = parser(
        flags: [CountFlag(name: 'verbose', short: 'v')],
      ).parse(['--verbose', '--verbose']).$3;

      expect(inputs.countFlags, {'verbose': 2});
    });

    test('parses paired primary and member short aliases', () {
      final inputs = parser(
        pairedOptions: [
          PairedIntOption(
            name: 'minimum',
            short: 'm',
            options: [PairIntOption(name: 'maximum', short: 'x')],
          ),
        ],
      ).parse(['-m', '-2', '-x', '-1']).$3;

      expect(inputs.intOptions, {'minimum': -2, 'maximum': -1});
    });
  });

  group('Parser choices and accessors', () {
    test('parses ordinary, paired, pair-member, and accessor choices', () {
      final inputs =
          parser(
            options: [ChoiceOption(name: 'mode', choices: Mode.values)],
            pairedOptions: [
              PairedChoiceOption(
                name: 'primary',
                choices: Mode.values,
                options: [
                  PairChoiceOption(name: 'secondary', choices: Mode.values),
                ],
              ),
            ],
            accessors: [
              AccessorChoiceOption(name: 'profile', choices: Mode.values),
            ],
          ).parse([
            '--mode',
            'always',
            '--primary',
            'auto',
            '--secondary',
            'always',
            '--profile',
            'auto',
          ]).$3;

      expect(inputs.stringOptions, {
        'mode': 'always',
        'primary': 'auto',
        'secondary': 'always',
      });
      expect(inputs.accessors, {'profile': 'auto'});
    });

    test('merges nested accessor defaults with explicit values', () {
      final inputs = parser(
        accessors: [
          AccessorListOption(
            name: 'server',
            options: [
              AccessorChoiceOption(
                name: 'mode',
                choices: Mode.values,
                defaultValue: Mode.auto,
              ),
              AccessorListOption(
                name: 'tls',
                options: [
                  AccessorChoiceOption(
                    name: 'mode',
                    choices: Mode.values,
                    defaultValue: Mode.always,
                  ),
                  AccessorStringOption(name: 'certificate'),
                ],
              ),
            ],
          ),
        ],
      ).parse(['--server.tls.certificate', 'cert.pem']).$3;

      expect(inputs.accessors, {
        'server': {
          'mode': 'auto',
          'tls': {'mode': 'always', 'certificate': 'cert.pem'},
        },
      });
    });

    test('rejects invalid choice values', () {
      expectParseError(
        parser(
          options: [ChoiceOption(name: 'mode', choices: Mode.values)],
        ),
        ['--mode', 'never'],
      );
    });
  });

  group('Parser validation', () {
    test('rejects invalid values and missing required options', () {
      final subject = parser(
        options: [
          StringOption(name: 'word', required: true, regex: RegExp(r'^word$')),
          IntOption(name: 'integer'),
          DoubleOption(name: 'decimal'),
          RepeatableIntOption(name: 'numbers'),
        ],
      );

      expectParseError(subject, []);
      expectParseError(subject, ['--word', 'wrong']);
      expectParseError(subject, ['--word', 'word', '--integer', '1.5']);
      expectParseError(subject, ['--word', 'word', '--decimal', 'one']);
      expectParseError(subject, ['--word', 'word', '--numbers', 'two']);
    });

    test(
      'rejects unknown inputs, invalid negation, and excess positionals',
      () {
        final subject = parser(
          flags: [BooleanFlag(name: 'plain')],
          mandatoryPositionals: [Positional('source')],
        );

        expectParseError(subject, ['source', '--missing']);
        expectParseError(subject, ['source', '--no-plain']);
        expectParseError(subject, ['source', 'extra']);
      },
    );

    test('validates every required ordinary option type', () {
      final cases = <Option>[
        IntOption(name: 'integer', required: true),
        DoubleOption(name: 'decimal', required: true),
        RepeatableStringOption(name: 'words', required: true),
        RepeatableIntOption(name: 'integers', required: true),
        RepeatableDoubleOption(name: 'decimals', required: true),
      ];

      for (final option in cases) {
        expectParseError(parser(options: [option]), []);
      }
    });

    test('accepts negative numbers as inline and separate option values', () {
      final subject = parser(
        options: [
          IntOption(name: 'integer', short: 'i'),
          DoubleOption(name: 'decimal', short: 'd'),
        ],
      );

      final inputs = subject.parse(['--integer', '-2', '-d', '-1.5']).$3;
      expect(inputs.intOptions, {'integer': -2});
      expect(inputs.doubleOptions, {'decimal': -1.5});

      final inlineInputs = subject.parse(['--integer=-3', '--decimal=-2.5']).$3;
      expect(inlineInputs.intOptions, {'integer': -3});
      expect(inlineInputs.doubleOptions, {'decimal': -2.5});

      expectParseError(subject, ['--integer=1.5']);
      expectParseError(subject, ['--decimal=.5']);
      expectParseError(subject, ['--decimal=1e2']);
    });

    test('rejects missing and invalid mandatory positionals', () {
      final subject = parser(
        mandatoryPositionals: [
          Positional('source', regex: RegExp(r'^valid$')),
          Positional('target'),
        ],
      );

      expectParseError(subject, []);
      expectParseError(subject, ['invalid']);
      expectParseError(subject, ['valid']);
    });

    test('rejects invalid discretionary positionals', () {
      final subject = parser(
        discretionaryPositionals: [
          Positional('target', regex: RegExp(r'^valid$')),
        ],
      );

      expect(() => subject.parse(['invalid']), throwsArgumentError);
    });

    test('requires positional expressions to match the entire value', () {
      final subject = parser(
        mandatoryPositionals: [Positional('initial', regex: RegExp(r'[A-Z]'))],
      );

      expectParseError(subject, ['Ada']);
    });
  });
}

class _ParserGroupCommand extends GroupCommand {
  _ParserGroupCommand(
    this.name,
    super.commands, {
    super.inheritedFlags,
    super.inheritedOptions,
  });

  @override
  final String name;

  @override
  String get shortDescription => 'Parser group command.';
}

class _ParserCommand extends Command {
  _ParserCommand(this.name, {super.aliases});

  @override
  final String name;

  @override
  String get shortDescription => 'Parser command.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => '';
}
