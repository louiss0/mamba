import 'package:arg_parser/help_formatter.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';
import 'package:chalkdart/chalkstrings.dart';

void main() {
  group("Formatted Strings", () {
    test("throws when ANSI characters aren't used", () {
      expect(() => TestFormattedString(''), throwsFormatException);
    });

    test("doesn't throw when a string isn't ANSI", () {
      expect(() => TestFormattedString(''.red), returnsNormally);
    });

    group("Required Formatted String", () {
      test("throws when required and ANSI characters aren't used", () {
        expect(() => RequiredString(''), throwsFormatException);
      });

      group("Throws when required delimters are used", () {
        for (final delimiter in ['<', '>', '<url>']) {
          test("throws when $delimiter is used", () {
            expect(() => RequiredString(delimiter), throwsFormatException);
          });
        }
      });

      test("doesn't throw when required and ANSI characters are used", () {
        expect(() => RequiredString('bar'.red), returnsNormally);
      });
    });
    group("Optional Formatted String", () {
      test("throws when optional and ANSI characters aren't used", () {
        expect(() => OptionalString(''), throwsFormatException);
      });

      group("Throws when optional delimters are used", () {
        for (final delimiter in ['[', ']', '[ header ]']) {
          test("throws when $delimiter is used", () {
            expect(() => OptionalString(delimiter), throwsFormatException);
          });
        }
      });

      test("doesn't throw when optional and ANSI characters are used", () {
        expect(() => OptionalString('foo'.red), returnsNormally);
      });
    });
  });

  group('HelpFormatter', () {
    final formatter = HelpFormatter();

    group('Formats grammar strings', () {
      test('returns the appropriate formatted string type', () {
        expect(formatter.requiredFormatter('value'), isA<RequiredString>());
        expect(formatter.optionalFormatter('value'), isA<OptionalString>());
        expect(formatter.variadicFormatter('value'), isA<VariadicString>());
        expect(
          formatter.sectionTitleFormater('Section'),
          isA<SectionTitleString>(),
        );
        expect(
          formatter.entryDescriptionFormatter('Description'),
          isA<EntryDescriptionString>(),
        );
      });
    });

    group("Parses overall structure correctly", () {
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
    });

    group('Formats top-level section pairs', () {
      final registry = CommandRegistry.create(
        'workspace',
        'Manage workspace themes.',
        commands: [
          _FixtureCommand(
            'flags-options',
            'Set theme flags and options.',
            longDescription:
                'Set a theme for workspaces this allows you use commands to set the theme you want!',
            flags: [
              BooleanFlag(name: 'bright', description: 'Use a bright theme.'),
              BooleanFlag(name: 'quiet', description: 'Suppress theme output.'),
            ],
            singleOptions: [
              StringOption(
                name: 'primary',
                regex: RegExp(r'\S+'),
                description: 'Primary theme.',
              ),
              StringOption(
                name: 'accent',
                regex: RegExp(r'\S+'),
                description: 'Accent theme.',
              ),
            ],
          ),
          _FixtureCommand(
            'flags-accessors',
            'Set theme flags and accessors.',
            flags: [
              BooleanFlag(name: 'bright', description: 'Use a bright theme.'),
              BooleanFlag(name: 'quiet', description: 'Suppress theme output.'),
            ],
            accessorFlagSchema: {
              'foreground': AccessorInput.named(
                StringOption(
                  name: 'foreground',
                  regex: RegExp(r'\S+'),
                  description: 'Foreground theme.',
                ),
              ),
              'background': AccessorInput.named(
                StringOption(
                  name: 'background',
                  regex: RegExp(r'\S+'),
                  description: 'Background theme.',
                ),
              ),
            },
          ),
          _FixtureCommand(
            'flags-commands',
            'Set theme flags and commands.',
            flags: [
              BooleanFlag(name: 'bright', description: 'Use a bright theme.'),
              BooleanFlag(name: 'quiet', description: 'Suppress theme output.'),
            ],
            commands: [
              _FixtureCommand('apply', 'Apply a theme.'),
              _FixtureCommand('reset', 'Reset a theme.'),
            ],
          ),
          _FixtureCommand(
            'options-accessors',
            'Set theme options and accessors.',
            singleOptions: [
              StringOption(
                name: 'primary',
                regex: RegExp(r'\S+'),
                description: 'Primary theme.',
              ),
              StringOption(
                name: 'accent',
                regex: RegExp(r'\S+'),
                description: 'Accent theme.',
              ),
            ],
            accessorFlagSchema: {
              'foreground': AccessorInput.named(
                StringOption(
                  name: 'foreground',
                  regex: RegExp(r'\S+'),
                  description: 'Foreground theme.',
                ),
              ),
              'background': AccessorInput.named(
                StringOption(
                  name: 'background',
                  regex: RegExp(r'\S+'),
                  description: 'Background theme.',
                ),
              ),
            },
          ),
          _FixtureCommand(
            'options-commands',
            'Set theme options and commands.',
            singleOptions: [
              StringOption(
                name: 'primary',
                regex: RegExp(r'\S+'),
                description: 'Primary theme.',
              ),
              StringOption(
                name: 'accent',
                regex: RegExp(r'\S+'),
                description: 'Accent theme.',
              ),
            ],
            commands: [
              _FixtureCommand('apply', 'Apply a theme.'),
              _FixtureCommand('reset', 'Reset a theme.'),
            ],
          ),
          _FixtureCommand(
            'accessors-commands',
            'Set theme accessors and commands.',
            accessorFlagSchema: {
              'foreground': AccessorInput.named(
                StringOption(
                  name: 'foreground',
                  regex: RegExp(r'\S+'),
                  description: 'Foreground theme.',
                ),
              ),
              'background': AccessorInput.named(
                StringOption(
                  name: 'background',
                  regex: RegExp(r'\S+'),
                  description: 'Background theme.',
                ),
              ),
            },
            commands: [
              _FixtureCommand('apply', 'Apply a theme.'),
              _FixtureCommand('reset', 'Reset a theme.'),
            ],
          ),
        ],
      );

      CommandRegistry command(String name) => registry.commandRegistries!
          .singleWhere((candidate) => candidate.name == name);
      void expectHelp(String name, String expected) =>
          expect(formatter.formatHelp(command(name)), equals(expected));

      test(
        'formats flags and options',
        () => expectHelp(
          'flags-options',
          buildHelp(
            commandName: 'flags-options',
            shortDescription: 'Set theme flags and options.',
            longDescription:
                'Set a theme for workspaces this allows you use commands to set the theme you want!',
            flags: [
              (
                name: 'bright',
                short: null,
                description: 'Use a bright theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'quiet',
                short: null,
                description: 'Suppress theme output.',
                required: false,
                variadic: false,
              ),
            ],
            options: [
              (
                name: 'primary',
                short: null,
                description: 'Primary theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'accent',
                short: null,
                description: 'Accent theme.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats flags and accessor flags',
        () => expectHelp(
          'flags-accessors',
          buildHelp(
            commandName: 'flags-accessors',
            shortDescription: 'Set theme flags and accessors.',
            flags: [
              (
                name: 'bright',
                short: null,
                description: 'Use a bright theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'quiet',
                short: null,
                description: 'Suppress theme output.',
                required: false,
                variadic: false,
              ),
            ],
            accessorFlags: [
              (
                name: 'foreground',
                description: 'Foreground theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'background',
                description: 'Background theme.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats flags and commands',
        () => expectHelp(
          'flags-commands',
          buildHelp(
            commandName: 'flags-commands',
            shortDescription: 'Set theme flags and commands.',
            flags: [
              (
                name: 'bright',
                short: null,
                description: 'Use a bright theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'quiet',
                short: null,
                description: 'Suppress theme output.',
                required: false,
                variadic: false,
              ),
            ],
            commands: [
              (name: 'apply', description: 'Apply a theme.'),
              (name: 'reset', description: 'Reset a theme.'),
            ],
          ),
        ),
      );
      test(
        'formats options and accessor flags',
        () => expectHelp(
          'options-accessors',
          buildHelp(
            commandName: 'options-accessors',
            shortDescription: 'Set theme options and accessors.',
            accessorFlags: [
              (
                name: 'foreground',
                description: 'Foreground theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'background',
                description: 'Background theme.',
                required: false,
                variadic: false,
              ),
            ],
            options: [
              (
                name: 'primary',
                short: null,
                description: 'Primary theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'accent',
                short: null,
                description: 'Accent theme.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats options and commands',
        () => expectHelp(
          'options-commands',
          buildHelp(
            commandName: 'options-commands',
            shortDescription: 'Set theme options and commands.',
            options: [
              (
                name: 'primary',
                short: null,
                description: 'Primary theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'accent',
                short: null,
                description: 'Accent theme.',
                required: false,
                variadic: false,
              ),
            ],
            commands: [
              (name: 'apply', description: 'Apply a theme.'),
              (name: 'reset', description: 'Reset a theme.'),
            ],
          ),
        ),
      );
      test(
        'formats accessor flags and commands',
        () => expectHelp(
          'accessors-commands',
          buildHelp(
            commandName: 'accessors-commands',
            shortDescription: 'Set theme accessors and commands.',
            accessorFlags: [
              (
                name: 'foreground',
                description: 'Foreground theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'background',
                description: 'Background theme.',
                required: false,
                variadic: false,
              ),
            ],
            commands: [
              (name: 'apply', description: 'Apply a theme.'),
              (name: 'reset', description: 'Reset a theme.'),
            ],
          ),
        ),
      );
    });
  });
}

class TestFormattedString extends FormattedString {
  TestFormattedString(super.string);
}

enum OutputFormat { json, yaml }

enum ThemePalette { warm, cool }

enum ThemeTone { light, dark }

enum ColorMode { auto, always }

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
  PositionalHelpEntry? variadicPositional,
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
      '${formatInput(entry)} ${entry.description.brightYellow}';

  String formatAccessor(AccessorHelpEntry entry) {
    final name = entry.variadic ? '...${entry.name}' : entry.name;
    final formatted = entry.required ? '< $name >'.red : '[ $name ]'.dimGray;
    return '$formatted ${entry.description.brightYellow}';
  }

  String requiredPositional(PositionalHelpEntry entry) =>
      '< ${entry.name} >'.red;
  String optionalPositional(PositionalHelpEntry entry) =>
      '[ ${entry.name} ]'.dimGray;
  String formatVariadicPositional(PositionalHelpEntry entry) =>
      '[ ...${entry.name} ]'.dimGray;

  final positionals = [
    ...mandatoryPositionals.map(requiredPositional),
    ...optionalPositionals.map(optionalPositional),
    if (variadicPositional != null)
      formatVariadicPositional(variadicPositional),
  ];
  final commandLine =
      '$commandName${positionals.isEmpty ? '' : ' ${positionals.join(' ')}'}';
  final buffer = StringBuffer()..writeln("$commandLine  '$shortDescription'");

  if (longDescription != null) {
    buffer
      ..writeln('-' * 10)
      ..writeln(longDescription)
      ..writeln('-' * 10);
    buffer.writeln();
  }

  void writeSection(String title, List<HelpEntry> entries) {
    if (entries.isEmpty) return;
    buffer.writeln(title.brightGreen);
    buffer.writeln();
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
  buffer.writeln();
  writeAccessorSection(accessorFlags);
  buffer.writeln();
  writeSection('Options', options);
  if (commands.isNotEmpty) {
    buffer.writeln('Commands'.brightGreen);
    for (final command in commands) {
      buffer.writeln('${command.name} ${command.description.brightYellow}');
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
