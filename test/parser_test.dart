import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

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

void main() {
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
