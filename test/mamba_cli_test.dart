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
      contains('name: demo'),
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
    expect(File('${directory.path}/lib/demo.dart').existsSync(), isTrue);
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
}
