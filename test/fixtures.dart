import 'package:arg_parser/registry.dart';

class TestCommand extends Command {
  TestCommand(
    super.name,
    super.shortDescription, {
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
  void run(
    Map<String, String>? positionals,
    Inputs input,
    List<String> variadic,
  ) {}
}
