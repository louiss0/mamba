import 'dart:io';

import 'package:mamba/mamba.dart';

import '../fixtures/rig/rig.dart' as rig;

Future<void> main() async {
  final outputDirectory = Directory('fixtures/rig/completions')
    ..createSync(recursive: true);
  final executor = rig.createRigExecutor().fake();
  const shells = {
    'carapace': 'rig.yaml',
    'bash': 'rig.bash',
    'fish': 'rig.fish',
    'zsh': '_rig',
    'powershell': 'rig.ps1',
  };
  for (final entry in shells.entries) {
    final result = await executor.execute(['completion', '--shell', entry.key]);
    if (result case MambaSuccessResult(output: final output?)) {
      File('${outputDirectory.path}/${entry.value}').writeAsStringSync(output);
    } else {
      throw StateError('Unable to generate the ${entry.key} completion.');
    }
  }
}
