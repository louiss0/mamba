import 'package:arg_parser/executor.dart';

void main(List<String> args) {
  final executor = Executor('mamba', "This is ");

  executor.execute(args);
}
