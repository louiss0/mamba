import 'package:arg_parser/parser.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

enum When { auto, never, always }

class TestCommand extends Command {
  TestCommand(
    super.name,
    super.shortDescription, {
    super.positionalSchema,
    super.accessorFlagSchema,
    super.flags,
    super.options,
    super.commands,
  });

  @override
  void run(Inputs input) {
    // TODO: implement run
  }
}

void main() {
  group("Testing parser", () {
    group("Parses positionals and variadics", () {
      test("parses positionals", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            positionalSchema: PositionalSchema([Positional("name")]),
          ),
        );

        final (_, inputs) = parser.parse(['Simon Peyton Jones']);
        expect(
          inputs.mandatoryPositionals,
          equals({'name': 'Simon Peyton Jones'}),
        );
      });

      test("parses variadics", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            positionalSchema: PositionalSchema([], variadic: Variadic("rest")),
          ),
        );

        final (_, inputs) = parser.parse(['this', 'that', 'ok']);
        expect(inputs.variadic, equals(['this', 'that', 'ok']));
      });

      test("throws an error when a required positional isn't used", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            positionalSchema: PositionalSchema([
              Positional("name"),
            ], variadic: Variadic("rest")),
          ),
        );

        expect(
          () => parser.parse(['']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              "The name is required at 0 after this command",
            ),
          ),
        );
      });

      test("parses discretionary positionals", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            positionalSchema: PositionalSchema(
              [
                // Positional("name"),
              ],
              discretionary: [Positional("url")],
            ),
          ),
        );

        final (_, inputs) = parser.parse(['https://foo.com']);
        expect(
          inputs.discretionaryPositionals,
          equals({'url': 'https://foo.com'}),
        );
      });

      test("throws when discretionary positional's requrement isn't met", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            positionalSchema: PositionalSchema(
              [
                // Positional("name"),
              ],
              discretionary: [
                Positional(
                  "url",
                  regex: RegExp(r'^https?:\/\/[^\s/$.?#].[^\s]*$'),
                ),
              ],
            ),
          ),
        );

        final (_, inputs) = parser.parse(['foo.com']);
        expect(
          () => inputs.discretionaryPositionals,
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Invalid value for positional url at 0 after the command',
            ),
          ),
        );
      });
    });

    group("Parses choice options properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "bat",
          "Open files colorfully",
          options: [
            ChoiceOption<When>(
              name: 'paging',
              short: 'p',
              defaultValue: When.auto,
              choices: When.values,
            ),
            ChoiceOption<When>(name: 'decorations', choices: When.values),
          ],
        ),
      );

      test("throws when the choice is in correct", () {
        expect(
          () => parser.parse(['--paging', 'invalid']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              'invalid is not a valid choice for paging\nMust be one of: ${When.values.map((e) => e.name).toList()}',
            ),
          ),
        );
      });

      test("parses valid choice", () {
        final (_, inputs) = parser.parse(['--decorations', 'always']);
        expect(inputs.singleOptions, equals({'decorations': 'always'}));
      });

      test("parses valid short choice", () {
        final (_, inputs) = parser.parse(['-p', 'never']);
        expect(inputs.singleOptions, equals({'paging': 'never'}));
      });

      test("parses option with default value when it's not passed in", () {
        final (_, inputs) = parser.parse([]);

        expect(inputs.singleOptions, equals({'paging': 'auto'}));
      });
    });

    group("Parses repeated options properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "curl",
          "Do http requests in the terminal",
          options: [
            RepeatableStringOption(
              name: 'header',
              short: 'H',
              regex: RegExp(r'\S+:.+'),
            ),
          ],
        ),
      );

      test("parses repeated option", () {
        final (_, inputs) = parser.parse([
          '--header',
          'Accept: application/json',
          '--header',
          'Authorization: Bearer token',
        ]);
        expect(
          inputs.repeatedOptions,
          equals({
            'header': [
              'Accept: application/json',
              'Authorization: Bearer token',
            ],
          }),
        );
      });

      test("parses repeated short option", () {
        final (_, inputs) = parser.parse([
          '-H',
          'Accept: application/json',
          '-H',
          'Authorization: Bearer token',
        ]);
        expect(
          inputs.repeatedOptions,
          equals({
            'header': [
              'Accept: application/json',
              'Authorization: Bearer token',
            ],
          }),
        );
      });

      group('Parses repeated of all types properly', () {
        final parser = Parser(
          CommandRegistry.create(
            "probe",
            "Check service health",
            options: [
              RepeatableStringOption(
                name: 'endpoint',
                regex: RegExp(r'^https?:\/\/[^^\s/$.?#].[^^\s]*$'),
                short: "e",
              ),
              RepeatableIntOption(name: 'expect-status', short: 'es'),
              RepeatableDoubleOption(name: 'latency-threshold', short: 'lt'),
            ],
          ),
        );

        test("parses repeated string, int, and double options", () {
          final (_, inputs) = parser.parse([
            '--endpoint',
            'https://api.example.com/health',
            '--endpoint',
            'https://api.example.com/ready',
            '--expect-status',
            '200',
            '--expect-status',
            '204',
            '--latency-threshold',
            '0.25',
            '--latency-threshold',
            '1.0',
          ]);

          expect(
            inputs.repeatedOptions,
            equals({
              'endpoint': [
                'https://api.example.com/health',
                'https://api.example.com/ready',
              ],
              'expect-status': ['200', '204'],
              'latency-threshold': ['0.25', '1.0'],
            }),
          );
        });

        test("parses repeated short string, int, and double options", () {
          final (_, inputs) = parser.parse([
            '--e',
            'https://api.example.com/health',
            '--e',
            'https://api.example.com/ready',
            '--es',
            '200',
            '--es',
            '204',
            '--lt',
            '0.25',
            '--lt',
            '1.0',
          ]);

          expect(
            inputs.repeatedOptions,
            equals({
              'endpoint': [
                'https://api.example.com/health',
                'https://api.example.com/ready',
              ],
              'expect-status': ['200', '204'],
              'latency-threshold': ['0.25', '1.0'],
            }),
          );
        });
      });

      group("throws if repeated option type isn't meet", () {
        final cases = [
          (
            flag: "endpoint",
            goodInput: "https://api.example.com/health",
            badInput: "bad",
            error: "Invalid input must be a ",
          ),
          (
            flag: "expect-status",
            goodInput: "200",
            badInput: "bad",
            error: "Invalid input must be a int",
          ),
          (
            flag: "expect-status",
            goodInput: "200",
            badInput: "0.0",
            error: "Invalid input must be a int",
          ),
          (
            flag: "expect-status",
            goodInput: "200",
            badInput: ".0",
            error: "Invalid input must be a int",
          ),
          (
            flag: "expect-status",
            goodInput: "200",
            badInput: " 0",
            error: "Invalid input must be a int.\nDon't add spaces",
          ),
          (
            flag: "expect-status",
            goodInput: "200",
            badInput: "0 ",
            error: "Invalid input must be a int.\nDon't add spaces",
          ),
          (
            flag: "latency-threshold",
            goodInput: "0.25",
            badInput: "bad",
            error: "Invalid input must be a double",
          ),
          (
            flag: "latency-threshold",
            goodInput: "0.25",
            badInput: "4.5 ",
            error: "Invalid input must be a double.\nDon't add spaces",
          ),
          (
            flag: "latency-threshold",
            goodInput: "0.25",
            badInput: " 3.6",
            error: "Invalid input must be a  double.\nDon't add spaces",
          ),
        ];

        for (var i = 1; i <= 4; i++) {
          for (final (:flag, :goodInput, :badInput, :error) in cases) {
            test(
              "throws when repeated option $flag doesn't satisfy requirement for $i input(s)",
              () {
                expect(
                  () => parser.parse([
                    for (var j = 0; j < i; j++) ...['--$flag', goodInput],
                    '--$flag',
                    badInput,
                  ]),
                  throwsA(
                    isA<MambaParseException>().having(
                      (e) => e.message,
                      "message",
                      "Wrong option at ${i + 1} $error",
                    ),
                  ),
                );
              },
            );
          }
        }
      });
    });

    group("Parses string options properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "curl",
          "Do http requests in the terminal",
          options: [
            StringOption(
              name: 'url',
              regex: RegExp(r'^https?:\/\/[^\s/$.?#].[^\s]*$'),
              short: 'u',
            ),
            StringOption(name: 'user', regex: RegExp(r'^[^:]+:[^:]+$')),
          ],
        ),
      );

      test("throws when string option doesn't satisfy regex requirement", () {
        expect(
          () => parser.parse(['--user', 'get']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              "This value doesn't satify the requirement",
            ),
          ),
        );
      });

      test("parses a string option", () {
        final (_, inputs) = parser.parse(['--url', 'https://example.com']);
        expect(inputs, isA<Inputs>());
        expect(inputs.singleOptions, equals({'url': 'https://example.com'}));
      });

      test("parses a short string option", () {
        final (_, inputs) = parser.parse(['-u', 'https://example.com']);
        expect(inputs, isA<Inputs>());
        expect(inputs.singleOptions, equals({'url': 'https://example.com'}));
      });

      test("throws when required option isn't passed in", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            options: [
              StringOption(
                name: 'url',
                required: true,
                regex: RegExp(r'^https?:\/\/[^\s/$.?#].[^\s]*$'),
              ),
            ],
          ),
        );

        expect(
          () => parser.parse(['']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              "The url is required",
            ),
          ),
        );
      });
    });

    group("Parses int options properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "curl",
          "Do http requests in the terminal",
          options: [
            IntOption(name: 'max-redirs'),
            IntOption(name: 'retry'),
            IntOption(name: 'keep-alive-count', short: 'k'),
          ],
        ),
      );

      group("throws when int is invalid", () {
        const invalidInputs = ["3 ", " 2", "3.0", "h", "4.", "4 7"];

        for (final input in invalidInputs) {
          test("parses $input", () {
            expect(
              () => parser.parse(['curl', '--retry', input]),
              throwsA(
                isA<MambaParseException>().having(
                  (e) => e.message,
                  'message',
                  'Invalid int value: $input never have spaces in between numbers',
                ),
              ),
            );
          });
        }
      });

      test("parses correct long option", () {
        final (_, inputs) = parser.parse(['curl', '--max-redirs', '5']);

        expect(inputs.singleOptions, equals({'max-redirs': 5}));
      });

      test("parses correct short option", () {
        final (_, inputs) = parser.parse(['curl', '--k', '5']);

        expect(inputs.singleOptions, equals({'keep-alive-count': 5}));
      });

      test("throws when required int isn't added", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            options: [IntOption(name: 'retry', required: true)],
          ),
        );
        expect(
          () => parser.parse(['curl']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              'Option --retry is required',
            ),
          ),
        );
      });
    });

    group("Parses double options properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "curl",
          "Do http requests in the terminal",
          options: [
            DoubleOption(name: 'connect-timeout'),
            DoubleOption(name: 'max-time', short: 'm'),
            DoubleOption(name: 'retry-max-time'),
          ],
        ),
      );

      group("throws when double is invalid", () {
        const invalidInputs = ["3.0 ", " 2.0", "h", "4.", "4.0 7."];

        for (final input in invalidInputs) {
          test("parses $input", () {
            expect(
              () => parser.parse(['curl', '--retry-max-time', input]),
              throwsA(
                isA<MambaParseException>().having(
                  (e) => e.message,
                  'message',
                  'Invalid int value: $input never have spaces in between numbers',
                ),
              ),
            );
          });
        }
      });

      test("parses correct long option", () {
        final (_, inputs) = parser.parse(['curl', '--connect-timeout', '5.0']);

        expect(inputs.singleOptions, equals({'connect-timeout': 5.0}));
      });

      test("parses correct short option", () {
        final (_, inputs) = parser.parse(['curl', '-m', '5.0']);

        expect(inputs.singleOptions, equals({'max-time': 5.0}));
      });

      test("throws when required double isn't added", () {
        final parser = Parser(
          CommandRegistry.create(
            "curl",
            "Do http requests in the terminal",
            options: [DoubleOption(name: 'retry-max-time', required: true)],
          ),
        );

        expect(
          () => parser.parse(['curl']),
          throwsA(
            isA<MambaParseException>().having(
              (e) => e.message,
              'message',
              'Option --retry-max-time is required',
            ),
          ),
        );
      });
    });

    group("Parses boolean flags properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "bat",
          "Open files colorfully",
          flags: [
            BooleanFlag(name: 'color', negatable: true),
            BooleanFlag(name: 'diff'),
            BooleanFlag(name: "number", short: 'n'),
            BooleanFlag(name: "list-languages", short: "L", negatable: true),
          ],
        ),
      );

      test("parses non short or optional boolean flag", () {
        final (_, inputs) = parser.parse(['bat', '--diff']);

        expect(inputs.boolFlags, {'diff': true});
      });

      test("parses negatable boolean flag", () {
        final (_, inputs) = parser.parse(['bat', '--no-color']);

        expect(inputs.boolFlags, {'color': false});
      });
      test("parses short boolean flag", () {
        final (_, inputs) = parser.parse(['bat', '-n']);

        expect(inputs.boolFlags, {'number': true});
      });

      test("parses short negative boolean flag", () {
        final (_, inputs) = parser.parse(['bat', '-n-L']);

        expect(inputs.boolFlags, {'list-languages': false});
      });
    });

    group("Parses count flags properly", () {
      final parser = Parser(
        CommandRegistry.create(
          "git",
          "Sync files using virtual control",
          flags: [CountFlag(name: 'verbose', short: 'v')],
        ),
      );

      test("parses count flag normally", () {
        final (_, inputs) = parser.parse(['git', '--verbose']);

        expect(inputs.countFlags, {'verbose': 1});
      });

      test("parses repeated count flag ", () {
        final (_, inputs) = parser.parse(['git', '--verbose', '--verbose']);

        expect(inputs.countFlags, {'verbose': 2});
      });

      test("parses short count flags", () {
        final (_, inputs) = parser.parse(['git', '-v']);

        expect(inputs.countFlags, {'verbose': 1});
      });

      test("parses short count flags that are repeated", () {
        final (_, inputs) = parser.parse(['git', '-vv']);

        expect(inputs.countFlags, {'verbose': 2});
      });
    });

    group("Improper registration", () {
      final cases = [
        (
          input: "commit",
          messsage:
              "This term isn't a registered command positional or variadic",
        ),
        (input: "--message", messsage: "This isn't a registered flag"),
        (input: "-m", messsage: "This isn't a registered short flag or option"),
        (input: "--bundle.mode", messsage: "This isn't a registered acessor"),
        (
          input: "--bundle.name.uri",
          messsage: "This isn't a registered acessor",
        ),
        (input: "--user.port", messsage: "This isn't a registered acessor"),
        (
          input: "--user.address.location.lat",
          messsage: """
This accessor can't be processed
Only two dots can be used
          """,
        ),
      ];

      for (final (:input, :messsage) in cases) {
        test("throws error for input", () {
          final parser = Parser(
            CommandRegistry.create("git", "Use git to submit changes"),
          );

          expect(
            () => parser.parse([input]),
            throwsA(
              isA<MambaParseException>().having(
                (e) => e.message,
                "message",
                messsage,
              ),
            ),
          );
        });
      }
    });

    group("registration", () {
      test("parses options when they are registered", () {
        final parser = Parser(
          CommandRegistry.create(
            "run",
            "Run this script",
            options: [
              IntOption(name: "count", short: "c"),
              StringOption(name: "name", short: "n", regex: RegExp(r"\S+")),
            ],
          ),
        );

        final (command, inputs) = parser.parse([
          'run',
          '--count',
          '2',
          '--name',
          'Xavier Leroy',
        ]);

        expect(command, equals(["run"]));
        expect(
          inputs,
          isA<Inputs>().having((i) => i.singleOptions!['count'], "count", 2),
        );
        expect(
          inputs,
          isA<Inputs>().having(
            (i) => i.singleOptions!['name'],
            "name",
            "Xavier Leroy",
          ),
        );
      });

      test("parses count flags when they are registered", () {
        final parser = Parser(
          CommandRegistry.create(
            "run",
            "Run this script",
            flags: [CountFlag(name: "verbose")],
          ),
        );

        final (command, inputs) = parser.parse(['run', '--verbose']);

        expect(command, equals(["run"]));
        expect(
          inputs,
          isA<Inputs>().having((i) => i.countFlags!['verbose'], "verbose", 1),
        );
      });
      test("parses bool flags when they are registered", () {
        final parser = Parser(
          CommandRegistry.create(
            "run",
            "Run this script",
            flags: [BooleanFlag(name: "dry-run")],
          ),
        );

        final (command, inputs) = parser.parse(['run', '--dry-run']);

        expect(command, equals(equals(["run"])));
        expect(
          inputs,
          isA<Inputs>().having((i) => i.boolFlags!['dry-run'], "dry-run", true),
        );
      });
      test("parses variadic when it's registered", () {
        final parser = Parser(
          CommandRegistry.create(
            "run",
            "Run this script",
            positionalSchema: PositionalSchema(
              [],
              variadic: Variadic("scripts"),
            ),
          ),
        );

        final (command, inputs) = parser.parse(['run', 'foo', 'bar']);

        expect(command, equals(["run"]));
        expect(
          inputs,
          isA<Inputs>().having((i) => i.variadic, "variadic", ['foo', 'bar']),
        );
      });
      test("parses positionals when they are registered", () {
        final parser = Parser(
          CommandRegistry.create(
            "mv",
            "Move a file to a different place",
            positionalSchema: PositionalSchema([
              Positional("source"),
              Positional("destination"),
            ]),
          ),
        );

        final (command, inputs) = parser.parse([
          'mv',
          'user.dart',
          'lib/user.dart',
        ]);

        expect(command, equals(["mv"]));
        expect(
          inputs,
          isA<Inputs>().having(
            (i) => i.mandatoryPositionals,
            "mandatoryPositionals",
            {'source': 'user.dart', 'destination': 'lib/user.dart'},
          ),
        );
      });
    });
  });
}
