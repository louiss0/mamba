import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('all generated Clix components compile and return their public results', () async {
    final root = Directory.systemTemp.createTempSync('mamba_clix_codegen_');
    addTearDown(() => root.deleteSync(recursive: true));
    final packagePath = Directory.current.path
        .replaceAll(r'\', '/')
        .replaceAll("'", "''");
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: component_probe
environment:
  sdk: ^3.13.2
dependencies:
  mamba:
    path: '$packagePath'
''');
    final executor = Executor('probe', 'Probe.', '1.0.0', [
      ScaffoldComponentCommand(root),
    ]).fake();
    for (final (kind, name) in [
      ('prompt', 'ask'),
      ('selector', 'choose'),
      ('picker', 'target'),
      ('indicator', 'report'),
    ]) {
      expect((await executor.execute(['component', kind, name])).exitCode, 0);
    }
    final binary = File('${root.path}/bin/verify.dart');
    binary.parent.createSync();
    binary.writeAsStringSync('''
import 'dart:convert';
import '../lib/components/ask.dart';
import '../lib/components/choose.dart';
import '../lib/components/target.dart';
import '../lib/components/report.dart';

Future<void> main(List<String> arguments) async {
  Object? result;
  switch (arguments.single) {
    case 'prompt': result = await AskComponent().render();
    case 'selector': result = await ChooseComponent(options: ['Alpha', 'Beta']).render();
    case 'picker': result = await TargetComponent().render();
    case 'indicator': result = await ReportComponent().render(() async => 17);
    case 'indicator-error':
      try {
        await ReportComponent().render<int>(() async => throw StateError('work failed'));
        result = 'unexpected success';
      } on StateError catch (error) {
        result = error.message;
      }
    default: throw ArgumentError.value(arguments);
  }
  print('GENERATED_RESULT=\${jsonEncode(result)}');
}
''');
    final install = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: root.path);
    expect(install.exitCode, 0, reason: '${install.stdout}\n${install.stderr}');
    final snapshot = '${root.path}/verify.dill';
    final compile = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      binary.path,
      '--output=$snapshot',
    ], workingDirectory: root.path);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');

    for (final (scenario, input, expected) in <(String, String, Object?)>[
      ('prompt', 'probe\n', 'probe'),
      ('prompt', '\n', null),
      ('selector', '2\n', 'Beta'),
      ('selector', '\n', null),
      ('picker', '1\n', root.resolveSymbolicLinksSync()),
      ('picker', '\n', null),
      ('indicator', '', 17),
      ('indicator-error', '', 'work failed'),
    ]) {
      final process = await Process.start(Platform.resolvedExecutable, [
        snapshot,
        scenario,
      ], workingDirectory: root.path);
      process.stdin.write(input);
      await process.stdin.close();
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          process.kill();
          throw StateError('Generated $scenario did not exit.');
        },
      );
      final text = await output;
      expect(code, 0, reason: await errors);
      const marker = 'GENERATED_RESULT=';
      final resultLine = const LineSplitter()
          .convert(text)
          .singleWhere((line) => line.contains(marker));
      final Object? actual = jsonDecode(
        resultLine.substring(resultLine.indexOf(marker) + marker.length),
      ) as Object?;
      if (scenario == 'picker' && actual is String) {
        final selected = Directory(actual);
        expect(selected.isAbsolute, isTrue, reason: scenario);
        // Both macOS symlinks and Windows short paths name the same directory.
        expect(selected.resolveSymbolicLinksSync(), expected, reason: scenario);
      } else {
        expect(actual, expected, reason: scenario);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
