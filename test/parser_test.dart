import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

enum Format { text, json }

Parser parser({
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
}
