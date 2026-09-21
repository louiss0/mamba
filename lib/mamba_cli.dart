import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';

/// Creates a small Dart package using the current typed command API.
final class CreateProjectCommand extends Command {
  new(this._parentDirectory) : super(mandatoryPositionals: [packageName]);

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
  String run(ParsedInputs inputs, List<String> args) {
    final name = inputs.valueOf(packageName);

    final directory = Directory('${_parentDirectory.path}/$name');

    if (directory.existsSync())
      throw MambaException(
        'Cannot create $name: the directory already exists.',
      );

    directory.createSync();

    Directory('${directory.path}/bin').createSync();

    File('${directory.path}/pubspec.yaml').writeAsStringSync(
      'name: $name\nenvironment:\n  sdk: ^3.13.2\ndependencies:\n  mamba: any\n',
    );

    File('${directory.path}/bin/$name.dart').writeAsStringSync(
      "import 'package:mamba/mamba.dart';\nFuture<void> main(List<String> args) => Executor('$name', 'A command-line application.', '1.0.0', []).create().execute(args);\n",
    );

    return 'Created Mamba command-line application in ${directory.path}.';
  }
}

/// Generates a typed command skeleton.
final class ScaffoldCommand extends Command {
  new(this._parentDirectory)
    : super(
        mandatoryPositionals: [commandName],
        discretionaryPositionals: [fileName],
        flags: [group, append],
      );

  static final commandName = NormalPositional(
    'name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );

  static final fileName = NormalPositional.optional(
    'file',
    regExp: RegExp(r'.+'),
  );

  static final group = BooleanFlag(
    'group',
    description: 'Create a group command.',
  );

  static final append = BooleanFlag(
    'append',
    description: 'Append the command to an existing file.',
  );

  final Directory _parentDirectory;

  @override
  String get name => 'command';

  @override
  String get shortDescription => 'Create a Mamba command.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final name = inputs.valueOf(commandName);
    final targetPath = inputs.valueOf(fileName);
    final isGroup = inputs.valueOf(group);
    final shouldAppend = inputs.valueOf(append);

    if (targetPath != null && !shouldAppend) {
      throw MambaException('The file argument requires --append.');
    }
    if (targetPath == null && shouldAppend) {
      throw MambaException('--append requires a file argument.');
    }

    final file = targetPath == null
        ? File('${_parentDirectory.path}/lib/$name.dart')
        : File(targetPath);

    if (shouldAppend && !file.existsSync()) {
      throw MambaException('Cannot append $name: ${file.path} does not exist.');
    }
    if (!shouldAppend && file.existsSync()) {
      throw MambaException('Cannot create $name: the file already exists.');
    }

    final className = '${name[0].toUpperCase()}${name.substring(1)}Command';

    final implementation = isGroup
        ? "final class $className extends GroupCommand {\n  new() : super([]);\n  @override String get name => '$name';\n  @override String get shortDescription => 'Describe $name.';\n}\n"
        : "final class $className extends Command {\n  @override String get name => '$name';\n  @override String get shortDescription => 'Describe $name.';\n  @override String run(ParsedInputs inputs, List<String> args) => 'Completed $name.';\n}\n";

    if (shouldAppend) {
      file.writeAsStringSync('\n$implementation', mode: FileMode.append);
    } else {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        "import 'package:mamba/mamba.dart';\n\n$implementation",
      );
    }

    return shouldAppend
        ? 'Appended command to ${file.path}.'
        : 'Created command in ${file.path}.';
  }
}
