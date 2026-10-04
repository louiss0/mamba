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
final String? _skipReason = !runningInCi
    ? 'needs CI'
    : _bashMajor == null
    ? 'needs a bash shell'
    : _bashMajor < 4
    ? 'needs bash 4 or newer, found $_bashMajor'
    : null;

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
      'echo "handler=[\$(complete -p $command | sed -E \'s/.* -F ([^ ]+) .*/\\1/\')]" >&2\n'
      'COMP_WORDS=(${words.map((word) => "'$word'").join(' ')})\n'
      'COMP_CWORD=${words.length - 1}\n'
      '"\$(complete -p $command | sed -E \'s/.* -F ([^ ]+) .*/\\1/\'| head -1)"\n'
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
  });
}
