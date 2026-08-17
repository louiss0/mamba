import 'package:arg_parser/executor.dart';

Future<void> main(List<String> args) async {
  Executor("mamba", "This is the Manba CLI").execute(args);
}
