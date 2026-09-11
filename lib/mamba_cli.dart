import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';

/// Creates a small Dart package using the current typed command API.
final class CreateProjectCommand extends Command {
  CreateProjectCommand(this._parentDirectory)
    : super(mandatoryPositionals: [packageName]);
  static final packageName = NormalPositional(
    'package-name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );
  final Directory _parentDirectory;
  @override
  String get name => 'create';
  @override
  String get shortDescription =>
      'Create a Dart console application using Mamba.';
  @override
  String run(
    CommandInvocation invocation,
    List<String> args,
    ProcessedStandardInput? input,
  ) {
    final name = invocation.valueOf(packageName);
    final directory = Directory('${_parentDirectory.path}/$name');
    if (directory.existsSync())
      throw MambaException(
        'Cannot create $name: the directory already exists.',
      );
    directory.createSync();
    Directory('${directory.path}/bin').createSync();
    File('${directory.path}/pubspec.yaml').writeAsStringSync(
      'name: $name\nenvironment:\n  sdk: ^3.0.0\ndependencies:\n  mamba: any\n',
    );
    File('${directory.path}/bin/$name.dart').writeAsStringSync(
      "import 'package:mamba/mamba.dart';\nFuture<void> main(List<String> args) => Executor('$name', 'A command-line application.', '1.0.0', []).create().execute(args);\n",
    );
    return 'Created Mamba command-line application in ${directory.path}.';
  }
}

/// Generates a typed command skeleton.
final class ScaffoldCommand extends Command {
  ScaffoldCommand(this._parentDirectory)
    : super(mandatoryPositionals: [commandName], flags: [group]);
  static final commandName = NormalPositional(
    'name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );
  static final group = BooleanFlag(
    'group',
    description: 'Create a group command.',
  );
  final Directory _parentDirectory;
  @override
  String get name => 'command';
  @override
  String get shortDescription => 'Create a Mamba command.';
  @override
  String run(
    CommandInvocation invocation,
    List<String> args,
    ProcessedStandardInput? input,
  ) {
    final name = invocation.valueOf(commandName);
    final file = File('${_parentDirectory.path}/lib/$name.dart');
    if (file.existsSync())
      throw MambaException('Cannot create $name: the file already exists.');
    file.parent.createSync(recursive: true);
    final className = '${name[0].toUpperCase()}${name.substring(1)}Command';
    file.writeAsStringSync(
      "import 'package:mamba/mamba.dart';\n\nfinal class $className extends Command {\n  @override String get name => '$name';\n  @override String get shortDescription => 'Describe $name.';\n  @override String run(CommandInvocation invocation, List<String> args, ProcessedStandardInput? input) => '';\n}\n",
    );
    return 'Created command in ${file.path}.';
  }
}
