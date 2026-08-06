import 'package:arg_parser/arg_parser.dart';
import 'package:test/test.dart';

ArgArguments parseSuccessfully(ArgParser parser, List<String> tokens) {
  final outcome = parser.parse(tokens);
  expect(outcome, isA<ArgParseSuccess>());
  return (outcome as ArgParseSuccess).arguments;
}

ArgParseError parseWithError(ArgParser parser, List<String> tokens) {
  final outcome = parser.parse(tokens);
  expect(outcome, isA<ArgParseFailure>());
  return (outcome as ArgParseFailure).error;
}

void main() {
  group('declarative option schemas', () {
    test('parses long, abbreviated, attached, and clustered options', () {
      final parser = ArgParser(
        options: {
          'verbose': const BooleanOption(alias: 'v'),
          'force': const BooleanOption(alias: 'f'),
          'output': const StringOption(alias: 'o'),
        },
      );

      final long = parseSuccessfully(parser, ['--output=dist', '--verbose']);
      final short = parseSuccessfully(parser, ['-vfoarchive.zip']);

      expect(long.string('output'), 'dist');
      expect(long.flag('verbose'), isTrue);
      expect(short.flag('verbose'), isTrue);
      expect(short.flag('force'), isTrue);
      expect(short.string('output'), 'archive.zip');
    });

    test('applies defaults, choices, required values, and negation', () {
      final parser = ArgParser(
        options: {
          'color': const BooleanOption(defaultValue: true),
          'format': const StringOption(
            defaultValue: 'text',
            choices: {'text', 'json'},
          ),
          'output': const StringOption(required: true),
        },
      );

      final arguments = parseSuccessfully(parser, [
        '--no-color',
        '--format=json',
        '--output',
        'dist',
      ]);

      expect(arguments.flag('color'), isFalse);
      expect(arguments.string('format'), 'json');
      expect(arguments.string('output'), 'dist');
    });

    test('snapshots mutable schema collections at construction', () {
      final choices = <String>{'text'};
      final parser = ArgParser(
        options: {'format': StringOption(choices: choices)},
      );
      choices.add('json');

      final error = parseWithError(parser, ['--format=json']);

      expect(error.code, ArgParseErrorCode.invalidValue);
    });

    test('preserves explicitly empty and repeated option values', () {
      final parser = ArgParser(
        options: {'output': const StringOption(alias: 'o')},
      );

      final arguments = parseSuccessfully(parser, ['--output=first', '-o=']);

      expect(arguments.string('output'), isEmpty);
    });

    test('stops option parsing at the terminator', () {
      final parser = ArgParser(options: {'verbose': const BooleanOption()});

      final arguments = parseSuccessfully(parser, [
        '--verbose',
        '--',
        '--unknown',
      ]);

      expect(arguments.flag('verbose'), isTrue);
      expect(arguments.rest, ['--unknown']);
    });
  });

  group('native accessor values', () {
    test('materializes nested schemas as nested objects', () {
      final parser = ArgParser(
        accessors: {
          'user': {
            'name': const StringOption(),
            'address': {'city': const StringOption()},
            'admin': const BooleanOption(),
          },
        },
      );

      final arguments = parseSuccessfully(parser, [
        '--user.name=Ada',
        '--user.address.city',
        'London',
        '--user.admin',
      ]);

      expect(arguments['user'], {
        'name': 'Ada',
        'address': {'city': 'London'},
        'admin': true,
      });
      expect(arguments.value('user.address.city'), 'London');
      expect(arguments.object('user.address'), {'city': 'London'});
    });

    test('includes defaults while omitting unset string options', () {
      final parser = ArgParser(
        accessors: {
          'server': {
            'host': const StringOption(defaultValue: 'localhost'),
            'port': const StringOption(),
          },
        },
      );

      final arguments = parseSuccessfully(parser, []);

      expect(arguments.values, {
        'server': {'host': 'localhost'},
      });
    });

    test('treats objects as containers instead of root options', () {
      final parser = ArgParser(
        accessors: {
          'user': {'name': const StringOption()},
        },
      );

      final error = parseWithError(parser, ['--user=Ada']);

      expect(error.code, ArgParseErrorCode.unknownOption);
      expect(error.token, '--user=Ada');
    });

    test('rejects ordinary option and accessor path conflicts', () {
      expect(
        () => ArgParser(
          options: {'user': const StringOption()},
          accessors: {
            'user': {'name': const StringOption()},
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects dotted keys in ordinary option schemas', () {
      expect(
        () => ArgParser(options: {'user.name': const StringOption()}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('command schema activation', () {
    final parser = ArgParser(
      options: {'verbose': const BooleanOption(alias: 'v')},
      commands: [
        ArgCommand(
          'build',
          aliases: const {'b'},
          options: {
            'release': const BooleanOption(alias: 'r'),
            'target': const StringOption(),
          },
          positionals: const [ArgPositional('source', required: true)],
        ),
        ArgCommand(
          'serve',
          options: {'port': const StringOption(defaultValue: '8080')},
        ),
      ],
    );

    test('activates one command and returns one merged argument object', () {
      final arguments = parseSuccessfully(parser, [
        '--verbose',
        'build',
        '--release',
        '--target=web',
        'src',
      ]);

      expect(arguments.commandPath, ['build']);
      expect(arguments.values, {
        'verbose': true,
        'release': true,
        'target': 'web',
        'source': 'src',
      });
      expect(arguments.positional('source'), 'src');
    });

    test('does not activate command options before command selection', () {
      final error = parseWithError(parser, ['--release', 'build', 'src']);

      expect(error.code, ArgParseErrorCode.unknownOption);
      expect(error.token, '--release');
    });

    test('keeps root options active after selecting a command', () {
      final arguments = parseSuccessfully(parser, [
        'build',
        'src',
        '--verbose',
      ]);

      expect(arguments.flag('verbose'), isTrue);
    });

    test('does not activate sibling option schemas or defaults', () {
      final error = parseWithError(parser, ['build', 'src', '--port=9000']);
      final build = parseSuccessfully(parser, ['build', 'src']);

      expect(error.code, ArgParseErrorCode.unknownOption);
      expect(build.value('port'), isNull);
    });

    test('selects aliases but reports canonical command paths', () {
      final arguments = parseSuccessfully(parser, ['b', 'src']);

      expect(arguments.commandPath, ['build']);
    });

    test('requires a known root command', () {
      expect(parseWithError(parser, []).code, ArgParseErrorCode.missingCommand);
      expect(
        parseWithError(parser, ['deploy']).code,
        ArgParseErrorCode.unknownCommand,
      );
    });

    test('supports nested command schemas', () {
      final nestedParser = ArgParser(
        commands: [
          ArgCommand(
            'remote',
            options: {'verbose': const BooleanOption()},
            commands: [
              ArgCommand(
                'add',
                options: {'fetch': const BooleanOption()},
                positionals: const [
                  ArgPositional('name', required: true),
                  ArgPositional('url', required: true),
                ],
              ),
            ],
          ),
        ],
      );

      final arguments = parseSuccessfully(nestedParser, [
        'remote',
        'add',
        'origin',
        'https://example.test/repo',
        '--verbose',
        '--fetch',
      ]);

      expect(arguments.commandPath, ['remote', 'add']);
      expect(arguments.flag('verbose'), isTrue);
      expect(arguments.flag('fetch'), isTrue);
      expect(arguments.positional('name'), 'origin');
    });
  });

  group('positional schemas', () {
    test('binds named and variadic arguments', () {
      final parser = ArgParser(
        positionals: const [
          ArgPositional('input', required: true),
          ArgPositional('outputs', multiple: true),
        ],
      );

      final arguments = parseSuccessfully(parser, [
        'source.dart',
        'a.js',
        'b.js',
      ]);

      expect(arguments.positional('input'), 'source.dart');
      expect(arguments.positionals('outputs'), ['a.js', 'b.js']);
      expect(arguments.values, {
        'input': 'source.dart',
        'outputs': ['a.js', 'b.js'],
      });
    });

    test('returns missing positional errors with corrective context', () {
      final parser = ArgParser(
        commands: [
          ArgCommand(
            'build',
            positionals: const [ArgPositional('source', required: true)],
          ),
        ],
      );

      final error = parseWithError(parser, ['build']);

      expect(error.code, ArgParseErrorCode.missingPositional);
      expect(error.message, contains('<source>'));
      expect(error.message, contains('build'));
    });
  });

  group('structured failures', () {
    test('returns errors for malformed user input', () {
      final parser = ArgParser(
        options: {
          'verbose': const BooleanOption(negatable: false),
          'format': const StringOption(choices: {'json', 'text'}),
          'output': const StringOption(required: true),
        },
      );

      expect(
        parseWithError(parser, ['--unknown']).code,
        ArgParseErrorCode.unknownOption,
      );
      expect(
        parseWithError(parser, ['--verbose=yes']).code,
        ArgParseErrorCode.unexpectedValue,
      );
      expect(
        parseWithError(parser, ['--no-verbose']).code,
        ArgParseErrorCode.unknownOption,
      );
      expect(
        parseWithError(parser, ['--format']).code,
        ArgParseErrorCode.missingValue,
      );
      expect(
        parseWithError(parser, ['--format=yaml']).code,
        ArgParseErrorCode.invalidValue,
      );
      expect(
        parseWithError(parser, []).code,
        ArgParseErrorCode.missingRequiredOption,
      );
    });

    test('reports the failing token and absolute index', () {
      final parser = ArgParser(
        commands: [
          ArgCommand('build', options: {'release': const BooleanOption()}),
        ],
      );

      final error = parseWithError(parser, ['build', '--unknown']);

      expect(error.token, '--unknown');
      expect(error.index, 1);
    });
  });
}
