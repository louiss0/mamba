import 'dart:io';

const _versionPattern = r'^\d+\.\d+\.\d+$';

Future<void> main(List<String> arguments) async {
  final release = _parseRelease(arguments);
  final version = release.version;

  await _verifyReleaseState(version);
  await _runChecked('dart', ['format', '.']);
  await _verifyCleanWorktree();
  await _runChecked('dart', ['analyze']);
  await _runChecked('dart', ['test']);
  await _runChecked('dart', ['pub', 'publish', '--dry-run']);

  final tag = 'v$version';
  if (!release.push) {
    stdout.writeln(
      'Release checks passed for $tag. Re-run with --push to create and push '
      'the tag.',
    );
    return;
  }

  await _runChecked('git', ['tag', '-a', tag, '-m', 'Release $version']);
  await _runChecked('git', ['push', 'origin', tag]);
  stdout.writeln(
    'Pushed $tag. The Publish to pub.dev workflow will publish Mamba.',
  );
}

Release _parseRelease(List<String> arguments) {
  String? version;
  var push = false;

  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--version':
        if (index + 1 == arguments.length) _printUsageAndExit();
        version = arguments[++index];
        break;
      case '--push':
        push = true;
        break;
      case '--help':
      case '-h':
        _printUsageAndExit();
      default:
        stderr.writeln('Unknown argument: ${arguments[index]}');
        _printUsageAndExit();
    }
  }

  if (version == null || !RegExp(_versionPattern).hasMatch(version)) {
    stderr.writeln('Pass a stable semantic version with --version X.Y.Z.');
    _printUsageAndExit();
  }

  return Release(version: version, push: push);
}

Never _printUsageAndExit() {
  stdout.writeln('Usage: dart run tool/release.dart --version X.Y.Z [--push]');
  exitCode = 64;
  exit(exitCode);
}

Future<void> _verifyReleaseState(String version) async {
  final branch = (await _runChecked('git', [
    'branch',
    '--show-current',
  ])).trim();
  if (branch != 'main') {
    throw StateError(
      "Releases must be created from main; current branch is '$branch'.",
    );
  }

  await _verifyCleanWorktree();

  final pubspec = await File('pubspec.yaml').readAsString();
  final pubspecVersion = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec)?.group(1);
  if (pubspecVersion == null) {
    throw StateError('pubspec.yaml does not declare a version.');
  }
  if (pubspecVersion != version) {
    throw StateError(
      'pubspec.yaml has version $pubspecVersion; expected $version.',
    );
  }

  final changelog = await File('CHANGELOG.md').readAsString();
  final changelogHeading = RegExp(
    '^##\\s+${RegExp.escape(version)}\\s*\$',
    multiLine: true,
  );
  if (!changelogHeading.hasMatch(changelog)) {
    throw StateError("CHANGELOG.md must contain a '## $version' section.");
  }

  final tag = 'v$version';
  final tagCheck = await Process.run('git', [
    'rev-parse',
    '--verify',
    '--quiet',
    'refs/tags/$tag',
  ]);
  if (tagCheck.exitCode == 0) {
    throw StateError('The $tag tag already exists.');
  }
  if (tagCheck.exitCode != 1) {
    throw ProcessException(
      'git',
      ['rev-parse', '--verify', '--quiet', 'refs/tags/$tag'],
      '${tagCheck.stdout}${tagCheck.stderr}',
      tagCheck.exitCode,
    );
  }
}

Future<void> _verifyCleanWorktree() async {
  final status = await _runChecked('git', ['status', '--porcelain']);
  if (status.isNotEmpty) {
    throw StateError('The working tree must be clean before a release.');
  }
}

Future<String> _runChecked(String command, List<String> arguments) async {
  final result = await Process.run(command, arguments);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      command,
      arguments,
      'Command failed.',
      result.exitCode,
    );
  }
  return result.stdout as String;
}

final class Release {
  const Release({required this.version, required this.push});

  final String version;
  final bool push;
}
