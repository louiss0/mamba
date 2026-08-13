import 'package:arg_parser/errors.dart';
import 'package:arg_parser/executor.dart';
import 'package:arg_parser/help_formatter.dart';
import 'package:chalkdart/chalk.dart';

void main(List<String> args) {
  VariadicString("foo");

  try {
    Executor("mamba", "This is the Manba CLI").execute(args);
  } on MambaException catch (e) {
    print(chalk.red(e.message));
  }
}
