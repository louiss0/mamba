import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

enum Mode { auto, always }

Parser parser({
  List<Flag>? flags,
  List<Option>? options,
  List<AccessorOption>? accessors,
  List<Positional>? mandatoryPositionals,
  List<Positional>? discretionaryPositionals,
  Variadic? variadic,
}) => Parser(
  CommandRegistry.create(
    'tool',
    'Coverage command.',
    flags: flags,
    options: options,
    accessors: accessors,
    mandatoryPositionals: mandatoryPositionals,
    discretionaryPositionals: discretionaryPositionals,
    variadic: variadic,
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

      final inputs = subject.parse([
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
      ]).$2;

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
      expect(inputs.positionalOptions, {
        'source': 'input.txt',
        'target': 'output.txt',
      });
    });

    test('returns nullable maps according to registered content', () {
      final inputs = parser().parse([]).$2;

      expect(inputs.boolFlags, isNull);
      expect(inputs.countFlags, isNull);
      expect(inputs.stringOptions, isNull);
      expect(inputs.intOptions, isNull);
      expect(inputs.doubleOptions, isNull);
      expect(inputs.repeatedStringOptions, isNull);
      expect(inputs.repeatedIntOptions, isNull);
      expect(inputs.repeatedDoubleOptions, isNull);
      expect(inputs.accessors, isNull);
      expect(inputs.positionalOptions, isNull);
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
      ).parse([]).$2;

      expect(inputs.stringOptions, {'mode': 'auto'});
    });

    test('adds Boolean defaults only to Boolean flag maps', () {
      final inputs = parser(
        flags: [
          BooleanFlag(name: 'color', defaultValue: true),
          CountFlag(name: 'verbose'),
        ],
      ).parse([]).$2;

      expect(inputs.boolFlags, {'color': true});
      expect(inputs.countFlags, isEmpty);
    });

    test('collects variadic arguments separately from inputs', () {
      final result = parser(
        variadic: Variadic('arguments'),
      ).parse(['--', '--unknown', '-x']);

      expect(result.$2.positionalOptions, isNull);
      expect(result.$1, isEmpty);
      expect(result.$2.accessors, isNull);
      expect(result.$3, ['--unknown', '-x']);
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
      ]).$2;

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
