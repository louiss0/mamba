import 'package:arg_parser/errors.dart';
import 'package:arg_parser/registry.dart';
import 'package:test/test.dart';

void main() {
  group('Testing Registry.create', () {
    group("Throws approriate errors based on input", () {
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
        "Throws error when there's wrong name input based on keyboard symbols",
        () {
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
            test("throws error when $symbol is used for name", () {
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
            });
          }
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
    });

    group("Registers input to the right place", () {});
  });
}
