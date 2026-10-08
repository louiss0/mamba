import 'dart:io';

import 'package:mamba/command.dart';
import 'package:mamba/context.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

class TestGroupCommand extends GroupCommand {
  new(
    this.name,
    super.commands,
    this.shortDescription, {
    super.aliases,
    super.propagatedFlags,
    super.propagatedOptions,
    super.flags,
    super.options,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
  });

  @override
  final String name;

  @override
  final String shortDescription;
}

class TestCommand extends Command {
  new(
    this.name,
    this.shortDescription, {
    super.longDescription,
    super.aliases,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.variadic,
    super.flags,
    super.options,
    super.pairedOptions,
    super.conflicts,
    super.accessors,
  });

  @override
  String run(ValueOf valueOf, List<String> args) => '';

  @override
  final String name;

  @override
  final String shortDescription;
}

/// A command that keeps whatever the invocation piped into it.
final class InputCommand extends Command with HookRunner {
  ProcessedStandardInput? _input;

  @override
  String get name => 'input';

  @override
  String get shortDescription => 'Read standard input.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    _input = input;
  }

  @override
  String? run(ValueOf valueOf, List<String> args) => _input?.utf8Text;

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    _input = null;
  }
}

/// Removes the SGR sequences a help formatter writes.
///
/// Every suite that asserts on help needs this, and the pattern is the same
/// one [FormattedString] requires, so it is defined once here rather than
/// re-declared per file.
String stripAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

/// Creates a temporary directory that is deleted when the current test ends.
Directory tempDirectory([String prefix = 'mamba_']) {
  final directory = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

/// Runs `dart analyze` over [source] and asserts on the outcome.
///
/// [expectedDiagnostics] empty means the file has to pass; otherwise the
/// analysis has to fail and every named diagnostic has to appear. One
/// harness serves every test that proves a type is caught statically.
Future<void> expectAnalysis(
  String source, {
  List<String> expectedDiagnostics = const [],
  String fileName = 'analysis_subject_temp.dart',
}) async {
  final file = File('test/$fileName')..writeAsStringSync(source);
  try {
    final result = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      file.path,
    ]);
    final diagnostics = '${result.stdout}\n${result.stderr}';

    if (expectedDiagnostics.isEmpty) {
      expect(result.exitCode, 0, reason: diagnostics);
      return;
    }
    expect(result.exitCode, isNot(0), reason: diagnostics);
    for (final diagnostic in expectedDiagnostics) {
      expect(diagnostics, contains(diagnostic));
    }
  } finally {
    if (file.existsSync()) file.deleteSync();
  }
}

final class FakeSourceFormatter implements SourceFormatter {
  final formatted = <String>[];

  @override
  void formatSource(String path) => formatted.add(path);
}

/// The shared formatter instance so a test can read what was formatted.
final sourceFormatter = FakeSourceFormatter();

/// A [DirectoryProjectScaffolder] wired to fakes, for tests that only care
/// about the files a scaffold writes.
DirectoryProjectScaffolder realScaffolding(
  Directory parent, {
  ProjectProcessRunner? processRunner,
}) => DirectoryProjectScaffolder(
  parent,
  processRunner: processRunner ?? FakeProjectProcessRunner(),
  sourceFormatter: sourceFormatter,
);

final class FakeProjectScaffolder implements ProjectScaffolder {
  final projects =
      <
        ({
          String packageName,
          String shortDescription,
          bool installDependencies,
          bool initializeGitRepository,
        })
      >[];

  @override
  void scaffold(
    String packageName,
    String shortDescription, {
    required bool installDependencies,
    required bool initializeGitRepository,
    bool installCliMaker = false,
  }) {
    projects.add((
      packageName: packageName,
      shortDescription: shortDescription,
      installDependencies: installDependencies,
      initializeGitRepository: initializeGitRepository,
    ));
  }
}

final class FakeProjectProcessRunner implements ProjectProcessRunner {
  final invocations = <(String, List<String>, String)>[];

  @override
  void run(String executable, List<String> arguments, String workingDirectory) {
    invocations.add((executable, arguments, workingDirectory));
  }
}

final class FakeInstallPrompt implements InstallPrompt {
  new({required this.shouldInstall});

  final bool shouldInstall;
  var questions = 0;

  @override
  bool confirmsInstallation() {
    questions++;
    return shouldInstall;
  }
}

final class FakeGitPrompt implements GitPrompt {
  new({required this.shouldInitialize});

  final bool shouldInitialize;
  var questions = 0;

  @override
  bool confirmsInitialization() {
    questions++;
    return shouldInitialize;
  }
}

final class FakeCliMakerPrompt implements CliMakerPrompt {
  new({this.shouldInstall = false});

  final bool shouldInstall;
  var questions = 0;

  @override
  bool confirmsInstallation() {
    questions++;
    return shouldInstall;
  }
}
