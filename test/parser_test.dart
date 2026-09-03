import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<AccessorListOption>? accessors,
  List<PairedOptions>? pairedOptions,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
  Variadic? variadic,
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
    variadic: variadic,
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
          AccessorListOption('server', [
            AccessorIntOption('port'),
            AccessorDoubleOption('timeout'),
          ]),
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
      final result = parser().parse(['tool']);
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
      ).parse(['tool']).$3;

      expect(inputs.stringOptions, {'mode': 'auto'});
    });

    test('adds defaults to Boolean and count flag maps', () {
      final inputs = parser(
        flags: [BooleanFlag('color', defaultValue: true), CountFlag('verbose')],
      ).parse(['tool']).$3;

      expect(inputs.boolFlags, {'color': true});
      expect(inputs.countFlags, {'verbose': 0});
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

  group('Choice positionals', () {
    test('rejects a default for a mandatory choice positional', () {
      expect(
        () => parser(
          mandatoryPositionals: [
            ChoicePositional(
              'mode',
              choices: Mode.values,
              defaultValue: Mode.auto,
            ),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('accepts only registered choices for a single positional', () {
      final subject = parser(
        mandatoryPositionals: [
          ChoicePositional<Mode>('mode', choices: [Mode.auto]),
        ],
      );

      expect(subject.parse(['auto']).$2.singles, {'mode': 'auto'});
      expectParseError(subject, ['bogus']);
    });

    test('rejects a default for a mandatory repeated choice positional', () {
      expect(
        () => parser(
          mandatoryPositionals: [
            RepeatedChoicePositional(
              'modes',
              choices: Mode.values,
              defaultValue: Mode.auto,
            ),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('accepts only registered choices for a repeated positional', () {
      final subject = parser(
        mandatoryPositionals: [
          RepeatedChoicePositional<Mode>(
            'modes',
            choices: [Mode.auto],
            times: 1,
          ),
        ],
      );

      expect(subject.parse(['auto', 'auto']).$2.repeated, {
        'modes': ['auto', 'auto'],
      });
      expectParseError(subject, ['auto', 'bogus']);
    });
  });

  group('Repeated positionals alone', () {
    test('collects up to two values with the default maxCount of one', () {
      final inputs = parser(
        mandatoryPositionals: [RepeatedStringPositional('files')],
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
          mandatoryPositionals: [RepeatedStringPositional('files', times: 2)],
        );

        expectParseError(subject, ['a.txt', 'b.txt', 'c.txt', 'd.txt']);
      },
    );

    test('requires at least one value for a mandatory repeated positional', () {
      expectParseError(
        parser(mandatoryPositionals: [RepeatedStringPositional('files')]),
        ['tool'],
      );
    });

    test('reports an invalid first mandatory repeated positional value', () {
      final subject = parser(
        mandatoryPositionals: [
          RepeatedStringPositional('files', regExp: RegExp(r'^\\w+\\.txt$')),
        ],
      );

      expect(
        () => subject.parse(['notes.md']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            contains('Invalid value for positional files at 0'),
          ),
        ),
      );
    });

    test(
      'collects available values for a discretionary repeated positional',
      () {
        final inputs = parser(
          discretionaryPositionals: [RepeatedStringPositional('files')],
        ).parse(['a.txt', 'b.txt']).$2;

        expect(inputs.repeated, {
          'files': ['a.txt', 'b.txt'],
        });
      },
    );

    test('omits a discretionary repeated positional without values', () {
      final inputs = parser(
        discretionaryPositionals: [RepeatedStringPositional('files')],
      ).parse(['tool']).$2;

      expect(inputs.singles, isNull);
      expect(inputs.repeated, isNull);
    });

    test('rejects values that do not match the repeated positional regex', () {
      final subject = parser(
        mandatoryPositionals: [
          RepeatedStringPositional('files', regExp: RegExp(r'^\\w+\\.txt$')),
        ],
      );

      expectParseError(subject, ['a.txt', 'notes.md']);
    });
  });

  group('Repeated positionals with individual positionals', () {
    test('fills a leading repeated positional before later positionals', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedStringPositional('files', times: 2),
          Positional('destination'),
        ],
      ).parse(['a.txt', 'b.txt', 'c.txt', 'out']).$2;

      expect(inputs.singles, {'destination': 'out'});
      expect(inputs.repeated, {
        'files': ['a.txt', 'b.txt', 'c.txt'],
      });
    });

    test('reserves values for later mandatory positionals', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedStringPositional('files', times: 2),
          Positional('destination'),
        ],
      ).parse(['a.txt', 'b.txt', 'out']).$2;

      expect(inputs.repeated, {
        'files': ['a.txt', 'b.txt'],
      });
      expect(inputs.singles, {'destination': 'out'});
    });

    test(
      'fills individual positionals before a trailing repeated positional',
      () {
        final inputs = parser(
          mandatoryPositionals: [
            Positional('source'),
            RepeatedStringPositional('files'),
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
          RepeatedStringPositional('files'),
        ],
        discretionaryPositionals: [RepeatedStringPositional('more')],
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
          RepeatedStringPositional('files', times: 1),
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
            times: 2,
          ),
          Positional('label'),
        ],
      ).parse(['auto', 'always', 'auto', 'final']).$2;

      expect(inputs.singles, {'label': 'final'});
      expect(inputs.repeated, {
        'modes': ['auto', 'always', 'auto'],
      });
    });

    test('prioritizes mandatory positionals over discretionary ones', () {
      final inputs = parser(
        discretionaryPositionals: [Positional('target')],
        mandatoryPositionals: [RepeatedStringPositional('files', times: 1)],
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
          mandatoryPositionals: [RepeatedStringPositional('files')],
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
          RepeatedStringPositional('files', times: 1),
        ],
      );

      expectParseError(subject, ['in', 'a.txt', 'out', 'extra']);
    });
  });

  group('Mandatory repeated positional placement', () {
    test('collects at the start until maxCount two is filled', () {
      final inputs = parser(
        mandatoryPositionals: [
          RepeatedStringPositional('files', times: 2),
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
          RepeatedStringPositional('files', times: 3),
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
          RepeatedStringPositional('files', times: 4),
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
          RepeatedStringPositional('files', times: 12),
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
          RepeatedStringPositional('files', times: 7),
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
          RepeatedStringPositional('files', times: 5),
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
          mandatoryPositionals: [RepeatedStringPositional('kept', times: 4)],
          discretionaryPositionals: [
            RepeatedStringPositional('extra', times: 8),
          ],
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
          RepeatedStringPositional('kept', times: 3),
        ],
        discretionaryPositionals: [
          Positional('target'),
          RepeatedStringPositional('more', times: 6),
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
          mandatoryPositionals: [RepeatedStringPositional('kept', times: 3)],
          discretionaryPositionals: [
            RepeatedStringPositional('extra', times: 12),
          ],
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
          AccessorListOption('profile', [
            AccessorStringOption('value', regex: RegExp(r'^ada$')),
          ]),
          AccessorListOption('remote', [
            AccessorListOption('origin', [AccessorStringOption('url')]),
          ]),
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

    test('parses accessor paths with five dots and shared branches', () {
      final subject = parser(
        accessors: [
          AccessorListOption('cloud', [
            AccessorListOption('provider', [
              AccessorListOption('credentials', [
                AccessorListOption('oauth', [
                  AccessorListOption('client', [
                    AccessorStringOption('token'),
                    AccessorIntOption('timeout'),
                  ]),
                ]),
                AccessorStringOption('region'),
              ]),
              AccessorStringOption('endpoint'),
            ]),
          ]),
        ],
      );

      final inputs = subject.parse([
        '--cloud.provider.credentials.oauth.client.token=secret',
        '--cloud.provider.credentials.oauth.client.timeout',
        '30',
        '--cloud.provider.credentials.region',
        'eu-west',
        '--cloud.provider.endpoint',
        'api.example.com',
      ]).$3;

      expect(inputs.accessors, {
        'cloud': {
          'provider': {
            'credentials': {
              'oauth': {
                'client': {'token': 'secret', 'timeout': 30},
              },
              'region': 'eu-west',
            },
            'endpoint': 'api.example.com',
          },
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
          AccessorListOption('profile', [AccessorStringOption('value')]),
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
    test('parses a standalone paired options group', () {
      final parsed = parser(
        pairedOptions: [
          PairedOptions([PairStringOption('username'), PairIntOption('port')]),
        ],
      ).parse(['--username', 'mamba', '--port', '42']);

      expect(parsed.$3.stringOptions, {'username': 'mamba'});
      expect(parsed.$3.intOptions, {'port': 42});
    });

    test('rejects a partially supplied standalone group', () {
      final subject = parser(
        pairedOptions: [
          PairedOptions([PairStringOption('username'), PairIntOption('port')]),
        ],
      );

      expectParseError(subject, ['--username', 'mamba']);
    });

    test('reports missing required standalone group members', () {
      expect(
        () => parser(
          pairedOptions: [
            PairedOptions([
              PairStringOption('username', description: 'Account name.'),
              PairIntOption('port', description: 'Server port.'),
            ], required: true),
          ],
        ).parse(['--username', 'mamba']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Required paired options are missing: --port',
          ),
        ),
      );
    });

    test('accepts exactly one variant member', () {
      final parsed = parser(
        pairedOptions: [
          PairedOptions([
            PairStringOption('json'),
            PairStringOption('text'),
          ], variant: true),
        ],
      ).parse(['--json', 'report']);

      expect(parsed.$3.stringOptions, {'json': 'report'});
    });

    test('rejects multiple variant members', () {
      final subject = parser(
        pairedOptions: [
          PairedOptions([
            PairStringOption('json'),
            PairStringOption('text'),
          ], variant: true),
        ],
      );

      expectParseError(subject, ['--json', 'a', '--text', 'b']);
    });

    test('does not apply defaults to optional variant pairs', () {
      final inputs = parser(
        pairedOptions: [
          PairedOptions([
            PairChoiceOption('json', choices: Mode.values),
          ], variant: true),
        ],
      ).parse(['tool']).$3;

      expect(inputs.stringOptions, {});
    });

    test('does not apply defaults to optional all-of pairs', () {
      final inputs = parser(
        pairedOptions: [
          PairedOptions([
            PairChoiceOption('first', choices: Mode.values),
            PairChoiceOption('second', choices: Mode.values),
          ]),
        ],
      ).parse(['tool']).$3;

      expect(inputs.stringOptions, {});
    });
    test('requires one member for a required variant', () {
      final subject = parser(
        pairedOptions: [
          PairedOptions(
            [PairStringOption('json'), PairStringOption('text')],
            required: true,
            variant: true,
          ),
        ],
      );

      expectParseError(subject, ['tool']);
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

    test('reports an unknown child when no positional can consume it', () {
      final subject = parser(
        commands: [
          _ParserGroupCommand('config', [_ParserCommand('get')]),
        ],
      );

      expect(
        () => subject.parse(['config', 'missing']),
        throwsA(isA<MambaCommandNotFoundException>()),
      );
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

    test('does not locate a command inside an option value', () {
      final subject = Parser(
        CommandRegistry.create(
          'tool',
          'Tool command.',
          commands: [
            _ParserGroupCommand(
              'group',
              inheritedOptions: [StringOption('target', regex: RegExp(r'\S+'))],
              [_ParserCommand('leaf')],
            ),
          ],
        ),
      );

      final result = subject.parse(['group', '--target', 'leaf', 'leaf']);

      expect(result.$1, ['group', 'leaf']);
      expect(result.$3.stringOptions, {'target': 'leaf'});
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

    test(
      'accepts dash-prefixed string values when their regex allows them',
      () {
        final subject = parser(
          options: [StringOption('pattern', regex: RegExp(r'^-\w+$'))],
        );

        expect(subject.parse(['--pattern', '-value']).$3.stringOptions, {
          'pattern': '-value',
        });
      },
    );

    test('registered global help retains its flag meaning', () {
      final subject = parser(
        flags: [BooleanFlag('verbose')],
        options: [StringOption('pattern', regex: RegExp(r'\S+'))],
      );

      expectParseError(subject, ['--pattern', '--help']);
      final result = subject.parse(['--help', '--pattern', 'value']);
      expect(result.help, isTrue);
      expect(result.$3.boolFlags, {'verbose': false});
      expect(result.$3.stringOptions, isEmpty);
      expect(
        () => subject.parse(['--pattern', '--verbose']),
        throwsA(isA<MambaParseException>()),
      );
      expect(subject.parse(['--pattern=--verbose']).$3.stringOptions, {
        'pattern': '--verbose',
      });
    });

    test('stops option parsing after help but still resolves commands', () {
      final subject = parser(
        commands: [
          _ParserCommand(
            'deploy',
            options: [
              StringOption('required', regex: RegExp(r'\S+'), required: true),
            ],
          ),
        ],
      );

      final result = subject.parse([
        '--help',
        'deploy',
        '--unknown',
        '--required',
      ]);

      expect(result.$1, ['deploy']);
      expect(result.help, isTrue);
      expect(result.$3, isNotNull);
      expect(result.$3.stringOptions, isEmpty);
      final unknownTarget = subject.parse(['--help', 'missing']);
      expect(unknownTarget.$1, isEmpty);
      expect(unknownTarget.help, isTrue);
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
          AccessorListOption('server', [AccessorIntOption('port')]),
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
          PairedOptions([
            PairIntOption('minimum', short: 'm'),
            PairIntOption('maximum', short: 'x'),
          ]),
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
              PairedOptions([
                PairChoiceOption('primary', choices: Mode.values),
                PairChoiceOption('secondary', choices: Mode.values),
              ]),
            ],
            accessors: [
              AccessorListOption('profile', [
                AccessorChoiceOption('value', choices: Mode.values),
              ]),
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
          AccessorListOption('server', [
            AccessorChoiceOption(
              'mode',
              choices: Mode.values,
              defaultValue: Mode.auto,
            ),
            AccessorListOption('tls', [
              AccessorChoiceOption(
                'mode',
                choices: Mode.values,
                defaultValue: Mode.always,
              ),
              AccessorStringOption('certificate'),
            ]),
          ]),
        ],
      ).parse(['--server.tls.certificate', 'cert.pem']).$3;

      expect(inputs.accessors, {
        'server': {
          'mode': 'auto',
          'tls': {'mode': 'always', 'certificate': 'cert.pem'},
        },
      });
    });

    test('leaves omitted paired choice options unset', () {
      final inputs = parser(
        pairedOptions: [
          PairedOptions([PairChoiceOption('format', choices: Mode.values)]),
        ],
      ).parse(['tool']).$3;

      expect(inputs.stringOptions, {});
    });

    test('rejects invalid choice values', () {
      expectParseError(
        parser(options: [ChoiceOption('mode', choices: Mode.values)]),
        ['--mode', 'never'],
      );
    });
  });

  group('numeric ranges', () {
    test('accepts inclusive int and double bounds', () {
      final inputs = parser(
        options: [
          IntOption('count', min: 1, max: 3),
          DoubleOption('ratio', min: 0.5, max: 1.5),
        ],
      ).parse(['--count', '3', '--ratio', '0.5']).$3;

      expect(inputs.intOptions, {'count': 3});
      expect(inputs.doubleOptions, {'ratio': 0.5});
    });

    test('rejects numeric values outside their declared range', () {
      final subject = parser(options: [IntOption('count', min: 1, max: 3)]);

      expect(
        () => subject.parse(['--count', '4']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Option --count must be at least 1 and at most 3 (received 4).',
          ),
        ),
      );
    });

    test('rejects double values that do not match the declared step', () {
      final subject = parser(
        options: [DoubleOption('ratio', min: 0, max: 1, step: 0.25)],
      );

      expect(
        () => subject.parse(['--ratio', '0.3']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Option --ratio must increment by 0.25 from 0.0 to 1.0 (received 0.3).',
          ),
        ),
      );
    });

    test('rejects inverted numeric ranges during registry construction', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [DoubleOption('ratio', min: 2, max: 1)],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects double steps that do not reach the declared maximum', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [DoubleOption('ratio', min: 0, max: 1, step: 0.3)],
        ),
        throwsA(
          isA<MambaRegistryError>().having(
            (error) => error.message,
            'message',
            'Step 0.3 for ratio must evenly divide the range from 0.0 to 1.0.',
          ),
        ),
      );
    });

    test('rejects non-positive double steps', () {
      expect(
        () => CommandRegistry.create(
          'tool',
          'Tool command.',
          options: [DoubleOption('ratio', min: 0, max: 1, step: 0)],
        ),
        throwsA(
          isA<MambaRegistryError>().having(
            (error) => error.message,
            'message',
            'Step 0.0 for ratio must be greater than zero.',
          ),
        ),
      );
    });

    test('validates steps for repeatable and paired double options', () {
      final subject = parser(
        options: [
          RepeatableDoubleOption('repeated', min: 0, max: 1, step: 0.5),
        ],
        pairedOptions: [
          PairedOptions([
            PairDoubleOption('pair', min: 0, max: 1, step: 0.5),
            RepeatablePairDoubleOption(
              'repeated-pair',
              min: 0,
              max: 1,
              step: 0.5,
            ),
          ]),
        ],
      );

      expectParseError(subject, ['--repeated', '0.25']);
      expectParseError(subject, ['--pair', '0.25', '--repeated-pair', '0.5']);
      expectParseError(subject, ['--pair', '0.5', '--repeated-pair', '0.25']);
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

      expectParseError(subject, ['tool']);
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

    test('identifies the option and value rejected by a regex', () {
      final subject = parser(
        options: [StringOption('output', regex: RegExp(r'^valid$'))],
      );

      expect(
        () => subject.parse(['--output', 'invalid']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            "Option --output does not accept 'invalid'.",
          ),
        ),
      );
    });

    test('identifies unknown long inputs as flags or options', () {
      final subject = parser();

      expect(
        () => subject.parse(['--missing']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Unknown flag or option --missing.',
          ),
        ),
      );
    });

    test('validates every required ordinary option type', () {
      final cases = <Option>[
        IntOption('integer', required: true),
        DoubleOption('decimal', required: true),
        RepeatableStringOption('words', required: true),
        RepeatableIntOption('integers', required: true),
        RepeatableDoubleOption('decimals', required: true),
      ];

      for (final option in cases) {
        expectParseError(parser(options: [option]), ['tool']);
      }
    });

    test('uses one message for every missing required option', () {
      final subject = parser(
        options: [
          StringOption('output', required: true, regex: RegExp(r'\S+')),
        ],
      );

      expect(
        () => subject.parse(['tool']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Option --output is required.',
          ),
        ),
      );
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

      expectParseError(subject, ['tool']);
      expectParseError(subject, ['invalid']);
      expectParseError(subject, ['valid']);
    });

    test('rejects invalid discretionary positionals', () {
      final subject = parser(
        discretionaryPositionals: [
          Positional('target', regex: RegExp(r'^valid$')),
        ],
      );

      expect(
        () => subject.parse(['invalid']),
        throwsA(isA<MambaParseException>()),
      );
    });

    test('requires positional expressions to match the entire value', () {
      final subject = parser(
        mandatoryPositionals: [Positional('initial', regex: RegExp(r'[A-Z]'))],
      );

      expectParseError(subject, ['Ada']);
    });

    test('validates explicit empty positional values', () {
      final subject = parser(
        mandatoryPositionals: [Positional('value', regex: RegExp(r'^$'))],
      );

      expect(subject.parse(['']).$2.singles, {'value': ''});
    });
  });

  group('Parses Variadics correctly', () {
    test('sends every argument after -- into the variadic array', () {
      final subject = parser(variadic: NormalVariadic('extra'));

      final result = subject.parse(['--', 'one', 'two', 'three']);

      expect(result.$2.variadic, {
        'extra': ['one', 'two', 'three'],
      });
      expect(result.$2.singles, isNull);
      expect(result.$2.repeated, isNull);
      expect(result.$4, ['one', 'two', 'three']);
    });

    test('leaves the variadic map empty without arguments', () {
      final result = parser(variadic: NormalVariadic('extra')).parse(['tool']);

      expect(result.$2.variadic, isNull);
    });

    test('does not absorb ordinary positional arguments', () {
      final subject = parser(variadic: NormalVariadic('extra'));

      expectParseError(subject, ['ordinary']);
    });

    test('accepts a variadic on its own without mandatory, discretionary, '
        'or repeated positionals', () {
      final subject = parser(
        flags: [BooleanFlag('force')],
        options: [IntOption('retries')],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse([
        '--force',
        '--retries',
        '2',
        '--',
        'a',
        'b',
      ]);

      expect(result.$3.boolFlags, {'force': true});
      expect(result.$3.intOptions, {'retries': 2});
      expect(result.$2.singles, isNull);
      expect(result.$2.repeated, isNull);
      expect(result.$2.variadic, {
        'extra': ['a', 'b'],
      });
    });

    test('matches every NormalVariadic value against its regex', () {
      final subject = parser(
        variadic: NormalVariadic('ids', regExp: RegExp(r'^\d+$')),
      );

      final result = subject.parse(['--', '12', '34', '56']);

      expect(result.$2.variadic, {
        'ids': ['12', '34', '56'],
      });
    });

    test('reports the exact failing index for a NormalVariadic value', () {
      final subject = parser(
        variadic: NormalVariadic('ids', regExp: RegExp(r'^\d+$')),
      );

      expect(
        () => subject.parse(['--', '12', 'oops', '56']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            allOf(contains('index 1'), contains('ids')),
          ),
        ),
      );
    });

    test('applies an omitted choice variadic default', () {
      final variadic = parser(
        variadic: ChoiceVariadic(
          'modes',
          choices: Mode.values,
          defaultValue: Mode.auto,
        ),
      ).parse(['--']).$2;

      expect(variadic.variadic, {
        'modes': ['auto'],
      });
    });

    test('accepts only enum member names for a ChoiceVariadic', () {
      final subject = parser(
        variadic: RepeatedChoiceVariadic<Mode>(
          'modes',
          choices: Mode.values,
          defaultValue: Mode.auto,
        ),
      );

      final result = subject.parse(['--', 'auto', 'always', 'auto']);

      expect(result.$2.variadic, {
        'modes': ['auto', 'always', 'auto'],
      });
    });

    test('reports the exact failing index for a ChoiceVariadic value', () {
      final subject = parser(
        variadic: RepeatedChoiceVariadic<Mode>('modes', choices: Mode.values),
      );

      expect(
        () => subject.parse(['--', 'auto', 'always', 'never']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            allOf(contains('index 2'), contains('modes')),
          ),
        ),
      );
    });

    test('collects dash values after mandatory positionals', () {
      final subject = parser(
        mandatoryPositionals: [Positional('source')],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse(['input.txt', '--', 'one', 'two']);

      expect(result.$2.singles, {'source': 'input.txt'});
      expect(result.$2.variadic, {
        'extra': ['one', 'two'],
      });
    });

    test('collects dash values after discretionary positionals', () {
      final subject = parser(
        discretionaryPositionals: [Positional('target')],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse(['output.txt', '--', 'one', 'two']);

      expect(result.$2.singles, {'target': 'output.txt'});
      expect(result.$2.variadic, {
        'extra': ['one', 'two'],
      });
    });

    test('collects dash values after Mandatory, Repeated, Mandatory', () {
      final subject = parser(
        mandatoryPositionals: [
          Positional('first'),
          RepeatedStringPositional('files'),
          Positional('last'),
        ],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse(['a', 'f1', 'f2', 'b', '--', 'v1', 'v2']);

      expect(result.$2.singles, {'first': 'a', 'last': 'b'});
      expect(result.$2.repeated, {
        'files': ['f1', 'f2'],
      });
      expect(result.$2.variadic, {
        'extra': ['v1', 'v2'],
      });
    });

    test('collects dash values after Mandatory, Repeated, Discretionary', () {
      final subject = parser(
        mandatoryPositionals: [
          Positional('first'),
          RepeatedStringPositional('files'),
        ],
        discretionaryPositionals: [Positional('target')],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse(['a', 'f1', 'f2', 't', '--', 'v1', 'v2']);

      expect(result.$2.singles, {'first': 'a', 'target': 't'});
      expect(result.$2.repeated, {
        'files': ['f1', 'f2'],
      });
      expect(result.$2.variadic, {
        'extra': ['v1', 'v2'],
      });
    });

    test('collects dash values after Mandatory, Discretionary, Repeated', () {
      final subject = parser(
        mandatoryPositionals: [Positional('first')],
        discretionaryPositionals: [RepeatedStringPositional('more')],
        variadic: NormalVariadic('extra'),
      );

      final result = subject.parse(['a', 'm1', 'm2', '--', 'v1', 'v2']);

      expect(result.$2.singles, {'first': 'a'});
      expect(result.$2.repeated, {
        'more': ['m1', 'm2'],
      });
      expect(result.$2.variadic, {
        'extra': ['v1', 'v2'],
      });
    });

    test('rejects leftover values when no other postionals are registered', () {
      final subject = parser(mandatoryPositionals: [Positional('source')]);

      expectParseError(subject, ['source', 'extra']);
    });
  });

  group('0.3 contract fixes', () {
    test('parses help as a defaulted global boolean flag', () {
      final subject = parser(flags: [CountFlag('verbose', short: 'v')]);

      expect(subject.parse([]).$3.boolFlags, isNull);
      expect(subject.parse([]).$3.countFlags, {'verbose': 0});
      expect(subject.parse([]).help, isFalse);
      expect(subject.parse(['-h']).$3.boolFlags, isNull);
      expect(subject.parse(['-h']).$3.countFlags, {'verbose': 0});
      expect(subject.parse(['-h']).help, isTrue);
      expect(subject.parse(['-hv']).$3.boolFlags, isNull);
      expect(subject.parse(['-hv']).$3.countFlags, {'verbose': 1});
    });

    test('rejects crossed long and short option forms', () {
      final subject = parser(
        options: [StringOption('output', short: 'o', regex: RegExp(r'\S+'))],
      );

      expectParseError(subject, ['--o', 'file']);
      expectParseError(subject, ['-output', 'file']);
      expect(subject.parse(['--output', 'file']).$3.stringOptions, {
        'output': 'file',
      });
      expect(subject.parse(['-o', 'file']).$3.stringOptions, {
        'output': 'file',
      });
    });

    test('explicit pair members are validated without defaults', () {
      final subject = parser(
        pairedOptions: [
          PairedOptions([
            PairChoiceOption('json', choices: Mode.values),
            PairStringOption('text', regex: RegExp(r'\S+')),
          ], variant: true),
        ],
      );

      expect(subject.parse(['--text', 'plain']).$3.stringOptions, {
        'text': 'plain',
      });
    });

    test('makes ChoiceVariadic single-valued', () {
      final subject = parser(
        variadic: ChoiceVariadic<Mode>('mode', choices: Mode.values),
      );

      expect(subject.parse(['--', 'auto']).$2.variadic, {
        'mode': ['auto'],
      });
      expectParseError(subject, ['--', 'auto', 'always']);
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
  _ParserCommand(this.name, {super.aliases, super.options});

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
