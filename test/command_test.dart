import 'dart:async';

import 'package:arg_parser/command.dart';
import 'package:arg_parser/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  @override
  final String name;

  @override
  String get shortDescription => "This is a test command";

  TestGroupCommand(this.name, {required super.commands})
    : super(
        longDescription: '',
        mandatoryPositionals: null,
        discretionaryPositionals: null,
        variadic: null,
        flags: null,
        options: null,
        pairedOptions: null,
        accessors: null,
      );

  @override
  FutureOr<String> run(
    Map<String, String>? positionals,
    ParsedNamedInputs input,
    List<String> variadic,
  ) => '';

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
  });
}
