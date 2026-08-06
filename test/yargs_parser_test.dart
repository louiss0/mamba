import 'dart:io';

import 'package:arg_parser/arg_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = YargsParser();

  group('YargsParser token decoding', () {
    test(
      'parses strings, aliases, short groups, and generated camel aliases',
      () {
        final result = parser.detailed(
          '--output-file="release notes" -v',
          const YargsParserOptions(
            alias: {
              'verbose': ['v'],
              'output-file': ['o'],
            },
            boolean: ['verbose'],
            string: ['output-file'],
          ),
        );

        expect(result.error, isNull);
        expect(result.argv, {
          '_': [],
          'output-file': 'release notes',
          'o': 'release notes',
          'outputFile': 'release notes',
          'v': true,
          'verbose': true,
        });
        expect(result.aliases['output-file'], ['o', 'outputFile']);
        expect(result.newAliases, {'outputFile': true});
      },
    );

    test('parses count flags, arrays, fixed arity, and numeric values', () {
      final argv = parser.parse(
        ['-vv', '--tag', 'one', 'two', '--range', '1', '2'],
        const YargsParserOptions(
          alias: {
            'verbose': ['v'],
          },
          count: ['verbose'],
          array: [YargsParserArrayOption('tag')],
          narg: {'range': 2},
        ),
      );

      expect(argv, {
        '_': [],
        'v': 2,
        'verbose': 2,
        'tag': ['one', 'two'],
        'range': [1, 2],
      });
    });

    test('supports Boolean negation and preserves terminator values', () {
      final argv = parser.parse(
        ['--no-color', '--', '--literal'],
        const YargsParserOptions(
          boolean: ['color'],
          configuration: YargsParserConfiguration(populateDoubleDash: true),
        ),
      );

      expect(argv, {
        '_': [],
        'color': false,
        '--': ['--literal'],
      });
    });

    test(
      'builds dotted objects and can retain dotted keys when configured',
      () {
        final nested = parser.parse(['--user.name=Ada']);
        final flat = parser.parse(
          ['--user.name=Ada'],
          const YargsParserOptions(
            configuration: YargsParserConfiguration(dotNotation: false),
          ),
        );

        expect(nested, {
          '_': [],
          'user': {'name': 'Ada'},
        });
        expect(flat, {'_': [], 'user.name': 'Ada'});
      },
    );

    test('treats unknown options as positionals when configured', () {
      final argv = parser.parse(
        ['--unknown', '--known', 'value'],
        const YargsParserOptions(
          key: {'known': null},
          configuration: YargsParserConfiguration(unknownOptionsAsArgs: true),
        ),
      );

      expect(argv, {
        '_': ['--unknown'],
        'known': 'value',
      });
    });

    test('preserves command and subcommand words as ordered positionals', () {
      final argv = parser.parse([
        'remote',
        '--verbose',
        'add',
        'origin',
        '--fetch',
      ], const YargsParserOptions(boolean: ['verbose', 'fetch']));

      expect(argv, {
        '_': ['remote', 'add', 'origin'],
        'verbose': true,
        'fetch': true,
      });
    });

    test('honors duplicate-value configuration', () {
      final defaultBehavior = parser.parse(['--tag', 'one', '--tag', 'two']);
      final lastValueWins = parser.parse(
        ['--tag', 'one', '--tag', 'two'],
        const YargsParserOptions(
          configuration: YargsParserConfiguration(
            duplicateArgumentsArray: false,
          ),
        ),
      );

      expect(defaultBehavior, {
        '_': [],
        'tag': ['one', 'two'],
      });
      expect(lastValueWins, {'_': [], 'tag': 'two'});
    });
  });

  group('YargsParser storage walkthrough', () {
    test('stores options by name and command words in the positional list', () {
      final argv = parser.parse(
        ['remote', '--verbose', 'add', 'origin', '--tag', 'stable', 'release'],
        const YargsParserOptions(
          boolean: ['verbose'],
          array: [YargsParserArrayOption('tag')],
        ),
      );

      expect(argv['_'], ['remote', 'add', 'origin']);
      expect(argv['verbose'], true);
      expect(argv['tag'], ['stable', 'release']);
    });

    test('uses narg to consume an exact number of following values', () {
      final argv = parser.parse([
        'deploy',
        '--range',
        '1',
        '2',
        'production',
      ], const YargsParserOptions(narg: {'range': 2}));

      // `range` consumes exactly `1` and `2`; command-like words remain in `_`.
      expect(argv, {
        '_': ['deploy', 'production'],
        'range': [1, 2],
      });
    });

    test(
      'leaves a second value positional when an option has no narg hint',
      () {
        final argv = parser.parse(['deploy', '--range', '1', 'production']);

        expect(argv, {
          '_': ['deploy', 'production'],
          'range': 1,
        });
      },
    );
  });

  group('YargsParser value sources and transforms', () {
    test(
      'applies command-line, environment, config-object, and default precedence',
      () {
        const environmentOptions = YargsParserOptions(
          string: ['name'],
          defaultValues: {'name': 'default'},
          configObjects: [
            {'name': 'config'},
          ],
          envPrefix: 'TASK_',
          environment: {'TASK_NAME': 'environment'},
        );
        const configOptions = YargsParserOptions(
          string: ['name'],
          defaultValues: {'name': 'default'},
          configObjects: [
            {'name': 'config'},
          ],
        );
        const defaultOptions = YargsParserOptions(
          string: ['name'],
          defaultValues: {'name': 'default'},
        );

        expect(
          parser.parse(['--name=command'], environmentOptions)['name'],
          'command',
        );
        expect(parser.parse([], environmentOptions)['name'], 'environment');
        expect(parser.parse([], configOptions)['name'], 'config');
        expect(parser.parse([], defaultOptions)['name'], 'default');
      },
    );

    test('loads JSON config files after command-line values', () async {
      final directory = await Directory.systemTemp.createTemp('yargs-parser-');
      final configFile = File(
        '${directory.path}${Platform.pathSeparator}config.json',
      );
      await configFile.writeAsString('{"name":"from-config","retries":3}');
      addTearDown(() => directory.delete(recursive: true));

      final argv = parser.parse([
        '--config',
        configFile.path,
        '--name=command',
      ], const YargsParserOptions(config: {'config': null}, string: ['name']));

      expect(argv['name'], 'command');
      expect(argv['retries'], 3);
    });

    test('applies coercions once and captures coercion failures', () {
      final coerced = parser.detailed([
        '--name',
        'ada',
      ], YargsParserOptions(coerce: {'name': (value) => '$value!'}));
      final failed = parser.detailed(
        ['--name', 'ada'],
        YargsParserOptions(
          coerce: {'name': (value) => throw StateError('invalid name')},
        ),
      );

      expect(coerced.argv['name'], 'ada!');
      expect(coerced.error, isNull);
      expect(failed.error, isA<StateError>());
    });

    test('normalizes paths without resolving them to an absolute path', () {
      final argv = parser.parse([
        '--path',
        'notes/../release',
      ], const YargsParserOptions(normalize: ['path']));

      expect(argv['path'], 'release');
    });
  });
}
