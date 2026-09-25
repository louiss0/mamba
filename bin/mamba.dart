import 'dart:io';

import 'package:mamba/executor.dart';
import 'package:mamba/mamba_cli.dart';

const _mambaVersion = '0.12.0';

Future<void> main(List<String> arguments) => Executor(
  'mamba',
  'Scaffold Mamba command-line applications.',
  _mambaVersion,
  [
    CreateProjectCommand(Directory.current),
    ScaffoldBinaryCommand(Directory.current),
    ScaffoldCommand(Directory.current),
    ScaffoldTestCommand(Directory.current),
  ],
).create().execute(arguments);
