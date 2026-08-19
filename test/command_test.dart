import 'dart:async';

import 'package:arg_parser/command.dart';
import 'package:arg_parser/errors.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  @override
  final String name;

  @override
  String get shortDescription => "This is a test command";

  TestGroupCommand(
    this.name, {
    required super.commands,
    super.defaultSubCommandPath,
  }) : super(
         longDescription: '',
         mandatoryPositionals: null,
         discretionaryPositionals: null,
         flags: null,
         options: null,
         pairedOptions: null,
         accessors: null,
       );

  FutureOr<String> runWithNothingBasedOnCommandPathWithNothing(
    List<String> commandPath,
  ) {
    return runChildCommand(commandPath, null, (
      accessors: null,
      boolFlags: null,
      countFlags: null,
      doubleOptions: null,
      intOptions: null,
      repeatedDoubleOptions: null,
      repeatedIntOptions: null,
      repeatedStringOptions: null,
      stringOptions: null,
    ), []);
  }
}

class TestCommand extends Mock implements Command {
  @override
  final String name;

  TestCommand(this.name);
}

class TestChildGroupCommand extends Mock implements GroupCommand {
  @override
  final String name;

  @override
  final List<Command>? commands;

  TestChildGroupCommand(this.name, {this.commands});
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

  group("GroupCommand", () {
    final stashPush = TestCommand("push");
    final stashPop = TestCommand("pop");
    final stashCommand = TestChildGroupCommand(
      'stash',
      commands: [stashPush, stashPop],
    );

    when(() => stashPush.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashPop.run(any(), any(), any())).thenAnswer((_) => '');

    when(
      () => stashCommand.run(any(), any(), any()),
    ).thenAnswer((_) => Future.value(''));

    final groupCommand = TestGroupCommand('git', commands: [stashCommand]);

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

    test('runs a relative default subcommand path', () async {
      final git = TestGroupCommand(
        'git',
        commands: [stashCommand],
        defaultSubCommandPath: ['stash', 'pop'],
      );

      await git.run(null, emptyInputs, []);

      verify(() => stashPop.run(any(), any(), any())).called(1);
    });

    test('rejects empty and parent-qualified default paths', () {
      expect(
        () => TestGroupCommand(
          'git',
          commands: [stashCommand],
          defaultSubCommandPath: [],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TestGroupCommand(
          'git',
          commands: [stashCommand],
          defaultSubCommandPath: ['git'],
        ),
        throwsA(isA<ArgumentError>()),
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
      expect(await groupCommand.run(null, emptyInputs, []), isEmpty);
    });

    test('rejects empty segments in default paths', () {
      expect(
        () => TestGroupCommand(
          'git',
          commands: [stashCommand],
          defaultSubCommandPath: ['stash', ''],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Input definitions', () {
    test('accessor numeric regexes describe their accepted shapes', () {
      expect(AccessorIntOption(name: 'port').regex.hasMatch('80'), isTrue);
      expect(AccessorDoubleOption(name: 'ratio').regex.hasMatch('1.5'), isTrue);
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
