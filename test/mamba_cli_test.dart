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

  group('mamba command', () {
    late Directory temporaryDirectory;
    late ScaffoldCommand command;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'mamba_command_test',
      );
      command = ScaffoldCommand(temporaryDirectory);
    });

    tearDown(() => temporaryDirectory.deleteSync(recursive: true));

    test('scaffolds a regular hook command and its fake test suite', () async {
      final executor = Executor('mamba', 'Scaffold Mamba applications.', [
        command,
      ]).fake();

      final result = await executor.execute([
        'command',
        'greet',
        '--hook',
        '--with-suite',
      ]);

      expect(result, isA<MambaSuccessResult>());
      expect(
        File('${temporaryDirectory.path}/lib/greet.dart').readAsStringSync(),
        allOf(
          contains('extends Command with HookRunner'),
          contains('GreetCommand'),
        ),
      );
      expect(
        File('${temporaryDirectory.path}/test/greet_test.dart')
            .readAsStringSync(),
        allOf(contains('GreetCommand()'), contains('.fake()')),
      );
    });

    test(
      'appends a persistent hook group command to an existing file',
      () async {
        final commandFile = File('${temporaryDirectory.path}/commands.dart')
          ..writeAsStringSync('library commands;\n');
        final executor = Executor('mamba', 'Scaffold Mamba applications.', [
          command,
        ]).fake();

        final result = await executor.execute([
          'command',
          'tasks',
          commandFile.path,
          '--group',
          '--hook',
          '--persistent-hook',
          '--append',
        ]);

        expect(result, isA<MambaSuccessResult>());
        expect(
          commandFile.readAsStringSync(),
          allOf(
            contains(
              'extends GroupCommand with HookRunner, PersistentHookRunner',
            ),
            contains('TasksCommand() : super([]);'),
          ),
        );
      },
    );

    test('requires --append when a file argument is provided', () async {
      final commandFile = File('${temporaryDirectory.path}/commands.dart')
        ..writeAsStringSync('library commands;\n');
      final executor = Executor('mamba', 'Scaffold Mamba applications.', [
        command,
      ]).fake();

      final result = await executor.execute([
        'command',
        'greet',
        commandFile.path,
      ]);

      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).exception.toString(),
        contains('requires --append'),
      );
    });

    test('requires an existing file when appending', () async {
      final executor = Executor('mamba', 'Scaffold Mamba applications.', [
        command,
      ]).fake();

      final result = await executor.execute([
        'command',
        'greet',
        'missing.dart',
        '--append',
      ]);

      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).exception.toString(),
        contains('must already exist'),
      );
    });
  });
}
