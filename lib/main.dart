import 'package:mamba/executor.dart';

var executor = ExecutorFactory("mamba", "This is the Manba CLI ").create();

Future<void> main(List<String> args) async {
  executor.execute(args);
}
