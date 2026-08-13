import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';
import 'package:chalkdart/chalkstrings.dart';

///  When it comes to the grammar DSL these are the rules
/// [ ] are for optional things
/// < > Is for required things
/// ... is for variadic **It must be used in front of the other two**
/// The | is for **or**
/// The & is for **and**

void main() {
  group('HelpFormatter', () {
    final registry = CommandRegistry.create(
      'curl',
      'Transfer data to or from a server.',
      longDescription:
          'A curl-inspired HTTP client with commands for common request methods.',
      flags: [
        BooleanFlag(
          name: 'silent',
          short: 's',
          description: 'Do not show progress or diagnostic output.',
        ),
        BooleanFlag(
          name: 'verbose',
          short: 'v',
          description: 'Show request and response details.',
        ),
      ],
      singleOptions: [
        StringOption(
          name: 'output',
          short: 'o',
          regex: RegExp(r'\S+'),
          description: 'Write the response body to this file.',
        ),
        StringOption(
          name: 'user-agent',
          short: 'A',
          regex: RegExp(r'.+'),
          description: 'Set the HTTP User-Agent header.',
        ),
      ],
      repeatedOptions: [
        RepeatableStringOption(
          name: 'header',
          short: 'H',
          regex: RegExp(r'.+:.+'),
          description: 'Add a request header as "Name: value".',
        ),
      ],
      accessors: {
        'tls': AccessorInput.group({
          'cert': StringOption(
            name: 'cert',
            regex: RegExp(r'\S+'),
            description: 'Client certificate path.',
          ),
          'key': StringOption(
            name: 'key',
            regex: RegExp(r'\S+'),
            description: 'Private key path.',
          ),
        }),
      },
      commands: [
        _FixtureCommand(
          'get',
          'Retrieve a resource with an HTTP GET request.',
          positionalSchema: PositionalSchema([
            Positional('url', description: 'The resource URL.'),
          ]),
          singleOptions: [
            StringOption(
              name: 'query',
              short: 'q',
              regex: RegExp(r'\S+'),
              description: 'Append this query string to the URL.',
            ),
          ],
        ),
        _FixtureCommand(
          'post',
          'Create a resource with an HTTP POST request.',
          positionalSchema: PositionalSchema([
            Positional('url', description: 'The collection URL.'),
          ]),
          singleOptions: [
            StringOption(
              name: 'data',
              short: 'd',
              regex: RegExp(r'.+'),
              description: 'Request body data.',
              required: true,
            ),
          ],
        ),
        _FixtureCommand(
          'put',
          'Replace a resource with an HTTP PUT request.',
          positionalSchema: PositionalSchema([
            Positional('url', description: 'The resource URL.'),
          ]),
          singleOptions: [
            StringOption(
              name: 'data',
              short: 'd',
              regex: RegExp(r'.+'),
              description: 'Replacement resource data.',
              required: true,
            ),
          ],
        ),
        _FixtureCommand(
          'delete',
          'Remove a resource with an HTTP DELETE request.',
          positionalSchema: PositionalSchema([
            Positional('url', description: 'The resource URL.'),
          ]),
          flags: [
            BooleanFlag(
              name: 'include',
              short: 'i',
              description: 'Include response headers in the output.',
            ),
          ],
        ),
      ],
    );

    final formatter = HelpFormatter();

    test("When the root command is passed it's main info is revealed", () {
      final result = formatter.formatHelp(registry);

      final expected = buildHelp(
        commandName: 'curl',
        shortDescription: 'Transfer data to or from a server.',
        longDescription:
            'A curl-inspired HTTP client with commands for common request methods.',
        flags: [
          (
            name: 'silent',
            short: 's',
            description: 'Do not show progress or diagnostic output.',
            required: false,
            variadic: false,
          ),
          (
            name: 'verbose',
            short: 'v',
            description: 'Show request and response details.',
            required: false,
            variadic: false,
          ),
        ],
        accessorFlags: [
          (
            name: 'tls.cert',
            description: 'Client certificate path.',
            required: false,
            variadic: false,
          ),
          (
            name: 'tls.key',
            description: 'Private key path.',
            required: false,
            variadic: false,
          ),
        ],
        options: [
          (
            name: 'output',
            short: 'o',
            description: 'Write the response body to this file.',
            required: false,
            variadic: false,
          ),
          (
            name: 'user-agent',
            short: 'A',
            description: 'Set the HTTP User-Agent header.',
            required: false,
            variadic: false,
          ),
          (
            name: 'header',
            short: 'H',
            description: 'Add a request header as "Name: value".',
            required: false,
            variadic: true,
          ),
        ],
        commands: [
          (
            name: 'get',
            description: 'Retrieve a resource with an HTTP GET request.',
          ),
          (
            name: 'post',
            description: 'Create a resource with an HTTP POST request.',
          ),
          (
            name: 'put',
            description: 'Replace a resource with an HTTP PUT request.',
          ),
          (
            name: 'delete',
            description: 'Remove a resource with an HTTP DELETE request.',
          ),
        ],
      );

      expect(result, equals(expected));
    });

    test("Format's positionals and options properly", () {
      final getRegistry = registry.commandRegistries!.singleWhere(
        (registry) => registry.name == 'get',
      );

      final result = formatter.formatHelp(getRegistry);

      final expected = buildHelp(
        commandName: "get",
        shortDescription: "Retrieve a resource with an HTTP GET request.",
        optionalPositionals: [(name: 'url', description: 'The resource URL.')],
        options: [
          (
            name: "output",
            short: "o",
            description: "Output format (json, yaml, etc.)",
            required: false,
            variadic: false,
          ),
        ],
      );

      expect(result, equals(expected));
    });

    test("Format's positionals and flags properly", () {
      final deleteRegistry = registry.commandRegistries!.singleWhere(
        (registry) => registry.name == 'delete',
      );

      final result = formatter.formatHelp(deleteRegistry);

      final expected = buildHelp(
        commandName: "delete",
        shortDescription: "",
        optionalPositionals: [(name: 'url', description: 'The resource URL.')],
        flags: [
          (
            name: 'include',
            short: 'i',
            required: false,
            variadic: false,
            description: 'Include response headers in the output.',
          ),
        ],
      );

      expect(result, equals(expected));
    });
  });
}

