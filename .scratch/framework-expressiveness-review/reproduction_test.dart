import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

final class ProbeCommand extends Command {
  new(
    this.name, {
    super.flags,
    super.options,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.accessors,
    super.conflicts,
    this.body,
  });

  @override
  final String name;
  @override
  String get shortDescription => 'Review probe.';
  final String Function(ParsedInputs)? body;
  @override
  String run(ParsedInputs inputs, List<String> args) =>
      body?.call(inputs) ?? name;
}

String? failureMessage(MambaExecutionResult result) =>
    result is MambaFailureResult ? result.message : null;

void main() {
  test(
    'documented limitation: default strings reject shell-tokenized spaces',
    () async {
      final title = StringOption('title');
      final runner = Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand('run', options: [title], body: (i) => i.valueOf(title)!),
      ]).fake();
      final result = await runner.execute(['run', '--title', 'hello world']);
      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).message,
        "Option --title does not accept 'hello world'.",
      );
    },
  );

  test(
    'conflicting default must not behave as an explicitly supplied option',
    () async {
      final output = StringOption.withDefault('output', defaultValue: 'text');
      const replace = BooleanFlag('replace');
      final runner = Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand(
          'run',
          options: [output],
          flags: [replace],
          conflicts: {
            'replace': ['output'],
          },
        ),
      ]).fake();
      final result = await runner.execute(['run', '--replace']);
      expect(result, isA<MambaSuccessResult>(), reason: failureMessage(result));
    },
  );

  test(
    'effective inherited flag and local option cannot share a long spelling',
    () {
      const global = BooleanFlag('mode');
      final local = StringOption('mode');
      expect(
        () => Executor(
          'app',
          'Review app.',
          '1.0.0',
          [
            ProbeCommand('run', options: [local]),
          ],
          flags: [global],
        ).fake(),
        throwsA(isA<MambaRegistryError>()),
      );
    },
  );

  test(
    'existing policy: explicit no-cache shadows the generated negation',
    () async {
      const cache = BooleanFlag('cache', negatable: true, defaultValue: true);
      const noCache = BooleanFlag('no-cache');
      final result = await Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand(
          'run',
          flags: [cache, noCache],
          body: (i) =>
              'cache=${i.valueOf(cache)}, no-cache=${i.valueOf(noCache)}',
        ),
      ]).fake().execute(['run', '--no-cache']);
      expect(
        (result as MambaSuccessResult).output,
        'cache=true, no-cache=true',
      );
    },
  );

  test('small stepped doubles must complete to values the parser accepts', () {
    const ratio = DoubleOption('ratio', min: 1e-7, max: 3e-7, step: 1e-7);
    final registry = CommandRegistry.create(
      'app',
      'Review app.',
      commands: [
        ProbeCommand('run', options: [ratio]),
      ],
    );
    final script = ToPowerShellCompletionConverter(registry.toRecord())
        .convert();
    final line = script
        .split('\n')
        .singleWhere((line) => line.contains("['root.run.--ratio'] = @("));
    final candidates = RegExp("'([^']+)'")
        .allMatches(line)
        .skip(1)
        .map((match) => match.group(1)!)
        .toList();
    expect(candidates, isNotEmpty);
    for (final candidate in candidates) {
      expect(
        () => Parser(registry).parse(['run', '--ratio=$candidate']),
        returnsNormally,
        reason: 'Generated candidates: $candidates',
      );
    }
  });

  test('step declaration without finite bounds should be rejected', () {
    const ratio = DoubleOption('ratio', step: 0.25);
    expect(
      () => Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand('run', options: [ratio]),
      ]).fake(),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test(
    'invalid non-finite numeric defaults should be refused at registration',
    () {
      final ratio = DoubleOption.withDefault('ratio', defaultValue: double.nan);
      expect(
        () => Executor('app', 'Review app.', '1.0.0', [
          ProbeCommand('run', options: [ratio]),
        ]).fake(),
        throwsA(isA<MambaRegistryError>()),
      );
    },
  );

  test('a completion command shared between executors must use the invoking registry', () async {
    String? generated;
    final completion = CompletionCommand(
      createFile: (_, content) => generated = content,
    );
    final first = Executor('first', 'First app.', '1.0.0', [completion]).fake();
    Executor('second', 'Second app.', '1.0.0', [completion]).fake();
    final result = await first.execute(['completion', 'powershell']);
    expect(result, isA<MambaSuccessResult>(), reason: failureMessage(result));
    final registration = generated!
        .split('\n')
        .singleWhere((line) => line.startsWith('Register-ArgumentCompleter'));
    expect(registration, contains("-CommandName 'first'"));
  });

  test(
    'empty defaulted repeated choice must still produce its non-null list',
    () async {
      final choices = RepeatedChoicePositional.withDefault(
        'values',
        choices: ShellCompletion.values,
        defaultValue: <ShellCompletion>[],
      );
      final result = await Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand(
          'run',
          discretionaryPositionals: [choices],
          body: (i) => '${i.valueOf(choices)}',
        ),
      ]).fake().execute(['run']);
      expect(result, isA<MambaSuccessResult>(), reason: failureMessage(result));
    },
  );

  test(
    'documented limitation: -- does not supply a required positional',
    () async {
      final path = NormalPositional('path');
      final result = await Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand(
          'run',
          mandatoryPositionals: [path],
          body: (i) => i.valueOf(path),
        ),
      ]).fake().execute(['run', '--', '-file']);
      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).message,
        contains('path is required'),
      );
    },
  );

  test(
    'control: generic string options swallow a control flag as a value',
    () async {
      final label = StringOption('label');
      final result = await Executor('app', 'Review app.', '1.0.0', [
        ProbeCommand('run', options: [label], body: (i) => i.valueOf(label)!),
      ]).fake().execute(['run', '--label', '--help']);
      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, '--help');
    },
  );

  test(
    'documented limitation: parent local option is rejected with a child',
    () async {
      final endpoint = StringOption('endpoint');
      final group = GroupWithLocalOption(endpoint, [ProbeCommand('run')]);
      final result = await Executor('app', 'Review app.', '1.0.0', [
        group,
      ]).fake().execute(['group', '--endpoint', 'host', 'run']);
      expect(result, isA<MambaFailureResult>());
      expect(
        (result as MambaFailureResult).message,
        'Unknown flag or option --endpoint.',
      );
    },
  );

  test(
    'required accessor leaves must retain requiredness in Carapace metadata',
    () {
      final host = AccessorStringOption.required('host');
      final registry = CommandRegistry.create(
        'app',
        'Review app.',
        commands: [
          ProbeCommand(
            'run',
            accessors: [
              AccessorListOption('config', [host]),
            ],
          ),
        ],
      );
      expect(
        () => Parser(registry).parse(['run']),
        throwsA(isA<MambaParseException>()),
      );
      final spec = CarapaceSpecConverter(registry.toRecord()).convert();
      final entry = spec
          .split('\n')
          .singleWhere((line) => line.contains('--config.host'));
      expect(entry, contains('--config.host!='));
    },
  );

  test('hidden accessor groups must not be advertised in Bash completion', () {
    final registry = CommandRegistry.create(
      'app',
      'Review app.',
      accessors: [
        AccessorListOption('internal', [
          AccessorStringOption('token'),
        ], hidden: true),
      ],
    );
    final script = ToBashCompletionConverter(registry.toRecord()).convert();
    expect(
      script.contains('--internal.token'),
      isFalse,
      reason:
          'Hidden accessor spelling was emitted into Bash candidate tables.',
    );
  });

  test(
    'PowerShell namespaces must distinguish different legal application names',
    () {
      String namespaceFor(String name) {
        final record = CommandRegistry.create(name, 'Review app.').toRecord();
        final script = ToPowerShellCompletionConverter(record).convert();
        return script
            .split('\n')
            .firstWhere((line) => line.contains('Inputs = @{}'));
      }

      expect(namespaceFor('foo-bar'), isNot(namespaceFor('foo_bar')));
    },
  );
}

final class GroupWithLocalOption extends GroupCommand {
  new(Option<Object?> option, super.commands) : super(options: [option]);
  @override
  String get name => 'group';
  @override
  String get shortDescription => 'Review group.';
}
