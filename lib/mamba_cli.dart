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

/// Scaffolds a regular or group command for a Dart package using Mamba.
final class ScaffoldCommand extends Command {
  new(this._parentDirectory)
    : super(
        mandatoryPositionals: [
          Positional('name', regex: RegExp(r'[a-z][a-z0-9_]*')),
        ],
        discretionaryPositionals: [Positional('file', regex: RegExp(r'.+'))],
        flags: [
          BooleanFlag('group', description: 'Create a group command.'),
          BooleanFlag('hook', description: 'Mix in HookRunner.'),
          BooleanFlag(
            'persistent-hook',
            description: 'Mix in PersistentHookRunner for a group command.',
          ),
          BooleanFlag(
            'with-suite',
            description: 'Create a fake executor test.',
          ),
          BooleanFlag('append', description: 'Append to the supplied file.'),
        ],
      );

  final Directory _parentDirectory;

  @override
  String get name => 'command';

  @override
  String get shortDescription => 'Create a Mamba command.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final commandName = positionals.singles!['name']!;
    final fileName = fileNameFromPositionals(positionals);
    final flags = inputs.boolFlags!;
    final isGroup = flags['group']!;
    final hasHook = flags['hook']!;
    final hasPersistentHook = flags['persistent-hook']!;
    final hasSuite = flags['with-suite']!;
    final shouldAppend = flags['append']!;

    if (hasPersistentHook && !isGroup) {
      throw MambaException('--persistent-hook requires --group.');
    }

    if (fileName != null && !shouldAppend) {
      throw MambaException('A file argument requires --append.');
    }
    if (fileName == null && shouldAppend) {
      throw MambaException('--append requires a file argument.');
    }

    final commandFile = _commandFileFor(commandName, fileName);
    if (fileName != null && !commandFile.existsSync()) {
      throw MambaException('The file $fileName must already exist.');
    }
    if (fileName == null && commandFile.existsSync()) {
      throw MambaException(
        'Cannot create $commandName: the file already exists.',
      );
    }

    _writeCommand(
      commandFile,
      commandName,
      isGroup,
      hasHook,
      hasPersistentHook,
    );
    if (hasSuite) {
      _writeSuite(commandFile, commandName, isGroup);
    }
    return 'Created ${isGroup ? 'group ' : ''}command in ${commandFile.path}.';
  }

  String? fileNameFromPositionals(ParsedPositionals positionals) =>
      positionals.singles!['file'];

  File _commandFileFor(String commandName, String? fileName) => fileName == null
      ? File('${_parentDirectory.path}/lib/$commandName.dart')
      : File(fileName);

  void _writeCommand(
    File commandFile,
    String commandName,
    bool isGroup,
    bool hasHook,
    bool hasPersistentHook,
  ) {
    final source = _commandSource(
      commandName,
      isGroup,
      hasHook,
      hasPersistentHook,
    );
    if (commandFile.existsSync()) {
      commandFile.writeAsStringSync('\n$source', mode: FileMode.append);
      return;
    }

    commandFile.parent.createSync(recursive: true);
    commandFile.writeAsStringSync(
      "import 'package:mamba/mamba.dart';\n\n$source",
    );
  }

  void _writeSuite(File commandFile, String commandName, bool isGroup) {
    final suiteFile = File(
      '${_parentDirectory.path}/test/${commandName}_test.dart',
    );
    if (suiteFile.existsSync()) {
      throw MambaException(
        'Cannot create $commandName test: the file already exists.',
      );
    }

    suiteFile.parent.createSync(recursive: true);
    suiteFile.writeAsStringSync(
      _suiteSource(commandFile, suiteFile, commandName),
    );
  }

  String _commandSource(
    String commandName,
    bool isGroup,
    bool hasHook,
    bool hasPersistentHook,
  ) {
    final className = _classNameFor(commandName);
    final mixins = [
      if (hasHook) 'HookRunner',
      if (hasPersistentHook) 'PersistentHookRunner',
    ];
    final declaration = [
      'final class $className extends ${isGroup ? 'GroupCommand' : 'Command'}',
      if (mixins.isNotEmpty) 'with ${mixins.join(', ')}',
      '{',
    ].join(' ');
    final constructor = isGroup ? '\n  $className() : super([]);\n' : '';
    final hooks = hasHook
        ? '''
  @override
  void preRun(
    ProcessedStandardInput? input,
    MambaReadContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {}
'''
        : '';
    final persistentHooks = hasPersistentHook
        ? '''
  @override
  void prePersistentRun(
    MambaContext context,
    ParsedPositionals positionals,
    ParsedSingleOptions options,
  ) {}
'''
        : '';

    return '''$declaration$constructor
  @override
  String get name => '$commandName';

  @override
  String get shortDescription => 'Describe $commandName.';
$hooks$persistentHooks
  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => '';
}
''';
  }

  String _suiteSource(File commandFile, File suiteFile, String commandName) {
    final className = _classNameFor(commandName);
    final relativeCommandPath = _relativePath(suiteFile.parent, commandFile);
    final commands = '$className()';
    return '''import '$relativeCommandPath';
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

void main() {
  test('$commandName shows help', () async {
    final result = await Executor(
      'app',
      'A command-line application.',
      [$commands],
    ).fake().execute([]);

    expect(result, isA<MambaSuccessResult>());
  });
}
''';
  }

  String _classNameFor(String commandName) =>
      '${commandName.split('_').map((word) => '${word[0].toUpperCase()}${word.substring(1)}').join()}Command';

  String _relativePath(Directory from, File to) {
    final fromParts = from.absolute.path.replaceAll('\\', '/').split('/');
    final toParts = to.absolute.path.replaceAll('\\', '/').split('/');
    var sharedLength = 0;
    while (sharedLength < fromParts.length &&
        sharedLength < toParts.length &&
        fromParts[sharedLength].toLowerCase() ==
            toParts[sharedLength].toLowerCase()) {
      sharedLength++;
    }
    return [
      ...List.filled(fromParts.length - sharedLength, '..'),
      ...toParts.skip(sharedLength),
    ].join('/');
  }
}
