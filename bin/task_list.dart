import 'dart:io';

import 'package:arg_parser/task_list.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await TaskListCli().run(arguments);
}
