import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Bash CI policy', () {
    late Directory directory;
    late String fakeDirectory;

    setUpAll(() async {
      directory = Directory.systemTemp.createTempSync('mamba-bash-policy-');
      fakeDirectory = '${directory.path}/fake';
      Directory(fakeDirectory).createSync();
      final executable =
          '$fakeDirectory/bash${Platform.isWindows ? '.exe' : ''}';
      final result = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        'test/support/fake_bash.dart',
        '-o',
        executable,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });
    tearDownAll(() => directory.deleteSync(recursive: true));

    test('action preflight accepts Bash 4', () async {
      final result = await _preflight(fakeDirectory, major: '4');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('Using Bash 4'));
    });

    test('action preflight accepts newer Bash', () async {
      final result = await _preflight(fakeDirectory, major: '5');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    });

    for (final major in ['3', 'unreadable']) {
      test('action preflight rejects version $major', () async {
        final result = await _preflight(fakeDirectory, major: major);
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('Bash 4 or newer is required'));
      });
    }

    test('action preflight rejects a failed version probe', () async {
      final result = await _preflight(
        fakeDirectory,
        major: '4',
        probeExit: '7',
      );
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('the selected bash could not run'));
    });

    test('action preflight rejects missing Bash', () async {
      final empty = Directory('${directory.path}/empty-action')..createSync();
      final result = await _preflight(empty.path);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('bash was not found on PATH'));
    });

    test('completion CI runs every test on supported Bash', () async {
      final result = await _suite(File(_realBash()).parent.path);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('+5: All tests passed!'));
      expect(result.stdout, isNot(contains('Skip:')));
    });

    test('completion CI rejects an unreadable version', () async {
      final result = await _suite(fakeDirectory, major: 'unreadable');
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains('requires Bash 4 or newer'),
      );
      expect(result.stdout, isNot(contains('Skip:')));
    });

    test('completion CI rejects a failed version probe', () async {
      final result = await _suite(fakeDirectory, major: '4', probeExit: '7');
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains('requires Bash 4 or newer'),
      );
      expect(result.stdout, isNot(contains('Skip:')));
    });

    test('completion CI rejects missing Bash', () async {
      final empty = Directory('${directory.path}/empty-suite')..createSync();
      final result = await _suite(empty.path, isolated: true);
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains('requires Bash 4 or newer'),
      );
      expect(result.stdout, isNot(contains('Skip:')));
    });

    test('completion CI fails rather than skips on Bash 3', () async {
      final result = await _suite(fakeDirectory, major: '3');
      expect(
        result.exitCode,
        isNot(0),
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(
        '${result.stdout}${result.stderr}',
        contains('requires Bash 4 or newer'),
      );
      expect(result.stdout, isNot(contains('Skip:')));
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<ProcessResult> _preflight(
  String bashDirectory, {
  String major = '3',
  String probeExit = '0',
}) {
  return Process.run(
    _realBash(),
    [
      '--noprofile',
      '--norc',
      '-c',
      r'fixture_path="$(cd "$1" && pwd)"; PATH="$fixture_path"; . "$2"',
      '--',
      bashDirectory.replaceAll('\\', '/'),
      File('.github/actions/setup-bash/verify.sh').absolute.path
          .replaceAll('\\', '/'),
    ],
    environment: {
      'MAMBA_FAKE_BASH_MAJOR': major,
      'MAMBA_FAKE_BASH_EXIT': probeExit,
    },
  );
}

String _realBash() {
  if (Platform.isWindows) {
    return '${Platform.environment['ProgramFiles'] ?? 'C:/Program Files'}/Git/bin/bash.exe';
  }
  final result = Process.runSync('which', ['bash']);
  if (result.exitCode != 0) throw StateError('Bash policy tests require Bash.');
  return '${result.stdout}'.trim();
}

Future<ProcessResult> _suite(
  String bashDirectory, {
  String major = '3',
  String probeExit = '0',
  bool isolated = false,
}) => Process.run(
  Platform.resolvedExecutable,
  [
    'test',
    'test/completion_shell_test.dart',
    '--name',
    'completion in a real shell',
    '--reporter=expanded',
  ],
  environment: {
    'CI': 'true',
    'PATH': isolated
        ? bashDirectory
        : '$bashDirectory${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}',
    'MAMBA_FAKE_BASH_MAJOR': major,
    'MAMBA_FAKE_BASH_EXIT': probeExit,
  },
);
