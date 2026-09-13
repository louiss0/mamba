import 'package:mamba/command.dart';

class TestGroupCommand extends GroupCommand {
  new(
    this.name,
    super.commands,
    this.shortDescription, {
    super.aliases,
    super.propagatedFlags,
    super.propagatedOptions,
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
  new(
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
    super.selectedOptions,
    super.accessors,
  });

  @override
  String run(ParsedInputs inputs, List<String> args) => '';

  @override
  final String name;

  @override
  final String shortDescription;
}
