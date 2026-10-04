import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Where a generated completion is run for real.
///
/// Every test here needs a shell that exists on this machine and would need a
/// different one on another, so they run in CI, where the runners are known. A
/// developer's machine runs the parse checks in `integrations_test.dart`
/// instead, and this suite skips rather than pretending.
final bool _inCi =
    Platform.environment['CI'] == 'true' || Platform.environment['CI'] == '1';

bool _hasShell(String candidate) {
  try {
    return Process.runSync('where.exe', [candidate]).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

final _bash = _inCi && _hasShell('bash');

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
  final scriptFile = File('${directory.path}/completion.sh')
    ..writeAsStringSync(script);
  final harness =
      'source "$scriptFile"\n'
      'handler=\$(complete -p $command | sed -E \'s/.* -F ([^ ]+) .*/\\1/\')\n'
      'COMP_WORDS=(${words.map((word) => "'$word'").join(' ')})\n'
      'COMP_CWORD=${words.length - 1}\n'
      '"\$handler"\n'
      'printf \'%s\\n\' "\${COMPREPLY[@]}"\n';
  final harnessFile = File('${directory.path}/harness.sh')
    ..writeAsStringSync(harness);
  try {
    final result = Process.runSync('bash', [harnessFile.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
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
    }, skip: _bash ? false : 'needs CI and a bash shell');

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
    }, skip: _bash ? false : 'needs CI and a bash shell');
  });
}
