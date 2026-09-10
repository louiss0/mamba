import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

void main() {
  test('scaffolding command uses typed positional handle', () async {
    final directory = Directory.systemTemp.createTempSync('mamba_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ScaffoldCommand(directory),
    ]).fake().execute(['command', 'demo']);
    expect(result.exitCode, 0);
    expect(File('${directory.path}/lib/demo.dart').existsSync(), isTrue);
  });
}
