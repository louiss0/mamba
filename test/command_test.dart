import 'dart:async';

import 'package:arg_parser/command.dart' show GroupCommand;
import 'package:arg_parser/registry.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  TestGroupCommand(String name, {required super.commands})
    : super(
        name,
        'This is a command',
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
  FutureOr<String> run(Inputs input, List<String> variadic) {
    return '';
  }

  FutureOr<void> runWithNothingBasedOnCommandPathWithNothing(
    List<String> commandPath,
  ) {
    return runChildCommand(commandPath, (
      accessors: null,
      boolFlags: null,
      countFlags: null,
      doubleOptions: null,
      intOptions: null,
      positionalOptions: null,
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
  group("GroupCommand", () {
    final stashPush = TestCommand("push");
    final stashPop = TestCommand("pop");
    final stashCommand = TestCommand('stash', commands: [stashPush, stashPop]);

    when(
      () => stashPush.run(any(), any()),
    ).thenReturn(Future.value("Push ran"));

    when(() => stashPop.run(any(), any())).thenReturn(Future.value("Pop ran"));

    when(
      () => stashCommand.run(any(), any()),
    ).thenReturn(Future.value("Stash ran"));

    final groupCommand = TestGroupCommand('git', commands: [stashCommand]);

    test("calls the run child command", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing(['stash']);

      verifyNever(() => stashPush.run(any(), any()));
      verifyNever(() => stashPop.run(any(), any()));
      verify(() => stashCommand.run(any(), any())).called(1);
    });

    test("calls the child's child command when path points to it", () {
      groupCommand.runWithNothingBasedOnCommandPathWithNothing([
        'stash',
        'pop',
      ]);

      verifyNever(() => stashPush.run(any(), any()));
      verify(() => stashPop.run(any(), any())).called(1);
      verifyNever(() => stashCommand.run(any(), any()));
    });
  });
}
