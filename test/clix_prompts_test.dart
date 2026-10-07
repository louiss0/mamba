import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

import 'fixtures.dart';
import 'fixtures/clix_io.dart';

void main() {
  test('create awaits Clix answers and retries an empty description', () async {
    final io = ScriptedCliIO(['', 'probe', 'n', 'y']);
    final scaffolder = FakeProjectScaffolder();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      CreateProjectCommand(
        Directory.current,
        projectScaffolder: scaffolder,
        descriptionPrompt: ClixDescriptionPrompt(io: io),
        installPrompt: ClixInstallPrompt(io: io),
        gitPrompt: ClixGitPrompt(io: io),
      ),
    ]).fake().execute(['create', 'probe']);

    expect(result.exitCode, 0);
    expect(scaffolder.projects, [
      (
        packageName: 'probe',
        shortDescription: 'probe',
        installDependencies: false,
        initializeGitRepository: true,
      ),
    ]);
    expect(io.output.toString(), contains('Enter a short description.'));
    expect(io.reads, 4);
  });

  test('Clix setup prompts preserve bare-Enter defaults', () async {
    expect(
      await ClixInstallPrompt(io: ScriptedCliIO([''])).confirmsInstallation(),
      isTrue,
    );
    expect(
      await ClixGitPrompt(io: ScriptedCliIO([''])).confirmsInitialization(),
      isFalse,
    );
  });

  test(
    'create flags skip Clix confirmations rather than consuming input',
    () async {
      final io = ScriptedCliIO([]);
      final scaffolder = FakeProjectScaffolder();
      final result =
          await Executor('tool', 'Tool.', '1.0.0', [
            CreateProjectCommand(
              Directory.current,
              projectScaffolder: scaffolder,
              descriptionPrompt: ClixDescriptionPrompt(io: io),
              installPrompt: ClixInstallPrompt(io: io),
              gitPrompt: ClixGitPrompt(io: io),
            ),
          ]).fake().execute([
            'create',
            'probe',
            'Provided description',
            '--install',
            '--git',
          ]);
      expect(result.exitCode, 0);
      expect(io.reads, 0);
      expect(
        scaffolder.projects.single.shortDescription,
        'Provided description',
      );
      expect(scaffolder.projects.single.installDependencies, isTrue);
      expect(scaffolder.projects.single.initializeGitRepository, isTrue);
    },
  );
}
