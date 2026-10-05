import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// The declaration errors the scaffolder refuses to work with.
///
/// Each one is a way a person can invoke it wrongly, so each is worth a message
/// they can act on rather than a file left half written.
void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('mamba_cli_'));
  tearDown(() => directory.deleteSync(recursive: true));

  /// Writes [contents] at [path] under the temporary directory.
  File write(String path, [String contents = '']) =>
      File('${directory.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);

  /// The file at [path] under the temporary directory.
  File file(String path) => File('${directory.path}/$path');

  /// The absolute path an invocation would type for [path].
  String at(String path) => file(path).path;

  Future<MambaExecutionResult> test_(List<String> args) => Executor(
    'tool',
    'Tool.',
    '1.0.0',
    [ScaffoldTestCommand(directory, sourceFormatter: sourceFormatter)],
  ).fake().execute(['test', ...args]);

  Matcher failsWith(String fragment) => isA<MambaFailureResult>().having(
    (failure) => failure.errors.single.exception.message,
    'message',
    contains(fragment),
  );

  group('test command', () {
    test('refuses a command file that does not exist', () async {
      write('pubspec.yaml', 'name: demo\n');

      expect(
        await test_(['greet', at('lib/missing.dart'), '--append']),
        failsWith('does not exist'),
      );
    });

    test('refuses a pubspec with no usable package name', () async {
      write('pubspec.yaml', 'title: demo\n');
      write('lib/greet.dart');

      expect(
        await test_(['greet', at('lib/greet.dart'), '--append']),
        failsWith('no valid package name'),
      );
    });

    test('refuses a command file that is not under lib', () async {
      write('pubspec.yaml', 'name: demo\n');
      write('bin/greet.dart');

      expect(
        await test_(['greet', at('bin/greet.dart'), '--append']),
        failsWith('must be under lib'),
      );
    });

    test('refuses to append to a file that is not a test suite', () async {
      write('pubspec.yaml', 'name: demo\n');
      write('lib/greet.dart');
      write('test/greet_test.dart', '// not a suite: no closing brace');

      expect(
        await test_(['greet', at('lib/greet.dart'), '--append']),
        failsWith('not a test suite'),
      );
    });
  });

  group('defaults', () {
    test('formats with the system formatter when none is supplied', () async {
      write('pubspec.yaml', 'name: demo\n');

      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldCommand(directory),
      ]).fake().execute(['command', 'greet', '--test']);

      expect(result.exitCode, 0);
      expect(file('lib/greet.dart').existsSync(), isTrue);
      expect(file('test/greet_test.dart').existsSync(), isTrue);
    });

    test('uses the real prompts when none are supplied', () {
      // Constructing the command is enough: the defaults are built eagerly, and
      // nothing is asked because no invocation happens here.
      expect(() => CreateProjectCommand(directory), returnsNormally);
    });

    test(
      'formats a binary and a test command with the system formatter',
      () async {
        write('pubspec.yaml', 'name: demo\n');
        write('lib/greet.dart', "import 'package:mamba/mamba.dart';\n");

        final binary = await Executor('tool', 'Tool.', '1.0.0', [
          ScaffoldBinaryCommand(directory),
        ]).fake().execute(['binary', 'demo']);
        final test = await Executor('tool', 'Tool.', '1.0.0', [
          ScaffoldTestCommand(directory),
        ]).fake().execute(['test', 'greet']);

        expect(
          binary,
          isA<MambaSuccessResult>(),
          reason: 'binary: ${binary.toString()}',
        );
        expect(
          test,
          isA<MambaSuccessResult>(),
          reason: 'test: ${test.toString()}',
        );
      },
    );

    test('offers every kind as a subcommand without a formatter', () async {
      write('pubspec.yaml', 'name: demo\n');
      write('lib/greet.dart', "import 'package:mamba/mamba.dart';\n");

      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ScaffoldComponentCommand(directory),
      ]).fake().execute(['component', 'prompt', 'ask']);

      expect(result, isA<MambaSuccessResult>());
    });
  });

  group('appending', () {
    test(
      'restores the file when the test it was asked for cannot be made',
      () async {
        final existing = "import 'package:mamba/mamba.dart';\n";
        write('pubspec.yaml', 'name: demo\n');
        write('lib/greet.dart', existing);
        write('test/greet_test.dart', '// not a suite: no closing brace');

        final result =
            await Executor('tool', 'Tool.', '1.0.0', [
              ScaffoldCommand(directory, sourceFormatter: sourceFormatter),
            ]).fake().execute([
              'command',
              'greet',
              at('lib/greet.dart'),
              '--append',
              '--test',
            ]);

        expect(result, isA<MambaFailureResult>());
        expect(
          file('lib/greet.dart').readAsStringSync(),
          existing,
          reason: 'a failed append must not leave the command half written',
        );
      },
    );
  });
}
