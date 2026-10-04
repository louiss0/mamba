import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Future<({int exitCode, String output, String errors})> _execute(
  List<String> arguments, {
  String? standardInput,
}) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    'test/fixtures/process_cli.dart',
    ...arguments,
  ], workingDirectory: Directory.current.path);
  if (standardInput != null) process.stdin.write(standardInput);
  await process.stdin.close();

  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;

  return (exitCode: exitCode, output: await output, errors: await errors);
}

void main() {
  test('production execution reads piped standard input', () async {
    final result = await _execute(['input'], standardInput: 'hello');

    expect(result.exitCode, 0);
    expect(result.output, 'hello');
    expect(result.errors, isEmpty);
  });

  test('production execution reports failures', () async {
    final result = await _execute(['fail']);

    expect(result.exitCode, 7);
    expect(result.output, isEmpty);
    expect(result.errors, 'process failed');
  });

  test('production execution leaves successful null output silent', () async {
    final result = await _execute(['silent']);

    expect(result.exitCode, 0);
    expect(result.output, isEmpty);
    expect(result.errors, isEmpty);
  });

  test(
    'production execution writes the exact bytes the result carries',
    () async {
      final result = await _execute(['echo']);

      expect(result.exitCode, 0);
      expect(result.output, 'line one\nline two');
      expect(result.errors, isEmpty);
    },
  );

  test('production execution writes error bytes without a newline', () async {
    final result = await _execute(['error-text']);

    expect(result.exitCode, 9);
    expect(result.output, isEmpty);
    expect(result.errors, 'error text');
  });
}
