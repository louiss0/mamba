import 'package:arg_parser/arg_parser.dart';
import 'package:test/test.dart';

void main() {
  test(
    'selects a nested command and invokes its handler with named values',
    () async {
      YargsCommandArguments? received;
      final runtime = YargsCommandRuntime(
        commands: [
          YargsCommand(
            'remote',
            commands: [
              YargsCommand(
                'add',
                positionals: const [YargsPositional('name', required: true)],
                options: const [
                  YargsCommandOption.boolean('fetch', alias: 'f'),
                ],
                handler: (arguments) => received = arguments,
              ),
            ],
          ),
        ],
      );

      final outcome = await runtime.run(['remote', 'add', 'origin', '--fetch']);

      expect(outcome, isA<YargsCommandSuccess>());
      expect(received?.commandPath, ['remote', 'add']);
      expect(received?.positional('name'), 'origin');
      expect(received?.flag('fetch'), true);
    },
  );

  test(
    'keeps root options active before and after the selected command',
    () async {
      YargsCommandArguments? received;
      final runtime = YargsCommandRuntime(
        options: const [YargsCommandOption.boolean('verbose', alias: 'v')],
        commands: [
          YargsCommand(
            'deploy',
            positionals: const [YargsPositional('file', required: true)],
            handler: (arguments) => received = arguments,
          ),
        ],
      );

      final outcome = await runtime.run(['-v', 'deploy', 'README.md']);

      expect(outcome, isA<YargsCommandSuccess>());
      expect(received?.flag('verbose'), true);
      expect(received?.positional('file'), 'README.md');
    },
  );

  test('validates required option values and declared choices', () async {
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'deploy',
          options: const [
            YargsCommandOption.string(
              'region',
              required: true,
              choices: {'eu', 'us'},
            ),
          ],
        ),
      ],
    );

    final accepted = await runtime.run(['deploy', '--region', 'eu']);
    final missing = await runtime.run(['deploy']);
    final invalid = await runtime.run(['deploy', '--region', 'moon']);

    expect(accepted, isA<YargsCommandSuccess>());
    expect((accepted as YargsCommandSuccess).arguments['region'], 'eu');
    expect(missing, isA<YargsCommandFailure>());
    expect((missing as YargsCommandFailure).message, contains('--region'));
    expect(invalid, isA<YargsCommandFailure>());
    expect((invalid as YargsCommandFailure).message, contains('eu, us'));
  });

  test(
    'forwards number, array, and narg option hints to YargsParser',
    () async {
      YargsCommandArguments? received;
      final runtime = YargsCommandRuntime(
        commands: [
          YargsCommand(
            'deploy',
            options: const [
              YargsCommandOption.number('retries'),
              YargsCommandOption.array('tag'),
              YargsCommandOption.string('range', narg: 2),
            ],
            handler: (arguments) => received = arguments,
          ),
        ],
      );

      final outcome = await runtime.run([
        'deploy',
        '--retries',
        '3',
        '--tag',
        'stable',
        'release',
        '--range',
        'eu',
        'us',
      ]);

      expect(outcome, isA<YargsCommandSuccess>());
      expect(received?['retries'], 3);
      expect(received?['tag'], ['stable', 'release']);
      expect(received?['range'], ['eu', 'us']);
    },
  );

  test('binds explicit required, optional, and variadic positionals', () async {
    YargsCommandArguments? received;
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'copy',
          positionals: const [
            YargsPositional('source', required: true),
            YargsPositional('destination'),
            YargsPositional('extras', multiple: true),
          ],
          handler: (arguments) => received = arguments,
        ),
      ],
    );

    final outcome = await runtime.run(['copy', 'a', 'b', 'c', 'd']);

    expect(outcome, isA<YargsCommandSuccess>());
    expect(received?.positional('source'), 'a');
    expect(received?.positional('destination'), 'b');
    expect(received?.positionals('extras'), ['c', 'd']);
  });

  test('validates conflicting and implied options', () async {
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'deploy',
          options: const [
            YargsCommandOption.boolean('force', conflicts: {'safe'}),
            YargsCommandOption.boolean('safe'),
            YargsCommandOption.boolean('publish', implies: {'token'}),
            YargsCommandOption.string('token'),
          ],
        ),
      ],
    );

    final conflict = await runtime.run(['deploy', '--force', '--safe']);
    final implication = await runtime.run(['deploy', '--publish']);
    final accepted = await runtime.run([
      'deploy',
      '--publish',
      '--token',
      'secret',
    ]);

    expect(conflict, isA<YargsCommandFailure>());
    expect((conflict as YargsCommandFailure).message, contains('--safe'));
    expect(implication, isA<YargsCommandFailure>());
    expect((implication as YargsCommandFailure).message, contains('--token'));
    expect(accepted, isA<YargsCommandSuccess>());
  });

  test('returns strict failures for unknown commands and options', () async {
    final runtime = YargsCommandRuntime(commands: [YargsCommand('deploy')]);

    final unknownCommand = await runtime.run(['install']);
    final unknownOption = await runtime.run(['deploy', '--mystery']);

    expect(unknownCommand, isA<YargsCommandFailure>());
    expect(
      (unknownCommand as YargsCommandFailure).message,
      contains('Unknown command'),
    );
    expect(unknownOption, isA<YargsCommandFailure>());
    expect(
      (unknownOption as YargsCommandFailure).message,
      contains('--mystery'),
    );
  });

  test('returns handler failures as command outcomes', () async {
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'deploy',
          handler: (_) => throw StateError('deployment failed'),
        ),
      ],
    );

    final outcome = await runtime.run(['deploy']);

    expect(outcome, isA<YargsCommandFailure>());
    expect(
      (outcome as YargsCommandFailure).message,
      contains('deployment failed'),
    );
  });

  test('rejects ambiguous command and positional declarations', () {
    expect(
      () => YargsCommandRuntime(
        commands: [
          YargsCommand('deploy', aliases: const ['run']),
          YargsCommand('run'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => YargsCommandRuntime(
        commands: [
          YargsCommand(
            'copy',
            positionals: const [
              YargsPositional('files', multiple: true),
              YargsPositional('destination'),
            ],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('renders dependency-free help and completion candidates', () {
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'deploy',
          description: 'Publish an artifact.',
          options: const [
            YargsCommandOption.boolean(
              'verbose',
              alias: 'v',
              description: 'Show detailed output.',
            ),
          ],
          commands: [
            YargsCommand('status', description: 'Show deployment state.'),
          ],
        ),
      ],
    );

    expect(runtime.help(), contains('deploy'));
    expect(
      runtime.help(['deploy']),
      allOf(contains('--verbose'), contains('status')),
    );
    expect(runtime.completionCandidates(['dep']), ['deploy']);
    expect(runtime.completionCandidates(['deploy', '-']), ['--verbose', '-v']);
  });

  test('normalizes command aliases in the selected command path', () async {
    final runtime = YargsCommandRuntime(
      commands: [
        YargsCommand(
          'remote',
          aliases: const ['r'],
          commands: [
            YargsCommand('status', aliases: const ['s']),
          ],
        ),
      ],
    );

    final outcome = await runtime.run(['r', 's']);

    expect(outcome, isA<YargsCommandSuccess>());
    expect((outcome as YargsCommandSuccess).arguments.commandPath, [
      'remote',
      'status',
    ]);
  });
}
