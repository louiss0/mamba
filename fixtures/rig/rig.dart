import 'package:mamba/mamba.dart';

/// A completion fixture that exercises every surface a converter has to
/// render: a group with children, mandatory and repeated positionals, a
/// variadic, boolean/count/negatable flags, plain/required/repeatable/choice
/// options, a paired group, a selected group, and a nested accessor.
///
/// Nothing here runs. The fixture exists so the generated completion artifacts
/// in `completions/` pin the converters' output for a registry that is not
/// trivial.
enum Output { text, json, yaml }

enum Level { debug, info, warn }

final class DeployCommand extends Command {
  new()
    : super(
        longDescription: 'Ship a build to an environment.',
        aliases: ['ship'],
        mandatoryPositionals: [target],
        discretionaryPositionals: [profile],
        variadic: files,
        flags: [dryRun, retries],
        options: [format, tag, replicas, level, token],
        pairedOptions: [credentials],
        selectedOptions: [output],
        accessors: [database],
      );

  static final target = NormalPositional(
    'target',
    description: 'Where to deploy.',
  );
  static final profile = NormalPositional.optional(
    'profile',
    description: 'Profile to deploy with.',
  );
  static final files = NormalVariadic(description: 'Extra files to ship.');
  static final dryRun = BooleanFlag(
    'dry-run',
    description: 'Report without deploying.',
    negatable: true,
  );
  static final retries = CountFlag(
    'retries',
    short: 'r',
    description: 'Retry a failed deploy.',
  );
  static final format = ChoiceOption.required(
    'format',
    choices: Output.values,
    description: 'Output format.',
  );
  static final tag = RepeatableStringOption(
    'tag',
    short: 't',
    description: 'Tag to apply.',
  );
  static final replicas = IntOption.withDefault(
    'replicas',
    defaultValue: 2,
    min: 1,
    max: 4,
    description: 'Replica count.',
  );
  static final level = ChoiceOption.withDefault(
    'level',
    choices: Level.values,
    defaultValue: Level.info,
    description: 'Log level.',
  );
  static final token = StringOption.required(
    'token',
    short: 'k',
    description: 'Deploy token.',
  );
  static final credentials = PairedOptions<String>.required([
    PairStringOption('host', description: 'Deploy host.'),
    PairStringOption('port', description: 'Deploy port.'),
  ]);
  static final output = SelectedOptions<String>([
    PairStringOption('log', description: 'Write a log.'),
    PairStringOption('report', description: 'Write a report.'),
  ]);
  static final database = AccessorListOption('database', [
    AccessorStringOption('dsn', description: 'Connection string.'),
    AccessorListOption('pool', [
      AccessorIntOption('size', description: 'Pool size.'),
      AccessorChoiceOption('mode', choices: Output.values),
    ]),
  ], description: 'Database configuration.');

  @override
  String get name => 'deploy';

  @override
  String get shortDescription => 'Deploy a build.';

  @override
  String run(ValueOf valueOf, List<String> args) => valueOf(target);
}

/// The root of the fixture: one group of children, and its own flag.
final class RigCommand extends GroupCommand {
  new() : super([DeployCommand(), StatusCommand()], propagatedFlags: [quiet]);

  static final quiet = BooleanFlag(
    'quiet',
    short: 'q',
    description: 'Suppress progress output.',
    hidden: true,
  );

  @override
  String get name => 'rig';

  @override
  String get shortDescription => 'Completion fixture.';

  @override
  String run(ValueOf valueOf, List<String> args) => '';
}

final class StatusCommand extends Command {
  new() : super(mandatoryPositionals: [files], flags: [watch]);

  static final files = RepeatedStringPositional(
    'files',
    times: 3,
    description: 'Files to inspect.',
  );
  static final watch = BooleanFlag(
    'watch',
    short: 'w',
    description: 'Keep watching.',
  );

  @override
  String get name => 'status';

  @override
  String get shortDescription => 'Report status.';

  @override
  String run(ValueOf valueOf, List<String> args) => valueOf(files).join(',');
}
