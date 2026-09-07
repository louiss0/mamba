import 'dart:async';
import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  @override
  final String name;

  @override
  String get shortDescription => "This is a test command";

  new(this.name, super.commands, {super.defaultSubCommandPath, super.variadic})
    : super(
        longDescription: '',
        mandatoryPositionals: null,
        discretionaryPositionals: null,
        flags: null,
        options: null,
        pairedOptions: null,
        accessors: null,
      );

  FutureOr<String?> runWithNothingBasedOnCommandPathWithNothing(
    List<String> commandPath,
  ) {
    return runChildCommand(
      commandPath,
      (singles: null, repeated: null),
      (
        accessors: null,
        boolFlags: null,
        countFlags: null,
        doubleOptions: null,
        intOptions: null,
        repeatedDoubleOptions: null,
        repeatedIntOptions: null,
        repeatedStringOptions: null,
        stringOptions: null,
      ),
      [],
    );
  }
}

class TestCommand extends Mock implements Command {
  @override
  final String name;

  new(this.name);
}

enum OutputFormat { yaml, json }

final class _VariadicCommand extends Command {
  new({super.variadic});

  @override
  String get name => 'tool';

  @override
  String get shortDescription => 'A test command.';

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) => '';
}

class TestChildGroupCommand extends Mock implements GroupCommand {
  @override
  final String name;

  @override
  final List<Command> commands;

  new(this.name, this.commands);
}

class TestCompletionCommand extends CompletionCommand {
  static const commandName = 'rig';

  final List<String> createdPaths;

  new(this.createdPaths)
    : super.preset((path) {
        // Keep the test isolated from the real filesystem.
        createdPaths.add(path);
      }) {
    registryRecord = CommandRegistry.create(
      commandName,
      'A test command.',
    ).toMap();
  }
}

