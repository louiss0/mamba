import 'dart:io';

import 'package:mamba/mamba.dart';

import '../fixtures/rig/rig.dart';

/// Rewrites every checked-in completion artifact for the `rig` fixture.
void main() {
  final record = CommandRegistry.create(
    'rig',
    'Completion fixture.',
    commands: [RigCommand()],
  ).toRecord();
  final artifacts = <String, String>{
    'rig.bash': ToBashCompletionConverter(record).convert(),
    '_rig': ToZshCompletionConverter(record).convert(),
    'rig.fish': ToFishCompletionConverter(record).convert(),
    'rig.ps1': ToPowerShellCompletionConverter(record).convert(),
    'rig.yaml': CarapaceSpecConverter(record).convert(),
  };
  for (final artifact in artifacts.entries) {
    File('fixtures/rig/completions/${artifact.key}')
        .writeAsStringSync(artifact.value);
    stdout.writeln('wrote ${artifact.key} (${artifact.value.length} bytes)');
  }
}
