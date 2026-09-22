import 'dart:io';

import 'package:interact/interact.dart';
import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';

/// Scaffolds a project in a parent directory.
abstract interface class ProjectScaffolder {
  void scaffold(String packageName);
}

/// Runs a required project-setup command in a project directory.
abstract interface class ProjectProcessRunner {
  void run(String executable, List<String> arguments, String workingDirectory);
}

/// Asks whether a new project should be initialized as a Git repository.
abstract interface class GitPrompt {
  bool confirmsInitialization();
}

final class DirectoryProjectScaffolder implements ProjectScaffolder {
  new(
    this._parentDirectory, {
    ProjectProcessRunner? processRunner,
    GitPrompt? gitPrompt,
  }) : _processRunner = processRunner ?? SystemProjectProcessRunner(),
       _gitPrompt = gitPrompt ?? InteractGitPrompt();

  final Directory _parentDirectory;
  final ProjectProcessRunner _processRunner;
  final GitPrompt _gitPrompt;

  @override
  void scaffold(String packageName) {
    final projectDirectory = Directory(
      '${_parentDirectory.path}${Platform.pathSeparator}$packageName',
    );

    if (projectDirectory.existsSync()) {
      throw MambaException(
        'Cannot create $packageName: the directory already exists.',
      );
    }

    projectDirectory.createSync();
    _createProjectFiles(projectDirectory, packageName);
    _installDependencies(projectDirectory);
    _installMambaSkills(projectDirectory);

    if (_gitPrompt.confirmsInitialization()) {
      _initializeGitRepository(projectDirectory);
    }
  }

  void _createProjectFiles(Directory projectDirectory, String packageName) {
    Directory('${projectDirectory.path}${Platform.pathSeparator}bin')
        .createSync();

    File(
      '${projectDirectory.path}${Platform.pathSeparator}pubspec.yaml',
    ).writeAsStringSync(
      'name: $packageName\nenvironment:\n  sdk: ^3.13.2\ndependencies:\n  mamba: any\n',
    );

    File(
      '${projectDirectory.path}${Platform.pathSeparator}bin${Platform.pathSeparator}$packageName.dart',
    ).writeAsStringSync(
      "import 'package:mamba/mamba.dart';\nFuture<void> main(List<String> args) => Executor('$packageName', 'A command-line application.', '1.0.0', []).create().execute(args);\n",
    );
  }

  void _installDependencies(Directory projectDirectory) {
    _processRunner.run('dart', ['pub', 'get'], projectDirectory.path);
  }

  void _installMambaSkills(Directory projectDirectory) {
    _processRunner.run('dart', [
      'run',
      'skills@',
      'get',
      '--all',
      '-p',
      'mamba',
      '--agent',
      'generic',
    ], projectDirectory.path);
  }

  void _initializeGitRepository(Directory projectDirectory) {
    _processRunner.run('git', ['init'], projectDirectory.path);
  }
}

final class SystemProjectProcessRunner implements ProjectProcessRunner {
  @override
  void run(String executable, List<String> arguments, String workingDirectory) {
    final result = Process.runSync(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    stdout.write(result.stdout);
    stderr.write(result.stderr);

    if (result.exitCode != 0) {
      throw MambaException('Failed to run $executable ${arguments.join(' ')}.');
    }
  }
}

final class InteractGitPrompt implements GitPrompt {
  @override
  bool confirmsInitialization() => Confirm(
    prompt: 'Initialize a Git repository?',
    defaultValue: false,
    waitForNewLine: true,
  ).interact();
}

/// Creates a small Dart package using the current typed command API.
final class CreateProjectCommand extends Command {
  new(Directory parentDirectory, {ProjectScaffolder? projectScaffolder})
    : _parentDirectory = parentDirectory,
      _projectScaffolder =
          projectScaffolder ?? DirectoryProjectScaffolder(parentDirectory),
      super(mandatoryPositionals: [packageName]);

  static final packageName = NormalPositional(
    'package-name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );

  final Directory _parentDirectory;
  final ProjectScaffolder _projectScaffolder;

  @override
  String get name => 'create';

  @override
  String get shortDescription =>
      'Create a Dart console application using Mamba.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final name = inputs.valueOf(packageName);

    _projectScaffolder.scaffold(name);

    return 'Created Mamba command-line application in '
        '${_parentDirectory.path}${Platform.pathSeparator}$name.';
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
