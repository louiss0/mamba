import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('documentation example checker', () {
    test('checks and executes an example with explicit context', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/README.md').writeAsStringSync('''
```dart
expect(answer, 42);
```
''');
      File('${root.path}/tool/doc_examples/example_test.dart.template')
          .writeAsStringSync('''
import 'package:test/test.dart';
void main() {
  test('documented answer', () {
    const answer = 42;
    {{README.md#1}}
  });
}
''');

      final result = await _check(root);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('1 Dart examples checked'));
      expect(result.stdout, contains('All tests passed!'));
      _expectClean(root);
    }, timeout: const Timeout(Duration(minutes: 3)));
    test(
      'rejects a broken Mamba API reference instead of exempting it',
      () async {
        final root = _fixture();
        addTearDown(() => root.deleteSync(recursive: true));
        _example(root, 'Executor();', '''
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';
void main() { test('broken API', () { {{README.md#1}} }); }
''');
        final result = await _check(root);
        expect(result.exitCode, 1);
        expect(
          '${result.stdout}${result.stderr}',
          contains('not_enough_positional_arguments'),
        );
        _expectClean(root);
      },
    );

    test('fails when a documented assertion is wrong', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      _example(root, 'expect(41, 42);', '''
import 'package:test/test.dart';
void main() { test('wrong answer', () { {{README.md#1}} }); }
''');
      final result = await _check(root);
      expect(result.exitCode, 1);
      expect(result.stdout, contains('Expected: <42>'));
      _expectClean(root);
    });

    test('fails when a new fence has no context', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      _example(root, 'const answer = 42;', '{{README.md#1}}');
      File('${root.path}/README.md').writeAsStringSync(
        '\n```dart\nUndefinedType value;\n```\n',
        mode: FileMode.append,
      );
      final result = await _check(root);
      expect(result.exitCode, 1);
      expect(
        result.stderr,
        contains('Missing context for Dart example README.md#2'),
      );
      _expectClean(root);
    });

    test('fails when a template refers to a removed fence', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      _example(root, 'const answer = 42;', '{{README.md#2}}');
      final result = await _check(root);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('unknown Dart example README.md#2'));
      _expectClean(root);
    });

    test(
      'finds examples outside the documentation site content folder',
      () async {
        final root = _fixture();
        addTearDown(() => root.deleteSync(recursive: true));
        _example(root, 'expect(42, 42);', '''
import 'package:test/test.dart';
void main() { test('answer', () { {{README.md#1}} }); }
''');
        Directory('${root.path}/docs').createSync();
        File('${root.path}/docs/notes.md')
            .writeAsStringSync('```dart\nUnknown value;\n```\n');
        final result = await _check(root);
        expect(result.exitCode, 1);
        expect(
          result.stderr,
          contains('Missing context for Dart example docs/notes.md#1'),
        );
        _expectClean(root);
      },
    );

    test('checks tilde fences and CRLF documents', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      _example(root, 'expect(answer, 42);', '''
import 'package:test/test.dart';
void main() { test('answer', () { const answer = 42; {{README.md#1}} }); }
''');
      File('${root.path}/README.md')
          .writeAsStringSync('~~~dart\r\nexpect(answer, 42);\r\n~~~\r\n');
      final result = await _check(root);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout, contains('1 Dart examples checked'));
      _expectClean(root);
    });

    test('does not report success for an empty inventory', () async {
      final root = _fixture();
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/README.md').writeAsStringSync('# No examples\n');
      final result = await _check(root);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('No Dart examples found.'));
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}

void _example(Directory root, String code, String template) {
  File('${root.path}/README.md').writeAsStringSync('```dart\n$code\n```\n');
  File('${root.path}/tool/doc_examples/example_test.dart.template')
      .writeAsStringSync(template);
}

void _expectClean(Directory root) => expect(
  root.listSync().whereType<Directory>().where(
    (entry) => entry.path.contains('.example_check_'),
  ),
  isEmpty,
);

Future<ProcessResult> _check(Directory root) => Process.run(
  Platform.resolvedExecutable,
  [File('tool/check_examples.dart').absolute.path],
  workingDirectory: root.path,
);

Directory _fixture() {
  final root = Directory.systemTemp.createTempSync('mamba-example-test-');
  Directory('${root.path}/tool/doc_examples').createSync(recursive: true);
  Directory('${root.path}/.dart_tool').createSync();
  File('${root.path}/pubspec.yaml')
      .writeAsStringSync(File('pubspec.yaml').readAsStringSync());
  final configFile = File('.dart_tool/package_config.json').absolute;
  final Object? decoded = jsonDecode(configFile.readAsStringSync());
  if (decoded case {'packages': final List<Object?> packages}) {
    for (final package in packages) {
      if (package case {'rootUri': final String uri}) {
        (package as Map<String, Object?>)['rootUri'] = configFile.uri
            .resolve(uri)
            .toString();
      }
    }
  }
  File('${root.path}/.dart_tool/package_config.json')
      .writeAsStringSync(jsonEncode(decoded));
  return root;
}
