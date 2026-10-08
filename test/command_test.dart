import 'dart:async';
import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';
import 'package:mamba/help_formatter.dart';
import 'package:mamba/parser.dart';
import 'package:mamba/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

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

  FutureOr<String?> runChildAtPath(List<String> commandPath) {
    return runChildCommand(commandPath, valueOfWithoutValues, const []);
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
  String run(ValueOf valueOf, List<String> args) => '';
}

class TestChildGroupCommand extends Mock implements GroupCommand {
  @override
  final String name;

  @override
  final List<Command> commands;

  new(this.name, this.commands);
}

final valueOfWithoutValues = Parser(CommandRegistry.create('tool', 'Tool.'))
    .parse([])
    .$2;

String stripAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

/// A child command that renders under its own name in help.
final class _NamedCommand extends Command {
  new(this.name, this.shortDescription);

  @override
  final String name;

  @override
  final String shortDescription;

  @override
  String run(ValueOf valueOf, List<String> args) => '';
}

/// A real command that records having run, for paths that must not be mocks.
final class _RecordingCommand extends Command {
  new(this.name);

  @override
  final String name;

  var ran = false;

  @override
  String get shortDescription => 'Records having run.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    ran = true;
    return '';
  }
}

/// Records which registry it was asked to render.
final class _RecordingHelpFormatter extends HelpFormatter {
  final formatted = <CommandRegistry>[];

  @override
  String format(CommandRegistry registry) {
    formatted.add(registry);
    return 'recorded help';
  }

  @override
  void formatLongDescription(StringBuffer buffer, String longDescription) {}
}

ValueOf createCompletionInputs(ShellCompletion shell, {String? path}) {
  final registry = CommandRegistry.create(
    'tool',
    'Tool.',
    mandatoryPositionals: [CompletionCommand.shellInput],
    discretionaryPositionals: [CompletionCommand.pathInput],
  );
  return Parser(registry).parse([shell.name, ?path]).$2;
}

/// Records where a completion command was told to write and what it generated.
final class _RecordingWriter {
  new(this.paths, this.contents);

  final List<String> paths;
  final List<String>? contents;

  void write(String path, String script) {
    paths.add(path);
    contents?.add(script);
  }
}

class TestCompletionCommand extends CompletionCommand {
  static const commandName = 'rig';

  final List<String> createdPaths;
  final List<String> createdContents;

  new(this.createdPaths, [List<String>? contents])
    : createdContents = contents ?? <String>[],
      // Keep the test isolated from the real filesystem.
      super.preset(createFile: _RecordingWriter(createdPaths, contents).write) {
    registryRecord = CommandRegistry.create(
      commandName,
      'A test command.',
    ).toRecord();
  }
}

