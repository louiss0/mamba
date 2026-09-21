import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

enum Format { text, json }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<MandatoryPositional>? mandatory,
  List<DiscretionaryPositional>? discretionary,
  List<AccessorListOption>? accessors,
  List<PairedOptionsDefinition>? paired,
  List<SelectedOptions>? selectedOptions,
  Map<String, List<String>>? conflicts,
  Variadic? variadic,
}) => Parser(
  CommandRegistry.create(
    'tool',
    'Test tool.',
    flags: flags,
    options: options,
    mandatoryPositionals: mandatory,
    discretionaryPositionals: discretionary,
    accessors: accessors,
    pairedOptions: paired,
    selectedOptions: selectedOptions,
    conflicts: conflicts,
    variadic: variadic,
  ),
);

void main() {
  group('typed parsed inputs', () {
    test('returns values through their declaration identities', () {
      final name = StringOption('name');
      final count = IntOption('count');
      final mode = ChoiceOption<Format>('format', choices: Format.values);
      final formats = RepeatableChoiceOption<Format>('formats', Format.values);
      final source = ChoicePositional<Format>('source', choices: Format.values);
      final inputs =
          parser(
            options: [name, count, mode, formats],
            mandatory: [source],
          ).parse([
            'json',
            '--name',
            'Ada',
            '--count',
            '2',
            '--format',
            'text',
            '--formats',
            'json',
            '--formats=text',
          ]).$2;
      expect(inputs.valueOf(name), 'Ada');
      expect(inputs.valueOf(count), 2);
      expect(inputs.valueOf(mode), Format.text);
      expect(inputs.valueOf(formats), [Format.json, Format.text]);
      expect(inputs.valueOf(source), Format.json);
    });
    test('keeps same-typed inputs separate and omitted values null', () {
      final first = StringOption('first');
      final second = StringOption('second');
      final inputs = parser(options: [first, second])
          .parse(['--first', 'one'])
          .$2;
      expect(inputs.valueOf(first), 'one');
      expect(inputs.valueOf(second), isNull);
    });
  });

  group('built-in flags', () {
    final registry = CommandRegistry.create(
      'tool',
      'Test tool.',
      flags: [
        MambaBuiltInFlags.dryRun,
        MambaBuiltInFlags.verbose,
        MambaBuiltInFlags.version,
      ],
    );
    final builtInParser = Parser(registry);

    test('returns the help flag through its declaration', () {
      final inputs = builtInParser.parse(['--help']).$2;

      expect(inputs.valueOf(MambaBuiltInFlags.help), isTrue);
    });

    test('returns the dry-run flag through its declaration', () {
      final inputs = builtInParser.parse(['--dry-run']).$2;

      expect(inputs.valueOf(MambaBuiltInFlags.dryRun), isTrue);
    });

    test('returns the verbose flag through its declaration', () {
      final inputs = builtInParser.parse(['--verbose', '--verbose']).$2;

      expect(inputs.valueOf(MambaBuiltInFlags.verbose), 2);
    });

    test('returns the version flag through its declaration', () {
      final inputs = builtInParser.parse(['--version']).$2;

      expect(inputs.valueOf(MambaBuiltInFlags.version), isTrue);
    });
  });

  group("rejects conflict's", () {
    Parser namedInputParser(Map<String, List<String>> conflicts) => parser(
      flags: [BooleanFlag('enabled'), CountFlag('verbose')],
      options: [
        StringOption('text'),
        IntOption('number'),
        DoubleOption('ratio'),
        ChoiceOption<Format>('format', choices: Format.values),
        RepeatableStringOption('tags'),
        RepeatableIntOption('retries'),
        RepeatableDoubleOption('weights'),
        RepeatableChoiceOption<Format>('formats', Format.values),
      ],
      paired: [
        PairedOptions<Object>([
          PairStringOption('host'),
          PairIntOption('port'),
        ]),
      ],
      selectedOptions: [
        SelectedOptions<Object>([
          PairStringOption('output'),
          PairIntOption('limit'),
        ]),
      ],
      conflicts: conflicts,
    );

    group('named inputs', () {
      final cases =
          <
            ({
              String description,
              Map<String, List<String>> conflicts,
              List<String> arguments,
            })
          >[
            (
              description: 'flags',
              conflicts: {
                'enabled': ['verbose'],
              },
              arguments: ['--enabled', '--verbose'],
            ),
            (
              description: 'scalar options',
              conflicts: {
                'text': ['number'],
              },
              arguments: ['--text', 'value', '--number', '1'],
            ),
            (
              description: 'numeric and choice options',
              conflicts: {
                'ratio': ['format'],
              },
              arguments: ['--ratio', '1.5', '--format', 'json'],
            ),
            (
              description: 'repeatable options',
              conflicts: {
                'tags': ['retries'],
              },
              arguments: ['--tags', 'one', '--retries', '2'],
            ),
            (
              description: 'repeatable numeric and choice options',
              conflicts: {
                'weights': ['formats'],
              },
              arguments: ['--weights', '1.5', '--formats', 'text'],
            ),
            (
              description: 'paired options',
              conflicts: {
                'host': ['port'],
              },
              arguments: ['--host', 'localhost', '--port', '8080'],
            ),
            (
              description: 'selected options',
              conflicts: {
                'output': ['limit'],
              },
              arguments: ['--output', 'stdout', '--limit', '10'],
            ),
          ];

      for (final testCase in cases) {
        test('rejects ${testCase.description}', () {
          expect(
            () =>
                namedInputParser(testCase.conflicts).parse(testCase.arguments),
            throwsA(isA<MambaParseException>()),
          );
        });
      }
    });

    Parser accessorParser(Map<String, List<String>> conflicts) => parser(
      accessors: [
        AccessorListOption('profile', [
          AccessorStringOption('name'),
          AccessorListOption('contact', [AccessorStringOption('email')]),
        ]),
        AccessorListOption('deployment', [
          AccessorListOption('release', [
            AccessorListOption('channel', [AccessorStringOption('name')]),
          ]),
        ]),
        AccessorListOption('telemetry', [
          AccessorListOption('exporter', [
            AccessorListOption('otlp', [
              AccessorListOption('authentication', [
                AccessorStringOption('token'),
              ]),
            ]),
          ]),
        ]),
      ],
      conflicts: conflicts,
    );

    group('accessor inputs', () {
      final cases =
          <
            ({
              String description,
              Map<String, List<String>> conflicts,
              List<String> arguments,
            })
          >[
            (
              description: 'a one-dot key',
              conflicts: {
                'profile.name': ['profile.contact.email'],
              },
              arguments: [
                '--profile.name',
                'Ada',
                '--profile.contact.email',
                'ada@example.com',
              ],
            ),
            (
              description: 'a two-dot key',
              conflicts: {
                'profile.contact.email': ['deployment.release.channel.name'],
              },
              arguments: [
                '--profile.contact.email',
                'ada@example.com',
                '--deployment.release.channel.name',
                'stable',
              ],
            ),
            (
              description: 'a three-dot key',
              conflicts: {
                'deployment.release.channel.name': [
                  'telemetry.exporter.otlp.authentication.token',
                ],
              },
              arguments: [
                '--deployment.release.channel.name',
                'stable',
                '--telemetry.exporter.otlp.authentication.token',
                'secret',
              ],
            ),
            (
              description: 'a four-dot key',
              conflicts: {
                'telemetry.exporter.otlp.authentication.token': [
                  'profile.name',
                ],
              },
              arguments: [
                '--telemetry.exporter.otlp.authentication.token',
                'secret',
                '--profile.name',
                'Ada',
              ],
            ),
            (
              description: 'a one-dot list value',
              conflicts: {
                'telemetry.exporter.otlp.authentication.token': [
                  'profile.name',
                ],
              },
              arguments: [
                '--telemetry.exporter.otlp.authentication.token',
                'secret',
                '--profile.name',
                'Ada',
              ],
            ),
            (
              description: 'a two-dot list value',
              conflicts: {
                'profile.name': ['profile.contact.email'],
              },
              arguments: [
                '--profile.name',
                'Ada',
                '--profile.contact.email',
                'ada@example.com',
              ],
            ),
            (
              description: 'a three-dot list value',
              conflicts: {
                'profile.name': ['deployment.release.channel.name'],
              },
              arguments: [
                '--profile.name',
                'Ada',
                '--deployment.release.channel.name',
                'stable',
              ],
            ),
            (
              description: 'a four-dot list value',
              conflicts: {
                'profile.name': [
                  'telemetry.exporter.otlp.authentication.token',
                ],
              },
              arguments: [
                '--profile.name',
                'Ada',
                '--telemetry.exporter.otlp.authentication.token',
                'secret',
              ],
            ),
          ];

      for (final testCase in cases) {
        test('rejects ${testCase.description}', () {
          expect(
            () => accessorParser(testCase.conflicts).parse(testCase.arguments),
            throwsA(isA<MambaParseException>()),
          );
        });
      }
    });
  });

  group('repeatable choices', () {
    test('preserves duplicates unless unique is enabled', () {
      final mode = RepeatableChoiceOption<Format>('format', Format.values);
      expect(
        parser(options: [mode])
            .parse(['--format', 'json', '--format=json'])
            .$2
            .valueOf(mode),
        [Format.json, Format.json],
      );
    });

    test('rejects duplicate enum members for all option spellings', () {
      for (final args in [
        ['--format', 'json', '--format', 'json'],
        ['-f', 'json', '-f', 'json'],
        ['--format=json', '--format=json'],
      ]) {
        final mode = RepeatableChoiceOption<Format>(
          'format',
          Format.values,
          short: 'f',
          unique: true,
        );
        expect(
          () => parser(options: [mode]).parse(args),
          throwsA(
            isA<MambaParseException>().having(
              (error) => error.message,
              'message',
              contains('json was provided more than once'),
            ),
          ),
        );
      }
    });

    test('exports unique only when enabled', () {
      final enabled = RepeatableChoiceOption<Format>(
        'format',
        Format.values,
        unique: true,
      );
      final disabled = RepeatableChoiceOption<Format>('other', Format.values);
      final record = CommandRegistry.create(
        'tool',
        'Tool.',
        options: [enabled, disabled],
      ).toMap();
      expect(record.options!.first.unique, true);
      expect(record.options!.last.unique, isNull);
    });
  });

  group('paired options', () {
    test('returns an empty map when the optional group is omitted', () {
      final host = PairStringOption('host');
      final password = PairStringOption('password');
      final credentials = PairedOptions<String>([host, password]);

      final Map<String, String> values = parser(paired: [credentials])
          .parse([])
          .$2
          .valueOf(credentials);

      expect(values, isEmpty);
    });

    test('preserves the declared map value type', () {
      final host = PairStringOption('host');
      final password = PairStringOption('password');
      final credentials = PairedOptions<String>.required([host, password]);

      final Map<String, String> values = parser(paired: [credentials])
          .parse(['--host', 'db.internal', '--password', 'mamba'])
          .$2
          .valueOf(credentials);

      expect(values, {'host': 'db.internal', 'password': 'mamba'});
    });

    test('maps a complete group into one typed map', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final server = PairedOptions<Object>.required([host, port]);

      final inputs = parser(paired: [server])
          .parse(['--host', 'localhost', '--port', '8080'])
          .$2;

      expect(inputs.valueOf(server), {'host': 'localhost', 'port': 8080});
      expect(inputs.contains(host), isFalse);
      expect(inputs.contains(port), isFalse);
    });
  });

  test('discretionary positionals preserve nullable and defaulted outputs', () {
    final destination = NormalPositional.optional('destination');
    final formats = RepeatedChoicePositional.withDefault(
      'formats',
      choices: Format.values,
      defaultValue: [Format.text],
    );
    final inputs = parser(discretionary: [destination, formats]).parse([]).$2;

    expect(inputs.valueOf(destination), isNull);
    expect(inputs.valueOf(formats), [Format.text]);
  });

  test('required and defaulted options always produce values', () {
    final name = StringOption.required('name');
    final format = ChoiceOption.withDefault(
      'format',
      choices: Format.values,
      defaultValue: Format.text,
    );

    expect(
      () => parser(options: [name, format]).parse([]),
      throwsA(isA<MambaParseException>()),
    );
    final inputs = parser(options: [name, format])
        .parse(['--name', 'mamba'])
        .$2;
    expect(inputs.valueOf(name), 'mamba');
    expect(inputs.valueOf(format), Format.text);
  });

  test(
    'required repeatable options reject omission and return typed lists',
    () {
      final formats = RepeatableChoiceOption.required('format', Format.values);
      expect(
        () => parser(options: [formats]).parse([]),
        throwsA(isA<MambaParseException>()),
      );

      final inputs = parser(options: [formats]).parse(['--format', 'json']).$2;
      expect(inputs.valueOf(formats), <Format>[Format.json]);
    },
  );

  group('flag and option tokens', () {
    test('parses long and clustered short flags', () {
      final verbose = BooleanFlag('verbose', short: 'v', negatable: true);
      final count = CountFlag('count', short: 'c');

      final result = parser(flags: [verbose, count])
          .parse(['--no-verbose', '--count', '-vcch']);

      expect(result.help, isTrue);
      expect(result.$2.valueOf(verbose), isTrue);
      expect(result.$2.valueOf(count), 3);
    });

    test('rejects unknown and valued long flags', () {
      final verbose = BooleanFlag('verbose', short: 'v');
      final subject = parser(flags: [verbose]);

      expect(
        () => subject.parse(['--unknown']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Unknown flag or option --unknown.',
          ),
        ),
      );
      expect(
        () => subject.parse(['--verbose=true']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Flag --verbose does not accept a value',
          ),
        ),
      );
    });

    test('rejects unknown clustered short flags', () {
      expect(
        () => parser().parse(['-x']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            "This isn't a registered short flag or option",
          ),
        ),
      );
    });

    test('requires option values while allowing matching dashed values', () {
      final name = StringOption('name', short: 'n');
      final format = ChoiceOption<Format>('format', choices: Format.values);
      final subject = parser(options: [name, format]);

      expect(
        () => subject.parse(['--name']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Option --name requires a value',
          ),
        ),
      );
      expect(
        () => subject.parse(['--format', '--name']),
        throwsA(isA<MambaParseException>()),
      );
      expect(subject.parse(['-n', '-draft']).$2.valueOf(name), '-draft');
    });
  });

  group('value validation', () {
    test('rejects values outside string patterns', () {
      final label = StringOption('label', regex: RegExp(r'[a-z]+'));

      expect(
        () => parser(options: [label]).parse(['--label', '123']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            "Option --label does not accept '123'.",
          ),
        ),
      );
    });

    test('rejects malformed integer and double values', () {
      final count = IntOption('count');
      final ratio = DoubleOption('ratio');
      final subject = parser(options: [count, ratio]);

      expect(
        () => subject.parse(['--count', 'many']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            contains('must be a signed decimal integer'),
          ),
        ),
      );
      for (final value in ['many', '1e2']) {
        expect(
          () => subject.parse(['--ratio', value]),
          throwsA(
            isA<MambaParseException>().having(
              (error) => error.message,
              'message',
              contains('must be a signed decimal number'),
            ),
          ),
        );
      }
    });

    test('rejects numeric values outside their range or step', () {
      final count = IntOption('count', min: 1, max: 3);
      final ratio = DoubleOption('ratio', min: 0, max: 1, step: 0.25);

      for (final value in ['0', '4']) {
        expect(
          () => parser(options: [count]).parse(['--count', value]),
          throwsA(
            isA<MambaParseException>().having(
              (error) => error.message,
              'message',
              'Option --count is outside its accepted range.',
            ),
          ),
        );
      }
      expect(
        () => parser(options: [ratio]).parse(['--ratio', '0.3']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            contains('must increment by 0.25'),
          ),
        ),
      );
      expect(
        parser(options: [ratio]).parse(['--ratio', '0.5']).$2.valueOf(ratio),
        0.5,
      );
    });

    test('rejects unknown choices', () {
      final format = ChoiceOption<Format>('format', choices: Format.values);

      expect(
        () => parser(options: [format]).parse(['--format', 'xml']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'xml is not a valid choice for format',
          ),
        ),
      );
    });
  });

  group('selected options', () {
    test('returns a map for a registered selected option', () {
      final json = PairStringOption('json');
      final output = SelectedOptions<String>([json]);

      final inputs = parser(selectedOptions: [output])
          .parse(['--json', 'tasks.json'])
          .$2;

      expect(inputs.valueOf(output), {'json': 'tasks.json'});
    });

    group('returns typed maps for each pair option type', () {
      final name = PairStringOption('name');
      final retries = PairIntOption('retries');
      final ratio = PairDoubleOption('ratio');
      final selected = SelectedOptions<Object>([name, retries, ratio]);
      final subject = parser(selectedOptions: [selected]);
      final cases = <({List<String> arguments, Map<String, Object> expected})>[
        (arguments: ['--name', 'mamba'], expected: {'name': 'mamba'}),
        (arguments: ['--retries', '3'], expected: {'retries': 3}),
        (arguments: ['--ratio', '0.5'], expected: {'ratio': 0.5}),
      ];

      for (final testCase in cases) {
        test('returns ${testCase.expected.keys.single}', () {
          final inputs = subject.parse(testCase.arguments).$2;

          expect(inputs.valueOf(selected), testCase.expected);
        });
      }
    });

    group('honors explicit value types', () {
      test('uses only string pair options for String', () {
        final host = PairStringOption('host');
        final database = PairStringOption('database');
        final connection = SelectedOptions<String>([host, database]);

        final Map<String, String> values = parser(selectedOptions: [connection])
            .parse(['--host', 'db.internal', '--database', 'mamba'])
            .$2
            .valueOf(connection);

        expect(values, {'host': 'db.internal', 'database': 'mamba'});
      });

      test('uses only int pair options for int', () {
        final port = PairIntOption('port');
        final retries = PairIntOption('retries');
        final connection = SelectedOptions<int>([port, retries]);

        final Map<String, int> values = parser(selectedOptions: [connection])
            .parse(['--port', '5432', '--retries', '3'])
            .$2
            .valueOf(connection);

        expect(values, {'port': 5432, 'retries': 3});
      });

      test('uses only double pair options for double', () {
        final timeout = PairDoubleOption('timeout');
        final ratio = PairDoubleOption('ratio');
        final connection = SelectedOptions<double>([timeout, ratio]);

        final Map<String, double> values = parser(selectedOptions: [connection])
            .parse(['--timeout', '1.5', '--ratio', '0.75'])
            .$2
            .valueOf(connection);

        expect(values, {'timeout': 1.5, 'ratio': 0.75});
      });
    });

    group('parses multiple values', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final timeout = PairDoubleOption('timeout');
      final connection = SelectedOptions<Object>([host, port, timeout]);
      final subject = parser(selectedOptions: [connection]);
      final cases = <({List<String> arguments, Map<String, Object> expected})>[
        (
          arguments: ['--host', 'db.internal', '--port', '5432'],
          expected: {'host': 'db.internal', 'port': 5432},
        ),
        (
          arguments: ['--host', 'db.internal', '--timeout', '1.5'],
          expected: {'host': 'db.internal', 'timeout': 1.5},
        ),
        (
          arguments: ['--port', '5432', '--timeout', '1.5'],
          expected: {'port': 5432, 'timeout': 1.5},
        ),
        (
          arguments: [
            '--host',
            'db.internal',
            '--port',
            '5432',
            '--timeout',
            '1.5',
          ],
          expected: {'host': 'db.internal', 'port': 5432, 'timeout': 1.5},
        ),
      ];

      for (final testCase in cases) {
        test('returns ${testCase.expected.keys.join(', ')}', () {
          final inputs = subject.parse(testCase.arguments).$2;

          expect(inputs.valueOf(connection), testCase.expected);
        });
      }
    });

    test('requires at least one selected value', () {
      final json = PairStringOption('json');
      final text = PairStringOption('text');
      final output = SelectedOptions<String>.required([json, text]);
      final subject = parser(selectedOptions: [output]);

      expect(() => subject.parse([]), throwsA(isA<MambaParseException>()));
    });

    test('allows a single selected value when requested', () {
      final json = PairStringOption('json');
      final text = PairStringOption('text');
      final output = SelectedOptions<String>.single([json, text]);
      final subject = parser(selectedOptions: [output]);

      expect(subject.parse(['--json', 'tasks.json']).$2.valueOf(output), {
        'json': 'tasks.json',
      });
      expect(
        () => subject.parse(['--json', 'tasks.json', '--text', 'tasks.txt']),
        throwsA(isA<MambaParseException>()),
      );
    });

    group('single and required selected options', () {
      final json = PairStringOption('json');
      final text = PairStringOption('text');
      final attempts = PairIntOption('attempts');
      final output = SelectedOptions<String>.single([json, text]);
      final retry = SelectedOptions<int>.required([attempts]);
      final subject = parser(selectedOptions: [output, retry]);

      test('requires a value for the required selection', () {
        expect(() => subject.parse([]), throwsA(isA<MambaParseException>()));
      });

      test('returns one required selected value', () {
        final inputs = subject.parse(['--attempts', '3']).$2;

        expect(inputs.valueOf(retry), {'attempts': 3});
        expect(inputs.valueOf(output), isEmpty);
      });
    });
  });

  group('acessor options', () {
    test('returns accessor values through their top-level map', () {
      final host = AccessorStringOption('host');
      final port = AccessorIntOption('port');
      final server = AccessorListOption('server', [host, port]);
      final inputs = parser(accessors: [server])
          .parse(['--server.host', 'localhost', '--server.port=80'])
          .$2;

      expect(inputs.valueOf(server), {'host': 'localhost', 'port': 80});
    });

    test('returns nested accessor values in immutable maps', () {
      final token = AccessorStringOption('token');
      final auth = AccessorListOption('auth', [token]);
      final server = AccessorListOption('server', [auth]);

      final values = parser(accessors: [server])
          .parse(['--server.auth.token', 'secret'])
          .$2
          .valueOf(server);

      expect(values, {
        'auth': {'token': 'secret'},
      });
      expect(() => values['auth'] = {}, throwsUnsupportedError);
      expect(
        () => (values['auth']! as Map<String, Object?>)['token'] = 'changed',
        throwsUnsupportedError,
      );
    });

    test('returns defaulted accessor leaves', () {
      final format = AccessorChoiceOption.withDefault(
        'format',
        choices: Format.values,
        defaultValue: Format.text,
      );
      final output = AccessorListOption('output', [format]);

      final inputs = parser(accessors: [output]).parse([]).$2;

      expect(inputs.valueOf(output), {'format': Format.text});
    });

    test('requires nested accessor leaves', () {
      final token = AccessorStringOption.required('token');
      final subject = parser(
        accessors: [
          AccessorListOption('server', [
            AccessorListOption('auth', [token]),
          ]),
        ],
      );

      expect(
        () => subject.parse([]),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Option --server.auth.token is required.',
          ),
        ),
      );
    });

    test('rejects reusing an accessor leaf in multiple paths', () {
      final leaf = AccessorStringOption('host');

      expect(
        () => parser(
          accessors: [
            AccessorListOption('one', [leaf]),
            AccessorListOption('two', [leaf]),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects duplicate accessor paths', () {
      expect(
        () => parser(
          accessors: [
            AccessorListOption('server', [AccessorStringOption('host')]),
            AccessorListOption('server', [AccessorStringOption('host')]),
          ],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    group('extracts nested values', () {
      final database = AccessorListOption('database', [
        AccessorStringOption('host'),
        AccessorIntOption('port'),
      ]);
      final cache = AccessorListOption('cache', [
        AccessorListOption('redis', [
          AccessorStringOption('host'),
          AccessorIntOption('port'),
        ]),
      ]);
      final deployment = AccessorListOption('deployment', [
        AccessorListOption('region', [
          AccessorListOption('primary', [
            AccessorStringOption('name'),
            AccessorStringOption('zone'),
          ]),
        ]),
      ]);
      final gateway = AccessorListOption('gateway', [
        AccessorListOption('tls', [
          AccessorListOption('certificate', [
            AccessorListOption('renewal', [
              AccessorStringOption('path'),
              AccessorIntOption('days'),
            ]),
          ]),
        ]),
      ]);
      final telemetry = AccessorListOption('telemetry', [
        AccessorListOption('exporter', [
          AccessorListOption('otlp', [
            AccessorListOption('authentication', [
              AccessorListOption('credentials', [
                AccessorStringOption('client-id'),
                AccessorStringOption('client-secret'),
              ]),
            ]),
          ]),
        ]),
      ]);
      final subject = parser(
        accessors: [database, cache, deployment, gateway, telemetry],
      );
      final cases =
          <
            ({
              String description,
              List<String> arguments,
              AccessorListOption accessor,
              Map<String, Object?> expected,
            })
          >[
            (
              description: 'two-level database settings',
              arguments: [
                '--database.host',
                'db.internal',
                '--database.port',
                '5432',
              ],
              accessor: database,
              expected: {'host': 'db.internal', 'port': 5432},
            ),
            (
              description: 'three-level cache settings',
              arguments: [
                '--cache.redis.host',
                'cache.internal',
                '--cache.redis.port',
                '6379',
              ],
              accessor: cache,
              expected: {
                'redis': {'host': 'cache.internal', 'port': 6379},
              },
            ),
            (
              description: 'four-level deployment settings',
              arguments: [
                '--deployment.region.primary.name',
                'us-east',
                '--deployment.region.primary.zone',
                'us-east-1a',
              ],
              accessor: deployment,
              expected: {
                'region': {
                  'primary': {'name': 'us-east', 'zone': 'us-east-1a'},
                },
              },
            ),
            (
              description: 'five-level certificate settings',
              arguments: [
                '--gateway.tls.certificate.renewal.path',
                '/etc/certs/gateway.pem',
                '--gateway.tls.certificate.renewal.days',
                '30',
              ],
              accessor: gateway,
              expected: {
                'tls': {
                  'certificate': {
                    'renewal': {'path': '/etc/certs/gateway.pem', 'days': 30},
                  },
                },
              },
            ),
            (
              description: 'six-level telemetry credentials',
              arguments: [
                '--telemetry.exporter.otlp.authentication.credentials.client-id',
                'mamba-cli',
                '--telemetry.exporter.otlp.authentication.credentials.client-secret',
                'secret',
              ],
              accessor: telemetry,
              expected: {
                'exporter': {
                  'otlp': {
                    'authentication': {
                      'credentials': {
                        'client-id': 'mamba-cli',
                        'client-secret': 'secret',
                      },
                    },
                  },
                },
              },
            ),
          ];

      for (final testCase in cases) {
        test(testCase.description, () {
          final inputs = subject.parse(testCase.arguments).$2;

          expect(inputs.valueOf(testCase.accessor), testCase.expected);
        });
      }
    });
  });

  group('required inputs and groups', () {
    test('reports missing required paired options', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final server = PairedOptions<Object>.required([host, port]);

      expect(
        () => parser(paired: [server]).parse([]),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Required paired options are missing: --host, --port',
          ),
        ),
      );
    });

    test('requires optional paired options to appear together', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final server = PairedOptions<Object>([host, port]);

      expect(
        () => parser(paired: [server]).parse(['--host', 'localhost']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'Paired options --host, --port must be passed together',
          ),
        ),
      );
    });

    test('returns typed repeatable paired option values', () {
      final tags = RepeatablePairStringOption('tag');
      final ports = RepeatablePairIntOption('port');
      final ratios = RepeatablePairDoubleOption('ratio');
      final group = PairedOptions<Object>([tags, ports, ratios]);

      final inputs = parser(paired: [group]).parse([
        '--tag',
        'one',
        '--tag=two',
        '--port',
        '1',
        '--port=2',
        '--ratio',
        '0.5',
        '--ratio=1',
      ]).$2;

      final result = inputs.valueOf(group);
      expect(result['tag'], ['one', 'two']);
      expect(result['port'], [1, 2]);
      expect(result['ratio'], [0.5, 1.0]);
    });
  });

  group('positionals and variadics', () {
    test('parses repeated positionals before the next matching input', () {
      final files = RepeatedStringPositional(
        'files',
        times: 2,
        regExp: RegExp(r'[a-z]+'),
      );
      final count = NormalPositional('count', regExp: RegExp(r'\d+'));

      final inputs = parser(mandatory: [files, count])
          .parse(['one', 'two', '3'])
          .$2;

      expect(inputs.valueOf(files), ['one', 'two']);
      expect(inputs.valueOf(count), '3');
    });

    test('limits repeated positionals when the next input also matches', () {
      final files = RepeatedStringPositional('files', times: 2);
      final destination = NormalPositional('destination');

      final inputs = parser(mandatory: [files, destination])
          .parse(['one', 'two', 'three'])
          .$2;

      expect(inputs.valueOf(files), ['one', 'two']);
      expect(inputs.valueOf(destination), 'three');
    });

    test('reports missing mandatory positional inputs', () {
      final files = RepeatedStringPositional('files');
      final destination = NormalPositional('destination');

      expect(
        () => parser(mandatory: [files]).parse([]),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'The files is required at 0 after this command',
          ),
        ),
      );
      expect(
        () => parser(mandatory: [destination]).parse([]),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'The destination is required at 0 after this command',
          ),
        ),
      );
    });

    test('uses positional defaults and rejects excess terms', () {
      final format = ChoicePositional.withDefault(
        'format',
        choices: Format.values,
        defaultValue: Format.text,
      );

      expect(
        parser(discretionary: [format]).parse([]).$2.valueOf(format),
        Format.text,
      );
      expect(
        () => parser().parse(['extra']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            "This term isn't a registered command positional",
          ),
        ),
      );
    });

    test('validates normal and choice variadics', () {
      final normal = NormalVariadic(regExp: RegExp(r'[a-z]+'));
      final choices = ChoiceVariadic<Format>(choices: Format.values);

      expect(parser(variadic: normal).parse(['--', 'one', 'two']).$3, [
        'one',
        'two',
      ]);
      expect(
        () => parser(variadic: normal).parse(['--', '123']),
        throwsA(isA<MambaParseException>()),
      );
      expect(
        () => parser(variadic: choices).parse(['--', 'text', 'json']),
        throwsA(
          isA<MambaParseException>().having(
            (error) => error.message,
            'message',
            'The registered variadic accepts only one value.',
          ),
        ),
      );
      expect(
        () => parser(variadic: choices).parse(['--', 'xml']),
        throwsA(isA<MambaParseException>()),
      );
      expect(parser(variadic: choices).parse(['--', 'json']).$3, ['json']);
    });
  });
}
