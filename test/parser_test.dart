import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';
import 'package:arg_parser/errors.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:chalkdart/chalkstrings.dart';
import 'fixtures.dart';

class RequestOptions extends OptionSchema<({String url, int retries})> {
  @override
  final schema = <Option>[
    StringOption(name: 'url', required: true, regex: RegExp(r'https?://\S+')),
    IntOption(name: 'retries'),
  ];

  @override
  ({String url, int retries}) toRecord(Map<String, dynamic> args) => (
    url: args['url'] as String,
    retries: int.parse(args['retries'] as String? ?? '0'),
  );
}

class RequestFlags extends FlagSchema<({bool verbose, int quiet})> {
  @override
  final schema = <Flag>[
    BooleanFlag(name: 'verbose', short: 'v'),
    CountFlag(name: 'quiet', short: 'q'),
  ];

  @override
  ({bool verbose, int quiet}) toRecord(Map<String, dynamic> args) => (
    verbose: args['verbose'] as bool? ?? false,
    quiet: args['quiet'] as int? ?? 0,
  );
}

class RequestPositionals extends PositionalSchema<({String source})> {
  RequestPositionals() : super([Positional('source')]);

  @override
  ({String source}) toRecord(Map<String, dynamic> args) =>
      (source: args['source'] as String);
}

class ServerAccessors extends AccessorOptionSchema<({int port})> {
  @override
  final schema = <AccessorOption>[
    AccessorListOption(
      name: 'server',
      options: [AccessorIntOption(name: 'port')],
    ),
  ];

  @override
  ({int port}) toRecord(Map<String, dynamic> args) => (
    port: int.parse((args['server'] as Map<String, Object>)['port'] as String),
  );
}

class RunCommand
    extends
        Command<
          ({bool verbose, int quiet}),
          ({String url, int retries}),
          ({int port}),
          ({String source})
        > {
  RunCommand()
    : super(
        'run',
        'Run a request.',
        flagSchema: RequestFlags(),
        optionSchema: RequestOptions(),
        positionalSchema: RequestPositionals(),
        accessorSchema: ServerAccessors(),
      );

  @override
  void run(
    Inputs<
      ({bool verbose, int quiet}),
      ({String url, int retries}),
      ({int port}),
      ({String source})
    >
    input,
    List<String> variadic,
  ) {}
}

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

enum FactoryMode { first, second }

final class GroupCoverageCommand extends GroupCommand {
  GroupCoverageCommand()
    : super(
        'group',
        'Group command.',
        defaultSubCommandPath: null,
        longDescription: null,
        positionalSchema: null,
        accessorSchema: null,
        flagSchema: null,
        optionSchema: null,
        commands: null,
      );
}

enum ConfigMode { auto, always }

class DefaultAccessors extends AccessorOptionSchema<({String mode, int port})> {
  @override
  final schema = <AccessorOption>[
    AccessorListOption(
      name: 'server',
      options: [
        AccessorListOption(
          name: 'database',
          options: [
            AccessorChoiceOption<ConfigMode>(
              name: 'mode',
              choices: ConfigMode.values,
              defaultValue: ConfigMode.auto,
            ),
            AccessorIntOption(name: 'port'),
          ],
        ),
      ],
    ),
  ];

  @override
  ({String mode, int port}) toRecord(Map<String, dynamic> args) {
    final database =
        ((args['server'] as Map<String, Object>)['database']
            as Map<String, Object>);
    return (
      mode: database['mode'] as String,
      port: int.parse(database['port'] as String),
    );
  }
}

