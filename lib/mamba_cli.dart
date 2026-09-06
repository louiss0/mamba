import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/errors.dart';

/// Scaffolds a Dart console package configured to use Mamba.
final class CreateProjectCommand extends Command {
  new(this._parentDirectory)
    : super(
        mandatoryPositionals: [
          Positional('package-name', regex: RegExp(r'[a-z][a-z0-9_]*')),
        ],
      );

  final Directory _parentDirectory;

  @override
  String get name => 'create';

  @override
  String get shortDescription =>
      'Create a Dart console application using Mamba.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final packageName = positionals.singles!['package-name']!;
    final projectDirectory = Directory('${_parentDirectory.path}/$packageName');
    if (projectDirectory.existsSync()) {
      throw MambaException(
        'Cannot create $packageName: the directory already exists.',
      );
    }

    _createProject(projectDirectory, packageName);
    return 'Created Mamba command-line application in ${projectDirectory.path}.';
  }

  void _createProject(Directory projectDirectory, String packageName) {
    projectDirectory.createSync();
    Directory('${projectDirectory.path}/bin').createSync();
    Directory('${projectDirectory.path}/lib').createSync();
    Directory('${projectDirectory.path}/test').createSync();

    File('${projectDirectory.path}/pubspec.yaml')
        .writeAsStringSync(_pubspec(packageName));
    File('${projectDirectory.path}/analysis_options.yaml')
        .writeAsStringSync("include: package:lints/recommended.yaml\n");
    File('${projectDirectory.path}/CHANGELOG.md').writeAsStringSync(
      '# Changelog\n\nAll notable changes to this project will be documented in this file.\n',
    );
    File('${projectDirectory.path}/README.md').writeAsStringSync(
      '# $packageName\n\nA command-line application built with Mamba.\n',
    );
    File('${projectDirectory.path}/lib/$packageName.dart')
        .writeAsStringSync(_library(packageName));
    File('${projectDirectory.path}/bin/$packageName.dart')
        .writeAsStringSync(_executable(packageName));
    File('${projectDirectory.path}/test/${packageName}_test.dart')
        .writeAsStringSync(_test(packageName));
  }

  String _pubspec(String packageName) => '''name: $packageName
description: A command-line application built with Mamba.
version: 1.0.0
environment:
  sdk: ^3.13.2

dependencies:
  mamba: ^0.3.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.6
''';

  String _library(String packageName) =>
      '''import 'package:mamba/mamba.dart';

Executor createExecutor() => Executor(
  '$packageName',
  'A command-line application.',
  [],
);
''';

  String _executable(String packageName) =>
      '''import 'package:$packageName/$packageName.dart';

Future<void> main(List<String> arguments) => createExecutor().create().execute(arguments);
''';

  String _test(String packageName) =>
      '''import 'package:$packageName/$packageName.dart';
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('shows help when no command is selected', () async {
    final result = await createExecutor().fake().execute([]);

    expect(result, isA<MambaSuccessResult>());
  });
}
''';
}
