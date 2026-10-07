import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Future<({int exitCode, String output, String errors})> runClixFixture(
  String scenario, {
  String input = '',
}) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    'test/fixtures/clix_terminal.dart',
    scenario,
  ]);
  process.stdin.write(input);
  await process.stdin.close();
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      process.kill();
      throw StateError('Clix fixture did not exit.');
    },
  );
  return (exitCode: code, output: await output, errors: await errors);
}

void main() {
  test(
    'create fails on closed input instead of accepting a setup default',
    () async {
      final result = await runClixFixture('create-eof');
      expect(result.exitCode, 1);
      expect(result.output, contains('No input available'));
      expect(result.errors, isEmpty);
    },
  );

  test('required Clix description exits cleanly at end of input', () async {
    final result = await runClixFixture('create');
    expect(result.exitCode, 1);
    expect(result.output, contains('No input available'));
    expect(result.errors, isEmpty);
  });

  test('Clix setup can consume complete piped answers', () async {
    final result = await runClixFixture('create', input: 'probe\nn\ny\n');
    expect(result.exitCode, 0);
    expect(
      result.output,
      contains(
        'CLIX_RESULT={"description":"probe","install":false,"git":true}',
      ),
    );
    expect(result.errors, isEmpty);
  });

  for (final (scenario, expected) in [
    ('spinner', '17'),
    ('spinner-error', '"work failed"'),
  ]) {
    test(
      'native $scenario restores the cursor and lets the process exit',
      () async {
        final result = await runClixFixture(scenario);
        expect(result.exitCode, 0);
        expect(result.errors, isEmpty);
        expect(result.output, contains('CLIX_RESULT=$expected'));
        expect(result.output, contains('\x1b[?25h'));
      },
    );
  }
}
