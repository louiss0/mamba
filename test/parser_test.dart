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
  List<SelectedOptionsDefinition>? selected,
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
    selectedOptions: selected,
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
    test('stores accessor leaves rather than dynamic path maps', () {
      final host = AccessorStringOption('host');
      final port = AccessorIntOption('port');
      final inputs =
          parser(
            accessors: [
              AccessorListOption('server', [host, port]),
              AccessorListOption('proxy', [AccessorStringOption('host')]),
            ],
          ).parse([
            '--server.host',
            'localhost',
            '--server.port=80',
            '--proxy.host',
            'remote',
          ]).$2;
      expect(inputs.valueOf(host), 'localhost');
      expect(inputs.valueOf(port), 80);
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
    test('maps a complete group into one typed output', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final server = PairedOptions.required([
        host,
        port,
      ], (values) => (host: values.valueOf(host), port: values.valueOf(port)));

      final inputs = parser(paired: [server])
          .parse(['--host', 'localhost', '--port', '8080'])
          .$2;

      expect(inputs.valueOf(server), (host: 'localhost', port: 8080));
      expect(inputs.contains(host), isFalse);
      expect(inputs.contains(port), isFalse);
    });
  });

  group('selected options', () {
    test('maps exactly one selected typed value', () {
      final json = PairStringOption('json');
      final text = PairStringOption('text');
      final selected = SelectedOptions.required([
        SelectableOption(json, (value) => 'json:$value'),
        SelectableOption(text, (value) => 'text:$value'),
      ]);
      final inputs = parser(selected: [selected]).parse(['--json', 'out']).$2;
      expect(inputs.valueOf(selected), 'json:out');
      expect(inputs.contains(json), isFalse);
      expect(inputs.contains(text), isFalse);
    });
    test(
      'allows no optional selection and rejects none or many when required',
      () {
        final first = PairStringOption('first');
        final second = PairStringOption('second');
        final optional = SelectedOptions<String>([
          SelectableOption(first, (value) => value),
          SelectableOption(second, (value) => value),
        ]);
        expect(
          parser(selected: [optional]).parse([]).$2.valueOf(optional),
          isNull,
        );
        final required = SelectedOptions.required([
          SelectableOption(first, (value) => value),
          SelectableOption(second, (value) => value),
        ]);
        expect(
          () => parser(selected: [required]).parse([]),
          throwsA(isA<MambaParseException>()),
        );
        expect(
          () =>
              parser(selected: [required])
                  .parse(['--first', 'a', '--second', 'b']),
          throwsA(isA<MambaParseException>()),
        );
        expect(
          () =>
              parser(selected: [required])
                  .parse(['--first', 'a', '--first', 'b']),
          throwsA(isA<MambaParseException>()),
        );
      },
    );
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

  test('defaulted accessor leaves always produce values', () {
    final format = AccessorChoiceOption.withDefault(
      'format',
      choices: Format.values,
      defaultValue: Format.text,
    );
    final inputs = parser(
      accessors: [
        AccessorListOption('output', [format]),
      ],
    ).parse([]).$2;

    expect(inputs.valueOf(format), Format.text);
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

  group('required inputs and groups', () {
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

    test('reports missing required paired options', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final server = PairedOptions.required([host, port], (_) => Object());

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
      final server = PairedOptions([host, port], (_) => Object());

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
      final group =
          PairedOptions<
            ({List<String> tags, List<int> ports, List<double> ratios})
          >(
            [tags, ports, ratios],
            (values) => (
              tags: values.valueOf(tags),
              ports: values.valueOf(ports),
              ratios: values.valueOf(ratios),
            ),
          );

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

      final result = inputs.valueOf(group)!;
      expect(result.tags, ['one', 'two']);
      expect(result.ports, [1, 2]);
      expect(result.ratios, [0.5, 1.0]);
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
