import 'dart:async';
import 'dart:io';

import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

String stripAnsi(String value) =>
    value.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

final class ResultCommand extends Command with HookRunner {
  new(
    this.events, {
    this.failPre = false,
    this.failRun = false,
    this.failPost = false,
  }) : super(flags: [enabled]);
  static final enabled = BooleanFlag('enabled');
  final List<String> events;
  final bool failPre;
  final bool failRun;
  final bool failPost;
  @override
  String get name => 'run';
  @override
  String get shortDescription => 'Runs.';
  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    events.add('pre');
    if (failPre) throw Exception('pre failed');
    expect(valueOf(enabled), isA<bool>());
  }

  @override
  String run(ValueOf valueOf, List<String> args) {
    events.add('run');
    if (failRun) throw MambaException('run failed', exitCode: 7);
    return 'output';
  }

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    events.add('post');
    if (failPost) throw MambaException('post failed', exitCode: 9);
  }
}

final class Persistent extends GroupCommand with PersistentHookRunner {
  new(
    this.events,
    super.commands, {
    this.failPre = false,
    this.failPost = false,
  }) : super();
  final List<String> events;
  final bool failPre;
  final bool failPost;
  @override
  String get name => 'group';
  @override
  String get shortDescription => 'Group.';
  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    events.add('pre-group');
    if (failPre) throw MambaException('persistent pre failed', exitCode: 6);
  }

  @override
  void postPersistentRun(ValueOf valueOf, MambaContext context) {
    events.add('post-group');
    if (failPost) throw MambaException('persistent failed', exitCode: 8);
  }
}

final _contextValue = MambaContextKey<String>();

final class ContextReader extends Command with HookRunner {
  @override
  String get name => 'read';
  @override
  String get shortDescription => 'Reads hook context.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    expect(context.get(_contextValue), 'available');
  }

  @override
  String? run(ValueOf valueOf, List<String> args) => null;
}

final class ContextWriter extends GroupCommand with PersistentHookRunner {
  new(super.commands) : super();
  @override
  String get name => 'context';
  @override
  String get shortDescription => 'Writes hook context.';

  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    context.set(_contextValue, const MambaContextString('available'));
  }

  @override
  void postPersistentRun(ValueOf valueOf, MambaContext context) {
    expect(context.get(_contextValue), 'available');
    context.set(_contextValue, const MambaContextString('replaced'));
  }
}

final class RetainingContextWriter extends GroupCommand
    with PersistentHookRunner {
  new(super.commands) : super();
  @override
  String get name => 'retaining';
  @override
  String get shortDescription => 'Retains hook context.';

  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    if (context.get(_contextValue) == null) {
      context.set(_contextValue, const MambaContextString('available'));
    }
  }
}

final class BareGroup extends GroupCommand {
  new(super.commands);

  @override
  String get name => 'git';

  @override
  String get shortDescription => 'Groups commands.';
}

/// A group whose name and default sub-command a test chooses.
final class _DefaultingNamedGroup extends GroupCommand {
  new(
    this.events,
    super.commands,
    this.groupName, {
    super.defaultSubCommandPath,
  });

  final List<String> events;
  final String groupName;

  @override
  String get name => groupName;

  @override
  String get shortDescription => 'Groups commands.';
}

/// Records that it ran, so a test can name the command that actually ran.
final class _LeafNamed extends Command {
  new(this.events, this.leafName);

  final List<String> events;
  final String leafName;

  @override
  String get name => leafName;

  @override
  String get shortDescription => 'Records that it ran.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    events.add(leafName);
    return leafName;
  }
}

/// Records the command path it was reached by, so a test can name the command
/// that actually ran.
final class PathRecordingCommand extends Command {
  new(this.path, this.commandName);

  final List<String> path;
  final String commandName;

  @override
  String get name => commandName;

  @override
  String get shortDescription => 'Records its command path.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    path.add(name);
    return name;
  }
}

final class PathRecordingGroup extends GroupCommand {
  new(this.path, super.commands, this.groupName);

  final List<String> path;
  final String groupName;

  @override
  String get name => groupName;

  @override
  String get shortDescription => 'Groups commands.';
}

final class DefaultingGroup extends GroupCommand {
  new(super.commands, {required super.defaultSubCommandPath});

  @override
  String get name => 'git';

  @override
  String get shortDescription => 'Groups commands.';
}

final class DefaultPostHookCommand extends Command with HookRunner {
  @override
  String get name => 'default-post';

  @override
  String get shortDescription => 'Uses the default post-run hook.';

  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  String run(ValueOf valueOf, List<String> args) => 'complete';
}

final class LabelCommand extends Command {
  new() : super(options: [label]);
  static final label = StringOption('label');
  @override
  String get name => 'label-command';
  @override
  String get shortDescription => 'Reads a label.';
  @override
  String? run(ValueOf valueOf, List<String> args) => valueOf(label);
}

final class CountCommand extends Command with HookRunner {
  new(this.events) : super(options: [count]);
  static final count = IntOption.withDefault('count', defaultValue: 3);
  final List<String> events;
  @override
  String get name => 'count-command';
  @override
  String get shortDescription => 'Counts.';
  @override
  void preRun(
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    events.add('pre:${valueOf(count)}');
  }

