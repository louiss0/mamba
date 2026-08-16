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
    super.accessors,
    super.commands,
  });

  @override
  void run(Inputs input, List<String> variadic) {}
}
