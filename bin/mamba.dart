import 'dart:io';

import 'package:mamba/executor.dart';
import 'package:mamba/mamba_cli.dart';

Future<void> main(List<String> arguments) => Executor(
  'mamba',
  'Scaffold Mamba command-line applications.',
  [CreateProjectCommand(Directory.current)],
).create().execute(arguments);
