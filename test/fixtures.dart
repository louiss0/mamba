import 'package:arg_parser/command.dart';

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
    super.commands,
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
