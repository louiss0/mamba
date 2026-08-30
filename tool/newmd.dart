import 'dart:io';

/// Creates a new Markdown file in docs/src/content/docs/ with Starlight frontmatter.
///
/// Usage: dart run tool/newmd.dart <title> [--section guides|reference] [--slug <custom-slug>]
///
/// Examples:
///   dart run tool/newmd.dart "My New Guide"
///   dart run tool/newmd.dart "My New Guide" --section reference
///   dart run tool/newmd.dart "My New Guide" --slug my-custom-slug
Future<void> main(List<String> arguments) async {
  final args = _parseArgs(arguments);

  final section = args['section'] as String;
  final title = args['title'] as String;
  final slug = args['slug'] as String?;

  // Generate slug from title if not provided
  final fileSlug = slug ?? _toSlug(title);
  final fileName = '$fileSlug.md';
  final dirPath = 'docs/src/content/docs/$section';
  final filePath = '$dirPath/$fileName';

  // Create directory if it doesn't exist
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  // Check if file already exists
  final file = File(filePath);
  if (await file.exists()) {
    stderr.writeln('Error: File already exists: $filePath');
    exit(1);
  }

  // Generate frontmatter
  final description = args['description'] as String? ?? 'A guide in the Mamba documentation.';
  final frontmatter = _generateFrontmatter(title: title, description: description);
  final content = '''$frontmatter

# $title

Write your content here.

## Prerequisites

- Item 1
- Item 2

## Steps

1. Step one
2. Step two

## See also

- [Related doc](../reference/commands.md)
''';

  await file.writeAsString(content);
  stdout.writeln('Created: $filePath');
  stdout.writeln('Edit this file to add your content.');
}

Map<String, Object?> _parseArgs(List<String> arguments) {
  String? title;
  String section = 'guides';
  String? description;
  String? slug;

  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--section':
      case '-s':
        if (i + 1 >= arguments.length) {
          _printUsageAndExit('Missing value for --section');
        }
        section = arguments[++i];
        if (section != 'guides' && section != 'reference') {
          _printUsageAndExit('Section must be "guides" or "reference"');
        }
        break;
      case '--description':
      case '-d':
        if (i + 1 >= arguments.length) {
          _printUsageAndExit('Missing value for --description');
        }
        description = arguments[++i];
        break;
      case '--slug':
        if (i + 1 >= arguments.length) {
          _printUsageAndExit('Missing value for --slug');
        }
        slug = arguments[++i];
        break;
      case '--help':
      case '-h':
        _printUsageAndExit(null);
      default:
        if (arguments[i].startsWith('-')) {
          _printUsageAndExit('Unknown option: ${arguments[i]}');
        }
        title = arguments[i];
    }
  }

  if (title == null || title.isEmpty) {
    _printUsageAndExit('Title is required');
  }

  return {
    'title': title,
    'section': section,
    'description': description,
    'slug': slug,
  };
}

Never _printUsageAndExit([String? message]) {
  if (message != null) {
    stderr.writeln('Error: $message\n');
  }
  stdout.writeln('''
Usage: dart run tool/newmd.dart <title> [options]

Options:
  --section, -s <guides|reference>  Section to create file in (default: guides)
  --description, -d <text>         Description for frontmatter
  --slug <slug>                    Custom URL slug (default: auto-generated from title)
  --help, -h                       Show this help message

Examples:
  dart run tool/newmd.dart "Getting Started"
  dart run tool/newmd.dart "Architecture" --section reference
  dart run tool/newmd.dart "CLI Guide" -s guides -d "A comprehensive CLI guide"
''');
  exit(message == null ? 0 : 64);
}

String _generateFrontmatter({required String title, required String description}) {
  return '''---
title: $title
description: $description
---''';
}

/// Converts a title to a URL-friendly slug.
String _toSlug(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'[\s_]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
