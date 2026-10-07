import 'dart:convert';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:mamba/mamba_cli.dart';

void emitResult(Object? value) =>
    stdout.writeln('CLIX_RESULT=${jsonEncode(value)}');

final class RecordingScaffolder implements ProjectScaffolder {
  @override
  void scaffold(
    String packageName,
    String shortDescription, {
    required bool installDependencies,
    required bool initializeGitRepository,
  }) => emitResult({
    'description': shortDescription,
    'install': installDependencies,
    'git': initializeGitRepository,
  });
}

Future<void> main(List<String> arguments) async {
  switch (arguments.first) {
    case 'create' || 'create-custom' || 'create-flags':
      final result =
          await Executor('probe', 'Probe.', '1.0.0', [
            CreateProjectCommand(
              Directory.current,
              projectScaffolder: RecordingScaffolder(),
            ),
          ]).fake().execute([
            'create',
            'keyboard_probe',
            if (arguments.first == 'create-custom') ...[
              '--description',
              'Custom description',
            ],
            if (arguments.first == 'create-flags') ...['--install', '--git'],
          ]);
      if (result case MambaFailureResult(:final message)) {
        emitResult({'error': message});
        exitCode = result.exitCode;
      }
    case 'input':
      emitResult(await ClixInput(prompt: 'Clix input').interact());
    case 'selector':
      emitResult(
        await ClixSelector(
          prompt: 'Clix selection',
          options: ['Alpha', 'Alpine', 'Beta'],
        ).interact(),
      );
    case 'picker':
      emitResult(
        await ClixDirectoryPicker(
          prompt: 'Clix directory',
          startDirectory: Directory(arguments[1]),
        ).interact(),
      );
    case 'spinner':
      emitResult(await Spinner('Clix spinner').whileRunning(() async => 17));
    case 'spinner-error':
      try {
        await Spinner('Clix spinner')
            .whileRunning<int>(() async => throw StateError('work failed'));
      } on StateError catch (error) {
        emitResult(error.message);
      }
    default:
      throw ArgumentError.value(arguments, 'arguments');
  }
}
