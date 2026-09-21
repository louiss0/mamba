import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

void main() {
  test('project command creates a Dart application', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(directory),
    ]).fake().execute(['create', 'demo']);

    expect(result.exitCode, 0);
    expect(
      (result as MambaSuccessResult).output,
      'Created Mamba command-line application in ${directory.path}/demo.',
    );
    expect(
      File('${directory.path}/demo/pubspec.yaml').readAsStringSync(),
      allOf(contains('name: demo'), contains('sdk: ^3.13.2')),
    );
    expect(
      File('${directory.path}/demo/bin/demo.dart').readAsStringSync(),
      contains("Executor('demo'"),
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
