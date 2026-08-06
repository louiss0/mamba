import 'dart:io';

import 'package:arg_parser/yargs_task_list.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await YargsTaskListCli().run(arguments);
}
