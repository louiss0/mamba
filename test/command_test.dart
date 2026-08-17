import 'dart:async';

import 'package:arg_parser/command.dart';
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

  @override
  final List<Command>? commands;

  TestCommand(this.name, {this.commands});
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
    final stashCommand = TestCommand('stash', commands: [stashPush, stashPop]);

    when(() => stashPush.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashPop.run(any(), any(), any())).thenAnswer((_) => '');

    when(() => stashCommand.run(any(), any(), any())).thenAnswer((_) => '');

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
  });
}
