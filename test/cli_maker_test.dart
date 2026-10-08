import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';
import 'package:test/test.dart';

import 'fixtures.dart';
import 'fixtures/clix_io.dart';

final class _SkillPrompt(final bool answer) implements CliMakerPrompt {
  var questions = 0;

  @override
  Future<bool> confirmsInstallation() async {
    questions++;
    return answer;
  }
}

final class _Scaffolder implements ProjectScaffolder {
  final choices = <bool>[];

  @override
  void scaffold(
    String packageName,
    String shortDescription, {
    required bool installDependencies,
    required bool initializeGitRepository,
    bool installCliMaker = false,
  }) {
    choices.add(installCliMaker);
  }
}

void main() {
  group('cli-maker setup', () {
    for (final answer in [false, true]) {
      test('uses the prompt answer $answer when no flag answers it', () async {
        final prompt = _SkillPrompt(answer);
        final scaffolder = _Scaffolder();
        final result = await Executor('tool', 'Tool.', '1.0.0', [
          CreateProjectCommand(
            Directory.current,
            projectScaffolder: scaffolder,
            installPrompt: FakeInstallPrompt(shouldInstall: false),
            gitPrompt: FakeGitPrompt(shouldInitialize: false),
            cliMakerPrompt: prompt,
          ),
        ]).fake().execute(['create', 'demo']);

        expect(result, isA<MambaSuccessResult>());
        expect(prompt.questions, 1);
        expect(scaffolder.choices, [answer]);
      });
    }

    for (final (flag, expected) in [
      ('--cli-maker', true),
      ('--no-cli-maker', false),
    ]) {
      test('$flag answers the skill step without prompting', () async {
        final prompt = _SkillPrompt(!expected);
        final scaffolder = _Scaffolder();
        final result = await Executor('tool', 'Tool.', '1.0.0', [
          CreateProjectCommand(
            Directory.current,
            projectScaffolder: scaffolder,
            installPrompt: FakeInstallPrompt(shouldInstall: false),
            gitPrompt: FakeGitPrompt(shouldInitialize: false),
            cliMakerPrompt: prompt,
          ),
        ]).fake().execute(['create', 'demo', '--install', '--git', flag]);

        expect(result, isA<MambaSuccessResult>());
        expect(prompt.questions, 0);
        expect(scaffolder.choices, [expected]);
      });
    }

    test(
      'rejects contradictory flags before prompting or scaffolding',
      () async {
        final prompt = _SkillPrompt(true);
        final scaffolder = _Scaffolder();
        final result = await Executor('tool', 'Tool.', '1.0.0', [
          CreateProjectCommand(
            Directory.current,
            projectScaffolder: scaffolder,
            cliMakerPrompt: prompt,
          ),
        ]).fake().execute(['create', 'demo', '--cli-maker', '--no-cli-maker']);

        expect(result, isA<MambaFailureResult>());
        expect((result as MambaFailureResult).message, contains('cli-maker'));
        expect(prompt.questions, 0);
        expect(scaffolder.choices, isEmpty);
      },
    );

    test('bare Enter declines the optional skill', () async {
      final io = ScriptedCliIO(['']);
      expect(await ClixCliMakerPrompt(io: io).confirmsInstallation(), isFalse);
      expect(io.reads, 1);
      expect(io.output.toString(), contains('cli-maker'));
    });

    test('offers both scripted choices in help without asking', () async {
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        CreateProjectCommand(Directory.current),
      ]).fake().execute(['create', '--help']);

      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, contains('--cli-maker'));
      expect(result.output, contains('--no-cli-maker'));
    });
  });

  group('skill installation selection', () {
    for (final optedIn in [false, true]) {
      test('installs only the selected skills when opt-in is $optedIn', () {
        final runner = FakeProjectProcessRunner();
        final root = tempDirectory('mamba_cli_maker_');
        DirectoryProjectScaffolder(
          root,
          processRunner: runner,
          sourceFormatter: FakeSourceFormatter(),
        ).scaffold(
          'demo',
          'Demo.',
          installDependencies: false,
          initializeGitRepository: false,
          installCliMaker: optedIn,
        );

        expect(runner.invocations, hasLength(2));
        for (final (index, agent) in ['generic', 'claude'].indexed) {
          final invocation = runner.invocations[index];
          expect(invocation.$1, 'dart');
          expect(invocation.$2, [
            'run',
            'skills@',
            'get',
            '-p',
            'mamba',
            '--skill',
            'mamba-framework',
            if (optedIn) ...['--skill', 'mamba-cli-maker'],
            '--agent',
            agent,
          ]);
        }
        final instructions = File('${root.path}/demo/AGENTS.md')
            .readAsStringSync();
        expect(instructions.contains('## CLI design'), optedIn);
      });
    }

    test('ships the imported skill and its relative references', () {
      final skill = File('skills/mamba-cli-maker/SKILL.md').readAsStringSync();
      expect(skill, contains('name: mamba-cli-maker'));
      expect(
        File('skills/mamba-cli-maker/references/args-and-flags.md')
            .existsSync(),
        isTrue,
      );
      expect(
        File('skills/mamba-cli-maker/references/cli-models.md').existsSync(),
        isTrue,
      );
    });
  });
}
