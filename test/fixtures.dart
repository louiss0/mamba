import 'package:arg_parser/registry.dart';

class TestCommand extends Command {
  TestCommand(
    this.name,
    this.shortDescription, {
    super.longDescription,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.accessors,
    super.commands,
  });

  @override
  String run(
    Map<String, String>? positionals,
    Inputs input,
    List<String> variadic,
  ) => '';

  @override
  final String name;

  @override
  final String shortDescription;
}
