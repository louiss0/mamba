import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

enum Format { text, json }

Parser parser({
  List<Option>? options,
  List<Positional>? mandatory,
  List<AccessorListOption>? accessors,
  List<PairedOptions>? paired,
  List<SelectedOptions>? selected,
  Variadic? variadic,
}) => Parser(
  CommandRegistry.create(
    'tool',
    'Test tool.',
    options: options,
    mandatoryPositionals: mandatory,
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
      expect(inputs.require(source), Format.json);
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
  });
  group('repeatable choices', () {
    test('preserves duplicates unless unique is enabled', () {
      final mode = RepeatableChoiceOption<Format>('format', Format.values);
      expect(
        parser(options: [mode])
            .parse(['--format', 'json', '--format=json'])
            .$2
            .require(mode),
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
  group('selected options', () {
    test('maps exactly one selected typed value', () {
      final json = PairStringOption('json');
      final text = PairStringOption('text');
      final selected = SelectedOptions<String>([
        SelectableOption(json, (value) => 'json:$value'),
        SelectableOption(text, (value) => 'text:$value'),
      ], required: true);
      final inputs = parser(selected: [selected]).parse(['--json', 'out']).$2;
      expect(inputs.require(selected), 'json:out');
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
        final required = SelectedOptions<String>([
          SelectableOption(first, (value) => value),
          SelectableOption(second, (value) => value),
        ], required: true);
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
  test('keeps validated -- arguments out of inputs in order', () {
    final option = StringOption('value');
    final result = parser(
      options: [option],
      variadic: RepeatedChoiceVariadic<Format>(choices: Format.values),
    ).parse(['--value', 'one', '--', 'json', 'text', 'json']);
    expect(result.$3, ['json', 'text', 'json']);
    expect(result.$2.contains(option), isTrue);
  });
}
