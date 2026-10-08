import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures.dart';
import 'shell_support.dart';

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

enum _Color { blue, red }

enum const _Literal(@override final String value) implements MambaEnumValue {
  empty(''),
  spaced('two words'),
  quoted("quote's"),
  metacharacter(r'$(throw "unsafe")'),
  dash('--help'),
}

void main() {
  test(
    'PowerShell completion encodes literal choices without evaluating their content',
    () {
      final shell = firstShellOnPath(['powershell.exe', 'pwsh']);
      expect(shell, isNotNull);
      final directory = tempDirectory('mamba_literal_');
      final registry = CommandRegistry.create(
        'literal-probe',
        'Exact choices.',
        options: [ChoiceOption('format', choices: _Literal.values)],
      );
      final artifact = File('${directory.path}/literal.ps1')
        ..writeAsStringSync(
          ToPowerShellCompletionConverter(registry.toRecord()).convert(),
        );
      final harness = File('${directory.path}/harness.ps1')
        ..writeAsStringSync('''
\$ErrorActionPreference = 'Stop'
. '${artifact.path.replaceAll("'", "''")}'
function literal-probe { \$args[0] }
\$line = 'literal-probe --format='
\$matches = [System.Management.Automation.CommandCompletion]::CompleteInput(\$line, \$line.Length, \$null).CompletionMatches
foreach (\$match in \$matches) { Invoke-Expression ('literal-probe ' + \$match.CompletionText) }
\$line = 'literal-probe --format '
\$separate = [System.Management.Automation.CommandCompletion]::CompleteInput(\$line, \$line.Length, \$null).CompletionMatches
foreach (\$match in \$separate) {
  if (\$match.ListItemText -ceq '--help') { throw 'Dash-leading choice requires inline supply' }
}
''');
      final result = Process.runSync(shell!, [
        '-NoProfile',
        '-NonInteractive',
        '-File',
        harness.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect('${result.stdout}'.replaceAll('\r', '').trim().split('\n'), [
        '--format=',
        '--format=two words',
        "--format=quote's",
        r'--format=$(throw "unsafe")',
        '--format=--help',
      ]);
    },
    skip: firstShellOnPath(['powershell.exe', 'pwsh']) == null
        ? 'PowerShell unavailable; literal runtime unverified'
        : false,
  );

  for (final shellName in ['powershell.exe', 'pwsh']) {
    final shell = firstShellOnPath([shellName]);
    test(
      'PowerShell isolation in $shellName across load order, sourcing, and paths',
      () {
        expect(
          shell,
          isNotNull,
          reason: 'Windows CI requires $shellName on PATH.',
        );
        final directory = tempDirectory('mamba_ps_');
        final paths = <String>[];
        for (final (name, color) in [
          ('foo-bar', _Color.blue),
          ('foo_bar', _Color.red),
        ]) {
          final record = CommandRegistry.create(
            name,
            'Isolated candidates.',
            commands: [
              TestCommand(
                'run',
                'Run.',
                options: [
                  ChoiceOption('color', choices: [color]),
                ],
              ),
              TestGroupCommand('foo-bar', [
                TestCommand(
                  'run',
                  'Run.',
                  options: [
                    ChoiceOption('color', choices: [_Color.blue]),
                  ],
                ),
              ], 'Blue path.'),
              TestGroupCommand('foo_bar', [
                TestCommand(
                  'run',
                  'Run.',
                  options: [
                    ChoiceOption('color', choices: [_Color.red]),
                  ],
                ),
              ], 'Red path.'),
            ],
          ).toRecord();
          final file = File('${directory.path}/$name.ps1')
            ..writeAsStringSync(
              ToPowerShellCompletionConverter(record).convert(),
            );
          paths.add(file.path);
        }
        String quote(String value) => "'${value.replaceAll("'", "''")}'";
        for (final order in [paths, paths.reversed.toList()]) {
          final harness = File('${directory.path}/harness.ps1')
            ..writeAsStringSync('''
\$ErrorActionPreference = 'Stop'
\$PSVersionTable.PSVersion.ToString()
. ${quote(order[0])}
. ${quote(order[1])}
. ${quote(order[0])}
foreach (\$case in @(
  @('foo-bar run --color ', 'blue'),
  @('foo_bar run --color ', 'red'),
  @('foo-bar foo-bar run --color ', 'blue'),
  @('foo-bar foo_bar run --color ', 'red')
)) {
  \$line = \$case[0]
  \$result = [System.Management.Automation.CommandCompletion]::CompleteInput(\$line, \$line.Length, \$null)
  \$actual = (\$result.CompletionMatches | ForEach-Object CompletionText) -join ','
  if (\$actual -cne \$case[1]) { throw "\$line expected \$(\$case[1]), got \$actual" }
}
'ISOLATED'
''');
          final result = Process.runSync(shell!, [
            '-NoProfile',
            '-NonInteractive',
            '-File',
            harness.path,
          ]);
          printOnFailure('${result.stdout}\n${result.stderr}');
          expect(result.exitCode, 0, reason: '${result.stderr}');
          expect(result.stdout, contains('ISOLATED'));
        }
      },
      skip:
          shell == null &&
              !(runningInCi &&
                  Platform.isWindows &&
                  Platform.environment['GITHUB_ACTIONS'] == 'true')
          ? '$shellName unavailable locally; runtime unverified'
          : false,
    );
  }
  group('completion in a real shell', () {
    setUpAll(() {
      final major = bashMajorVersion();
      expect(
        major,
        isNotNull,
        reason:
            'Completion CI requires Bash 4 or newer on PATH; '
            'Bash is missing or its version could not be read.',
      );
      expect(
        major,
        greaterThanOrEqualTo(4),
        reason: 'Completion CI requires Bash 4 or newer; found Bash $major.',
      );
    });
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
    });

    test(
      'offers exact literal choices for long and equals-attached short forms',
      () {
        final option = ChoiceOption(
          'format',
          choices: _Literal.values,
          short: 'o',
        );
        final registry = CommandRegistry.create(
          'probe',
          'Exact choices.',
          flags: [BooleanFlag('verbose', short: 'v')],
          options: [option],
        );
        final script = ToBashCompletionConverter(registry.toRecord()).convert();
        for (final prefix in ['--format=', '-o=', '-vo=']) {
          final output = _bashCompletionOutput(script, [
            'probe',
            prefix,
          ], command: 'probe');
          final candidates = output.replaceAll('\r', '').trim().split('\n');
          expect(
            candidates,
            _Literal.values.map((choice) => '$prefix${choice.value}').toList(),
          );
          for (final candidate in candidates) {
            expect(
              Parser(registry).parse([candidate]).$2(option),
              isA<_Literal>(),
            );
          }
        }
        final invalid = _bashCompletionOutput(script, [
          'probe',
          '-xo=',
        ], command: 'probe');
        expect(invalid.trim(), isEmpty);
      },
    );

    test('separate choice completions omit option-looking values', () {
      final option = ChoiceOption('format', choices: _Literal.values);
      final registry = CommandRegistry.create(
        'probe',
        'Choices.',
        options: [option],
      );
      final output = _bashCompletionOutput(
        ToBashCompletionConverter(registry.toRecord()).convert(),
        ['probe', '--format', ''],
        command: 'probe',
      );
      final candidates = output.replaceAll('\r', '').split('\n')..removeLast();
      expect(candidates, ['', 'two words', "quote's", r'$(throw "unsafe")']);
      for (final candidate in candidates) {
        expect(
          Parser(registry).parse(['--format', candidate]).$2(option),
          isA<_Literal>(),
        );
      }
    });

    test('offers stepped numbers the parser accepts', () {
      for (final (option, expected) in [
        (
          DoubleOption('ratio', min: 0, max: 1, step: 0.3),
          ['0.0', '0.3', '0.6', '0.9'],
        ),
        (
          DoubleOption('fine', min: 0, max: 0.3, step: 0.1),
          ['0.0', '0.1', '0.2', '0.3'],
        ),
        (
          DoubleOption('tiny', min: 1e-7, max: 3e-7, step: 1e-7),
          ['0.0000001', '0.0000002', '0.0000003'],
        ),
        (DoubleOption('shifted', min: 1, max: 1.0000002, step: 1e-7), ['1.0']),
        (
          DoubleOption('signed', min: -0.3, max: 0, step: 0.1),
          ['-0.3', '-0.2', '-0.1', '0.0'],
        ),
      ]) {
        final registry = CommandRegistry.create(
          'probe',
          'Stepped numbers.',
          options: [option],
        );
        final candidates = _bashCompletionOutput(
          ToBashCompletionConverter(registry.toRecord()).convert(),
          ['probe', '--${option.name}', ''],
          command: 'probe',
        ).replaceAll('\r', '').trim().split('\n');
        expect(candidates, expected, reason: option.name);
        for (final candidate in candidates) {
          expect(
            () => Parser(registry).parse(['--${option.name}', candidate]),
            returnsNormally,
            reason: '${option.name}: $candidate',
          );
        }
      }
    });

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
    });
  }, skip: runningInCi ? false : 'needs CI');
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
