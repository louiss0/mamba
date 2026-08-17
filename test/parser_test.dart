import 'package:arg_parser/command.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<AccessorOption>? accessors,
  List<PairedOption>? pairedOptions,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
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

      final help = HelpFormatter().formatHelp(registry);

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
            name: 'first-name',
            options: [PairStringOption(name: 'last-name')],
          ),
          PairedIntOption(
            name: 'minimum',
            options: [PairIntOption(name: 'maximum')],
          ),
          PairedDoubleOption(
            name: 'minimum-ratio',
            options: [PairDoubleOption(name: 'maximum-ratio')],
          ),
        ],
      );

      final inputs = subject.parse([
        '--first-name',
        'Ada',
        '--last-name',
        'Lovelace',
        '--minimum',
        '1',
        '--maximum',
        '2',
        '--minimum-ratio',
        '0.5',
        '--maximum-ratio',
        '1.5',
      ]).$3;

      expect(inputs.stringOptions, {
        'first-name': 'Ada',
        'last-name': 'Lovelace',
      });
      expect(inputs.intOptions, {'minimum': 1, 'maximum': 2});
      expect(inputs.doubleOptions, {
        'minimum-ratio': 0.5,
        'maximum-ratio': 1.5,
      });
    });

    test('parses paired repeatable string, int, and double options', () {
      final subject = parser(
        pairedOptions: [
          PairedRepeatableStringOption(
            name: 'name',
            options: [PairRepeatableStringOption(name: 'value')],
          ),
          PairedRepeatableIntOption(
            name: 'minimum',
            options: [PairRepeatableIntOption(name: 'maximum')],
          ),
          PairedRepeatableDoubleOption(
            name: 'minimum-weight',
            options: [PairRepeatableDoubleOption(name: 'maximum-weight')],
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
        '--minimum-weight',
        '0.5',
        '--maximum-weight',
        '1.5',
        '--minimum-weight',
        '2.5',
        '--maximum-weight',
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
        'minimum-weight': [0.5, 2.5],
        'maximum-weight': [1.5, 3.5],
      });
    });

    test('rejects a partially passed repeatable pair', () {
      final subject = parser(
        pairedOptions: [
          PairedRepeatableStringOption(
            name: 'name',
            options: [PairRepeatableStringOption(name: 'value')],
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
            options: [PairStringOption(name: 'api-key')],
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
            options: [PairStringOption(name: 'api-key')],
          ),
        ],
      );

      expectParseError(subject, ['--token', 'secret', '--api-key', 'key']);
    });

    test('accepts one repeatable variant member', () {
      final subject = parser(
        pairedOptions: [
          PairedRepeatableStringOption(
            name: 'tag',
            variant: true,
            options: [PairRepeatableStringOption(name: 'label')],
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
            options: [PairStringOption(name: 'api-key')],
          ),
        ],
      );

      expectParseError(subject, []);
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
  });
}
