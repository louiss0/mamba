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

    File('${projectDirectory.path}${Platform.pathSeparator}pubspec.yaml')
        .writeAsStringSync(
          'name: $packageName\n'
          'environment:\n'
          '  sdk: ^3.13.2\n'
          'dependencies:\n'
          '  mamba: any\n'
          'dev_dependencies:\n'
          '  test: any\n',
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
    _installMambaSkillsFor(projectDirectory, 'generic');
    _installMambaSkillsFor(projectDirectory, 'claude');
  }

  void _installMambaSkillsFor(Directory projectDirectory, String agent) {
    _processRunner.run('dart', [
      'run',
      'skills@',
      'get',
      '--all',
      '-p',
      'mamba',
      '--agent',
      agent,
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

/// Generates an executable backed by a process-facing Mamba executor.
final class ScaffoldBinaryCommand extends Command {
  new(this._parentDirectory) : super(mandatoryPositionals: [binaryName]);

  static final binaryName = NormalPositional(
    'name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );

  final Directory _parentDirectory;

  @override
  String get name => 'binary';

  @override
  String get shortDescription => 'Create a Mamba executable.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final name = inputs.valueOf(binaryName);
    final file = File(
      '${_parentDirectory.path}${Platform.pathSeparator}bin'
      '${Platform.pathSeparator}$name.dart',
    );

    if (file.existsSync()) {
      throw MambaException('Cannot create $name: the file already exists.');
    }

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      "import 'package:mamba/mamba.dart';\n\n"
      'Future<void> main(List<String> args) => '
      "Executor('$name', 'A command-line application.', '1.0.0', [])\n"
      '    .create()\n'
      '    .execute(args);\n',
    );

    return 'Created executable in ${file.path}.';
  }
}

/// Generates a test suite for a scaffolded command.
final class ScaffoldTestCommand extends Command {
  new(this._parentDirectory)
    : super(
        mandatoryPositionals: [commandName],
        discretionaryPositionals: [sourcePath],
        flags: [append],
      );

  static final commandName = NormalPositional(
    'name',
    regExp: RegExp(r'[a-z][a-z0-9_]*'),
  );

  static final sourcePath = NormalPositional.optional(
    'file',
    regExp: RegExp(r'.+'),
  );

  static final append = BooleanFlag(
    'append',
    description: 'Add a suite for a command in an existing source file.',
  );

  final Directory _parentDirectory;

  @override
  String get name => 'test';

  @override
  String get shortDescription => 'Create a test suite for a Mamba command.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final name = inputs.valueOf(commandName);
    final targetPath = inputs.valueOf(sourcePath);
    final shouldAppend = inputs.valueOf(append);

    if (targetPath != null && !shouldAppend) {
      throw MambaException('The file argument requires --append.');
    }
    if (targetPath == null && shouldAppend) {
      throw MambaException('--append requires a file argument.');
    }

    final sourceFile = targetPath == null
        ? File(
            '${_parentDirectory.path}${Platform.pathSeparator}lib'
            '${Platform.pathSeparator}$name.dart',
          )
        : File(targetPath);

    final testFile = _createTestSuiteFile(
      name,
      sourceFile,
      appendToSuite: shouldAppend,
    );
    return shouldAppend
        ? 'Added test suite to ${testFile.path}.'
        : 'Created test suite in ${testFile.path}.';
  }

  File _createTestSuiteFile(
    String name,
    File sourceFile, {
    required bool appendToSuite,
  }) {
    if (!sourceFile.existsSync()) {
      throw MambaException(
        'Cannot create a test for $name: ${sourceFile.path} does not exist.',
      );
    }
    final pubspec = File(
      '${_parentDirectory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    final packageMatch = RegExp(
      r'^name:\s*([a-z][a-z0-9_]*)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.existsSync() ? pubspec.readAsStringSync() : '');
    if (packageMatch == null) {
      throw MambaException(
        'Cannot create a test for $name: pubspec.yaml has no valid package name.',
      );
    }

    final packageName = packageMatch.group(1)!;
    final libraryRoot = _parentDirectory.absolute.path.replaceAll('\\', '/');
    final absoluteSourcePath = sourceFile.absolute.path.replaceAll('\\', '/');
    final sourcePrefix = '$libraryRoot/lib/';
    final comparableSource = Platform.isWindows
        ? absoluteSourcePath.toLowerCase()
        : absoluteSourcePath;
    final comparablePrefix = Platform.isWindows
        ? sourcePrefix.toLowerCase()
        : sourcePrefix;
    if (!comparableSource.startsWith(comparablePrefix) ||
        !absoluteSourcePath.endsWith('.dart')) {
      throw MambaException(
        'Cannot create a test for $name: the command file must be under lib.',
      );
    }

    final libraryPath = absoluteSourcePath
        .substring(sourcePrefix.length)
        .replaceAll('\\', '/');
    final testPath = libraryPath.substring(0, libraryPath.length - 5);
    final testFile = File(
      '${_parentDirectory.path}${Platform.pathSeparator}test'
      '${Platform.pathSeparator}${testPath}_test.dart',
    );
    if (!appendToSuite && testFile.existsSync()) {
      throw MambaException(
        'Cannot create $name: the test file already exists.',
      );
    }

    final className = '${name[0].toUpperCase()}${name.substring(1)}Command';
    final suite =
        "  group('$className', () {\n"
        "    test('shows help', () async {\n"
        "      final result = await Executor('test', 'Test.', '1.0.0', [\n"
        '        $className(),\n'
        "      ]).fake().execute(['$name', '--help']);\n\n"
        '      expect(result, isA<MambaSuccessResult>());\n'
        '    });\n'
        '  });\n';

    testFile.parent.createSync(recursive: true);
    if (appendToSuite && testFile.existsSync()) {
      final existing = testFile.readAsStringSync().trimRight();
      final mainClosingBrace = existing.lastIndexOf('}');
      if (mainClosingBrace == -1) {
        throw MambaException(
          'Cannot append $name: ${testFile.path} is not a test suite.',
        );
      }
      testFile.writeAsStringSync(
        '${existing.substring(0, mainClosingBrace)}\n$suite}\n',
      );
    } else {
      testFile.writeAsStringSync(
        "import 'package:mamba/mamba.dart';\n"
        "import 'package:$packageName/$libraryPath';\n"
        "import 'package:test/test.dart';\n\n"
        'void main() {\n'
        '$suite}\n',
      );
    }

    return testFile;
  }
}

/// Generates a typed command skeleton.
final class ScaffoldCommand extends Command {
  new(this._parentDirectory)
    : super(
        mandatoryPositionals: [commandName],
        discretionaryPositionals: [fileName],
        flags: [group, append, test],
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

  static final test = BooleanFlag(
    'test',
    description: 'Create a test suite for the command.',
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
    final shouldCreateTest = inputs.valueOf(test);

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

    final previousSource = shouldAppend ? file.readAsStringSync() : null;
    try {
      if (shouldAppend) {
        file.writeAsStringSync('\n$implementation', mode: FileMode.append);
      } else {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          "import 'package:mamba/mamba.dart';\n\n$implementation",
        );
      }

      if (shouldCreateTest) {
        ScaffoldTestCommand(_parentDirectory)
            ._createTestSuiteFile(name, file, appendToSuite: shouldAppend);
      }
    } on Object {
      if (previousSource == null) {
        if (file.existsSync()) file.deleteSync();
      } else {
        file.writeAsStringSync(previousSource);
      }
      rethrow;
    }

    return shouldAppend
        ? 'Appended command to ${file.path}.'
        : 'Created command in ${file.path}.';
  }
}
