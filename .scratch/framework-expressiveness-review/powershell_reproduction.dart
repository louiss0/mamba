import 'dart:io';

import 'package:mamba/mamba.dart';

enum Color { blue, red }

final class ColorCommand extends Command {
  new(this.color) : super(options: [color]);

  final ChoiceOption<Color> color;

  @override
  String get name => 'run';

  @override
  String get shortDescription => 'Namespace collision probe.';

  @override
  String run(ParsedInputs inputs, List<String> args) =>
      inputs.valueOf(color)!.name;
}

String psQuote(String value) => "'${value.replaceAll("'", "''")}'";

void main() {
  if (!Platform.isWindows) {
    stderr.writeln('This reproduction requires Windows PowerShell.');
    exitCode = 2;
    return;
  }
  final directory = Directory.systemTemp.createTempSync('mamba_review_');
  try {
    final paths = <String>[];
    for (final (name, choice) in [
      ('foo-bar', Color.blue),
      ('foo_bar', Color.red),
    ]) {
      final registry = CommandRegistry.create(
        name,
        'Namespace collision probe.',
        commands: [
          ColorCommand(ChoiceOption('color', choices: [choice])),
        ],
      );
      final file = File('${directory.path}/$name.ps1');
      file.writeAsStringSync(
        ToPowerShellCompletionConverter(registry.toRecord()).convert(),
      );
      paths.add(file.path);
    }
    final script =
        '''
. ${psQuote(paths[0])}
\$line = 'foo-bar run --color '
\$before = [System.Management.Automation.CommandCompletion]::CompleteInput(\$line, \$line.Length, \$null)
'Before: ' + ((\$before.CompletionMatches | ForEach-Object CompletionText) -join ', ')
. ${psQuote(paths[1])}
foreach (\$line in @('foo-bar run --color ', 'foo_bar run --color ')) {
  \$result = [System.Management.Automation.CommandCompletion]::CompleteInput(\$line, \$line.Length, \$null)
  \$line.Trim() + ': ' + ((\$result.CompletionMatches | ForEach-Object CompletionText) -join ', ')
}
''';
    final result = Process.runSync('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]);
    final output = result.stdout.toString();
    stdout.write(output);
    stderr.write(result.stderr);
    // Red-capable: the first executable must retain its own blue candidate.
    if (result.exitCode != 0 ||
        !output.contains('Before: blue') ||
        !output.contains('foo-bar run --color: blue') ||
        !output.contains('foo_bar run --color: red')) {
      stderr.writeln('FAIL: completion state leaked between applications.');
      exitCode = 1;
    }
  } finally {
    directory.deleteSync(recursive: true);
  }
}
