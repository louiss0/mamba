import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

import 'fixtures.dart';
import 'fixtures/clix_io.dart';

void main() {
  test(
    'create asks for installation, Git, and optional CLI guidance',
    () async {
      final io = ScriptedCliIO(['n', 'y', 'n']);
      final scaffolder = FakeProjectScaffolder();
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        CreateProjectCommand(
          Directory.current,
          projectScaffolder: scaffolder,
          installPrompt: ClixInstallPrompt(io: io),
          gitPrompt: ClixGitPrompt(io: io),
          cliMakerPrompt: ClixCliMakerPrompt(io: io),
        ),
      ]).fake().execute(['create', 'probe']);

      expect(result.exitCode, 0);
      expect(scaffolder.projects, [
        (
          packageName: 'probe',
          shortDescription: 'This is a CLI app',
          installDependencies: false,
          initializeGitRepository: true,
        ),
      ]);
      expect(io.output.toString(), isNot(contains('Short description')));
      expect(io.reads, 3);
    },
  );

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

  for (final (descriptionArgs, expectedDescription) in [
    (<String>[], 'This is a CLI app'),
    (['--description', 'Provided description'], 'Provided description'),
  ]) {
    test(
      'create with $descriptionArgs and setup flags reads no input',
      () async {
        final io = ScriptedCliIO([]);
        final scaffolder = FakeProjectScaffolder();
        final result =
            await Executor('tool', 'Tool.', '1.0.0', [
              CreateProjectCommand(
                Directory.current,
                projectScaffolder: scaffolder,
                installPrompt: ClixInstallPrompt(io: io),
                gitPrompt: ClixGitPrompt(io: io),
                cliMakerPrompt: ClixCliMakerPrompt(io: io),
              ),
            ]).fake().execute([
              'create',
              'probe',
              ...descriptionArgs,
              '--install',
              '--git',
              '--no-cli-maker',
            ]);
        expect(result.exitCode, 0);
        expect(io.reads, 0);
        expect(scaffolder.projects, [
          (
            packageName: 'probe',
            shortDescription: expectedDescription,
            installDependencies: true,
            initializeGitRepository: true,
          ),
        ]);
      },
    );
  }
}
