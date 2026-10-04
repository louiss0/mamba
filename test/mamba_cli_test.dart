import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  test('project command scaffolds the requested application', () async {
    final directory = tempDirectory();
    final projectScaffolder = FakeProjectScaffolder();
    final installPrompt = FakeInstallPrompt(shouldInstall: true);
    final gitPrompt = FakeGitPrompt(shouldInitialize: false);
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        projectScaffolder: projectScaffolder,
        installPrompt: installPrompt,
        gitPrompt: gitPrompt,
      ),
    ]).fake().execute(['create', 'demo', 'A demonstration CLI.']);

    expect(result.exitCode, 0);
    expect(installPrompt.questions, 1);
    expect(gitPrompt.questions, 1);
    expect(projectScaffolder.projects, [
      (
        packageName: 'demo',
        shortDescription: 'A demonstration CLI.',
        installDependencies: true,
        initializeGitRepository: false,
      ),
    ]);
    expect(
      (result as MambaSuccessResult).output,
      'Created Mamba command-line application in '
      '${directory.path}${Platform.pathSeparator}demo.',
    );
  });

  test('project scaffolder installs dependencies, Mamba skills, and Git', () {
    final directory = tempDirectory();
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = realScaffolding(
      directory,
      processRunner: processRunner,
    );

    projectScaffolder.scaffold(
      'demo',
      "Manage Bob's \$tasks.",
      installDependencies: true,
      initializeGitRepository: true,
    );

    final projectDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}demo',
    );
    expect(
      File('${projectDirectory.path}/pubspec.yaml').readAsStringSync(),
      allOf(
        contains('name: demo'),
        contains(r"description: 'Manage Bob''s $tasks.'"),
        contains('sdk: ^3.13.2'),
        contains('dev_dependencies:\n  lints: any\n  test: any'),
      ),
    );
    expect(
      File('${projectDirectory.path}/bin/demo.dart').readAsStringSync(),
      allOf(
        contains("import 'package:mamba/mamba.dart';\n\n"),
        contains("  'demo',\n"),
        contains(r"  'Manage Bob\'s \$tasks.',"),
        contains("  '0.0.0',\n"),
        contains(').create().execute(args);'),
      ),
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

  test('project scaffolder points Claude Code at the agent instructions', () {
    final directory = tempDirectory();
    final projectScaffolder = realScaffolding(directory);

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: true,
      initializeGitRepository: false,
    );

    final projectDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}demo',
    );
    expect(
      File('${projectDirectory.path}/AGENTS.md').readAsStringSync(),
      allOf(
        contains('# AGENTS.md'),
        contains('## The mamba CLI'),
        contains('## What not to do'),
        contains(r'mamba command <name> --append <file>'),
        contains('throw `MambaException`'),
      ),
    );
    expect(
      File('${projectDirectory.path}/CLAUDE.md').readAsStringSync(),
      '@AGENTS.md\n',
    );
    expect(
      sourceFormatter.formatted,
      contains(allOf(endsWith('demo.dart'), isNot(contains('.md')))),
      reason: 'the generated executable is formatted, the documents are not',
    );
  });

  test('project scaffolder writes a Dart gitignore', () {
    final directory = tempDirectory();
    final projectScaffolder = realScaffolding(directory);

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: true,
      initializeGitRepository: false,
    );

    final gitignore = File(
      '${directory.path}${Platform.pathSeparator}demo${Platform.pathSeparator}.gitignore',
    ).readAsStringSync();
    expect(
      gitignore,
      allOf(
        contains('https://www.toptal.com/developers/gitignore/api/dart'),
        contains('.dart_tool/'),
        contains('doc/api/'),
        contains('.env*'),
        contains('*.dart.js'),
        contains('.flutter-plugins'),
        isNot(matches(RegExp(r'^pubspec\.lock$', multiLine: true))),
      ),
      reason:
          'a scaffolded CLI commits its lockfile, so the template entry '
          'is dropped',
    );
  });

  test('project scaffolder claims a new child directory', () {
    final directory = tempDirectory();
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = realScaffolding(
      directory,
      processRunner: processRunner,
    );

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: true,
      initializeGitRepository: false,
    );

    final projectRoot = '${directory.path}/demo';
    expect(
      File('$projectRoot/pubspec.yaml').readAsStringSync(),
      contains('name: demo'),
    );
    expect(File('$projectRoot/bin/demo.dart').existsSync(), isTrue);
    expect(File('$projectRoot/AGENTS.md').existsSync(), isTrue);
  });

  test('project command rejects a dot as a package name', () async {
    final directory = tempDirectory();
    final workspace = Directory('${directory.path}/workspace')..createSync();
    final projectScaffolder = FakeProjectScaffolder();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        workspace,
        projectScaffolder: projectScaffolder,
        installPrompt: FakeInstallPrompt(shouldInstall: true),
        gitPrompt: FakeGitPrompt(shouldInitialize: true),
      ),
    ]).fake().execute(['create', '.', 'A demonstration CLI.']);

    expect(result, isA<MambaFailureResult>());
    expect(projectScaffolder.projects, isEmpty);
    expect(workspace.listSync(), isEmpty);
  });

  test('project command rejects a package name that is not a name', () async {
    final directory = tempDirectory();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        projectScaffolder: FakeProjectScaffolder(),
        installPrompt: FakeInstallPrompt(shouldInstall: true),
        gitPrompt: FakeGitPrompt(shouldInitialize: true),
      ),
    ]).fake().execute(['create', 'My Project', 'A demonstration CLI.']);

    expect(result, isA<MambaFailureResult>());
  });

  test('project scaffolder installs agent skills without dependencies', () {
    final directory = tempDirectory();
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = realScaffolding(
      directory,
      processRunner: processRunner,
    );

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: false,
      initializeGitRepository: false,
    );

    expect(
      processRunner.invocations
          .map((invocation) => invocation.$2.join(' '))
          .toList(),
      [
        'run skills@ get --all -p mamba --agent generic',
        'run skills@ get --all -p mamba --agent claude',
      ],
    );
  });

  test('project scaffolder skips Git when the user declines', () {
    final directory = tempDirectory();
    final processRunner = FakeProjectProcessRunner();
    final projectScaffolder = realScaffolding(
      directory,
      processRunner: processRunner,
    );

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: true,
      initializeGitRepository: false,
    );

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

  test('project scaffolder quotes a YAML-unsafe package description', () {
    final directory = tempDirectory();
    final projectScaffolder = realScaffolding(directory);

    projectScaffolder.scaffold(
      'demo',
      "Manage: Bob's #1 tasks",
      installDependencies: true,
      initializeGitRepository: false,
    );

    final projectDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}demo',
    );
    expect(
      File('${projectDirectory.path}/pubspec.yaml').readAsStringSync(),
      contains(r"description: 'Manage: Bob''s #1 tasks'"),
    );
    expect(
      File('${projectDirectory.path}/bin/demo.dart').readAsStringSync(),
      contains(r"'Manage: Bob\'s #1 tasks'"),
    );
  });

  test('project command answers both setup steps from flags alone', () async {
    final directory = tempDirectory();
    final projectScaffolder = FakeProjectScaffolder();
    final installPrompt = FakeInstallPrompt(shouldInstall: false);
    final gitPrompt = FakeGitPrompt(shouldInitialize: false);
    final result =
        await Executor('tool', 'Tool.', '1.0.0', [
          CreateProjectCommand(
            directory,
            projectScaffolder: projectScaffolder,
            installPrompt: installPrompt,
            gitPrompt: gitPrompt,
          ),
        ]).fake().execute([
          'create',
          'demo',
          'A demonstration CLI.',
          '--install',
          '--git',
        ]);

    expect(result.exitCode, 0);
    expect(installPrompt.questions, 0, reason: 'the flag answered the install');
    expect(gitPrompt.questions, 0, reason: 'the flag answered Git');
    expect(projectScaffolder.projects.single.installDependencies, isTrue);
    expect(projectScaffolder.projects.single.initializeGitRepository, isTrue);
    expect(
      (result as MambaSuccessResult).output,
      isNot(contains('dart pub get')),
    );
  });

  test('project command reports what finishes a declined install', () async {
    final directory = tempDirectory();
    final projectScaffolder = FakeProjectScaffolder();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        projectScaffolder: projectScaffolder,
        installPrompt: FakeInstallPrompt(shouldInstall: false),
        gitPrompt: FakeGitPrompt(shouldInitialize: true),
      ),
    ]).fake().execute(['create', 'demo', 'A demonstration CLI.']);

    final projectPath = '${directory.path}${Platform.pathSeparator}demo';
    expect((result as MambaSuccessResult).output, '''
Created Mamba command-line application in $projectPath.
Run `dart pub get` in $projectPath to install its dependencies.''');
  });

  test('project command rejects an existing directory', () async {
    final directory = tempDirectory();
    Directory('${directory.path}/demo').createSync();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        installPrompt: FakeInstallPrompt(shouldInstall: true),
        gitPrompt: FakeGitPrompt(shouldInitialize: false),
      ),
    ]).fake().execute(['create', 'demo', 'A demonstration CLI.']);

    expect(result.exitCode, 1);
    expect(
      (result as MambaFailureResult).message,
      'Cannot create demo: the directory already exists.',
    );
  });

  test('project command asks for a description when none is passed', () async {
    final directory = tempDirectory();
    final projectScaffolder = FakeProjectScaffolder();
    final descriptionPrompt = FakeDescriptionPrompt('A prompted description.');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        projectScaffolder: projectScaffolder,
        descriptionPrompt: descriptionPrompt,
        installPrompt: FakeInstallPrompt(shouldInstall: true),
        gitPrompt: FakeGitPrompt(shouldInitialize: false),
      ),
    ]).fake().execute(['create', 'demo']);

    expect(result.exitCode, 0);
    expect(descriptionPrompt.questions, 1);
    expect(
      projectScaffolder.projects.single.shortDescription,
      'A prompted description.',
    );
  });

  test('project command keeps a description it was given', () async {
    final directory = tempDirectory();
    final projectScaffolder = FakeProjectScaffolder();
    final descriptionPrompt = FakeDescriptionPrompt('A prompted description.');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        directory,
        projectScaffolder: projectScaffolder,
        descriptionPrompt: descriptionPrompt,
        installPrompt: FakeInstallPrompt(shouldInstall: true),
        gitPrompt: FakeGitPrompt(shouldInitialize: false),
      ),
    ]).fake().execute(['create', 'demo', 'A demonstration CLI.']);

    expect(result.exitCode, 0);
    expect(descriptionPrompt.questions, 0);
    expect(
      projectScaffolder.projects.single.shortDescription,
      'A demonstration CLI.',
    );
  });

  test('binary command scaffolds a process-facing executor', () async {
    final directory = tempDirectory();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldBinaryCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['binary', 'demo']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/bin/demo.dart').readAsStringSync(),
      allOf(
        contains("  'demo',\n"),
        contains("  '0.0.0',\n"),
        contains(').create().execute(args);'),
      ),
    );
  });

  test('binary command rejects an existing executable', () async {
    final directory = tempDirectory();
    final file = File('${directory.path}/bin/demo.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('existing');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldBinaryCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['binary', 'demo']);

    expect(result, isA<MambaFailureResult>());
    expect((result as MambaFailureResult).message, contains('already exists'));
    expect(file.readAsStringSync(), 'existing');
  });

  test('test command scaffolds a grouped command suite', () async {
    final directory = tempDirectory();
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    File('${directory.path}/lib/greet.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final class GreetCommand {}\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    File('${directory.path}/lib/greet.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('final class GreetCommand {}\n');
    final testFile = File('${directory.path}/test/greet_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('existing');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['test', 'greet']);

    expect(result, isA<MambaFailureResult>());
    expect((result as MambaFailureResult).message, contains('already exists'));
    expect(testFile.readAsStringSync(), 'existing');
  });

  test(
    'test command appends a suite for a command in an existing file',
    () async {
      final directory = tempDirectory();
      File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final sourceFile = File('${directory.path}/lib/admin.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'final class AdminCommand {}\nfinal class UserCommand {}\n',
        );
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldTestCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
    final sourcePath = '${directory.path}/lib/admin.dart';
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldTestCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['command', 'demo']);
    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/lib/demo.dart').readAsStringSync(),
      allOf(contains('extends Command'), contains("'Completed demo.'")),
    );
  });

  test('scaffolding command creates its test suite with --test', () async {
    final directory = tempDirectory();
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['command', 'greet', '--test']);

    expect(result.exitCode, 0);
    expect(File('${directory.path}/lib/greet.dart').existsSync(), isTrue);
    expect(
      File('${directory.path}/test/greet_test.dart').readAsStringSync(),
      allOf(
        contains("import 'package:demo/greet.dart';"),
        contains("group('GreetCommand'"),
        contains('A floor, not coverage'),
        contains("test('rejects an input it does not declare'"),
        contains('isA<MambaFailureResult>()'),
      ),
    );
  });

  test(
    'scaffolding command leaves no command when its test cannot be created',
    () async {
      final directory = tempDirectory();
      File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
      final testFile = File('${directory.path}/test/greet_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('existing');
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['command', 'greet', '--test']);

      expect(result, isA<MambaFailureResult>());
      expect(File('${directory.path}/lib/greet.dart').existsSync(), isFalse);
      expect(testFile.readAsStringSync(), 'existing');
    },
  );

  test('scaffolding command creates a group command when requested', () async {
    final directory = tempDirectory();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['command', 'demo', '--group']);

    expect(result.exitCode, 0);
    expect(
      File('${directory.path}/lib/demo.dart').readAsStringSync(),
      allOf(contains('extends GroupCommand'), contains(': super([]);')),
    );
  });

  test(
    'scaffolding component creates a prompt that awaits terminice',
    () async {
      final directory = tempDirectory();
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['component', 'prompt', 'ask']);

      expect(result.exitCode, 0);
      expect(
        File('${directory.path}/lib/components/ask.dart').readAsStringSync(),
        allOf(
          contains('final class AskComponent'),
          contains('Future<String?> render() async'),
          contains('terminice.text(label)'),
        ),
      );
    },
  );

  test(
    'scaffolding component reads its selector choices from a field',
    () async {
      final directory = tempDirectory();
      await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['component', 'selector', 'choose']);

      expect(
        File('${directory.path}/lib/components/choose.dart').readAsStringSync(),
        allOf(
          contains('required this.options'),
          contains('Future<String?> render() async'),
          contains('terminice.searchSelector('),
        ),
      );
    },
  );

  test(
    'scaffolding component browses the filesystem through a render',
    () async {
      final directory = tempDirectory();
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['component', 'picker', 'target']);

      expect(result.exitCode, 0);
      expect(
        File('${directory.path}/lib/components/target.dart').readAsStringSync(),
        allOf(
          contains('Future<String?> render() async'),
          contains('terminice.pathPicker(label)'),
        ),
      );
    },
  );

  test(
    'scaffolding component awaits the work an indicator reports on',
    () async {
      final directory = tempDirectory();
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['component', 'indicator', 'report']);

      expect(result.exitCode, 0);
      expect(
        File('${directory.path}/lib/components/report.dart').readAsStringSync(),
        allOf(
          contains('Future<T> render<T>(Future<T> Function() work)'),
          contains('terminice.loadingSpinner(label'),
          contains('spinner().whileRunning(work)'),
        ),
      );
    },
  );

  test('scaffolding component offers every kind as a subcommand', () async {
    final directory = tempDirectory();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['component', '--help']);

    expect(
      stripAnsi((result as MambaSuccessResult).output!),
      allOf(
        contains('prompt'),
        contains('selector'),
        contains('picker'),
        contains('indicator'),
      ),
    );
  });

  test(
    'scaffolding component leaves no command when the file exists',
    () async {
      final directory = tempDirectory();
      final componentDirectory = Directory('${directory.path}/lib/components')
        ..createSync(recursive: true);
      File('${componentDirectory.path}/ask.dart').writeAsStringSync('mine');
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory, sourceFormatter: sourceFormatter),
      ]).fake().execute(['component', 'prompt', 'ask']);

      expect(result, isA<MambaFailureResult>());
      expect(
        File('${componentDirectory.path}/ask.dart').readAsStringSync(),
        'mine',
      );
    },
  );

  test('scaffolding group command creates a compatible test suite', () async {
    final directory = tempDirectory();
    File('${directory.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
    final file = File('${directory.path}/lib/demo.dart')
      ..createSync(recursive: true);
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['command', 'demo']);

    expect(result.exitCode, 1);
    expect(
      (result as MambaFailureResult).message,
      'Cannot create demo: the file already exists.',
    );
    expect(file.existsSync(), isTrue);
  });

  test('scaffolding command appends a command to an existing file', () async {
    final directory = tempDirectory();
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
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
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
          ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
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
    final directory = tempDirectory();
    final missingFile = '${directory.path}/lib/admin.dart';
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
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

  test('generated test suite orders imports around the package name', () async {
    final directory = tempDirectory();
    final projectScaffolder = realScaffolding(directory);

    // A name sorting after both Mamba and test proves the order follows the
    // package name instead of a fixed sequence.
    projectScaffolder.scaffold(
      'zzztool',
      'A demonstration CLI.',
      installDependencies: false,
      initializeGitRepository: false,
    );

    final projectDirectory = Directory('${directory.path}/zzztool');
    await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(projectDirectory, sourceFormatter: sourceFormatter),
    ]).fake().execute(['command', 'greet', '--test']);

    expect(
      File('${projectDirectory.path}/test/greet_test.dart').readAsStringSync(),
      startsWith(
        "import 'package:mamba/mamba.dart';\n"
        "import 'package:test/test.dart';\n"
        "import 'package:zzztool/greet.dart';\n",
      ),
    );
  });

  test(
    'project scaffolder writes analysis options and the lints dependency',
    () {
      final directory = tempDirectory();
      final projectScaffolder = realScaffolding(directory);

      projectScaffolder.scaffold(
        'demo',
        'A demonstration CLI.',
        installDependencies: false,
        initializeGitRepository: false,
      );

      expect(
        File('${directory.path}/demo/analysis_options.yaml').readAsStringSync(),
        allOf(
          contains('include: package:lints/recommended.yaml'),
          contains('strict-inference: true'),
          contains('- no_dynamic_casts'),
          contains('- no_raw_types'),
          contains('- strict_top_level_inference'),
        ),
      );
      expect(
        File('${directory.path}/demo/pubspec.yaml').readAsStringSync(),
        contains('dev_dependencies:\n  lints: any\n  test: any\n'),
      );
    },
  );

  test('generated sources are already dart-format clean', () async {
    final directory = tempDirectory();
    final projectScaffolder = DirectoryProjectScaffolder(
      directory,
      processRunner: FakeProjectProcessRunner(),
      sourceFormatter: SystemSourceFormatter(),
    );

    projectScaffolder.scaffold(
      'demo',
      'A demonstration CLI.',
      installDependencies: false,
      initializeGitRepository: false,
    );

    final projectDirectory = Directory('${directory.path}/demo');
    await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(
        projectDirectory,
        sourceFormatter: SystemSourceFormatter(),
      ),
      ScaffoldBinaryCommand(
        projectDirectory,
        sourceFormatter: SystemSourceFormatter(),
      ),
    ]).fake().execute(['command', 'greet', '--test']);
    await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldBinaryCommand(
        projectDirectory,
        sourceFormatter: SystemSourceFormatter(),
      ),
    ]).fake().execute(['binary', 'helper']);

    expect(_unformattedPaths(projectDirectory), isEmpty);
  });

  test(
    'generated sources stay format clean at the edges of the line limit',
    () async {
      final directory = tempDirectory();
      final projectScaffolder = DirectoryProjectScaffolder(
        directory,
        processRunner: FakeProjectProcessRunner(),
        sourceFormatter: SystemSourceFormatter(),
      );

      projectScaffolder.scaffold(
        'deploy_production_toolkit',
        'A deliberately long description that pushes every generated line past '
            'the eighty column limit the formatter wraps at.',
        installDependencies: false,
        initializeGitRepository: false,
      );

      final projectDirectory = Directory(
        '${directory.path}/deploy_production_toolkit',
      );
      await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldCommand(
          projectDirectory,
          sourceFormatter: SystemSourceFormatter(),
        ),
      ]).fake().execute([
        'command',
        'synchronise_deployments_across_regions',
        '--group',
        '--test',
      ]);

      expect(_unformattedPaths(projectDirectory), isEmpty);
    },
  );
}

/// The generated Dart files `dart format` would rewrite, which is every one of
/// them when a template's layout does not already match the formatter.
///
/// The formatter's exit status is checked first: a `dart format` that fails for
/// any other reason prints no `Changed` lines, and reading that silence as
/// "everything is formatted" is a false green.
List<String> _unformattedPaths(Directory projectDirectory) {
  final result = Process.runSync('dart', [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'bin',
    'lib',
    'test',
  ], workingDirectory: projectDirectory.path);

  expect(
    result.exitCode,
    anyOf(0, 1),
    reason: 'dart format failed: ${result.stderr}',
  );

  return RegExp(r'Changed (\S+)')
      .allMatches(result.stdout.toString())
      .map((match) => match.group(1)!.replaceAll(r'\', '/'))
      .toList();
}