  @override
  String run(ValueOf valueOf, List<String> args) {
    events.add('run:${valueOf(count)}');
    return 'counted';
  }

  @override
  void postRun(ValueOf valueOf, MambaReadContext context) {
    events.add('post');
  }
}

final class DefaultCommand extends Command {
  new(this.events);
  final List<String> events;
  @override
  String get name => 'default';

  @override
  String get shortDescription => 'Runs by default.';

  @override
  List<String> get aliases => ['d'];

  @override
  String run(ValueOf valueOf, List<String> args) {
    events.add('run');
    return 'default output';
  }
}

final class InvalidContextWriter extends GroupCommand
    with PersistentHookRunner {
  new() : super([ResultCommand(<String>[])]);
  @override
  String get name => 'invalid';
  @override
  String get shortDescription => 'Writes invalid hook context.';

  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    final dynamic rawKey = _contextValue;
    // This test exists to prove a dynamic write is rejected, so the implicit
    // cast is the behaviour under test rather than an oversight.
    // ignore: no_dynamic_casts
    context.set(rawKey, const MambaContextBool(true));
  }
}

final class GlobalAccessorCommand extends Command {
  new(this.configuration);

  final AccessorListOption configuration;

  @override
  String get name => 'read-config';

  @override
  String get shortDescription => 'Reads global configuration.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    final values = valueOf(configuration);
    return values['host'] as String;
  }
}

final class DryRunFlagReader extends Command {
  @override
  String get name => 'read-flags';

  @override
  String get shortDescription => 'Read opt-in framework flags.';

  @override
  String run(ValueOf valueOf, List<String> args) =>
      '${valueOf(MambaBuiltInFlags.dryRun)}';
}

final class _ControlledCommand extends Command {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool first = true;
  @override
  String get name => 'wait';
  @override
  String get shortDescription => 'Controlled execution.';
  @override
  Future<String> run(ValueOf valueOf, List<String> args) async {
    if (first) {
      first = false;
      entered.complete();
      await release.future;
    }
    return 'done';
  }
}

final class _ValueProbe extends Command {
  new({
    this.action,
    super.flags,
    super.options,
    super.mandatoryPositionals,
    super.discretionaryPositionals,
    super.accessors,
  });
  final FutureOr<String?> Function(ValueOf, List<String>)? action;
  @override
  String get name => 'run';
  @override
  String get shortDescription => 'Observe public invocation values.';
  @override
  FutureOr<String?> run(ValueOf valueOf, List<String> args) =>
      action?.call(valueOf, args);
}

final class _InputScope extends GroupCommand with PersistentHookRunner {
  new(
    super.commands, {
    super.propagatedFlags,
    super.propagatedOptions,
    super.options,
    super.conflicts,
    this.observe,
    this.observeContext,
  });
  final void Function(ValueOf)? observe;
  final void Function(MambaContext)? observeContext;
  @override
  String get name => 'scope';
  @override
  String get shortDescription => 'Scoped inputs.';
  @override
  void prePersistentRun(ValueOf valueOf, MambaContext context) {
    observe?.call(valueOf);
    observeContext?.call(context);
  }
}

enum _Pick { one, two }

MambaExecutor<MambaExecutionResult> _probeExecutor(_ValueProbe command) =>
    Executor('app', 'Application.', '1.0.0', [command]).fake();

