import 'package:arg_parser/command.dart';

class TestGroupCommand extends GroupCommand {
  TestGroupCommand(
    this.name,
    this.shortDescription, {
    super.inheritedFlags,
    super.inheritedOptions,
    super.flags,
    super.options,
    super.commands,
  });

  @override
  final String name;

  @override
  final String shortDescription;
}

class TestCommand extends Command {
  TestCommand(
    this.name,
    this.shortDescription, {
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
  });

  @override
  String run(
    Map<String, String>? positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) => '';

  @override
  final String name;

  @override
  final String shortDescription;
}