class RemoteAccessors
    extends AccessorOptionSchema<({String fetch, String push})> {
  @override
  final schema = <AccessorOption>[
    AccessorListOption(
      name: 'remote',
      options: [
        AccessorListOption(
          name: 'origin',
          options: [
            AccessorListOption(
              name: 'urls',
              options: [
                AccessorStringOption(name: 'fetch'),
                AccessorStringOption(name: 'push'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  ({String fetch, String push}) toRecord(Map<String, dynamic> args) {
    final urls =
        (((args['remote'] as Map<String, Object>)['origin']
                as Map<String, Object>)['urls']
            as Map<String, Object>);
    return (fetch: urls['fetch'] as String, push: urls['push'] as String);
  }
}

class NestedConfigAccessors extends AccessorOptionSchema<({String value})> {
  NestedConfigAccessors(this.levels)
    : names = [
        for (var level = 1; level < levels; level++) 'level$level',
        'value',
      ];

  final int levels;
  final List<String> names;

  @override
  List<AccessorOption> get schema => [_accessorAt(0)];

  AccessorOption _accessorAt(int index) {
    final name = names[index];
    if (index == names.length - 1) return AccessorStringOption(name: name);
    return AccessorListOption(name: name, options: [_accessorAt(index + 1)]);
  }

  @override
  ({String value}) toRecord(Map<String, dynamic> args) {
    Object value = args;
    for (final name in names) {
      value = (value as Map<String, Object>)[name]!;
    }
    return (value: value as String);
  }

  String get path => names.join('.');
}

void main() {
  group('Recursive Git-config-style accessors', () {
    for (final levels in [2, 3, 4, 5]) {
      test('parses an accessor with $levels levels', () {
        final accessors = NestedConfigAccessors(levels);
        final parser = Parser(
          CommandRegistry.create(
            'config',
            'Read configuration.',
            accessorSchema: accessors,
          ),
        );

        final inputs = parser.parse(['--${accessors.path}', 'configured']).$2;

        expect(inputs.acessors, (value: 'configured'));
      });
    }

    test('merges nested choice defaults with parsed accessor values', () {
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: DefaultAccessors(),
        ),
      );

      final inputs = parser.parse(['--server.database.port', '5432']).$2;

      expect(inputs.acessors, (mode: 'auto', port: 5432));
    });

    test('merges sibling values at four accessor levels', () {
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: RemoteAccessors(),
        ),
      );

      final inputs = parser.parse([
        '--remote.origin.urls.fetch',
        'https://fetch.example',
        '--remote.origin.urls.push',
        'https://push.example',
      ]).$2;

      expect(inputs.acessors, (
        fetch: 'https://fetch.example',
        push: 'https://push.example',
      ));
    });

    test('parses an accessor with 10 levels', () {
      final accessors = NestedConfigAccessors(10);
      final parser = Parser(
        CommandRegistry.create(
          'config',
          'Read configuration.',
          accessorSchema: accessors,
        ),
      );

      final inputs = parser.parse(['--${accessors.path}', 'configured']).$2;

      expect(inputs.acessors, (value: 'configured'));
    });

    test('renders the complete path for nested accessor help', () {
      final accessors = NestedConfigAccessors(5);
      final registry = CommandRegistry.create(
        'config',
        'Read configuration.',
        accessorSchema: accessors,
      );

      expect(HelpFormatter().formatHelp(registry), contains(accessors.path));
    });
  });

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

    test('parses equals values for every option kind', () {
      final subject = parser(options: CoverageOptions());

      expectSuccess(subject, [
        '--word=word',
        '--integer=2',
        '--decimal=1.5',
        '--mode=always',
        '--header=Accept: json',
        '--numbers=200',
        '--ratios=0.5',
      ]);
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

    test('parses equals values for primitive and grouped accessors', () {
      final subject = parser(accessors: CoverageAccessors());

      expectSuccess(subject, [
        '--user=ada',
        '--number=2',
        '--decimal=1.5',
        '--mode=always',
        '--server.name=api',
        '--server.port=8080',
        '--server.timeout=0.5',
        '--server.mode=always',
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

  group('Value object coverage', () {
    test('formats exception messages', () {
      expect(MambaException('message').toString(), 'MambaException message');
      expect(MambaRegistryError('message').message, 'message');
    });

    test('validates direct variadic formatting', () {
      expect(VariadicString('item'.red).string, contains('...'));
      expect(() => VariadicString('...item'.red), throwsFormatException);
    });

    test('formats every positional and accessor shape', () {
      final registry = CommandRegistry.create(
        'tool',
        'Tool command.',
        positionalSchema: TestPositionalSchema.create(
          [Positional('source')],
          discretionary: [Positional('target')],
          variadic: Variadic('rest'),
        ),
        accessorSchema: TestAccessorOptionSchema.create([
          AccessorStringOption(name: 'user', description: 'User name.'),
        ]),
        optionSchema: TestOptionSchema.create([
          StringOption(name: 'required', required: true, regex: RegExp(r'\S+')),
          RepeatableStringOption(name: 'tags', required: true),
        ]),
      );

      final help = HelpFormatter().formatHelp(registry);

      expect(help, contains('source'));
      expect(help, contains('target'));
      expect(help, contains('rest'));
      expect(help, contains('user'));
      expect(help, contains('required'));
      expect(help, contains('tags'));
    });

    test('constructs option factories and default regular expressions', () {
      final singleString = Option.stringOption('string', RegExp(r'^value$'));
      final singleInt = Option.intOption('integer');
      final singleDouble = Option.doubleOption('double');
      final choice = Option.choiceOption('mode', FactoryMode.values);
      final repeatedInt = RepeatableOption.intOption(name: 'integers');
      final repeatedDouble = RepeatableOption.doubleOption(name: 'doubles');
      final repeatedString = RepeatableOption.stringOption(
        name: 'strings',
        regex: RegExp(r'^value$'),
      );

      expect(singleString.regex.hasMatch('value'), isTrue);
      expect(singleInt.name, 'integer');
      expect(singleDouble.name, 'double');
      expect(choice.choices, FactoryMode.values);
      expect(repeatedInt.name, 'integers');
      expect(repeatedDouble.name, 'doubles');
      expect(repeatedString.regex.hasMatch('value'), isTrue);
      expect(
        RepeatableStringOption(name: 'default').regex.hasMatch('value'),
        isTrue,
      );
      expect(AccessorIntOption(name: 'port').regex.hasMatch('80'), isTrue);
      expect(
        AccessorDoubleOption(name: 'timeout').regex.hasMatch('1.5'),
        isTrue,
      );
    });

    test('runs the default group command handler', () {
      final command = GroupCoverageCommand();

      command.run((
        flags: null,
        options: null,
        positionals: null,
        acessors: null,
        variadic: const [],
      ), const []);
    });
  });

  group('Parser schema output', () {
    test('converts registered inputs through their schemas', () {
      final parser = Parser(
        CommandRegistry.create(
          'tool',
          'Manage tools.',
          commands: [RunCommand()],
        ),
      );

      final (command, inputs) = parser.parse([
        'tool',
        'run',
        'input.txt',
        '--url',
        'https://example.com',
        '--retries',
        '2',
        '-vqq',
        '--server.port',
        '8080',
      ]);

      expect(command, ['tool', 'run']);
      expect(inputs.flags, (verbose: true, quiet: 2));
      expect(inputs.options, (url: 'https://example.com', retries: 2));
      expect(inputs.positionals, (source: 'input.txt'));
      expect(inputs.acessors, (port: 8080));
    });

    test('returns schema defaults for omitted registered inputs', () {
      final parser = Parser(
        CommandRegistry.create(
          'run',
          'Run a request.',
          flagSchema: RequestFlags(),
        ),
      );

      expect(parser.parse([]).$2.flags, (verbose: false, quiet: 0));
    });

    test('preserves parsing errors before converting values', () {
      final parser = Parser(
        CommandRegistry.create(
          'run',
          'Run a request.',
          optionSchema: RequestOptions(),
        ),
      );

      expect(
        () => parser.parse(['--url', 'invalid']),
        throwsA(isA<MambaParseException>()),
      );
    });
  });
}
