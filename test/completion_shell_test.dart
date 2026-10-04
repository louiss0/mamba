import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures.dart';
import 'shell_support.dart';

/// Whether a generated completion can be driven for real here.
///
/// The generated Bash completion needs bash 4 for associative arrays, and
/// macOS still ships bash 3.2 as `/bin/bash`, so the version is checked rather
/// than assumed from the shell existing.
final _bashMajor = bashMajorVersion();
final String? _skipReason = switch ((runningInCi, _bashMajor)) {
  (false, _) => 'needs CI',
  (_, null) => 'needs a bash shell',
  (_, final int major) when major < 4 => 'needs bash 4 or newer, found $major',
  _ => null,
};

final _first = BooleanFlag('first');
final _second = BooleanFlag('second');

/// Completes [words] in bash against [script] and prints one candidate per
/// line.
///
/// The completion function is asked for through `complete`, so this never has
/// to know how the generator names its handlers.
String _bashCompletionOutput(
  String script,
  List<String> words, {
  required String command,
}) {
  final directory = Directory.systemTemp.createTempSync('mamba_completion_');
  // One file: the generated script registers its handler, and the harness that
  // follows drives it. Two files would make a missing write look like a shell
  // that cannot find its completion.
  final harness =
      'handler=\$(complete -p $command | sed -E \'s/.* -F ([^ ]+) .*/\\1/\')\n'
      'echo "handler=[\$handler]" >&2\n'
      'COMP_WORDS=(${words.map((word) => "'$word'").join(' ')})\n'
      'COMP_CWORD=${words.length - 1}\n'
      '"\$handler"\n'
      'echo "reply=[\${COMPREPLY[*]}]" >&2\n'
      'printf \'%s\\n\' "\${COMPREPLY[@]}"\n';
  final harnessFile = File('${directory.path}/completion.sh')
    ..writeAsStringSync('$script\n$harness');
  try {
    final result = Process.runSync('bash', [harnessFile.path]);
    // The shell is the only oracle for this, so its diagnostics travel with
    // the failure rather than disappearing into a captured stream.
    printOnFailure('harness stderr:\n${result.stderr}');
    expect(result.exitCode, 0, reason: 'harness failed:\n${result.stderr}');
    return '${result.stdout}';
  } finally {
    directory.deleteSync(recursive: true);
  }
}

void main() {
  group('completion in a real shell', () {
    test('offers the flags of the command whose name has a hyphen', () {
      final record = CommandRegistry.create(
        'probe',
        'Collision probe.',
        commands: [
          TestCommand('foo-bar', 'Hyphenated.', flags: [_first]),
          TestCommand('foo_bar', 'Underscored.', flags: [_second]),
        ],
      ).toRecord();
      final script = ToBashCompletionConverter(record).convert();

      for (final (command, own, other) in [
        ('foo-bar', '--first', '--second'),
        ('foo_bar', '--second', '--first'),
      ]) {
        final output = _bashCompletionOutput(script, [
          'probe',
          command,
          '--',
        ], command: 'probe');

        expect(output, contains(own), reason: 'completing $command');
        expect(
          output,
          isNot(contains(other)),
          reason: "completing $command offered another command's flags",
        );
      }
    }, skip: _skipReason);

    test('offers stepped numbers the parser accepts', () {
      final registry = CommandRegistry.create(
        'probe',
        'Stepped numbers.',
        options: [DoubleOption('ratio', min: 0, max: 1, step: 0.3)],
      );
      final script = ToBashCompletionConverter(registry.toRecord()).convert();

      final output = _bashCompletionOutput(script, [
        'probe',
        '--ratio',
        '',
      ], command: 'probe');

      expect(output, contains('0.9'));
      expect(
        output,
        isNot(contains('1.0')),
        reason: 'the parser rejects 1.0 for this step',
      );
    }, skip: _skipReason);

    test('stops a shell that cannot load the artifact', () {
      final script = ToBashCompletionConverter(
        CommandRegistry.create(
          'probe',
          'Collision probe.',
          commands: [TestCommand('run', 'Run it.')],
        ).toRecord(),
      ).convert();

      final result = _runAsOldBash(script);

      expect(
        result.stderr,
        contains('probe: completion requires bash 4 or newer'),
      );
      expect(
        result.stderr,
        isNot(contains('declare')),
        reason:
            'the guard has to stop the script before the associative arrays',
      );
      expect(result.stdout, isEmpty);
    }, skip: _skipReason);
  });
}

/// Runs [script] as though the shell were older than Mamba supports.
///
/// The guard reads `BASH_VERSINFO`, which a shell will not let a test
/// overwrite, so the version in the guard is relaxed instead. That exercises
/// the path the guard exists for — the message, and the script stopping before
/// anything an old bash rejects — without needing an old bash.
({String stdout, String stderr}) _runAsOldBash(String script) {
  final directory = Directory.systemTemp.createTempSync('mamba_oldbash_');
  final file = File('${directory.path}/completion.sh')
    ..writeAsStringSync(script.replaceFirst('< 4', '< 99'));
  try {
    final result = Process.runSync('bash', [file.path]);
    printOnFailure('old-bash stderr:\n${result.stderr}');
    return (stdout: '${result.stdout}', stderr: '${result.stderr}');
  } finally {
    directory.deleteSync(recursive: true);
  }
}