typedef HelpEntry = ({
  String name,
  String? short,
  String description,
  bool required,
  bool variadic,
});
typedef PositionalHelpEntry = ({String name, String description});
typedef AccessorHelpEntry = ({
  String name,
  String description,
  bool required,
  bool variadic,
});
typedef HelpCommand = ({String name, String description});

String orString(String first, String second) => '$first |  $second'.bold;

String buildHelp({
  required String commandName,
  required String shortDescription,
  String? longDescription,
  List<PositionalHelpEntry> mandatoryPositionals = const [],
  List<PositionalHelpEntry> optionalPositionals = const [],
  List<PositionalHelpEntry> variadicPositionals = const [],
  List<HelpEntry> flags = const [],
  List<AccessorHelpEntry> accessorFlags = const [],
  List<HelpEntry> options = const [],
  List<HelpCommand> commands = const [],
}) {
  String formatInput(HelpEntry entry) {
    final alias = entry.short;
    final name = alias == null ? entry.name : orString(entry.name, alias);
    final variadicName = entry.variadic ? '...$name' : name;
    return entry.required
        ? '< $variadicName >'.red
        : '[ $variadicName ]'.dimGray;
  }

  String formatEntry(HelpEntry entry) =>
      '${formatInput(entry)} ${entry.description}'.brightYellow;

  String formatAccessor(AccessorHelpEntry entry) {
    final name = entry.variadic ? '...${entry.name}' : entry.name;
    final formatted = entry.required ? '< $name >'.red : '[ $name ]'.dimGray;
    return '$formatted ${entry.description}'.brightYellow;
  }

  String requiredPositional(PositionalHelpEntry entry) =>
      '< ${entry.name} >'.red;
  String optionalPositional(PositionalHelpEntry entry) =>
      '[ ${entry.name} ]'.dimGray;
  String variadicPositional(PositionalHelpEntry entry) =>
      '[ ...${entry.name} ]'.dimGray;

  final positionals = [
    ...mandatoryPositionals.map(requiredPositional),
    ...optionalPositionals.map(optionalPositional),
    ...variadicPositionals.map(variadicPositional),
  ];
  final commandLine =
      '$commandName${positionals.isEmpty ? '' : ' ${positionals.join(' ')}'}';
  final buffer = StringBuffer()..writeln("$commandLine  '$shortDescription'");

  if (longDescription != null) {
    buffer
      ..writeln('-' * 10)
      ..writeln(longDescription)
      ..writeln('-' * 10);
  }

  void writeSection(String title, List<HelpEntry> entries) {
    if (entries.isEmpty) return;
    buffer.writeln(title.brightGreen);
    for (final entry in entries) {
      buffer.writeln(formatEntry(entry));
    }
  }

  void writeAccessorSection(List<AccessorHelpEntry> entries) {
    if (entries.isEmpty) return;
    buffer.writeln('Accessor flags'.brightGreen);
    for (final entry in entries) {
      buffer.writeln(formatAccessor(entry));
    }
  }

  writeSection('Flags', flags);
  writeAccessorSection(accessorFlags);
  writeSection('Options', options);
  if (commands.isNotEmpty) {
    buffer.writeln('Commands'.brightGreen);
    for (final command in commands) {
      buffer.writeln('${command.name} ${command.description}'.brightYellow);
    }
  }

  return buffer.toString();
}

final class _FixtureCommand extends Command {
  _FixtureCommand(
    super.name,
    super.shortDescription, {
    super.longDescription,
    super.positionalSchema,
    super.accessorFlagSchema,
    super.flags,
    super.singleOptions,
    super.repeatedOptions,
    super.commands,
  });

  @override
  void run(Inputs input) {}
}
