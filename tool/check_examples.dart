import 'dart:io';

/// Checks the actual Dart fences, not copied examples or an exemption list.
///
/// Templates supply imports, enclosing declarations and application fixtures.
/// `{{path/to/document.md#N}}` inserts the Nth Dart fence verbatim. Every fence
/// must appear in a template, and every reference must resolve. The generated
/// libraries are analyzed and compiled together; templates ending in
/// `_test.dart.template` are also executed by the Dart test runner.
Future<void> main() async {
  final blocks = <String, String>{};
  final documents = [
    if (File('README.md').existsSync()) File('README.md'),
    for (final root in ['docs', 'skills'])
      if (Directory(root).existsSync()) ..._markdownFiles(Directory(root)),
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final file in documents) {
    final path = file.path.replaceAll('\\', '/');
    var index = 0;
    for (final block in _dartBlocks(file.readAsStringSync())) {
      blocks['$path#${++index}'] = block;
    }
  }
  if (blocks.isEmpty) {
    stderr.writeln('No Dart examples found.');
    exitCode = 1;
    return;
  }

  final templates = Directory('tool/doc_examples');
  if (!templates.existsSync()) {
    stderr.writeln('Missing tool/doc_examples context templates.');
    exitCode = 1;
    return;
  }
  final workspace = Directory.current.createTempSync('.example_check_');
  try {
    final referenced = <String>{};
    final tests = <String>[];
    final libraries = <String>[];
    var invalid = false;
    final reference = RegExp(r'\{\{([^{}]+#\d+)\}\}');
    for (final template
        in templates
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart.template'))) {
      final relative = template.path.substring(templates.path.length + 1);
      final output = File(
        '${workspace.path}/${relative.replaceFirst(RegExp(r'\.template$'), '')}',
      );
      final source = template.readAsStringSync().replaceAllMapped(reference, (
        match,
      ) {
        final key = match.group(1)!;
        final block = blocks[key];
        if (block == null) {
          stderr.writeln('${template.path}: unknown Dart example $key');
          invalid = true;
          return '';
        }
        referenced.add(key);
        return '// $key\n$block';
      });
      output.parent.createSync(recursive: true);
      output.writeAsStringSync(source);
      libraries.add(
        relative.replaceFirst(RegExp(r'\.template$'), '').replaceAll('\\', '/'),
      );
      if (output.path.endsWith('_test.dart')) tests.add(output.path);
    }
    for (final key in blocks.keys.where((key) => !referenced.contains(key))) {
      stderr.writeln('Missing context for Dart example $key');
      invalid = true;
    }
    if (invalid) {
      exitCode = 1;
      return;
    }
    // Import every generated library so even non-executable declarations and
    // production entry points go through the real compiler, not just analysis.
    libraries.sort();
    final harness = File('${workspace.path}/all_examples.dart');
    harness.writeAsStringSync(
      [
        for (var index = 0; index < libraries.length; index++)
          "import '${libraries[index]}' as example$index;",
        'void main() {}',
      ].join('\n'),
    );
    final analysis = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--no-fatal-warnings',
      workspace.path,
    ]);
    if (analysis.exitCode != 0) {
      stdout.write(analysis.stdout);
      stderr.write(analysis.stderr);
      exitCode = 1;
      return;
    }
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      harness.path,
      '--output=${workspace.path}/all_examples.dill',
    ]);
    if (compilation.exitCode != 0) {
      stdout.write(compilation.stdout);
      stderr.write(compilation.stderr);
      exitCode = 1;
      return;
    }
    if (tests.isEmpty) {
      stderr.writeln('No executable example tests found.');
      exitCode = 1;
      return;
    }
    final execution = await Process.run(Platform.resolvedExecutable, [
      'test',
      '--reporter=expanded',
      ...tests..sort(),
    ]);
    stdout.write(execution.stdout);
    stderr.write(execution.stderr);
    if (execution.exitCode != 0) {
      exitCode = 1;
      return;
    }
    stdout.writeln(
      '${blocks.length} Dart examples checked; '
      'all compile and example assertions pass.',
    );
  } finally {
    workspace.deleteSync(recursive: true);
  }
}

Iterable<String> _dartBlocks(String markdown) sync* {
  final opening = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*([^ \t\r]*)');
  RegExp? closing;
  var isDart = false;
  final lines = <String>[];
  for (final line in markdown.split('\n')) {
    if (closing != null) {
      if (closing.hasMatch(line)) {
        if (isDart) yield '${lines.join('\n')}\n';
        closing = null;
        lines.clear();
      } else if (isDart) {
        lines.add(line);
      }
      continue;
    }
    final match = opening.firstMatch(line);
    if (match == null) continue;
    final delimiter = match.group(1)!;
    closing = RegExp(
      '^ {0,3}${RegExp.escape(delimiter[0])}'
      '{${delimiter.length},}[ \\t]*\\r?\$',
    );
    isDart = match.group(2) == 'dart';
  }
  if (closing != null && isDart) {
    throw FormatException('Unclosed Dart example fence.');
  }
}

Iterable<File> _markdownFiles(Directory directory) sync* {
  for (final entry in directory.listSync(followLinks: false)) {
    if (entry is Directory) {
      final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (!{'node_modules', 'dist', '.astro', '.git'}.contains(name)) {
        yield* _markdownFiles(entry);
      }
    } else if (entry is File &&
        (entry.path.endsWith('.md') || entry.path.endsWith('.mdx'))) {
      yield entry;
    }
  }
}