void main() {
  final ParsedNamedInputs emptyInputs = (
    accessors: null,
    boolFlags: null,
    countFlags: null,
    doubleOptions: null,
    intOptions: null,
    repeatedDoubleOptions: null,
    repeatedIntOptions: null,
    repeatedStringOptions: null,
    stringOptions: null,
  );
  registerFallbackValue(emptyInputs);
  registerFallbackValue((singles: null, repeated: null));

  group("CompletionCommand", () {
    group('preset', () {
      test('creates a file synchronously by default', () {
        final directory = Directory.systemTemp.createTempSync(
          'mamba_completion_test_',
        );
        addTearDown(() => directory.deleteSync(recursive: true));

        final completionCommand = CompletionCommand.preset(null);
        completionCommand.registryRecord = CommandRegistry.create(
          TestCompletionCommand.commandName,
          'A test command.',
        ).toMap();
        final path = '${directory.path}${Platform.pathSeparator}rig.bash';

        completionCommand.run(
          (
            singles: {'shell': ShellCompletion.bash.name, 'path': path},
            repeated: null,
          ),
          emptyInputs,
          [],
        );

        expect(File(path).existsSync(), isTrue);
      });

      final completionCommand = TestCompletionCommand([]);

      group("If path is empty then the compeltions are sent to the global path based on shell", () {
        final cases = [
          (shell: ShellCompletion.bash.name, path: null, expected: ""),
          (shell: ShellCompletion.zsh.name, path: null, expected: ""),
          (shell: ShellCompletion.fish.name, path: null, expected: ""),
          (shell: ShellCompletion.powershell.name, path: null, expected: ""),
          (shell: ShellCompletion.carapace.name, path: null, expected: ""),
        ];
        for (final $case in cases) {
          test("The path ${$case.expected} is written for ${$case.shell}", () {
            completionCommand.createdPaths.clear();
            completionCommand.run(
              (singles: {'shell': $case.shell}, repeated: null),
              emptyInputs,
              [],
            );

            expect(completionCommand.createdPaths, [$case.expected]);
          });
        }
      });

      group("If path is defined but the extension is incorrect", () {
        final cases = [
          (
            shell: ShellCompletion.bash.name,
            path: "ffff.fish",
            extension: ".bash",
          ),
          (shell: ShellCompletion.zsh.name, path: "ffff.h", extension: ".zsh"),
          (
            shell: ShellCompletion.fish.name,
            path: "ffff.fish",
            extension: ".fish",
          ),
          (
            shell: ShellCompletion.powershell.name,
            path: "ffff.4sh",
            extension: ".ps1",
          ),
          (
            shell: ShellCompletion.carapace.name,
            path: "ffff.3g",
            extension: ".yaml",
          ),
        ];

        for (final $case in cases) {
          test("The path ${$case.path} is rejected for ${$case.shell}", () {
            expect(
              () => completionCommand.run(
                (
                  singles: {'shell': $case.shell, "path": $case.path},
                  repeated: null,
                ),
                emptyInputs,
                [],
              ),
              throwsA(
                isA<MambaException>().having(
                  (exception) => exception.message,
                  "message",
                  "When shell is ${$case.shell} the path must end in ${$case.extension} and must have ${completionCommand.registryRecord.name} in the file name",
                ),
              ),
            );
          });
        }
      });

      group('The command name belongs to the file name', () {
        test(
          'rejects a path that only places the command name in the extension',
          () {
            expect(
              () => completionCommand.run(
                (
                  singles: {
                    'shell': ShellCompletion.bash.name,
                    'path': 'ffff.${TestCompletionCommand.commandName}',
                  },
                  repeated: null,
                ),
                emptyInputs,
                [],
              ),
              throwsA(isA<MambaException>()),
            );
          },
        );

        test('rejects a correctly extended path without the command name', () {
          expect(
            () => completionCommand.run(
              (
                singles: {
                  'shell': ShellCompletion.bash.name,
                  'path': 'ffff.bash',
                },
                repeated: null,
              ),
              emptyInputs,
              [],
            ),
            throwsA(isA<MambaException>()),
          );
        });
      });

      group("When the correct path is written it's", () {
        final cases = [
          (
            shell: ShellCompletion.bash.name,
            path: "./ffff${TestCompletionCommand.commandName}.bash",
          ),
          (
            shell: ShellCompletion.zsh.name,
            path: "./ffff${TestCompletionCommand.commandName}.zsh",
          ),
          (
            shell: ShellCompletion.fish.name,
            path: "./ffff${TestCompletionCommand.commandName}.fish",
          ),
          (
            shell: ShellCompletion.powershell.name,
            path: "./ffff${TestCompletionCommand.commandName}.ps1",
          ),
          (
            shell: ShellCompletion.carapace.name,
            path: "./ffff${TestCompletionCommand.commandName}.yaml",
          ),
        ];

        for (final $case in cases) {
          test("The path ${$case.path} is used for ${$case.shell}", () async {
            completionCommand.createdPaths.clear();
            final output = await completionCommand.run(
              (
                singles: {'shell': $case.shell, 'path': $case.path},
                repeated: null,
              ),
              emptyInputs,
              [],
            );

            expect(completionCommand.createdPaths, [$case.path]);

            expect(
              output,
              equals("Created completion ${$case.shell} in ${$case.path}"),
            );
          });
        }
      });
    });
  });

  group("GroupCommand", () {
    final stashPush = TestCommand("push");
    final stashPop = TestCommand("pop");
    final stashCommand = TestChildGroupCommand('stash', [stashPush, stashPop]);

    when(() => stashPush.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashPop.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashCommand.run(any(), any(), any()))
        .thenAnswer((_) => Future.value(''));

    final groupCommand = TestGroupCommand('git', [stashCommand]);

    test("calls the run child command", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing(['stash']);

      verifyNever(() => stashPush.run(any(), any(), any()));
      verifyNever(() => stashPop.run(any(), any(), any()));
      verify(() => stashCommand.run(any(), any(), any())).called(1);
    });

    test("calls the child's child command when path points to it", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing([
        'stash',
        'pop',
      ]);

      verifyNever(() => stashPush.run(any(), any(), any()));
      verify(() => stashPop.run(any(), any(), any())).called(1);
      verifyNever(() => stashCommand.run(any(), any(), any()));
    });

    test('resolves aliases in direct child command paths', () async {
      when(() => stashCommand.aliases).thenReturn(['st']);

      await groupCommand.runWithNothingBasedOnCommandPathWithNothing(['st']);

      verify(() => stashCommand.run(any(), any(), any())).called(1);
    });

    test('runs a relative default subcommand path', () async {
      final git = TestGroupCommand(
        'git',
        [stashCommand],
        defaultSubCommandPath: ['stash', 'pop'],
      );

      await git.run((singles: null, repeated: null), emptyInputs, []);

      verify(() => stashPop.run(any(), any(), any())).called(1);
    });

    test('rejects empty and parent-qualified default paths', () {
      expect(
        () =>
            TestGroupCommand('git', [stashCommand], defaultSubCommandPath: []),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => TestGroupCommand(
          'git',
          [stashCommand],
          defaultSubCommandPath: ['git'],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('requires child paths to be relative to the group', () {
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing(['git']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty runtime paths and unknown child commands', () {
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing([]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => groupCommand.runWithNothingBasedOnCommandPathWithNothing([
          'missing',
        ]),
        throwsA(isA<MambaException>()),
      );
    });

    test('returns empty output when no default child is configured', () async {
      expect(
        await groupCommand.run(
          (singles: null, repeated: null),
          emptyInputs,
          [],
        ),
        isEmpty,
      );
    });

    test('rejects empty segments in default paths', () {
      expect(
        () => TestGroupCommand(
          'git',
          [stashCommand],
          defaultSubCommandPath: ['stash', ''],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });
  });

  group('Input definitions', () {
    test('accessor numeric regexes describe parser numeric syntax', () {
      final integer = AccessorIntOption('port').regex;
      final decimal = AccessorDoubleOption('ratio').regex;

      expect(integer.hasMatch('-80'), isTrue);
      expect(integer.hasMatch('+80'), isTrue);
      expect(decimal.hasMatch('-1.5'), isTrue);
      expect(decimal.hasMatch('+1'), isTrue);
    });

    test('rejects negative repeated positional counts', () {
      expect(
        () => RepeatedStringPositional('files', times: -1),
        throwsA(isA<MambaRegistryError>()),
      );
      expect(
        () => RepeatedChoicePositional<OutputFormat>(
          'formats',
          choices: OutputFormat.values,
          times: -1,
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });
  });

  group('Variadic', () {
    test('defaults the variadic field to absent', () {
      expect(_VariadicCommand().variadic, isNull);
    });

    test('registers a variadic without any positionals', () {
      final extra = NormalVariadic();

      final command = _VariadicCommand(variadic: extra);

      expect(command.mandatoryPositionals, isNull);
      expect(command.discretionaryPositionals, isNull);
      expect(command.variadic, same(extra));
    });

    test('registers a NormalVariadic under variadic', () {
      final extra = NormalVariadic();

      expect(_VariadicCommand(variadic: extra).variadic, same(extra));
    });

    test('registers a ChoiceVariadic under variadic', () {
      final formats = ChoiceVariadic<OutputFormat>(
        choices: OutputFormat.values,
        defaultValue: OutputFormat.yaml,
      );

      final command = _VariadicCommand(variadic: formats);

      expect(command.variadic, same(formats));
    });

    test('forwards the variadic through group commands', () {
      final formats = ChoiceVariadic<OutputFormat>(
        choices: OutputFormat.values,
      );

      final group = TestGroupCommand('git', [
        TestCommand('stash'),
      ], variadic: formats);

      expect(group.variadic, same(formats));
    });
  });

  group('ProcessedStandardInput', () {
    test('exposes character, UTF-8, and JSON representations', () {
      final text = ProcessedStandardInput('hé'.codeUnits);
      final utf8Input = ProcessedStandardInput([104, 195, 169]);
      final json = ProcessedStandardInput('{"enabled":true}'.codeUnits);

      expect(text.text, 'hé');
      expect(utf8Input.utf8Text, 'hé');
      expect(json.json, {'enabled': true});
    });

    test('reports malformed JSON', () {
      expect(
        () => ProcessedStandardInput('not-json'.codeUnits).json,
        throwsFormatException,
      );
    });
  });
}
