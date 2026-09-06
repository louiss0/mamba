import 'dart:io';

import 'package:mamba/executor.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

void main() {
  group('mamba create', () {
    late Directory temporaryDirectory;
    late CreateProjectCommand command;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'mamba_cli_test',
      );
      command = CreateProjectCommand(temporaryDirectory);
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('scaffolds a Dart console project using Mamba', () async {
      final executor = Executor(
        'mamba',
        'Scaffold Mamba command-line applications.',
        [command],
      ).fake();

      final result = await executor.execute(['create', 'snake']);

      expect(result, isA<MambaSuccessResult>());
      expect(
        File('${temporaryDirectory.path}/snake/pubspec.yaml')
            .readAsStringSync(),
        allOf(contains('name: snake'), contains('mamba: ^0.3.0')),
      );
      expect(
        File('${temporaryDirectory.path}/snake/bin/snake.dart')
            .readAsStringSync(),
        allOf(contains('Executor('), contains('.create()')),
      );
      expect(
        File('${temporaryDirectory.path}/snake/test/snake_test.dart')
            .readAsStringSync(),
        contains('.fake()'),
      );
    });

    test('does not overwrite an existing project directory', () async {
      Directory('${temporaryDirectory.path}/snake').createSync();
      final executor = Executor(
        'mamba',
        'Scaffold Mamba command-line applications.',
        [command],
      ).fake();

      final result = await executor.execute(['create', 'snake']);

      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).exception.toString(),
        contains('already exists'),
      );
    });
  });
}
