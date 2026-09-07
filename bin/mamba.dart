import 'dart:io';

import 'package:mamba/executor.dart';
import 'package:mamba/mamba_cli.dart';

const _mambaVersion = '0.4.0';

Future<void> main(List<String> arguments) => Executor(
  'mamba',
  'Scaffold Mamba command-line applications.',
  _mambaVersion,
  [CreateProjectCommand(Directory.current), ScaffoldCommand(Directory.current)],
).create().execute(arguments);
