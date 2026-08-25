import 'package:mamba/command.dart';

class TestGroupCommand extends GroupCommand {
  TestGroupCommand(
    this.name,
    super.commands,
    this.shortDescription, {
    super.aliases,
    super.inheritedFlags,
    super.inheritedOptions,
    super.flags,
    super.options,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
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
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
  });

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs input,
    List<String> trailingArguments,
  ) => '';

  @override
  final String name;

  @override
  final String shortDescription;
}