void main() {
  test(
    'owner retains default and injected scalar context across adapters',
    () async {
      for (final injected in <MambaContext?>[null, MambaContext()]) {
        final key = MambaContextKey<int>();
        final seen = <MambaContext>[];
        final counts = <int>[];
        final scope = _InputScope(
          [_ValueProbe()],
          observeContext: (context) {
            seen.add(context);
            final count = (context.get(key) ?? 0) + 1;
            context.set(key, MambaContextInt(count));
            counts.add(count);
          },
        );
        final owner = Executor('app', 'App.', '1.0.0', [
          scope,
        ], context: injected);
        await owner.fake().execute(['scope', 'run']);
        await owner.fake().execute(['scope', 'run']);
        expect(counts, [1, 2]);
        expect(seen.last, same(injected ?? seen.first));
      }
    },
  );

  test(
    'reentrant execute raises StateError before the inner command enters',
    () async {
      late final Executor owner;
      var runs = 0;
      final command = _ValueProbe(
        action: (_, _) async {
          runs++;
          await expectLater(owner.fake().execute(['run']), throwsStateError);
          return 'outer';
        },
      );
      owner = Executor('app', 'App.', '1.0.0', [command]);
      expect(
        (await owner.fake().execute(['run']) as MambaSuccessResult).output,
        'outer',
      );
      expect(runs, 1);
    },
  );
  test('required overrides invalidate inherited conflicts before ownership is claimed', () async {
    for (final reverse in [false, true]) {
      final output = StringOption.withDefault('output', defaultValue: 'text');
      final requiredOutput = StringOption.required('output');
      final command = _ValueProbe(options: [requiredOutput]);
      final scope = _InputScope(
        [command],
        propagatedOptions: [output],
        propagatedFlags: [BooleanFlag('replace')],
        conflicts: reverse
            ? {
                'replace': ['output'],
              }
            : {
                'output': ['replace'],
              },
      );
      expect(
        () => Executor('app', 'App.', '1.0.0', [scope]),
        throwsA(
          isA<MambaRegistryError>().having(
            (error) => error.message,
            'message',
            contains('conflicts with required input --output'),
          ),
        ),
      );
      // Failed composition must leave every command reusable by a valid owner.
      expect(
        await _probeExecutor(command).execute(['run', '--output=text']),
        isA<MambaSuccessResult>(),
      );
    }
  });

  test('required accessor leaf overrides invalidate inherited conflicts', () {
    final oldRoot = AccessorListOption('config', [
      AccessorListOption('auth', [
        AccessorStringOption.withDefault('token', defaultValue: 'old'),
      ]),
    ]);
    final root = AccessorListOption('config', [
      AccessorListOption('auth', [AccessorStringOption.required('token')]),
    ]);
    expect(
      () => Executor(
        'app',
        'App.',
        '1.0.0',
        [
          _InputScope(
            [
              _InputScope([
                _ValueProbe(accessors: [root]),
              ]),
            ],
            propagatedFlags: [BooleanFlag('replace')],
            conflicts: {
              'replace': ['config.auth.token'],
            },
          ),
        ],
        accessors: [oldRoot],
      ),
      throwsA(
        isA<MambaRegistryError>().having(
          (error) => error.message,
          'message',
          contains('conflicts with required input --config.auth.token'),
        ),
      ),
    );
  });

  test('inherited conflict identities survive overrides but never resurrect local names', () async {
    final shared = BooleanFlag('shared');
    final remote = StringOption('remote');
    final local = StringOption('local');
    final scope = _InputScope(
      [
        _ValueProbe(
          flags: [BooleanFlag('shared')],
          options: [StringOption('local')],
        ),
      ],
      propagatedFlags: [shared],
      options: [local],
      conflicts: {
        'shared': ['remote', 'local'],
      },
    );
    final executor = Executor(
      'app',
      'App.',
      '1.0.0',
      [scope],
      options: [remote],
    ).fake();
    expect(
      await executor.execute(['scope', 'run', '--shared', '--remote=x']),
      isA<MambaFailureResult>(),
    );
    expect(
      await executor.execute(['scope', 'run', '--shared', '--local=x']),
      isA<MambaSuccessResult>(),
    );
    expect(
      await executor.execute(['scope', '--shared', '--local=x']),
      isA<MambaFailureResult>(),
    );
  });

  test(
    'compatible accessor overrides preserve every ancestor container and leaf',
    () async {
      final oldLeaf = AccessorStringOption.withDefault(
        'token',
        defaultValue: 'old',
      );
      final oldNested = AccessorListOption('auth', [oldLeaf]);
      final oldRoot = AccessorListOption('config', [oldNested]);
      final leaf = AccessorStringOption.withDefault(
        'token',
        defaultValue: 'new',
      );
      final nested = AccessorListOption('auth', [
        leaf,
        AccessorIntOption.withDefault('port', defaultValue: 80),
      ]);
      final root = AccessorListOption('config', [nested]);
      final command = _ValueProbe(
        accessors: [root],
        action: (valueOf, _) {
          expect(valueOf(oldLeaf), 'new');
          expect(valueOf(oldNested), {'token': 'new', 'port': 80});
          expect(valueOf(oldRoot), valueOf(root));
          return 'compatible';
        },
      );
      final executor = Executor(
        'app',
        'App.',
        '1.0.0',
        [command],
        accessors: [oldRoot],
      ).fake();
      expect(
        (await executor.execute(['run']) as MambaSuccessResult).output,
        'compatible',
      );
    },
  );

  test('owner context is shared across adapters and the guard releases after escaping Errors', () async {
    var calls = 0;
    final owner = Executor('app', 'App.', '1.0.0', [
      RetainingContextWriter([
        _ValueProbe(
          action: (_, _) {
            if (calls++ == 0) throw StateError('escaping');
            return 'reused';
          },
        ),
      ]),
    ]);
    final first = owner.fake();
    final second = owner.fake();
    await expectLater(first.execute(['retaining', 'run']), throwsStateError);
    expect(
      (await second.execute(['retaining', 'run']) as MambaSuccessResult).output,
      'reused',
    );
  });
  test('propagation includes its group and compatible retained handles read the override', () async {
    final ancestor = StringOption.withDefault(
      'label',
      defaultValue: 'ancestor',
      short: 'a',
    );
    final local = StringOption.withDefault(
      'label',
      defaultValue: 'local',
      short: 'l',
    );
    final group = _InputScope(
      [
        _ValueProbe(options: [local], action: (valueOf, _) => valueOf(local)),
      ],
      propagatedOptions: [ancestor],
      observe: (valueOf) => expect(valueOf(ancestor), 'local'),
    );
    final executor = Executor('app', 'Application.', '1.0.0', [group]).fake();
    expect(
      (await executor.execute(['scope', 'run']) as MambaSuccessResult).output,
      'local',
    );
    final direct = _InputScope([], propagatedOptions: [ancestor]);
    expect(
      await Executor('other', 'Application.', '1.0.0', [
        direct,
      ]).fake().execute(['scope', '--label=group']),
      isA<MambaSuccessResult>(),
    );
  });

  test('unconstrained sources reserve their required suffix', () async {
    final sources = RepeatedStringPositional('sources', times: 3);
    final destination = NormalPositional('destination');
    final executor = _probeExecutor(
      _ValueProbe(
        mandatoryPositionals: [sources, destination],
        action: (valueOf, _) => '${valueOf(sources)}:${valueOf(destination)}',
      ),
    );
    final result = await executor.execute(['run', 'a', 'out']);
    expect(result, isA<MambaSuccessResult>());
    expect((result as MambaSuccessResult).output, '[a]:out');
  });

  test(
    'bounded sources reserve a mandatory destination without backtracking',
    () async {
      final sources = RepeatedStringPositional(
        'sources',
        times: 3,
        regex: RegExp(r'.*\.txt'),
      );
      final destination = NormalPositional('destination');
      final executor = _probeExecutor(
        _ValueProbe(
          mandatoryPositionals: [sources, destination],
          action: (valueOf, _) =>
              '${valueOf(sources).join(',')} -> ${valueOf(destination)}',
        ),
      );
      expect(
        (await executor.execute([
          'run',
          'a.txt',
          'out/',
        ]) as MambaSuccessResult).output,
        'a.txt -> out/',
      );
      expect(
        (await executor.execute([
          'run',
          'a.txt',
          'b.txt',
          'c.txt',
          'out/',
        ]) as MambaSuccessResult).output,
        'a.txt,b.txt,c.txt -> out/',
      );
      for (final argv in [
        ['run', 'out/'],
        ['run', 'bad', 'out/'],
        ['run', 'a.txt', '--', 'out/'],
      ]) {
        expect(await executor.execute(argv), isA<MambaFailureResult>());
      }
    },
  );

  test('empty default repeats and nested accessor containers retain non-null values', () async {
    final picks = RepeatedChoicePositional.withDefault(
      'picks',
      choices: _Pick.values,
      defaultValue: <_Pick>[],
      times: 2,
    );
    final leaf = AccessorStringOption('token');
    final nested = AccessorListOption('auth', [leaf]);
    final root = AccessorListOption('config', [nested]);
    final executor = _probeExecutor(
      _ValueProbe(
        discretionaryPositionals: [picks],
        accessors: [root],
        action: (valueOf, _) {
          expect(valueOf(picks), isEmpty);
          expect(valueOf(nested), isEmpty);
          expect(valueOf(root), {'auth': <String, Object?>{}});
          expect(valueOf(leaf), isNull);
          expect(() => valueOf(picks).add(_Pick.one), throwsUnsupportedError);
          expect(
            () => valueOf(nested)['token'] = 'changed',
            throwsUnsupportedError,
          );
          return 'stored';
        },
      ),
    );
    final result = await executor.execute(['run']);
    expect(
      result,
      isA<MambaSuccessResult>(),
      reason: result is MambaFailureResult ? result.message : null,
    );
    expect((result as MambaSuccessResult).output, 'stored');
  });

  test('supplied strings remain one value, including empty content', () async {
    final label = StringOption.required('label');
    final executor = _probeExecutor(
      _ValueProbe(options: [label], action: (valueOf, _) => valueOf(label)),
    );
    for (final text in ['', 'two words', 'a\nb']) {
      final result = await executor.execute(['run', '--label', text]);
      expect(result, isA<MambaSuccessResult>());
      expect((result as MambaSuccessResult).output, text);
    }
  });

  test(
    'rejects equals attachment without a short name before execution',
    () async {
      var runs = 0;
      final executor = _probeExecutor(
        _ValueProbe(
          action: (_, _) {
            runs++;
            return 'executed';
          },
        ),
      );
      for (final argv in [
        ['run', '-='],
        ['run', '-=oops'],
        ['run', '-=oops', '--help'],
      ]) {
        expect(
          await executor.execute(argv),
          isA<MambaFailureResult>(),
          reason: '$argv',
        );
        expect(runs, 0);
      }
    },
  );

  test(
    'syntax owns option values, not content validators or controls',
    () async {
      final label = StringOption(
        'label',
        short: 'o',
        regex: RegExp(r'[\s\S]*'),
      );
      final executor = _probeExecutor(
        _ValueProbe(options: [label], action: (valueOf, _) => valueOf(label)),
      );
      expect(
        await executor.execute(['run', '--label', '--help']),
        isA<MambaFailureResult>(),
      );
      for (final (argv, expected) in <(List<String>, String)>[
        (['--label=--help'], '--help'),
        (['-o=--help'], '--help'),
        (['-vo=a=b'], 'a=b'),
        (['-vo='], ''),
        (['-o', 'two words'], 'two words'),
      ]) {
        final result = await executor.execute(['run', ...argv]);
        expect(result, isA<MambaSuccessResult>(), reason: '$argv');
        expect((result as MambaSuccessResult).output, expected);
      }
      for (final argv in [
        ['-ofile'],
        ['-vo', 'file'],
        ['-v=file'],
        ['-xo=file'],
        ['-oo=file'],
        ['-hv=file'],
        ['-hx'],
      ]) {
        expect(
          await executor.execute(['run', ...argv]),
          isA<MambaFailureResult>(),
          reason: '$argv',
        );
      }
      expect(
        await executor.execute(['run', '-h', '--typo']),
        isA<MambaSuccessResult>(),
      );
      expect(
        await executor.execute(['run', '--typo', '-h']),
        isA<MambaFailureResult>(),
      );
    },
  );
  test(
    'syntax conflicts depend on explicit occurrences, including false flags',
    () async {
      final output = StringOption.withDefault('output', defaultValue: 'text');
      final replace = BooleanFlag('replace');
      final command = TestCommand(
        'run',
        'Run.',
        options: [output],
        flags: [replace],
        conflicts: {
          'output': ['replace'],
        },
      );
      final executor = Executor('app', 'App.', '1.0.0', [command]).fake();
      expect(
        await executor.execute(['run', '--replace']),
        isA<MambaSuccessResult>(),
      );
      expect(
        await executor.execute(['run', '--replace', '--output=text']),
        isA<MambaFailureResult>(),
      );
      final negative = TestCommand(
        'run',
        'Run.',
        flags: [BooleanFlag('cache', negatable: true), replace],
        conflicts: {
          'cache': ['replace'],
        },
      );
      final negativeExecutor = Executor('negative', 'App.', '1.0.0', [
        negative,
      ]).fake();
      expect(
        await negativeExecutor.execute(['run', '--no-cache', '--replace']),
        isA<MambaFailureResult>(),
      );
    },
  );
  test(
    'duplicate command placement fails before claiming either path',
    () async {
      final command = ResultCommand([]);
      expect(
        () => Executor('app', 'App.', '1.0.0', [
          command,
          BareGroup([command]),
        ]),
        throwsA(isA<MambaRegistryError>()),
      );
      final result = await Executor('valid', 'Valid.', '1.0.0', [
        command,
      ]).fake().execute(['run']);
      expect((result as MambaSuccessResult).output, 'output');
    },
  );
  test('configured ownership is eager and failed claims are atomic', () async {
    final owned = ResultCommand([]);
    final owner = Executor('first', 'First.', '1.0.0', [owned]);
    final reusable = ResultCommand([]);
    expect(
      () => Executor('second', 'Second.', '1.0.0', [
        BareGroup([reusable]),
        owned,
      ]),
      throwsA(isA<MambaRegistryError>()),
    );
    expect(
      (await owner.fake().execute(['run']) as MambaSuccessResult).output,
      'output',
    );
    expect(
      () => Executor('third', 'Third.', '1.0.0', [reusable]),
      returnsNormally,
    );
    final invalidTree = ResultCommand([]);
    expect(
      () => Executor('bad', 'Bad.', '1.0.0', [
        BareGroup([
          invalidTree,
          TestCommand(
            'bad',
            'Bad.',
            options: [DoubleOption('ratio', step: 0.1)],
          ),
        ]),
      ]),
      throwsA(isA<MambaRegistryError>()),
    );
    expect(
      () => Executor('valid', 'Valid.', '1.0.0', [invalidTree]),
      returnsNormally,
    );
  });

  test(
    'owner rejects cross-adapter overlap and releases after completion',
    () async {
      final command = _ControlledCommand();
      final owner = Executor('app', 'Application.', '1.0.0', [command]);
      final a = owner.fake();
      final b = owner.fake();
      final first = a.execute(['wait']);
      await command.entered.future;
      await expectLater(b.execute(['wait']), throwsStateError);
      command.release.complete();
      expect((await first as MambaSuccessResult).output, 'done');
      expect((await b.execute(['wait']) as MambaSuccessResult).output, 'done');
    },
  );
  group('MambaException', () {
    test('uses a portable default exit code', () {
      expect(MambaException('failure').exitCode, 1);
    });
  });

  group('Command hooks', () {
    test('allows the default post-run hook', () async {
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        DefaultPostHookCommand(),
      ]).fake().execute(['default-post']);

      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          'complete',
        ),
      );
    });
  });

  test('persistent hooks provide read-only context to command hooks', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ContextWriter([ContextReader()]),
    ]).fake().execute(['context', 'read']);

    expect(result, isA<MambaSuccessResult>());
  });

  test('persistent post-hooks can replace supported context values', () async {
    final context = MambaContext();
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ContextWriter([ContextReader()]),
    ], context: context).fake().execute(['context', 'read']);

    expect(result, isA<MambaSuccessResult>());
    expect(context.get(_contextValue), 'replaced');
  });

  test('reusing an executor retains supported context values', () async {
    final executor = Executor('tool', 'Tool.', '1.0.0', [
      RetainingContextWriter([ContextReader()]),
    ]).fake();

    expect(
      await executor.execute(['retaining', 'read']),
      isA<MambaSuccessResult>(),
    );
    expect(
      await executor.execute(['retaining', 'read']),
      isA<MambaSuccessResult>(),
    );
  });

  test('developer errors escape execution', () async {
    final execution = Executor('tool', 'Tool.', '1.0.0', [
      InvalidContextWriter(),
    ]).fake().execute(['invalid', 'run']);

    await expectLater(execution, throwsArgumentError);
  });

  test('success has zero exit code and runs eligible hooks', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(events),
    ]).fake().execute(['run']);
    expect(result, isA<MambaSuccessResult>());
    expect(result.exitCode, 0);
    expect(events, ['pre', 'run', 'post']);
  });
  test(
    'retains output and collects cleanup failures after command success',
    () async {
      final events = <String>[];
      final result = await Executor('tool', 'Tool.', '1.0.0', [
        ResultCommand(events, failPost: true),
      ]).fake().execute(['run']);
      expect(
        result,
        isA<MambaFailureResult>()
            .having((value) => value.output, 'output', 'output')
            .having((value) => value.exitCode, 'exit code', 9)
            .having(
              (value) => value.errors.single.phase,
              'error phase',
              MambaExecutionPhase.postRun,
            ),
      );
    },
  );
  test('preserves first command exit code while completing cleanup', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        ResultCommand(events, failRun: true, failPost: true),
      ], failPost: true),
    ]).fake().execute(['group', 'run']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.exitCode, 'exit code', 7)
          .having(
            (value) => value.errors.map((error) => error.phase),
            'error phases',
            [
              MambaExecutionPhase.run,
              MambaExecutionPhase.postRun,
              MambaExecutionPhase.postPersistentRun,
            ],
          ),
    );
    expect(events, ['pre-group', 'pre', 'run', 'post', 'post-group']);
  });
  test('only cleans up persistent hooks whose pre-hook completed', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(events, [
        Persistent(events, [ResultCommand(events)], failPre: true),
      ]),
    ]).fake().execute(['group', 'group', 'run']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.exitCode, 'exit code', 6)
          .having(
            (value) => value.errors.map((error) => error.phase),
            'error phases',
            [MambaExecutionPhase.prePersistentRun],
          ),
    );
    expect(events, ['pre-group', 'pre-group', 'post-group']);
  });

  test('validates failure result invariants and exception codes', () {
    expect(() => MambaException('bad', exitCode: 0), throwsArgumentError);
    expect(
      () => MambaFailureResult(exitCode: 0, errors: []),
      throwsArgumentError,
    );
    expect(
      () => MambaFailureResult(
        exitCode: 1,
        errors: const <MambaExecutionError>[],
      ),
      throwsArgumentError,
    );
  });

  test('does not register dry-run automatically', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.2.3',
      const [],
    ).fake().execute(['--help']);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => stripAnsi(value.output!),
        'output',
        allOf(isNot(contains('--dry-run')), contains('--version')),
      ),
    );
  });

  test('makes a registered dry-run flag available to commands', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.2.3',
      [DryRunFlagReader()],
      flags: [MambaBuiltInFlags.dryRun],
    ).fake().execute(['read-flags', '--dry-run']);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => value.output,
        'output',
        'true',
      ),
    );
  });

  for (final spelling in ['--version', '-V']) {
    test('renders the application version for $spelling', () async {
      final events = <String>[];
      final result = await Executor('tool', 'Tool.', '1.2.3', [
        ResultCommand(events),
      ]).fake().execute([spelling]);
      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          'tool 1.2.3',
        ),
      );
      expect(events, isEmpty);
    });
  }

  test('renders application help with the version', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.2.3',
      const [],
    ).fake().execute(['--help', '--version']);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => stripAnsi(value.output!),
        'output',
        startsWith('tool 1.2.3\n\ntool'),
      ),
    );
  });

  test('reports the resolved command path for parse failures', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      Persistent(<String>[], [ResultCommand(<String>[])]),
    ]).fake().execute(['group', 'run', '--unknown']);
    expect(
      result,
      isA<MambaFailureResult>()
          .having(
            (value) => value.errors.single.phase,
            'error phase',
            MambaExecutionPhase.parse,
          )
          .having((value) => value.errors.single.commandPath, 'error path', [
            'tool',
            'group',
            'run',
          ]),
    );
  });

  test('rejects versions that are not semantic versions', () {
    expect(
      () => Executor('tool', 'Tool.', '1.2', const []),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test('accepts complete SemVer and rejects malformed identifiers', () {
    expect(
      () => Executor('tool', 'Tool.', '1.0.0-beta+build.2', const []),
      returnsNormally,
    );
    for (final version in [
      '01.0.0',
      '1.0.0-alpha..beta',
      '1.0.0-01',
      '1.0.0+',
    ]) {
      expect(
        () => Executor('tool', 'Tool.', version, const []),
        throwsA(isA<MambaRegistryError>()),
      );
    }
  });

  test('uses its default command when no arguments are supplied', () async {
    final events = <String>[];
    final result = await Executor(
      'tool',
      'Tool.',
      '1.0.0',
      [DefaultCommand(events)],
      defaultCommandPath: ['default'],
    ).fake().execute([]);

    expect(result, isA<MambaSuccessResult>());
    expect(events, ['run']);
  });

  test("resolves a nested group's own default sub-command", () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      _DefaultingNamedGroup(events, [
        _DefaultingNamedGroup(
          events,
          [_LeafNamed(events, 'leaf')],
          'inner',
          defaultSubCommandPath: ['leaf'],
        ),
        _DefaultingNamedGroup(events, [_LeafNamed(events, 'leaf')], 'sibling'),
      ], 'outer'),
    ]).fake().execute(['outer', 'inner']);

    expect(result, isA<MambaSuccessResult>());
    expect(events, ['leaf']);
  });

  test('root and group defaults parse the leaf and run its hooks', () async {
    for (final (executor, arguments) in [
      (
        Executor(
          'tool',
          'Tool.',
          '1.0.0',
          [CountCommand(<String>[])],
          defaultCommandPath: ['count-command'],
        ),
        <String>[],
      ),
      (
        Executor('tool', 'Tool.', '1.0.0', [
          DefaultingGroup(
            [CountCommand(<String>[])],
            defaultSubCommandPath: ['count-command'],
          ),
        ]),
        <String>['git'],
      ),
    ]) {
      final events = (executor.commands.first is CountCommand
          ? (executor.commands.first as CountCommand).events
          : ((executor.commands.first as GroupCommand).commands.first
                    as CountCommand)
                .events);
      expect(
        await executor.fake().execute(arguments),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:3', 'run:3', 'post']);
    }
  });

  test(
    'chains root and group defaults while respecting typed-path help',
    () async {
      final events = <String>[];
      final executor = Executor(
        'tool',
        'Tool.',
        '1.0.0',
        [
          DefaultingGroup(
            [CountCommand(events)],
            defaultSubCommandPath: ['count-command'],
          ),
        ],
        defaultCommandPath: ['git'],
      ).fake();
      expect(
        await executor.execute(['--count', '9']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:9', 'run:9', 'post']);
      events.clear();
      expect(
        await executor.execute(['--count', '-2']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:-2', 'run:-2', 'post']);
      events.clear();
      expect(
        await executor.execute(['git', '--count', '7']),
        isA<MambaSuccessResult>(),
      );
      expect(events, ['pre:7', 'run:7', 'post']);
      events.clear();
      final rootHelp = await executor.execute(['--help']) as MambaSuccessResult;
      final groupHelp =
          await executor.execute(['git', '--help']) as MambaSuccessResult;
      expect(stripAnsi(rootHelp.output!), contains('tool'));
      expect(stripAnsi(groupHelp.output!), contains('tool git'));
      expect(events, isEmpty);
    },
  );

  group('default command paths', () {
    test('refuses a default path that ends at a group', () {
      expect(
        () => Executor(
          'tool',
          'Tool.',
          '1.0.0',
          [
            TestGroupCommand('group', [
              TestCommand('run', 'Run command.'),
            ], 'Group command.'),
          ],
          defaultCommandPath: ['group'],
        ),
        throwsA(
          isA<MambaRegistryError>().having(
            (error) => error.message,
            'message',
            contains('must end at an executable command'),
          ),
        ),
      );
    });

    test('validates a default on a group nested inside another', () {
      expect(
        () => Executor(
          'tool',
          'Tool.',
          '1.0.0',
          [
            TestGroupCommand('outer', [
              TestGroupCommand('inner', [
                TestCommand('run', 'Run command.'),
              ], 'Inner group.'),
            ], 'Outer group.'),
          ],
          defaultCommandPath: ['outer', 'inner'],
        ),
        throwsA(isA<MambaRegistryError>()),
      );
    });
  });

  group('command paths that repeat a name', () {
    test('runs a child command named after the application', () async {
      final path = <String>[];
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        PathRecordingCommand(path, 'tool'),
      ]).fake();

      for (final args in [
        ['tool'],
      ]) {
        final result = await executor.execute(List<String>.of(args));

        expect(result, isA<MambaSuccessResult>(), reason: 'invocation $args');
        expect(path, ['tool'], reason: 'invocation $args');
        path.clear();
      }
    });

    test('rejects a repeated name once the command has been named', () async {
      final path = <String>[];
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        PathRecordingCommand(path, 'tool'),
      ]).fake();

      final result = await executor.execute(['tool', 'tool']);

      expect(result, isA<MambaFailureResult>());
      expect(path, isEmpty);
    });

    test('rejects a token that names nothing after the leaf', () async {
      final path = <String>[];
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        PathRecordingCommand(path, 'tool'),
      ]).fake();

      final result = await executor.execute(['tool', 'tool', 'tool']);

      expect(result, isA<MambaFailureResult>());
      expect(path, isEmpty);
    });

    test('runs a leaf named after an ancestor', () async {
      final path = <String>[];
      final executor = Executor('tool', 'Tool.', '1.0.0', [
        PathRecordingGroup(path, [PathRecordingCommand(path, 'tool')], 'tool'),
      ]).fake();

      final result = await executor.execute(['tool', 'tool']);

      expect(result, isA<MambaSuccessResult>());
      expect(path, ['tool']);
    });

    test(
      'rejects a leading application name with the rule that explains it',
      () async {
        final path = <String>[];
        final executor = Executor('tool', 'Tool.', '1.0.0', [
          PathRecordingCommand(path, 'run'),
        ]).fake();

        final result = await executor.execute(['tool', 'run']);

        expect(result, isA<MambaFailureResult>());
        expect(path, isEmpty);
        expect(
          result,
          isA<MambaFailureResult>().having(
            (failure) => failure.errors.single.exception.message,
            'message',
            contains('never begins with the application name'),
          ),
        );
      },
    );
  });

  test('does not treat a default input value as an explicit command', () async {
    final executor = Executor(
      'tool',
      'Tool.',
      '1.0.0',
      [LabelCommand(), DefaultCommand(<String>[])],
      defaultCommandPath: ['label-command'],
    ).fake();
    final result = await executor.execute(['--label', 'default']);
    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => value.output,
        'output',
        'default',
      ),
    );
  });

  test(
    'does not confuse a default command option value with a version flag',
    () async {
      final executor = Executor(
        'tool',
        'Tool.',
        '1.0.0',
        [LabelCommand()],
        defaultCommandPath: ['label-command'],
      ).fake();
      final result = await executor.execute(['--label=-V']);
      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          '-V',
        ),
      );
    },
  );

  test('rejects invalid group default paths when building the executor', () {
    expect(
      () => Executor('tool', 'Tool.', '1.0.0', [
        DefaultingGroup(
          [CountCommand(<String>[])],
          defaultSubCommandPath: ['missing'],
        ),
      ]),
      throwsA(isA<MambaRegistryError>()),
    );
  });

  test('renders help when no command is selected', () async {
    final result = await Executor(
      'tool',
      'Tool.',
      '1.0.0',
      const [],
    ).fake().execute([]);

    expect(
      result,
      isA<MambaSuccessResult>().having(
        (value) => stripAnsi(value.output!),
        'output',
        startsWith('tool'),
      ),
    );
  });

  test('renders a group help when no child command is selected', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      BareGroup([ResultCommand(events)]),
    ]).fake().execute(['git']);

    expect(
      stripAnsi((result as MambaSuccessResult).output!),
      allOf(contains('tool git'), contains('Runs.')),
    );
    expect(events, isEmpty);
  });

  test('runs a group that names a default sub command path', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      DefaultingGroup([ResultCommand(events)], defaultSubCommandPath: ['run']),
    ]).fake().execute(['git']);

    expect(events, ['pre', 'run', 'post']);
    expect((result as MambaSuccessResult).output, 'output');
  });

  test('records non-Mamba hook errors', () async {
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      ResultCommand(<String>[], failPre: true),
    ]).fake().execute(['run']);

    expect(
      result,
      isA<MambaFailureResult>()
          .having((value) => value.message, 'message', 'Exception: pre failed')
          .having(
            (value) => value.errors.single.phase,
            'error phase',
            MambaExecutionPhase.preRun,
          ),
    );
  });

  test('runs commands selected by an alias', () async {
    final events = <String>[];
    final result = await Executor('tool', 'Tool.', '1.0.0', [
      DefaultCommand(events),
    ]).fake().execute(['d']);

    expect(result, isA<MambaSuccessResult>());
    expect(events, ['run']);
  });

  test('makes executor accessors available to commands', () async {
    final configuration = AccessorListOption('config', [
      AccessorStringOption.required('host'),
    ]);
    final executor = Executor(
      'tool',
      'Tool.',
      '1.0.0',
      [GlobalAccessorCommand(configuration)],
      accessors: [configuration],
    ).fake();

    for (final arguments in [
      ['--config.host', 'localhost', 'read-config'],
      ['read-config', '--config.host', 'localhost'],
    ]) {
      final result = await executor.execute(arguments);

      expect(
        result,
        isA<MambaSuccessResult>().having(
          (value) => value.output,
          'output',
          'localhost',
        ),
      );
    }
  });

  test('assigns completion commands their root registry', () {
    final completion = CompletionCommand(createFile: (_, _) {});

    Executor('tool', 'Tool.', '1.0.0', [completion]).fake();

    expect(completion.registryRecord.name, 'tool');
  });

  test('delivers standard input through the fake executor', () async {
    const input = ProcessedStandardInput([104, 105]);

    final result = await Executor('tool', 'Tool.', '1.0.0', [
      InputCommand(),
    ]).fake(standardInput: input).execute(['input']);

    expect(
      result,
      isA<MambaSuccessResult>().having((value) => value.output, 'output', 'hi'),
    );
  });

  test(
    'creates the system process adapter without accessing process streams',
    () {
      final executor = Executor('tool', 'Tool.', '1.0.0', const []).create();

      expect(executor, isA<MambaExecutor<void>>());
    },
  );

  test('identifies closed pipe errors without reading process streams', () {
    expect(
      isClosedPipeFileSystemException(
        FileSystemException('write', '', OSError('Broken pipe', 32)),
      ),
      isTrue,
    );
    expect(
      isClosedPipeFileSystemException(FileSystemException('write')),
      isFalse,
    );
  });
}
