import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

void main() {
  test('project command scaffolds the requested application', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final projectScaffolder = FakeProjectScaffolder();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(directory, projectScaffolder: projectScaffolder),
    ]).fake().execute(['create', 'demo']);

    expect(result.exitCode, 0);
    expect(projectScaffolder.packageNames, ['demo']);
    expect(
      (result as MambaSuccessResult).output,
      'Created Mamba command-line application in '
      '${directory.path}${Platform.pathSeparator}demo.',
    );
  });

  test('project scaffolder installs dependencies, Mamba skills, and Git', () {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = DirectoryProjectScaffolder(
      directory,
      processRunner: processRunner,
      gitPrompt: FakeGitPrompt(shouldInitialize: true),
    );

    projectScaffolder.scaffold('demo');

    final projectDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}demo',
    );
    expect(
      File('${projectDirectory.path}/pubspec.yaml').readAsStringSync(),
      allOf(
        contains('name: demo'),
        contains('sdk: ^3.13.2'),
        contains('dev_dependencies:\n  test: any'),
      ),
    );
    expect(
      File('${projectDirectory.path}/bin/demo.dart').readAsStringSync(),
      contains("Executor('demo'"),
    );
    expect(
      processRunner.invocations
          .map(
            (invocation) =>
                (invocation.$1, invocation.$2.join(' '), invocation.$3),
          )
          .toList(),
      [
        ('dart', 'pub get', projectDirectory.path),
        (
          'dart',
          'run skills@ get --all -p mamba --agent generic',
          projectDirectory.path,
        ),
        (
          'dart',
          'run skills@ get --all -p mamba --agent claude',
          projectDirectory.path,
        ),
        ('git', 'init', projectDirectory.path),
      ],
    );
  });

  test('project scaffolder skips Git when the user declines', () {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = DirectoryProjectScaffolder(
      directory,
      processRunner: processRunner,
      gitPrompt: FakeGitPrompt(shouldInitialize: false),
    );

    projectScaffolder.scaffold('demo');

    final projectDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}demo',
    );
    expect(
      processRunner.invocations
          .map(
            (invocation) =>
                (invocation.$1, invocation.$2.join(' '), invocation.$3),
          )
          .toList(),
      [
        ('dart', 'pub get', projectDirectory.path),
        (
          'dart',
          'run skills@ get --all -p mamba --agent generic',
          projectDirectory.path,
        ),
        (
          'dart',
          'run skills@ get --all -p mamba --agent claude',
          projectDirectory.path,
        ),
      ],
    );
  });

  test('project command rejects an existing directory', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    Directory('${directory.path}/demo').createSync();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(directory),
    ]).fake().execute(['create', 'demo']);

    expect(result.exitCode, 1);
    expect(
      (result as MambaFailureResult).message,
      'Cannot create demo: the directory already exists.',
    );
  });

  test('binary command scaffolds a process-facing executor', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldBinaryCommand(directory),
    ]).fake().execute(['binary', 'demo']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/bin/demo.dart').readAsStringSync(),
      allOf(
        contains("Executor('demo'"),
        contains('.create()'),
        contains('.execute(args)'),
      ),
    );
  });

  test('binary command rejects an existing executable', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/bin/demo.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('existing');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldBinaryCommand(directory),
    ]).fake().execute(['binary', 'demo']);

    expect(result, isA<MambaFailureResult>());
    expect((result as MambaFailureResult).message, contains('already exists'));
    expect(file.readAsStringSync(), 'existing');
  });

  test('test command scaffolds a grouped command suite', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    File('${directory.path}/lib/greet.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final class GreetCommand {}\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory),
    ]).fake().execute(['test', 'greet']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/test/greet_test.dart').readAsStringSync(),
      allOf(
        contains("import 'package:demo/greet.dart';"),
        contains("group('GreetCommand'"),
        contains("test('shows help'"),
        contains('.fake()'),
        contains("execute(['greet', '--help'])"),
      ),
    );
  });

  test('test command rejects an existing suite', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    File('${directory.path}/lib/greet.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final class GreetCommand {}\n');
    final testFile = File('${directory.path}/test/greet_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('existing');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory),
    ]).fake().execute(['test', 'greet']);

    expect(result, isA<MambaFailureResult>());
    expect((result as MambaFailureResult).message, contains('already exists'));
    expect(testFile.readAsStringSync(), 'existing');
  });

  test(
    'test command appends a suite for a command in an existing file',
    () async {
      final directory = Directory.systemTemp.createTempSync('mamba_');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final sourceFile = File('${directory.path}/lib/admin.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'final class AdminCommand {}\nfinal class UserCommand {}\n',
        );
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldTestCommand(directory),
      ]).fake();
      await executor.execute(['test', 'admin']);

      final result = await executor.execute([
        'test',
        'user',
        sourceFile.path,
        '--append',
      ]);

      expect(
        result.exitCode,
        0,
        reason: result is MambaFailureResult ? result.message : null,
      );
      final testSource = File('${directory.path}/test/admin_test.dart')
          .readAsStringSync();
      expect(testSource, contains("group('AdminCommand'"));
      expect(testSource, contains("group('UserCommand'"));
      expect('void main() {'.allMatches(testSource), hasLength(1));
    },
  );

  test('test command validates append arguments', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final sourcePath = '${directory.path}/lib/admin.dart';
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory),
    ]).fake();
    final cases = [
      (
        arguments: ['test', 'user', '--append'],
        message: '--append requires a file argument.',
      ),
      (
        arguments: ['test', 'user', sourcePath],
        message: 'The file argument requires --append.',
      ),
    ];

    for (final testCase in cases) {
      final result = await executor.execute(testCase.arguments);

      expect(result, isA<MambaFailureResult>());
      expect((result as MambaFailureResult).message, testCase.message);
    }
  });

  test('scaffolding command uses typed positional handle', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'demo']);
    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/lib/demo.dart').readAsStringSync(),
      allOf(contains('extends Command'), contains("'Completed demo.'")),
    );
  });

  test('scaffolding command creates its test suite with --test', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'greet', '--test']);

    expect(result.exitCode, 0);
    expect(File('${directory.path}/lib/greet.dart').existsSync(), isTrue);
    expect(
      File('${directory.path}/test/greet_test.dart').readAsStringSync(),
      allOf(
        contains("import 'package:demo/greet.dart';"),
        contains("group('GreetCommand'"),
      ),
    );
  });

  test(
    'scaffolding command leaves no command when its test cannot be created',
    () async {
      final directory = Directory.systemTemp.createTempSync('mamba_');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final testFile = File('${directory.path}/test/greet_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('existing');
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldCommand(directory),
      ]).fake().execute(['command', 'greet', '--test']);

      expect(result, isA<MambaFailureResult>());
      expect(File('${directory.path}/lib/greet.dart').existsSync(), isFalse);
      expect(testFile.readAsStringSync(), 'existing');
    },
  );

  test('scaffolding command creates a group command when requested', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'demo', '--group']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/lib/demo.dart').readAsStringSync(),
      allOf(contains('extends GroupCommand'), contains(': super([]);')),
    );
  });

  test('scaffolding group command creates a compatible test suite', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'admin', '--group', '--test']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/lib/admin.dart').readAsStringSync(),
      contains('extends GroupCommand'),
    );
    expect(
      File('${directory.path}/test/admin_test.dart').readAsStringSync(),
      allOf(
        contains("group('AdminCommand'"),
        contains("execute(['admin', '--help'])"),
      ),
    );
  });

  test('scaffolding command rejects an existing file', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/lib/demo.dart')
      ..createSync(recursive: true);
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'demo']);

    expect(result.exitCode, 1);
    expect(
      (result as MambaFailureResult).message,
      'Cannot create demo: the file already exists.',
    );
    expect(file.existsSync(), isTrue);
  });

  test('scaffolding command appends a command to an existing file', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/lib/admin.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "import 'package:mamba/mamba.dart';\n\n"
        'final class AdminCommand extends GroupCommand {\n'
        '  new() : super([]);\n'
        "  String get name => 'admin';\n"
        "  String get shortDescription => 'Manage users.';\n"
        '}\n',
      );

    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'user', file.path, '--append']);

    expect(result.exitCode, 0);
    expect(
      file.readAsStringSync(),
      allOf(
        contains('class AdminCommand extends GroupCommand'),
        contains('class UserCommand extends Command'),
        contains("'Completed user.'"),
      ),
    );
  });

  test('scaffolding command appends a command and its test suite', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final file = File('${directory.path}/lib/admin.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "import 'package:mamba/mamba.dart';\n\n"
        'final class AdminCommand extends GroupCommand {\n'
        '  new() : super([]);\n'
        "  String get name => 'admin';\n"
        "  String get shortDescription => 'Manage users.';\n"
        '}\n',
      );

    final result =
        await Executor('tool', 'Tool.', '1.0.0', [
          ScaffoldCommand(directory),
        ]).fake().execute([
          'command',
          'user',
          file.path,
          '--append',
          '--group',
          '--test',
        ]);

    expect(result.exitCode, 0);
    expect(
      file.readAsStringSync(),
      contains('class UserCommand extends GroupCommand'),
    );
    expect(
      File('${directory.path}/test/admin_test.dart').readAsStringSync(),
      allOf(
        contains("import 'package:demo/admin.dart';"),
        contains("group('UserCommand'"),
      ),
    );
  });

  test('scaffolding command validates append arguments', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final missingFile = '${directory.path}/lib/admin.dart';
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake();
    final cases = [
      (
        arguments: ['command', 'user', '--append'],
        message: '--append requires a file argument.',
      ),
      (
        arguments: ['command', 'user', missingFile],
        message: 'The file argument requires --append.',
      ),
      (
        arguments: ['command', 'user', missingFile, '--append'],
        message: 'Cannot append user: $missingFile does not exist.',
      ),
    ];

    for (final testCase in cases) {
      final result = await executor.execute(testCase.arguments);

      expect(result, isA<MambaFailureResult>());
      expect((result as MambaFailureResult).message, testCase.message);
    }
  });
}

final class FakeProjectScaffolder implements ProjectScaffolder {
  final packageNames = <String>[];

  @override
  void scaffold(String packageName) {
    packageNames.add(packageName);
  }
}

final class FakeProjectProcessRunner implements ProjectProcessRunner {
  final invocations = <(String, List<String>, String)>[];

  @override
  void run(String executable, List<String> arguments, String workingDirectory) {
    invocations.add((executable, arguments, workingDirectory));
  }
}

final class FakeGitPrompt implements GitPrompt {
  const new({required this.shouldInitialize});

  final bool shouldInitialize;

  @override
  bool confirmsInitialization() => shouldInitialize;
}
