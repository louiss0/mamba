import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

class TestCommand extends Command {
  TestCommand(
    super.name,
    super.shortDescription, {
    super.longDescription,
    super.positionalSchema,
    super.flags,
    super.singleOptions,
    super.repeatedOptions,
    super.accessorFlagSchema,
    super.commands,
  });

  @override
  void run(Inputs input) {
    // TODO: implement run
  }
}

void main() {
  group('Testing Registry.create', () {
    group("Throws approriate errors based on input", () {
      void parameterizedKeyboardSymbolTest(
        Function(String) computedDescription,
        Function(String) body,
      ) {
        const keyboardSymbols = [
          '!',
          '@',
          '#',
          r'$',
          '%',
          '^',
          '&',
          '*',
          '(',
          ')',
          '=',
          '+',
          '[',
          ']',
          '{',
          '}',
          ';',
          ':',
          '\'',
          '"',
          ',',
          '.',
          '<',
          '>',
          '/',
          '?',
          '\\',
          '|',
          '`',
          '~',
        ];

        for (final symbol in keyboardSymbols) {
          test(computedDescription(symbol), () {
            body(symbol);
          });
        }
      }

      group(
        "Throws error when there's wrong name input based on structure",
        () {
          const nameCases = [
            (name: "", expected: "Command name is empty,"),
            (
              name: "F F",
              expected:
                  "There should no spaces in between letters for command names",
            ),
            (name: "3", expected: "Command name should have no numbers"),
            (name: "f3", expected: "Command name should have no numbers"),
            (name: "_", expected: "Command name can't be an underscore"),
            (name: "-", expected: "Command name can't be a dash"),
          ];

          for (final (:name, :expected) in nameCases) {
            test("throws an error when command name is written wrong", () {
              expect(
                () => CommandRegistry.create(name, ""),
                throwsA(
                  isA<MambaException>().having(
                    (e) => e.message,
                    "message",
                    expected,
                  ),
                ),
              );
            });
          }
        },
      );

      group(
        "Throws error when there's wrong command name input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for command name",
            (symbol) {
              expect(
                () => CommandRegistry.create(symbol, ""),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Command names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong option name input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for option name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  singleOptions: [IntOption(name: symbol)],
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Option names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong flag name input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for flag name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  flags: [BooleanFlag(name: symbol)],
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Flag names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong positional name input based on positional symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  positionalSchema: PositionalSchema([Positional(symbol)]),
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Positional names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong positional name input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for variadic name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  positionalSchema: PositionalSchema(
                    [],
                    variadic: Variadic(symbol),
                  ),
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Positional names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong accessor name input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for variadic name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  accessors: [AccessorIntOption(name: symbol)],
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Positional names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group(
        "Throws error when there's wrong accessor name with group input based on keyboard symbols",
        () {
          parameterizedKeyboardSymbolTest(
            (symbol) => "throws error when $symbol is used for variadic name",
            (symbol) {
              expect(
                () => CommandRegistry.create(
                  'build',
                  "Build this!",
                  accessors: [
                    AccessorListOption(
                      name: 'user',
                      flags: [AccessorIntOption(name: symbol)],
                    ),
                  ],
                ),
                throwsA(
                  isA<MambaRegistryError>().having(
                    (e) => e.message,
                    "message",
                    equals(
                      "Positional names can't use keyboard symbols other than _ or -",
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      group("Throws error when shortDescription is invalid", () {
        final shortDescriptionCases = [
          (shortDescription: "", expected: "Short description can't be empty"),
          (
            shortDescription: "#" * 150,
            expected: "Short description can't go over 150 lines of code",
          ),
        ];

        for (final (:shortDescription, :expected) in shortDescriptionCases) {
          test("throws an error when short description is invalid", () {
            expect(
              () => CommandRegistry.create("add", shortDescription),
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  equals(expected),
                ),
              ),
            );
          });
        }
      });

      group(
        "throws error when the same name is used for registration of any field",
        () {
          test("throws for duplcate options", () {
            void createDuplicateOptions() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                singleOptions: [
                  StringOption(name: "commit", regex: RegExp(r"")),
                  StringOption(name: "commit", regex: RegExp(r"")),
                ],
              );
            }

            expect(
              createDuplicateOptions,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "There are duplicate option names at index 0 and 1",
                ),
              ),
            );
          });

          test('throws for matching single and repeated option names', () {
            expect(
              () => CommandRegistry.create(
                'commit',
                'Makes a git commit',
                singleOptions: [
                  StringOption(name: 'message', regex: RegExp(r'\S+')),
                ],
                repeatedOptions: [
                  RepeatableStringOption(
                    name: 'message',
                    regex: RegExp(r'\S+'),
                  ),
                ],
              ),
              throwsA(
                isA<MambaException>().having(
                  (error) => error.message,
                  'message',
                  'There are duplicate option names at index 0 and 1',
                ),
              ),
            );
          });

          test("throws for duplcate flags", () {
            void createDuplicateFlags() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                flags: [
                  BooleanFlag(name: "enable"),
                  BooleanFlag(name: "enable"),
                ],
              );
            }

            expect(
              createDuplicateFlags,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "There are duplicate flag names at index 0 and 1",
                ),
              ),
            );
          });

          test("throws for same accessor and flag names", () {
            void createDuplicateAccessorFlagNames() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                flags: [BooleanFlag(name: "user")],
                accessors: [AccessorStringOption(name: 'user')],
              );
            }

            expect(
              createDuplicateAccessorFlagNames,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "This accessor user has the same name as a flag at index 0",
                ),
              ),
            );
          });

          test("throws for same accessor and option names", () {
            void createDuplicateAccessorOptionNames() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                singleOptions: [StringOption(name: "user", regex: RegExp(r""))],
                accessors: [AccessorStringOption(name: 'user')],
              );
            }

            expect(
              createDuplicateAccessorOptionNames,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "This accessor user has the same name as an option at index 0",
                ),
              ),
            );
          });

          test("throws when a positional has the same name as a command", () {
            void createDuplicateAccessorPositionalNames() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                positionalSchema: PositionalSchema([Positional("message")]),
                commands: [TestCommand("message", "Makes a message")],
              );
            }

            expect(
              createDuplicateAccessorPositionalNames,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "This positional mesaage has the same name as a command at index 0",
                ),
              ),
            );
          });

          test("throws when there are duplicate positional names", () {
            void createDuplicatePositionalNames() {
              CommandRegistry.create(
                "add",
                "Adds files to the git index",
                positionalSchema: PositionalSchema([
                  Positional("files"),
                  Positional("files"),
                ]),
              );
            }

            expect(
              createDuplicatePositionalNames,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "A positional can't have the same name as another positional",
                ),
              ),
            );
          });

          test("throws when positnal and variadic have the same name", () {
            void createDuplicatePositionalandVariadicNames() {
              CommandRegistry.create(
                "commit",
                "Makes a git commit",
                positionalSchema: PositionalSchema([
                  Positional("message"),
                ], variadic: Variadic("message")),
              );
            }

            expect(
              createDuplicatePositionalandVariadicNames,
              throwsA(
                isA<MambaException>().having(
                  (e) => e.message,
                  "message",
                  "A positional and variadic can't have the same name you can pluralize the variadic",
                ),
              ),
            );
          });
        },
      );
    });

    group("Registers input to the right place", () {
      test("When options are added they are placed in the options map", () {
        final run = StringOption(name: "run", regex: RegExp(r"/S+"));
        final agent = StringOption(name: "agent", regex: RegExp(r"/S+"));

        final registry = CommandRegistry.create(
          "build",
          "Build this!",
          singleOptions: [run, agent],
        );

        expect(registry.singleOptions, equals({"run": run, "agent": agent}));
      });

      test("When flags are added they are placed in the right flag places", () {
        final dryRun = BooleanFlag(name: "dry-run");
        final verbose = CountFlag(name: "verbose");

        final registry = CommandRegistry.create(
          "build",
          "Build this!",
          flags: [dryRun, verbose],
        );

        expect(registry.boolFlags, equals({"dry-run": dryRun}));
        expect(registry.countFlags, equals({"verbose": verbose}));
      });

      test("When accessors are added they are added to the accesors field", () {
        final accessors = [
          AccessorListOption(
            name: 'user',
            flags: [
              AccessorStringOption(name: 'name'),
              AccessorStringOption(name: 'email'),
            ],
          ),
        ];

        final registry = CommandRegistry.create(
          "config",
          "configure this command",
          accessors: accessors,
        );

        expect(registry.accessorSchema, equals(accessors));
      });

      test(
        "When positionals are added they are added to the positionals map",
        () {
          final positionals = [Positional("script")];

          final registry = CommandRegistry.create(
            "run",
            "Run a command or script",
            positionalSchema: PositionalSchema(positionals),
          );

          expect(
            registry.mandatoryPositionals,
            equals({'script': positionals[0]}),
          );
        },
      );

      test("When the variadic is added its added to the variadic field", () {
        final variadic = Variadic("positionals");

        final registry = CommandRegistry.create(
          "run",
          "Run a command or script",
          positionalSchema: PositionalSchema([], variadic: variadic),
        );
        expect(registry.variadic, equals(variadic));
      });

      test(
        "when commands are added they are added the command registries are created",
        () {
          final commands = [
            TestCommand("create", "Make a new repo "),
            TestCommand("clone", "Clone a repo"),
            TestCommand("view", "View a repo"),
          ];

          final registry = CommandRegistry.create(
            "repo",
            "Controll git repos ",
            commands: commands,
          );

          expect(
            registry.commandRegistries
                ?.map(
                  (commandRegistry) => (
                    name: commandRegistry.name,
                    shortDescription: commandRegistry.shortDescription,
                  ),
                )
                .toList(),
            equals(
              commands
                  .map(
                    (command) => (
                      name: command.name,
                      shortDescription: command.shortDescription,
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );
    });
  });
}
