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
    final formatter = HelpFormatter();

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

    group('Formats every input shape', () {
      final registry = CommandRegistry.create(
        'workspace',
        'Manage workspace themes.',
        commands: [
          _FixtureCommand(
            'required',
            'Show required themes.',
            positionalSchema: PositionalSchema([
              Positional('day', description: 'Day theme.'),
              Positional('night', description: 'Night theme.'),
            ]),
          ),
          _FixtureCommand(
            'optional',
            'Show optional themes.',
            positionalSchema: PositionalSchema(
              [],
              discretionary: [
                Positional('dawn', description: 'Dawn theme.'),
                Positional('dusk', description: 'Dusk theme.'),
              ],
            ),
          ),
          _FixtureCommand(
            'variadic',
            'Show theme collection.',
            positionalSchema: PositionalSchema(
              [],
              variadic: Variadic('themes', description: 'Theme names.'),
            ),
          ),
          _FixtureCommand(
            'flags',
            'Set theme switches and levels.',
            flags: [
              BooleanFlag(
                name: 'bright',
                short: 'b',
                description: 'Use bright theme.',
              ),
              CountFlag(
                name: 'light',
                short: 'l',
                description: 'Increase light.',
              ),
            ],
          ),
          _FixtureCommand(
            'text-number-options',
            'Set theme labels and numbers.',
            singleOptions: [
              StringOption(
                name: 'primary',
                short: 'p',
                regex: RegExp(r'\S+'),
                description: 'Primary theme.',
              ),
              IntOption(
                name: 'warmth',
                short: 'w',
                description: 'Warmth number.',
              ),
            ],
          ),
          _FixtureCommand(
            'scale-mode-options',
            'Set theme scales and modes.',
            singleOptions: [
              DoubleOption(
                name: 'glow',
                short: 'g',
                description: 'Glow scale.',
              ),
              ChoiceOption(
                name: 'palette',
                short: 'p',
                choices: ThemePalette.values,
                description: 'Palette mode.',
              ),
            ],
          ),
          _FixtureCommand(
            'repeatable-text-number',
            'Set theme tags and stops.',
            repeatedOptions: [
              RepeatableStringOption(
                name: 'tag',
                short: 't',
                description: 'Theme tag.',
              ),
              RepeatableIntOption(
                name: 'stop',
                short: 's',
                description: 'Theme stop.',
              ),
            ],
          ),
          _FixtureCommand(
            'repeatable-number-scale',
            'Set theme bands and scales.',
            repeatedOptions: [
              RepeatableIntOption(
                name: 'band',
                short: 'b',
                description: 'Theme band.',
              ),
              RepeatableDoubleOption(
                name: 'opacity',
                short: 'o',
                description: 'Theme opacity.',
              ),
            ],
          ),
          _FixtureCommand(
            'named-accessors',
            'Set named theme values.',
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
            'group-accessors',
            'Set grouped theme values.',
            accessorFlagSchema: {
              'light': AccessorInput.group({
                'warm': StringOption(
                  name: 'warm',
                  regex: RegExp(r'\S+'),
                  description: 'Warm light.',
                ),
                'cool': StringOption(
                  name: 'cool',
                  regex: RegExp(r'\S+'),
                  description: 'Cool light.',
                ),
              }),
              'dark': AccessorInput.group({
                'soft': StringOption(
                  name: 'soft',
                  regex: RegExp(r'\S+'),
                  description: 'Soft dark.',
                ),
                'deep': StringOption(
                  name: 'deep',
                  regex: RegExp(r'\S+'),
                  description: 'Deep dark.',
                ),
              }),
            },
          ),
          _FixtureCommand(
            'nested-commands',
            'Manage theme commands.',
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
        'formats mandatory positionals',
        () => expectHelp(
          'required',
          buildHelp(
            commandName: 'required',
            shortDescription: 'Show required themes.',
            mandatoryPositionals: [
              (name: 'day', description: 'Day theme.'),
              (name: 'night', description: 'Night theme.'),
            ],
          ),
        ),
      );
      test(
        'formats optional positionals',
        () => expectHelp(
          'optional',
          buildHelp(
            commandName: 'optional',
            shortDescription: 'Show optional themes.',
            optionalPositionals: [
              (name: 'dawn', description: 'Dawn theme.'),
              (name: 'dusk', description: 'Dusk theme.'),
            ],
          ),
        ),
      );
      test(
        'formats a variadic positional alone',
        () => expectHelp(
          'variadic',
          buildHelp(
            commandName: 'variadic',
            shortDescription: 'Show theme collection.',
            variadicPositional: (name: 'themes', description: 'Theme names.'),
          ),
        ),
      );
      test(
        'formats a BooleanFlag and CountFlag pair',
        () => expectHelp(
          'flags',
          buildHelp(
            commandName: 'flags',
            shortDescription: 'Set theme switches and levels.',
            flags: [
              (
                name: 'bright',
                short: 'b',
                description: 'Use bright theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'light',
                short: 'l',
                description: 'Increase light.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats StringOption and IntOption pair',
        () => expectHelp(
          'text-number-options',
          buildHelp(
            commandName: 'text-number-options',
            shortDescription: 'Set theme labels and numbers.',
            options: [
              (
                name: 'primary',
                short: 'p',
                description: 'Primary theme.',
                required: false,
                variadic: false,
              ),
              (
                name: 'warmth',
                short: 'w',
                description: 'Warmth number.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats DoubleOption and ChoiceOption pair',
        () => expectHelp(
          'scale-mode-options',
          buildHelp(
            commandName: 'scale-mode-options',
            shortDescription: 'Set theme scales and modes.',
            options: [
              (
                name: 'glow',
                short: 'g',
                description: 'Glow scale.',
                required: false,
                variadic: false,
              ),
              (
                name: 'palette',
                short: 'p',
                description: 'Palette mode.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats RepeatableStringOption and RepeatableIntOption pair',
        () => expectHelp(
          'repeatable-text-number',
          buildHelp(
            commandName: 'repeatable-text-number',
            shortDescription: 'Set theme tags and stops.',
            options: [
              (
                name: 'tag',
                short: 't',
                description: 'Theme tag.',
                required: false,
                variadic: true,
              ),
              (
                name: 'stop',
                short: 's',
                description: 'Theme stop.',
                required: false,
                variadic: true,
              ),
            ],
          ),
        ),
      );
      test(
        'formats RepeatableIntOption and RepeatableDoubleOption pair',
        () => expectHelp(
          'repeatable-number-scale',
          buildHelp(
            commandName: 'repeatable-number-scale',
            shortDescription: 'Set theme bands and scales.',
            options: [
              (
                name: 'band',
                short: 'b',
                description: 'Theme band.',
                required: false,
                variadic: true,
              ),
              (
                name: 'opacity',
                short: 'o',
                description: 'Theme opacity.',
                required: false,
                variadic: true,
              ),
            ],
          ),
        ),
      );
      test(
        'formats named accessor pair',
        () => expectHelp(
          'named-accessors',
          buildHelp(
            commandName: 'named-accessors',
            shortDescription: 'Set named theme values.',
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
        'formats accessor group pair',
        () => expectHelp(
          'group-accessors',
          buildHelp(
            commandName: 'group-accessors',
            shortDescription: 'Set grouped theme values.',
            accessorFlags: [
              (
                name: 'light.warm',
                description: 'Warm light.',
                required: false,
                variadic: false,
              ),
              (
                name: 'light.cool',
                description: 'Cool light.',
                required: false,
                variadic: false,
              ),
              (
                name: 'dark.soft',
                description: 'Soft dark.',
                required: false,
                variadic: false,
              ),
              (
                name: 'dark.deep',
                description: 'Deep dark.',
                required: false,
                variadic: false,
              ),
            ],
          ),
        ),
      );
      test(
        'formats nested command pair',
        () => expectHelp(
          'nested-commands',
          buildHelp(
            commandName: 'nested-commands',
            shortDescription: 'Manage theme commands.',
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
