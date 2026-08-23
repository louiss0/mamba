import 'package:mamba/command.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<AccessorListOption>? accessors,
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
          BooleanFlag('color', negatable: true),
          CountFlag('verbose', short: 'v'),
        ],
        options: [
          StringOption('name', regex: RegExp(r'^Ada$')),
          IntOption('retries'),
          DoubleOption('ratio'),
          ChoiceOption<Mode>(
            'mode',
            choices: Mode.values,
            defaultValue: Mode.auto,
          ),
          RepeatableStringOption('tag', regex: RegExp(r'^\w+$')),
          RepeatableIntOption('port'),
          RepeatableDoubleOption('weight'),
        ],
        accessors: [
          AccessorListOption(
            'server',
            options: [
              AccessorIntOption('port'),
              AccessorDoubleOption('timeout'),
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
      expect(result.$2.singles, {
        'source': 'input.txt',
        'target': 'output.txt',
      });
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
      expect(result.$2.singles, isNull);
      expect(result.$2.repeated, isNull);
    });

    test('returns choice options in the string option map', () {
      final inputs = parser(
        options: [
          ChoiceOption<Mode>(
            'mode',
            choices: Mode.values,
            defaultValue: Mode.auto,
          ),
        ],
      ).parse([]).$3;

      expect(inputs.stringOptions, {'mode': 'auto'});
    });

    test('adds Boolean defaults only to Boolean flag maps', () {
      final inputs = parser(
        flags: [BooleanFlag('color', defaultValue: true), CountFlag('verbose')],
      ).parse([]).$3;

      expect(inputs.boolFlags, {'color': true});
      expect(inputs.countFlags, isEmpty);
    });

    test('collects arguments after -- separately from inputs', () {
      final result = parser().parse(['--', '--unknown', '-x']);

      expect(result.$2.singles, isNull);
      expect(result.$2.repeated, isNull);
      expect(result.$1, isEmpty);
      expect(result.$3.accessors, isNull);
      expect(result.$4, ['--unknown', '-x']);
    });

    test('does not parse arguments after -- as options or positionals', () {
      final result = parser(
        mandatoryPositionals: [Positional('source')],
      ).parse(['source', '--', '--unknown', 'extra']);

      expect(result.$2.singles, {'source': 'source'});
      expect(result.$4, ['--unknown', 'extra']);
    });
  });

  group('Repeated positionals alone', () {
    test('collects up to two values with the default maxCount of one', () {
      final inputs = parser(
        mandatoryPositionals: [RepeatedPositional('files')],
      ).parse(['a.txt', 'b.txt']).$2;

      expect(inputs.singles, isNull);
      expect(inputs.repeated, {
        'files': ['a.txt', 'b.txt'],
      });
    });

    test(
      'stops collecting a mandatory repeated positional after its repeats',
      () {
        final subject = parser(
          mandatoryPositionals: [RepeatedPositional('files', maxCount: 2)],
        );

        expectParseError(subject, ['a.txt', 'b.txt', 'c.txt', 'd.txt']);
      },
    );

    test('requires at least one value for a mandatory repeated positional', () {
      expectParseError(
        parser(mandatoryPositionals: [RepeatedPositional('files')]),
        [],
      );
    });

    test(
      'collects available values for a discretionary repeated positional',
      () {
        final inputs = parser(
          discretionaryPositionals: [RepeatedPositional('files')],
        ).parse(['a.txt', 'b.txt']).$2;

        expect(inputs.repeated, {
          'files': ['a.txt', 'b.txt'],
        });
      },
    );

    test('omits a discretionary repeated positional without values', () {
      final inputs = parser(
        discretionaryPositionals: [RepeatedPositional('files')],
      ).parse([]).$2;

      expect(inputs.singles, isNull);
      expect(inputs.repeated, isNull);
    });

    test('rejects values that do not match the repeated positional regex', () {
      final subject = parser(
        mandatoryPositionals: [
          RepeatedPositional('files', regExp: RegExp(r'^\\w+\\.txt$')),
        ],
      );

      expectParseError(subject, ['a.txt', 'notes.md']);
    });
  });

  group('Repeated positionals with individual positionals', () {
    test('fills a leading repeated positional before later positionals', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedPositional('files', maxCount: 2),
          Positional('destination'),
        ],
      ).parse(['a.txt', 'b.txt', 'c.txt', 'out']).$2;

      expect(inputs.singles, {'destination': 'out'});
      expect(inputs.repeated, {
        'files': ['a.txt', 'b.txt', 'c.txt'],
      });
    });

    test(
      'fills individual positionals before a trailing repeated positional',
      () {
        final inputs = parser(
          mandatoryPositionals: [
            Positional('source'),
            RepeatedPositional('files'),
          ],
        ).parse(['in', 'a.txt', 'b.txt']).$2;

        expect(inputs.singles, {'source': 'in'});
        expect(inputs.repeated, {
          'files': ['a.txt', 'b.txt'],
        });
      },
    );

    test('collects only the remaining values after individual positionals', () {
      final inputs = parser(
        mandatoryPositionals: [
          Positional('first'),
          Positional('second'),
          RepeatedPositional('files'),
        ],
        discretionaryPositionals: [RepeatedPositional('more')],
      ).parse(['one', 'two', 'a.txt', 'b.txt', 'c.txt']).$2;

      expect(inputs.singles, {'first': 'one', 'second': 'two'});
      expect(inputs.repeated, {
        'files': ['a.txt', 'b.txt'],
        'more': ['c.txt'],
      });
    });

    test('respects maxCount before handing values to later positionals', () {
      final inputs = parser(
        mandatoryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 1),
          Positional('destination'),
        ],
      ).parse(['in', 'a.txt', 'mid', 'out']).$2;

      expect(inputs.singles, {'source': 'in', 'destination': 'out'});
      expect(inputs.repeated, {
        'files': ['a.txt', 'mid'],
      });
    });

    test('caps a repeated choice positional between individual ones', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedChoicePositional<Mode>(
            'modes',
            choices: Mode.values,
            maxCount: 2,
          ),
          Positional('label'),
        ],
      ).parse(['auto', 'always', 'small', 'final']).$2;

      expect(inputs.singles, {'label': 'final'});
      expect(inputs.repeated, {
        'modes': ['auto', 'always', 'small'],
      });
    });

    test('prioritizes mandatory positionals over discretionary ones', () {
      final inputs = parser(
        discretionaryPositionals: [Positional('target')],
        mandatoryPositionals: [RepeatedPositional('files', maxCount: 1)],
      ).parse(['a.txt', 'out']).$2;

      expect(inputs.singles, isNull);
      expect(inputs.repeated, {
        'files': ['a.txt', 'out'],
      });
    });

    test(
      'leaves a discretionary single unfilled after a greedy repeated one',
      () {
        final inputs = parser(
          mandatoryPositionals: [RepeatedPositional('files')],
          discretionaryPositionals: [Positional('target')],
        ).parse(['a.txt', 'b.txt']).$2;

        expect(inputs.singles, isNull);
        expect(inputs.repeated, {
          'files': ['a.txt', 'b.txt'],
        });
      },
    );

    test('reports leftover values beyond every registered positional', () {
      final subject = parser(
        mandatoryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 1),
        ],
      );

      expectParseError(subject, ['in', 'a.txt', 'out', 'extra']);
    });
  });

  group('Mandatory repeated positional placement', () {
    test('collects at the start until maxCount two is filled', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedPositional('files', maxCount: 2),
          Positional('target'),
        ],
      ).parse(['f0', 'f1', 'f2', 'out']).$2;

      expect(inputs.singles, {'target': 'out'});
      expect(inputs.repeated, {
        'files': ['f0', 'f1', 'f2'],
      });
    });

    test('collects in the middle until maxCount three is filled', () {
      final inputs = parser(
        mandatoryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 3),
          Positional('target'),
        ],
      ).parse(['in', 'f0', 'f1', 'f2', 'f3', 'out']).$2;

      expect(inputs.singles, {'source': 'in', 'target': 'out'});
      expect(inputs.repeated, {
        'files': ['f0', 'f1', 'f2', 'f3'],
      });
    });

    test('collects at the end until maxCount four is filled', () {
      final inputs = parser(
        mandatoryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 4),
        ],
      ).parse(['in', 'f0', 'f1', 'f2', 'f3']).$2;

      expect(inputs.singles, {'source': 'in'});
      expect(inputs.repeated, {
        'files': ['f0', 'f1', 'f2', 'f3'],
      });
    });
  });

  group('Discretionary repeated positional placement', () {
    test('collects at the start until maxCount twelve is filled', () {
      final inputs = parser(
        discretionaryPositionals: [
          RepeatedPositional('files', maxCount: 12),
          Positional('target'),
        ],
      ).parse([...List.generate(13, (index) => 'f$index'), 'out']).$2;

      expect(inputs.singles, {'target': 'out'});
      expect(inputs.repeated, {
        'files': List.generate(13, (index) => 'f$index'),
      });
    });

    test('collects in the middle until maxCount seven is filled', () {
      final inputs = parser(
        discretionaryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 7),
          Positional('target'),
        ],
      ).parse(['in', ...List.generate(8, (index) => 'f$index'), 'out']).$2;

      expect(inputs.singles, {'source': 'in', 'target': 'out'});
      expect(inputs.repeated, {
        'files': List.generate(8, (index) => 'f$index'),
      });
    });

    test('collects at the end until maxCount five is filled', () {
      final inputs = parser(
        discretionaryPositionals: [
          Positional('source'),
          RepeatedPositional('files', maxCount: 5),
        ],
      ).parse(['in', ...List.generate(5, (index) => 'f$index')]).$2;

      expect(inputs.singles, {'source': 'in'});
      expect(inputs.repeated, {
        'files': List.generate(5, (index) => 'f$index'),
      });
    });
  });

  group('Mandatory and discretionary repeated placement together', () {
    test(
      'splits values between a capped mandatory and an open discretionary',
      () {
        final inputs = parser(
          mandatoryPositionals: [RepeatedPositional('kept', maxCount: 4)],
          discretionaryPositionals: [RepeatedPositional('extra', maxCount: 8)],
        ).parse(List.generate(10, (index) => 'v$index')).$2;

        expect(inputs.singles, isNull);
        expect(inputs.repeated, {
          'kept': ['v0', 'v1', 'v2', 'v3', 'v4'],
          'extra': ['v5', 'v6', 'v7', 'v8', 'v9'],
        });
      },
    );

    test('fills singles around repeated positionals across both lists', () {
      final inputs = parser(
        mandatoryPositionals: [
          Positional('source'),
          RepeatedPositional('kept', maxCount: 3),
        ],
        discretionaryPositionals: [
          Positional('target'),
          RepeatedPositional('more', maxCount: 6),
        ],
      ).parse(['in', 'k0', 'k1', 'k2', 'k3', 'out', 'm0', 'm1', 'm2', 'm3']).$2;

      expect(inputs.singles, {'source': 'in', 'target': 'out'});
      expect(inputs.repeated, {
        'kept': ['k0', 'k1', 'k2', 'k3'],
        'more': ['m0', 'm1', 'm2', 'm3'],
      });
    });

    test(
      'caps both lists when fewer values arrive than the combined counts',
      () {
        final inputs = parser(
          mandatoryPositionals: [RepeatedPositional('kept', maxCount: 3)],
          discretionaryPositionals: [RepeatedPositional('extra', maxCount: 12)],
        ).parse(['k0', 'k1', 'k2', 'k3', 'e0', 'e1']).$2;

        expect(inputs.singles, isNull);
        expect(inputs.repeated, {
          'kept': ['k0', 'k1', 'k2', 'k3'],
          'extra': ['e0', 'e1'],
        });
      },
    );
  });

  group('Parser definitions', () {
    test('accepts accessor lists at the root and at nested paths', () {
      final subject = parser(
        accessors: [
          AccessorListOption(
            'profile',
            options: [AccessorStringOption('value', regex: RegExp(r'^ada$'))],
          ),
          AccessorListOption(
            'remote',
            options: [
              AccessorListOption(
                'origin',
                options: [AccessorStringOption('url')],
              ),
            ],
          ),
        ],
      );

      final inputs = subject.parse([
        '--profile.value',
        'ada',
        '--remote.origin.url',
        'https://example.com',
      ]).$3;

      expect(inputs.accessors, {
        'profile': {'value': 'ada'},
        'remote': {
          'origin': {'url': 'https://example.com'},
        },
      });
    });

    test('renders list-defined inputs in help', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        flags: [BooleanFlag('verbose')],
        options: [StringOption('name', regex: RegExp(r'\S+'))],
        accessors: [
          AccessorListOption(
            'profile',
            options: [AccessorStringOption('value')],
          ),
        ],
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
            'firstName',
            options: [PairStringOption('lastName')],
          ),
          PairedIntOption('minimum', options: [PairIntOption('maximum')]),
          PairedDoubleOption(
            'minimumRatio',
            options: [PairDoubleOption('maximumRatio')],
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
            'name',
            options: [RepeatablePairStringOption('value')],
          ),
          RepeatablePairedIntOption(
            'minimum',
            options: [RepeatablePairIntOption('maximum')],
          ),
          RepeatablePairedDoubleOption(
            'minimumWeight',
            options: [RepeatablePairDoubleOption('maximumWeight')],
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
            'name',
            options: [RepeatablePairStringOption('value')],
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
        group: PairedStringOption('host', options: [PairIntOption('port')]),
        arguments: ['--host', 'localhost', '--port', '8080'],
        missingArguments: ['--host', 'localhost'],
      ),
      (
        description: 'string and double options',
        group: PairedStringOption(
          'label',
          options: [PairDoubleOption('value')],
        ),
        arguments: ['--label', 'warning', '--value', '0.8'],
        missingArguments: ['--value', '0.8'],
      ),
      (
        description: 'int and double options',
        group: PairedIntOption('retries', options: [PairDoubleOption('delay')]),
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
            'token',
            variant: true,
            options: [PairStringOption('apiKey')],
          ),
        ],
      );

      expect(() => subject.parse(['--token', 'secret']), returnsNormally);
    });

    test('rejects multiple variant members', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            'token',
            variant: true,
            options: [PairStringOption('apiKey')],
          ),
        ],
      );

      expectParseError(subject, ['--token', 'secret', '--apiKey', 'key']);
    });

    test('accepts one repeatable variant member', () {
      final subject = parser(
        pairedOptions: [
          RepeatablePairedStringOption(
            'tag',
            variant: true,
            options: [RepeatablePairStringOption('label')],
          ),
        ],
      );

      expect(() => subject.parse(['--tag', 'first']), returnsNormally);
    });

    test('requires one member for a required variant', () {
      final subject = parser(
        pairedOptions: [
          PairedStringOption(
            'token',
            required: true,
            variant: true,
            options: [PairStringOption('apiKey')],
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
        inheritedFlags: [BooleanFlag('verbose', short: 'v')],
        inheritedOptions: [IntOption('retries')],
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
                inheritedOptions: [IntOption('retries')],
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
              inheritedFlags: [BooleanFlag('color', negatable: true)],
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
          StringOption('name', short: 'n', regex: RegExp(r'.+')),
          IntOption('count', short: 'c'),
          DoubleOption('ratio', short: 'r'),
        ],
      ).parse(['-n', 'Ada', '-c', '2', '-r', '1.5']).$3;

      expect(inputs.stringOptions, {'name': 'Ada'});
      expect(inputs.intOptions, {'count': 2});
      expect(inputs.doubleOptions, {'ratio': 1.5});
    });

    test('keeps equals signs after the first inline separator', () {
      final inputs = parser(
        options: [StringOption('query', regex: RegExp(r'.+'))],
      ).parse(['--query=a=b']).$3;

      expect(inputs.stringOptions, {'query': 'a=b'});
    });

    test('rejects values attached to flags and unknown accessor paths', () {
      final subject = parser(
        flags: [BooleanFlag('color')],
        accessors: [
          AccessorListOption('server', options: [AccessorIntOption('port')]),
        ],
      );

      expectParseError(subject, ['--color=true']);
      expectParseError(subject, ['--server.missing', '1']);
      expectParseError(subject, ['--server', '1']);
    });

    test('rejects missing option values', () {
      final subject = parser(options: [IntOption('count')]);

      expectParseError(subject, ['--count']);
      expectParseError(subject, ['--count', '--other']);
    });

    test('parses count bundles and rejects unknown short members', () {
      final subject = parser(
        flags: [
          CountFlag('verbose', short: 'v'),
          BooleanFlag('quiet', short: 'q'),
        ],
      );

      expect(subject.parse(['-vvq']).$3.countFlags, {'verbose': 2});
      expectParseError(subject, ['-vx']);
    });

    test('increments repeated long count flags', () {
      final inputs = parser(
        flags: [CountFlag('verbose', short: 'v')],
      ).parse(['--verbose', '--verbose']).$3;

      expect(inputs.countFlags, {'verbose': 2});
    });

    test('parses paired primary and member short aliases', () {
      final inputs = parser(
        pairedOptions: [
          PairedIntOption(
            'minimum',
            short: 'm',
            options: [PairIntOption('maximum', short: 'x')],
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
            options: [ChoiceOption('mode', choices: Mode.values)],
            pairedOptions: [
              PairedChoiceOption(
                'primary',
                choices: Mode.values,
                options: [PairChoiceOption('secondary', choices: Mode.values)],
              ),
            ],
            accessors: [
              AccessorListOption(
                'profile',
                options: [AccessorChoiceOption('value', choices: Mode.values)],
              ),
            ],
          ).parse([
            '--mode',
            'always',
            '--primary',
            'auto',
            '--secondary',
            'always',
            '--profile.value',
            'auto',
          ]).$3;

      expect(inputs.stringOptions, {
        'mode': 'always',
        'primary': 'auto',
        'secondary': 'always',
      });
      expect(inputs.accessors, {
        'profile': {'value': 'auto'},
      });
    });

    test('merges nested accessor defaults with explicit values', () {
      final inputs = parser(
        accessors: [
          AccessorListOption(
            'server',
            options: [
              AccessorChoiceOption(
                'mode',
                choices: Mode.values,
                defaultValue: Mode.auto,
              ),
              AccessorListOption(
                'tls',
                options: [
                  AccessorChoiceOption(
                    'mode',
                    choices: Mode.values,
                    defaultValue: Mode.always,
                  ),
                  AccessorStringOption('certificate'),
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
        parser(options: [ChoiceOption('mode', choices: Mode.values)]),
        ['--mode', 'never'],
      );
    });
  });

  group('Parser validation', () {
    test('rejects invalid values and missing required options', () {
      final subject = parser(
        options: [
          StringOption('word', required: true, regex: RegExp(r'^word$')),
          IntOption('integer'),
          DoubleOption('decimal'),
          RepeatableIntOption('numbers'),
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
          flags: [BooleanFlag('plain')],
          mandatoryPositionals: [Positional('source')],
        );

        expectParseError(subject, ['source', '--missing']);
        expectParseError(subject, ['source', '--no-plain']);
        expectParseError(subject, ['source', 'extra']);
      },
    );

    test('validates every required ordinary option type', () {
      final cases = <Option>[
        IntOption('integer', required: true),
        DoubleOption('decimal', required: true),
        RepeatableStringOption('words', required: true),
        RepeatableIntOption('integers', required: true),
        RepeatableDoubleOption('decimals', required: true),
      ];

      for (final option in cases) {
        expectParseError(parser(options: [option]), []);
      }
    });

    test('accepts negative numbers as inline and separate option values', () {
      final subject = parser(
        options: [
          IntOption('integer', short: 'i'),
          DoubleOption('decimal', short: 'd'),
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