void main() {
  registerFallbackValue(valueOfWithoutValues);

  group('CompletionCommand', () {
    group('metadata', () {
      test('describes the completion command', () {
        final command = CompletionCommand();

        expect(command.name, 'completion');
        expect(
          command.shortDescription,
          'Generate completion for various shells',
        );
      });

      test('declares the shell and path inputs it reads', () {
        final command = CompletionCommand();

        expect(command.mandatoryPositionals, [CompletionCommand.shellInput]);
        expect(command.discretionaryPositionals, [CompletionCommand.pathInput]);
      });
    });

    group('a caller-supplied destination', () {
      test('receives the generated script for the selected shell', () {
        final createdPaths = <String>[];
        final createdContents = <String>[];
        final command = TestCompletionCommand(createdPaths, createdContents);

        command.run(
          createCompletionInputs(ShellCompletion.bash, path: './rig.bash'),
          const [],
        );

        expect(createdPaths, ['./rig.bash']);
        expect(
          createdContents.single,
          contains('complete -F _rig_completion rig'),
        );
      });

      test('receives an empty path when no destination is supplied', () {
        final createdPaths = <String>[];
        final command = TestCompletionCommand(createdPaths);

        command.run(createCompletionInputs(ShellCompletion.fish), const []);

        expect(createdPaths, ['']);
      });
    });

    group('preset', () {
      test('writes generated completion content for every shell by default', () {
        final directory = Directory.systemTemp.createTempSync(
          'mamba_completion_test_',
        );
        addTearDown(() => directory.deleteSync(recursive: true));

        final completionCommand = CompletionCommand.preset(createFile: null);
        completionCommand.registryRecord = CommandRegistry.create(
          TestCompletionCommand.commandName,
          'A test command.',
        ).toRecord();
        final cases = [
          (
            shell: ShellCompletion.bash,
            fileName: 'rig.bash',
            marker: 'complete -F _rig_completion rig',
          ),
          (
            shell: ShellCompletion.zsh,
            fileName: 'rig.zsh',
            marker: 'compdef _rig rig',
          ),
          (
            shell: ShellCompletion.fish,
            fileName: 'rig.fish',
            marker: '# Completion for rig: A test command.',
          ),
          (
            shell: ShellCompletion.powershell,
            fileName: 'rig.ps1',
            marker: "-CommandName 'rig'",
          ),
          (
            shell: ShellCompletion.carapace,
            fileName: 'rig.yaml',
            marker: 'name: "rig"',
          ),
        ];

        for (final testCase in cases) {
          final path =
              '${directory.path}${Platform.pathSeparator}${testCase.fileName}';
          completionCommand.run(
            createCompletionInputs(testCase.shell, path: path),
            const [],
          );

          expect(File(path).readAsStringSync(), contains(testCase.marker));
        }
      });

      final completionCommand = TestCompletionCommand([]);

      group('with no path', () {
        for (final shell in ShellCompletion.values) {
          test('hands the callback an empty path for ${shell.name}', () {
            final createdContents = <String>[];
            final command = TestCompletionCommand([], createdContents);

            command.run(createCompletionInputs(shell), const []);

            expect(command.createdPaths, ['']);
            expect(createdContents.single, isNotEmpty);
          });
        }

        test('rejects a missing destination when no writer is supplied', () {
          final command = CompletionCommand.preset(createFile: null);
          command.registryRecord = CommandRegistry.create(
            TestCompletionCommand.commandName,
            'A test command.',
          ).toRecord();

          expect(
            () => command.run(
              createCompletionInputs(ShellCompletion.bash),
              const [],
            ),
            throwsA(
              isA<MambaException>().having(
                (error) => error.message,
                'message',
                contains('destination path is required'),
              ),
            ),
          );
        });
      });

      group('with an invalid path', () {
        final cases = [
          (shell: ShellCompletion.bash, path: 'ffff.fish', extension: '.bash'),
          (shell: ShellCompletion.zsh, path: 'ffff.h', extension: '.zsh'),
          (shell: ShellCompletion.fish, path: 'ffff.fish', extension: '.fish'),
          (
            shell: ShellCompletion.powershell,
            path: 'ffff.4sh',
            extension: '.ps1',
          ),
          (
            shell: ShellCompletion.carapace,
            path: 'ffff.3g',
            extension: '.yaml',
          ),
        ];

        for (final $case in cases) {
          test('rejects ${$case.path} for ${$case.shell.name}', () {
            expect(
              () => completionCommand.run(
                createCompletionInputs($case.shell, path: $case.path),
                const [],
              ),
              throwsA(
                isA<MambaException>().having(
                  (exception) => exception.message,
                  'message',
                  'When shell is ${$case.shell.name} the path must end in ${$case.extension} and must have ${completionCommand.registryRecord.name} in the file name',
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
                createCompletionInputs(
                  ShellCompletion.bash,
                  path: 'ffff.${TestCompletionCommand.commandName}',
                ),
                const [],
              ),
              throwsA(isA<MambaException>()),
            );
          },
        );

        test('rejects a correctly extended path without the command name', () {
          expect(
            () => completionCommand.run(
              createCompletionInputs(ShellCompletion.bash, path: 'ffff.bash'),
              const [],
            ),
            throwsA(isA<MambaException>()),
          );
        });
      });

      group('with a valid path', () {
        final cases = [
          (
            shell: ShellCompletion.bash,
            path: './ffff${TestCompletionCommand.commandName}.bash',
          ),
          (
            shell: ShellCompletion.zsh,
            path: './ffff${TestCompletionCommand.commandName}.zsh',
          ),
          (
            shell: ShellCompletion.fish,
            path: './ffff${TestCompletionCommand.commandName}.fish',
          ),
          (
            shell: ShellCompletion.powershell,
            path: './ffff${TestCompletionCommand.commandName}.ps1',
          ),
          (
            shell: ShellCompletion.carapace,
            path: './ffff${TestCompletionCommand.commandName}.yaml',
          ),
        ];

        for (final $case in cases) {
          test('uses ${$case.path} for ${$case.shell.name}', () {
            completionCommand.createdPaths.clear();
            final output = completionCommand.run(
              createCompletionInputs($case.shell, path: $case.path),
              const [],
            );

            expect(completionCommand.createdPaths, [$case.path]);
            expect(
              output,
              'Created completion ${$case.shell.name} in ${$case.path}',
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

    when(() => stashPush.run(any(), any())).thenAnswer((_) => '');

    when(() => stashPop.run(any(), any())).thenAnswer((_) => '');

    when(() => stashCommand.run(any(), any()))
        .thenAnswer((_) => Future.value(''));

    final groupCommand = TestGroupCommand('git', [stashCommand]);

    test("calls the run child command", () {
      groupCommand.runChildAtPath(['stash']);

      verifyNever(() => stashPush.run(any(), any()));
      verifyNever(() => stashPop.run(any(), any()));
      verify(() => stashCommand.run(any(), any())).called(1);
    });

    test("calls the child's child command when path points to it", () {
      groupCommand.runChildAtPath(['stash', 'pop']);

      verifyNever(() => stashPush.run(any(), any()));
      verify(() => stashPop.run(any(), any())).called(1);
      verifyNever(() => stashCommand.run(any(), any()));
    });

    test('resolves aliases in direct child command paths', () async {
      when(() => stashCommand.aliases).thenReturn(['st']);

      await groupCommand.runChildAtPath(['st']);

      verify(() => stashCommand.run(any(), any())).called(1);
    });

    test('runs a relative default subcommand path', () async {
      final git = TestGroupCommand(
        'git',
        [stashCommand],
        defaultSubCommandPath: ['stash', 'pop'],
      );

      await git.run(valueOfWithoutValues, const []);

      verify(() => stashPop.run(any(), any())).called(1);
    });

    test('rejects empty default paths', () {
      expect(
        () =>
            TestGroupCommand('git', [stashCommand], defaultSubCommandPath: []),
        throwsA(isA<MambaRegistryError>()),
      );
    });

    test('rejects parent-qualified default paths when run', () async {
      final git = TestGroupCommand(
        'git',
        [stashCommand],
        defaultSubCommandPath: ['git'],
      );

      await expectLater(
        git.run(valueOfWithoutValues, const []),
        throwsA(isA<MambaCommandNotFoundException>()),
      );
    });

    test('runs a child that shares its group name', () async {
      final same = _RecordingCommand('same');
      final group = TestGroupCommand(
        'same',
        [same],
        defaultSubCommandPath: ['same'],
      );

      await group.run(valueOfWithoutValues, const []);

      expect(same.ran, isTrue);
    });

    test('requires child paths to be relative to the group', () {
      when(() => stashCommand.aliases).thenReturn(const <String>[]);

      expect(
        () => groupCommand.runChildAtPath(['git']),
        throwsA(
          isA<MambaCommandNotFoundException>().having(
            (error) => error.message,
            'message',
            'Command git was not found under git. Available commands: stash',
          ),
        ),
      );
    });

    test('rejects empty runtime paths and unknown child commands', () {
      expect(
        () => groupCommand.runChildAtPath([]),
        throwsA(isA<MambaException>()),
      );
      expect(
        () => groupCommand.runChildAtPath(['missing']),
        throwsA(isA<MambaException>()),
      );
    });

    test('returns no output when no default child is configured', () async {
      expect(await groupCommand.run(valueOfWithoutValues, const []), isNull);
    });

    test(
      'renders help that lists its children when a registry is given',
      () async {
        final stash = _NamedCommand('stash', 'Stash changes.');
        final git = TestGroupCommand('git', [stash]);

        git.help = CommandHelp(
          MambaHelpFormatter(),
          CommandRegistry.create('git', 'Manage changes.', commands: [stash]),
        );
        final output = await git.run(valueOfWithoutValues, const []);

        expect(
          stripAnsi(output!),
          allOf(
            contains('Commands'),
            contains('stash'),
            contains('Stash changes.'),
          ),
        );
      },
    );

    test(
      'renders help for a nested group with the formatter it is given',
      () async {
        final stash = _NamedCommand('stash', 'Stash changes.');
        final remote = TestGroupCommand('remote', []);
        final git = TestGroupCommand('git', [stash, remote]);
        final formatter = _RecordingHelpFormatter();
        final registry = CommandRegistry.create(
          'git',
          'Manage changes.',
          commands: [stash, remote],
        );

        git.help = CommandHelp(formatter, registry);
        await git.run(valueOfWithoutValues, const []);

        expect(formatter.formatted, [registry]);
      },
    );

    test('prefers a default subcommand path over rendering help', () async {
      final stash = _NamedCommand('stash', 'Stash changes.');
      final git = TestGroupCommand(
        'git',
        [stash],
        defaultSubCommandPath: ['stash'],
      );
      final formatter = _RecordingHelpFormatter();
      final registry = CommandRegistry.create(
        'git',
        'Manage changes.',
        commands: [stash],
      );

      git.help = CommandHelp(formatter, registry);
      final output = await git.run(valueOfWithoutValues, const []);

      expect(output, isEmpty);
      expect(formatter.formatted, isEmpty);
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
    test('retain identity', () {
      final one = StringOption('one');
      final two = StringOption('two');

      expect(identical(one, two), isFalse);
    });

    test('expose output availability in their types', () {
      final optional = StringOption('optional');
      final required = StringOption.required('required');
      final defaulted = ChoiceOption.withDefault(
        'format',
        choices: OutputFormat.values,
        defaultValue: OutputFormat.yaml,
      );

      expect(optional, isA<OptionalInput<String>>());
      expect(required, isA<RequiredInput<String>>());
      expect(defaulted, isA<DefaultedInput<OutputFormat>>());
    });

    test('positionals expose presence constraints in their types', () {
      final mandatory = NormalPositional('source');
      final discretionary = NormalPositional.optional('destination');

      expect(mandatory, isA<MandatoryPositional<String>>());
      expect(discretionary, isA<DiscretionaryPositional<String?>>());
    });

    test('positional factories preserve typed metadata and values', () {
      final optionalChoice = ChoicePositional.optional<OutputFormat>(
        'format',
        choices: OutputFormat.values,
      );
      final defaultedChoice = ChoicePositional.withDefault(
        'format',
        choices: OutputFormat.values,
        defaultValue: OutputFormat.yaml,
      );
      final optionalFiles = RepeatedStringPositional.optional(
        'files',
        times: 2,
      );
      final optionalFormats = RepeatedChoicePositional.optional<OutputFormat>(
        'formats',
        choices: OutputFormat.values,
        times: 2,
      );
      final defaultedFormats =
          RepeatedChoicePositional.withDefault<OutputFormat>(
            'formats',
            choices: OutputFormat.values,
            defaultValue: [OutputFormat.yaml],
            times: 2,
          );

      expect(
        (optionalChoice as ChoiceValidated<OutputFormat>).choices,
        OutputFormat.values,
      );
      expect(
        (defaultedChoice as DefaultValue<OutputFormat>).defaultValue,
        OutputFormat.yaml,
      );
      expect((optionalFiles as RepeatedPositionalDefinition).times, 2);
      expect((optionalFormats as RepeatedPositionalDefinition).times, 2);
      expect((defaultedFormats as RepeatedPositionalDefinition).times, 2);

      final values = (optionalFormats as RepeatedPositionalDefinition)
          .freezeValues([OutputFormat.yaml, OutputFormat.json]);
      expect(values, OutputFormat.values);
      expect(
        () => (values as List<OutputFormat>).add(OutputFormat.yaml),
        throwsUnsupportedError,
      );
      expect(
        () => (defaultedFormats as DefaultValue<List<OutputFormat>>)
            .defaultValue
            .add(OutputFormat.json),
        throwsUnsupportedError,
      );
    });

    test('option factories preserve availability and constraints', () {
      final requiredString = StringOption.required('name');
      final defaultedString = StringOption.withDefault(
        'label',
        defaultValue: 'stable',
      );
      final requiredInt = IntOption.required('count', min: 1, max: 3);
      final defaultedInt = IntOption.withDefault(
        'port',
        defaultValue: 80,
        min: 1,
        max: 65535,
      );
      final requiredDouble = DoubleOption.required(
        'ratio',
        min: 0,
        max: 1,
        step: 0.1,
      );
      final defaultedDouble = DoubleOption.withDefault(
        'scale',
        defaultValue: 1.5,
        min: 1,
        max: 2,
        step: 0.5,
      );
      final requiredChoice = ChoiceOption.required<OutputFormat>(
        'format',
        choices: OutputFormat.values,
      );
      final defaultedChoice = ChoiceOption.withDefault(
        'output',
        choices: OutputFormat.values,
        defaultValue: OutputFormat.json,
      );

      expect(requiredString, isA<RequiredInput<String>>());
      expect((defaultedString as DefaultValue<String>).defaultValue, 'stable');
      expect((requiredInt as NumericRangeValidated<int>).min, 1);
      expect((requiredInt as NumericRangeValidated<int>).max, 3);
      expect((defaultedInt as DefaultValue<int>).defaultValue, 80);
      expect((requiredDouble as NumericStepValidated).step, 0.1);
      expect((defaultedDouble as DefaultValue<double>).defaultValue, 1.5);
      expect(
        (requiredChoice as ChoiceValidated<OutputFormat>).choices,
        OutputFormat.values,
      );
      expect(
        (defaultedChoice as DefaultValue<OutputFormat>).defaultValue,
        OutputFormat.json,
      );
    });

    test('repeatable option factories append immutable typed values', () {
      final optional = RepeatableStringOption('tag');
      final required = RepeatableIntOption.required('port', min: 1, max: 10);
      final defaulted = RepeatableDoubleOption.withDefault(
        'ratio',
        defaultValue: [1.0],
        min: 0,
        max: 2,
        step: 0.5,
      );
      final requiredChoice = RepeatableChoiceOption.required<OutputFormat>(
        'format',
        OutputFormat.values,
        unique: true,
      );
      final defaultedChoice = RepeatableChoiceOption.withDefault<OutputFormat>(
        'output',
        OutputFormat.values,
        defaultValue: [OutputFormat.yaml],
      );
      final requiredString = RepeatableStringOption.required('file');
      final defaultedString = RepeatableStringOption.withDefault(
        'path',
        defaultValue: ['lib'],
      );
      final defaultedInt = RepeatableIntOption.withDefault(
        'attempt',
        defaultValue: [1],
      );
      final requiredDouble = RepeatableDoubleOption.required('weight');

      expect(optional.appendValue('one', null), ['one']);
      expect(required.appendValue(2, [1]), [1, 2]);
      expect(defaulted.appendValue(2.0, [1.0]), [1.0, 2.0]);
      expect(requiredChoice.unique, isTrue);
      expect(defaultedChoice, isA<DefaultedInput<List<OutputFormat>>>());
      expect(requiredString, isA<RequiredInput<List<String>>>());
      expect(defaultedString, isA<DefaultedInput<List<String>>>());
      expect(defaultedInt, isA<DefaultedInput<List<int>>>());
      expect(requiredDouble, isA<RequiredInput<List<double>>>());
      expect(
        () => (defaulted as DefaultValue<List<double>>).defaultValue.add(2),
        throwsUnsupportedError,
      );
    });

    test('accessor factories preserve typed defaults and constraints', () {
      final requiredString = AccessorStringOption.required('host');
      final defaultedString = AccessorStringOption.withDefault(
        'scheme',
        defaultValue: 'https',
      );
      final requiredInt = AccessorIntOption.required('port');
      final defaultedInt = AccessorIntOption.withDefault(
        'attempts',
        defaultValue: 3,
      );
      final requiredDouble = AccessorDoubleOption.required('ratio');
      final defaultedDouble = AccessorDoubleOption.withDefault(
        'scale',
        defaultValue: 1.5,
      );
      final requiredChoice = AccessorChoiceOption.required<OutputFormat>(
        'format',
        choices: OutputFormat.values,
      );
      final defaultedChoice = AccessorChoiceOption.withDefault<OutputFormat>(
        'output',
        choices: OutputFormat.values,
        defaultValue: OutputFormat.yaml,
      );

      expect(requiredString, isA<RequiredInput<String>>());
      expect((defaultedString as DefaultValue<String>).defaultValue, 'https');
      expect((requiredInt as NumericRangeValidated<int>).min, isNull);
      expect((defaultedInt as DefaultValue<int>).defaultValue, 3);
      expect((requiredDouble as NumericStepValidated).step, isNull);
      expect((defaultedDouble as DefaultValue<double>).defaultValue, 1.5);
      expect(
        (requiredChoice as ChoiceValidated<OutputFormat>).choices,
        OutputFormat.values,
      );
      expect(
        (defaultedChoice as DefaultValue<OutputFormat>).defaultValue,
        OutputFormat.yaml,
      );
    });

    test('parsed inputs reject unknown and missing required handles', () {
      final optional = StringOption('optional');
      final required = StringOption.required('required');
      final unknown = StringOption('unknown');
      final valueOf = Parser(
        CommandRegistry.create('tool', 'Tool.', options: [optional, required]),
      ).parse(['--optional=value', '--help']).$2;
      final parsed = valueOf;

      expect(parsed(optional), 'value');
      expect(() => parsed(unknown), throwsStateError);
      expect(() => parsed(required), throwsStateError);
    });

    test('paired groups describe typed map results', () {
      final host = PairStringOption('host');
      final port = PairIntOption('port');
      final optionalPair = PairedOptions<Object>([host, port]);
      final requiredPair = PairedOptions<Object>.required([host, port]);
      expect(optionalPair.options, [host, port]);
      expect(optionalPair.required, isFalse);
      expect(requiredPair.required, isTrue);
    });

    group('Repeated positionals', () {
      test('freeze mandatory and optional string values', () {
        final mandatory = RepeatedStringPositional('sources', times: 2);
        final optional = RepeatedStringPositional.optional(
          'targets',
          times: 2,
        ) as RepeatedPositionalDefinition;

        final mandatoryValues = mandatory.freezeValues(['one', 'two']);
        final optionalValues = optional.freezeValues(['three', 'four']);

        expect(mandatoryValues, ['one', 'two']);
        expect(optionalValues, ['three', 'four']);
        expect(() => mandatoryValues.add('three'), throwsUnsupportedError);
        expect(
          () => (optionalValues as List<String>).add('five'),
          throwsUnsupportedError,
        );
      });
    });

    group('Repeatable options', () {
      test('exposes cardinality and numeric constraints', () {
        final required = RepeatableIntOption.required(
          'required-port',
          min: 1,
          max: 10,
        );
        final defaulted = RepeatableDoubleOption.withDefault(
          'default-weight',
          defaultValue: [1],
        );
        final optionalInt = RepeatableIntOption('port', min: 1, max: 10);
        final optionalDouble = RepeatableDoubleOption(
          'weight',
          min: 0,
          max: 2,
          step: 0.5,
        );

        expect(required.unique, isFalse);
        expect(defaulted.unique, isFalse);
        expect(optionalInt.min, 1);
        expect(optionalInt.max, 10);
        expect(optionalDouble.min, 0);
        expect(optionalDouble.max, 2);
        expect(optionalDouble.step, 0.5);
      });
    });

    group('Paired options', () {
      test('describes scalar and repeatable pair inputs', () {
        final host = PairStringOption('host');
        final port = PairIntOption('port');
        final optional = PairedOptions<Object>([host, port]);
        final required = PairedOptions<Object>.required([host, port]);
        final ratio = PairDoubleOption('ratio', min: 0, max: 1, step: 0.1);
        final tags = RepeatablePairStringOption('tag');
        final ports = RepeatablePairIntOption('ports', min: 1, max: 10);
        final ratios = RepeatablePairDoubleOption(
          'ratios',
          min: 0,
          max: 2,
          step: 0.5,
        );

        expect(optional.required, isFalse);
        expect(required.options, [host, port]);
        expect(ratio.min, 0);
        expect(ratio.max, 1);
        expect(ratio.step, 0.1);
        expect(tags.regex.hasMatch('stable'), isTrue);
        expect(ports.min, 1);
        expect(ports.max, 10);
        expect(ratios.min, 0);
        expect(ratios.max, 2);
        expect(ratios.step, 0.5);
      });
    });

    group('Accessors', () {
      test('exposes unconstrained required numeric metadata', () {
        final integer =
            AccessorIntOption.required('port') as NumericRangeValidated<int>;
        final decimal = AccessorDoubleOption.required('ratio');
        final range = decimal as NumericRangeValidated<double>;
        final step = decimal as NumericStepValidated;

        expect(integer.min, isNull);
        expect(integer.max, isNull);
        expect(range.min, isNull);
        expect(range.max, isNull);
        expect(step.step, isNull);
      });
    });

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

  group('Input definition analyzer', () {
    test(
      'rejects nullable output and positional presence mismatches',
      () async {
        await expectAnalysis(
          r'''
import 'package:mamba/mamba.dart';

void invalid(ValueOf valueOf) {
  final optional = StringOption('name');
  final String value = valueOf(optional);
  CommandRegistry.create(
    'tool',
    'Tool.',
    mandatoryPositionals: [NormalPositional.optional('path')],
  );
  print(value);
}
''',
          expectedDiagnostics: const [
            'argument_type_not_assignable',
            'list_element_type_not_assignable',
          ],
          fileName: 'invalid_input_types_temp.dart',
        );
      },
    );
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
      final utf8Input = ProcessedStandardInput([104, 195, 169]);
      final json = ProcessedStandardInput('{"enabled":true}'.codeUnits);

      expect(utf8Input.text, 'hé');
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
