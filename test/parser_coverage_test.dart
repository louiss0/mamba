import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

class CoverageFlags extends FlagSchema<()> {
  @override
  final schema = <Flag>[
    BooleanFlag(name: 'negatable', short: 'n', negatable: true),
    BooleanFlag(name: 'plain', short: 'p'),
    CountFlag(name: 'verbose', short: 'v'),
  ];

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class CoverageOptions extends OptionSchema<()> {
  CoverageOptions({this.required = false});

  final bool required;

  @override
  List<Option> get schema => [
    StringOption(name: 'word', short: 'w', regex: RegExp(r'^word$')),
    IntOption(name: 'integer', short: 'i'),
    DoubleOption(name: 'decimal', short: 'd'),
    ChoiceOption<Mode>(
      name: 'mode',
      short: 'm',
      choices: Mode.values,
      defaultValue: Mode.auto,
    ),
    RepeatableStringOption(
      name: 'header',
      short: 'h',
      regex: RegExp(r'\S+:.+'),
    ),
    RepeatableIntOption(name: 'numbers', short: 'r', required: required),
    RepeatableDoubleOption(name: 'ratios', short: 't'),
  ];

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class RequiredWordOptions extends OptionSchema<()> {
  @override
  final schema = <Option>[
    StringOption(name: 'word', required: true, regex: RegExp(r'^word$')),
  ];

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class CoverageAccessors extends AccessorOptionSchema<()> {
  @override
  final schema = <AccessorOption>[
    AccessorStringOption(name: 'user', regex: RegExp(r'^ada$')),
    AccessorIntOption(name: 'number'),
    AccessorDoubleOption(name: 'decimal'),
    AccessorChoiceOption<Mode>(
      name: 'mode',
      choices: Mode.values,
      defaultValue: Mode.auto,
    ),
    AccessorListOption(
      name: 'server',
      options: [
        AccessorStringOption(name: 'name', regex: RegExp(r'^api$')),
        AccessorIntOption(name: 'port'),
        AccessorDoubleOption(name: 'timeout'),
        AccessorChoiceOption<Mode>(
          name: 'mode',
          choices: Mode.values,
          defaultValue: Mode.auto,
        ),
      ],
    ),
  ];

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

class CoveragePositionals extends PositionalSchema<()> {
  CoveragePositionals({
    List<Positional>? mandatory,
    List<Positional>? discretionary,
    Variadic? variadic,
  }) : super(
         mandatory ?? const [],
         discretionary: discretionary,
         variadic: variadic,
       );

  @override
  () toRecord(Map<String, dynamic> args) => ();
}

Parser parser({
  FlagSchema? flags,
  OptionSchema? options,
  AccessorOptionSchema? accessors,
  PositionalSchema? positionals,
}) => Parser(
  CommandRegistry.create(
    'tool',
    'Coverage command.',
    flagSchema: flags,
    optionSchema: options,
    accessorSchema: accessors,
    positionalSchema: positionals,
  ),
);

void expectSuccess(Parser parser, List<String> args) {
  expect(() => parser.parse(args), returnsNormally);
}

void expectParseError(Parser parser, List<String> args) {
  expect(() => parser.parse(args), throwsA(isA<MambaParseException>()));
}

void main() {
  group('Parser input forms', () {
    test('parses long and short values for every option kind', () {
      final subject = parser(options: CoverageOptions());

      expectSuccess(subject, [
        '--word',
        'word',
        '-i',
        '2',
        '--decimal',
        '1.5',
        '-m',
        'always',
        '--header',
        'Accept: json',
        '-r',
        '200',
        '--ratios',
        '0.5',
      ]);
      expectSuccess(subject, ['-w', 'word', '-d', '2.5', '-h', 'X: y']);
    });

    test('parses long, short, negated, and count flags', () {
      final subject = parser(flags: CoverageFlags());

      expectSuccess(subject, [
        '--negatable',
        '--plain',
        '--verbose',
        '--verbose',
      ]);
      expectSuccess(subject, ['--no-negatable', '-nvpv']);
    });

    test('adds option and accessor choice defaults', () {
      expectSuccess(parser(options: CoverageOptions()), []);
      expectSuccess(parser(accessors: CoverageAccessors()), []);
      expectSuccess(parser(accessors: CoverageAccessors()), [
        '--server.port',
        '8080',
      ]);
    });

    test('parses primitive and grouped accessors of every type', () {
      final subject = parser(accessors: CoverageAccessors());

      expectSuccess(subject, [
        '--user',
        'ada',
        '--number',
        '2',
        '--decimal',
        '1.5',
        '--mode',
        'always',
        '--server.name',
        'api',
        '--server.port',
        '8080',
        '--server.timeout',
        '0.5',
        '--server.mode',
        'always',
      ]);
    });

    test('rejects variadic values without an option terminator', () {
      final subject = parser(
        positionals: CoveragePositionals(
          mandatory: [Positional('source')],
          discretionary: [Positional('target', regex: RegExp(r'^out$'))],
          variadic: Variadic('rest', regex: RegExp(r'^item$')),
        ),
      );

      expectParseError(subject, ['source', 'out', 'item', 'item']);
    });

    test('collects option-like values after the option terminator', () {
      final subject = parser(
        positionals: CoveragePositionals(
          variadic: Variadic('arguments', regex: RegExp(r'^-.+$')),
        ),
      );

      final inputs = subject.parse(['--', '--unknown', '-x']).$2;

      expect(inputs.variadic, ['--unknown', '-x']);
    });
  });

  group('Parser validation failures', () {
    test('rejects unknown long, dotted, and short inputs', () {
      final subject = parser(flags: CoverageFlags());

      expectParseError(subject, ['--missing']);
      expectParseError(subject, ['--missing.value', 'value']);
      expectParseError(subject, ['--one.two.three.four', 'value']);
      expectParseError(subject, ['-x']);
    });

    test('rejects missing values and invalid flag negation', () {
      final options = parser(options: CoverageOptions());
      final flags = parser(flags: CoverageFlags());

      expectParseError(options, ['--word']);
      expectParseError(options, ['--word', '--integer', '1']);
      expectParseError(flags, ['--no-plain']);
      expectParseError(flags, ['-n-p']);
    });

    test('rejects invalid single option values', () {
      final subject = parser(options: CoverageOptions());

      expectParseError(subject, ['--word', 'invalid']);
      expectParseError(subject, ['--integer', '1.5']);
      expectParseError(subject, ['--decimal', 'one']);
      expectParseError(subject, ['--mode', 'missing']);
    });

    test('rejects invalid repeated option values', () {
      final subject = parser(options: CoverageOptions());

      expectParseError(subject, ['--header', 'invalid']);
      expectParseError(subject, ['--numbers', '1', '--numbers', ' 2']);
      expectParseError(subject, ['--ratios', '1.5', '--ratios', ' 2.5']);
      expectParseError(subject, ['--ratios', '2.5 ']);
      expectParseError(subject, ['--ratios', 'invalid']);
    });

    test('rejects required options when omitted', () {
      expectParseError(parser(options: CoverageOptions(required: true)), []);
      expectParseError(parser(options: RequiredWordOptions()), []);
    });

    test('rejects missing, invalid, and excess positionals', () {
      final mandatory = parser(
        positionals: CoveragePositionals(mandatory: [Positional('source')]),
      );
      final discretionary = parser(
        positionals: CoveragePositionals(
          discretionary: [Positional('target', regex: RegExp(r'^out$'))],
        ),
      );
      final variadic = parser(
        positionals: CoveragePositionals(
          variadic: Variadic('rest', regex: RegExp(r'^item$')),
        ),
      );

      expectParseError(mandatory, []);
      expect(() => discretionary.parse(['wrong']), throwsArgumentError);
      expect(() => variadic.parse(['--', 'wrong']), throwsArgumentError);
      expectParseError(parser(), ['extra']);
    });

    test('rejects invalid accessor values', () {
      final subject = parser(accessors: CoverageAccessors());

      expectParseError(subject, ['--user', 'wrong']);
      expectParseError(subject, ['--number', 'two']);
      expectParseError(subject, ['--decimal', 'two']);
      expectParseError(subject, ['--mode', 'missing']);
    });
  });
}
