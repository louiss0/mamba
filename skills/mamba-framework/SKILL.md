---
name: mamba-framework
description: Develop and test Dart CLI applications that use Mamba. Use when adding or changing executors, commands, command groups, typed inputs, injected dependencies, hooks, context, standard input, output, errors, help, or shell completions.
compatibility: requires mamba cli and dart cli
---

# Mamba

Treat `Executor` as the application's composition and execution boundary.
Treat `Command` as the unit of CLI behavior.

Drive every behavior change through an executor test before connecting real
dependencies or process-facing execution.

## Development workflow

### Write a failing executor test

Write the behavioral test before changing production code.

Construct the real command tree with `Executor`, replace external dependencies
with fakes, call `.fake().execute(arguments)`, and assert the observable CLI
result.

Assert the applicable behavior:

- `MambaSuccessResult.output` for successful output;
- `MambaFailureResult.message`, `errors`, and `exitCode` for failure;
- calls made to injected dependencies;
- state passed into or returned from dependencies; and
- the full command path and inputs supplied by the user.

Run the focused test and confirm that it fails because the requested behavior
does not exist. A compilation failure caused by a missing command or dependency
contract is an acceptable initial failure.

For standard-input behavior, pass a `ProcessedStandardInput` through
`Executor.fake(standardInput: input)`.

### Alter the command or executor

Change the `Command`, `GroupCommand`, or `Executor` composition needed to
express the behavior.

Define the smallest dependency contract required by the command. Supply a fake
implementation from the test. Defer the production implementation of that
dependency until the executor test passes.

When adding a command skeleton, use:

```console
mamba command <name>
mamba command <name> --group
mamba command <name> <file> --append
```

Use `--append` to place a closely related command in an existing command file.
Register every new command in its parent `GroupCommand` or in the executor's
root command list.

### Make the executor test pass

Implement only the CLI behavior required by the failing test.

Run the focused test until it passes. Add executor tests for meaningful
validation and failure paths before continuing.

Keep the test at the executor boundary. Calling `Command.run()` directly does
not prove that registration, parsing, validation, command selection, hooks, or
result conversion works.

### Implement the real dependency

Implement the production dependency only after the command behavior passes
with its fake.

Inject the real implementation while constructing the command tree in the
application entry point. Keep dependency construction out of the command.

Add direct unit or integration tests for the production dependency. Then run
the formatter, analyzer, focused tests, and full test suite.

Finish only when:

- the requested command path is registered and reachable;
- the executor tests pass with fake dependencies;
- the production dependency is implemented and wired;
- no fake is reachable from production composition; and
- formatting, analysis, and tests pass.

## Executor

Use `Executor` to define the application and its root command tree.

Its positional constructor parameters are:

1. application name;
2. short description;
3. semantic version; and
4. root commands.

Use these named parameters when needed:

- `longDescription` for detailed root help;
- `flags`, `options`, and `accessors` for root inputs;
- `defaultCommandPath` for execution without a command argument;
- `context` for executor-scoped hook state; and
- `helpFormatter` for custom help rendering.

Call `create().execute(args)` only at the process-facing application boundary.
The system process reads piped standard input, writes command output and
errors, and sets a non-zero process exit code for failures.

Call `fake().execute(args)` in tests. It performs real Mamba parsing,
validation, command selection, hooks, and execution without writing to process
streams. Supply `standardInput` when testing a command that reads piped input.

`fake()` returns:

- `MambaSuccessResult` when execution succeeds; or
- `MambaFailureResult` when parsing, a hook, or a command fails.

A successful command may return output or complete silently. A failure may
retain output produced before a later hook failed.

Use `MambaContext` only for scalar state shared through hooks. Pass application
dependencies through constructors instead of storing them in the context.

## Commands

Extend `Command` for executable behavior.

Extend `GroupCommand` for a command that owns child commands. Register its
children through the group constructor. Use `defaultSubCommandPath` when
invoking the group itself should select a descendant.

Every command defines:

```dart
String get name;
String get shortDescription;

FutureOr<String?> run(
  ParsedInputs inputs,
  List<String> args,
);
```

Return a string when the command should produce standard output. Return `null`
when successful execution should remain silent.

Throw `MambaException` when an expected failure is part of the CLI contract.
Give it a user-facing message and a meaningful non-zero exit code when the
default code is insufficient.

Let programming errors remain programming errors instead of disguising them as
expected CLI failures.

## Retain parsed declarations

Retain every parsed declaration as a stable field. Pass that declaration to
the command constructor and pass the same instance to `ParsedInputs.valueOf`.
Declarations are identity-based typed keys.

```dart
final class AddCommand extends Command {
  new(this.store)
    : super(
        mandatoryPositionals: [path],
        flags: [force],
      );

  static final path = NormalPositional('path');
  static const force = BooleanFlag('force');

  final ItemStore store;

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add an item.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final pathValue = inputs.valueOf(path);
    final forceValue = inputs.valueOf(force);
    store.add(pathValue, replace: forceValue);
    return 'Added $pathValue.';
  }
}
```

Use `ParsedInputs.contains(declaration)` when behavior depends on whether an
optional or defaulted declaration was present.

## Parsable entities

### Flags

Register boolean switches and occurrence counters in `flags`:

```dart
static const force = BooleanFlag(
  'force',
  short: 'f',
  description: 'Replace an existing item.',
  negatable: true,
);
static const verbose = CountFlag(
  'verbose',
  short: 'v',
  description: 'Increase verbosity.',
);

new() : super(flags: [force, verbose]);

final forceValue = inputs.valueOf(force);
final verbosity = inputs.valueOf(verbose);
```

### Single options

Register optional, required, or defaulted scalar options in `options`:

```dart
enum OutputFormat { text, json }

static final output = StringOption.required(
  'output',
  short: 'o',
  regex: RegExp(r'.+'),
);
static final retries = IntOption.withDefault(
  'retries',
  defaultValue: 3,
  min: 0,
  max: 10,
);
static const threshold = DoubleOption(
  'threshold',
  min: 0,
  max: 1,
  step: 0.1,
);
static final format = ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);

new() : super(options: [output, retries, threshold, format]);

final outputValue = inputs.valueOf(output);
final retryCount = inputs.valueOf(retries);
final thresholdValue = inputs.valueOf(threshold);
final formatValue = inputs.valueOf(format);
```

Use the direct constructor for an optional value, `.required(...)` for a
required value, and `.withDefault(...)` for a typed default. A double `step` is
measured relative to `min`, so supply `min` when using `step`.

### Repeatable options

Register named values that may occur multiple times in `options`:

```dart
enum TagKind { public, private }

static final labels = RepeatableStringOption('label');
static const ports = RepeatableIntOption('port', min: 1, max: 65535);
static const ratios = RepeatableDoubleOption(
  'ratio',
  min: 0,
  max: 1,
  step: 0.1,
);
static final tags = RepeatableChoiceOption(
  'tag',
  TagKind.values,
  unique: true,
);

new() : super(options: [labels, ports, ratios, tags]);

final labelValues = inputs.valueOf(labels);
final portValues = inputs.valueOf(ports);
final ratioValues = inputs.valueOf(ratios);
final tagValues = inputs.valueOf(tags);
```

Repeatable options also provide `.required(...)` and `.withDefault(...)`.
They return immutable typed lists. An explicit occurrence replaces a default
list instead of extending it.

### Positionals

Register required positionals in `mandatoryPositionals` and optional or
defaulted positionals in `discretionaryPositionals`:

```dart
enum Environment { development, staging, production }

static final source = NormalPositional('source');
static final environment = ChoicePositional(
  'environment',
  choices: Environment.values,
);
static final coordinates = RepeatedStringPositional('coordinate', times: 2);
static final stages = RepeatedChoicePositional(
  'stage',
  choices: Environment.values,
  times: 2,
);

static final destination = NormalPositional.optional('destination');
static final fallbackEnvironment = ChoicePositional.withDefault(
  'fallback-environment',
  choices: Environment.values,
  defaultValue: Environment.development,
);
static final extraPaths = RepeatedStringPositional.optional(
  'extra-path',
  times: 2,
);
static final fallbackStages = RepeatedChoicePositional.withDefault(
  'fallback-stage',
  choices: Environment.values,
  defaultValue: [Environment.staging],
  times: 2,
);

new()
  : super(
      mandatoryPositionals: [source, environment, coordinates, stages],
      discretionaryPositionals: [
        destination,
        fallbackEnvironment,
        extraPaths,
        fallbackStages,
      ],
    );
```

Required repeated positionals accept from one value through `times`; optional
repeated positionals accept from zero through `times`.

### Variadics

Register one variadic declaration to validate values supplied after `--`:

```dart
final class ForwardCommand extends Command {
  new() : super(variadic: NormalVariadic(regExp: RegExp(r'.+')));

  @override
  String get name => 'forward';

  @override
  String get shortDescription => 'Forward trailing arguments.';

  @override
  String run(ParsedInputs inputs, List<String> args) => args.join(' ');
}
```

Use `ChoiceVariadic` when at most one trailing enum value is accepted:

```dart
enum OutputFormat { text, json }

final choice = ChoiceVariadic(
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
```

Mamba validates variadics and passes their original strings to `run` through
`args`. Variadics are not stored in `ParsedInputs`.

### Paired options

Use `PairedOptions` when every member must appear together. The parsed value is
an immutable map keyed by member name:

```dart
enum Protocol { http, https }

static final credentials = PairedOptions<String>.required([
  PairStringOption('username'),
  PairStringOption('password'),
]);
static final window = PairedOptions<int>([
  PairIntOption('start', min: 0),
  PairIntOption('end', min: 0),
]);
static final range = PairedOptions<double>([
  PairDoubleOption('minimum', step: 0.5),
  PairDoubleOption('maximum', step: 0.5),
]);
static final transport = PairedOptions<Protocol>([
  PairChoiceOption('protocol', choices: Protocol.values),
  PairChoiceOption('fallback-protocol', choices: Protocol.values),
]);
static final includeExclude = PairedOptions<List<String>>([
  RepeatablePairStringOption('include'),
  RepeatablePairStringOption('exclude'),
]);
static final lowHighPorts = PairedOptions<List<int>>([
  RepeatablePairIntOption('low-port', min: 1),
  RepeatablePairIntOption('high-port', max: 65535),
]);
static final lowerUpperRatios = PairedOptions<List<double>>([
  RepeatablePairDoubleOption('lower-ratio', min: 0, max: 1),
  RepeatablePairDoubleOption('upper-ratio', min: 0, max: 1),
]);

new()
  : super(
      pairedOptions: [
        credentials,
        window,
        range,
        transport,
        includeExclude,
        lowHighPorts,
        lowerUpperRatios,
      ],
    );

final credentialValues = inputs.valueOf(credentials);
```

The default `PairedOptions` constructor allows the whole group to be omitted.
Use `PairedOptions.required` to require the whole group.

### Selected options

Use `SelectedOptions` when the user may choose named members independently:

```dart
static final outputSelection = SelectedOptions<String>.required(
  [
    PairStringOption('json'),
    PairStringOption('text'),
  ],
  single: true,
);

new() : super(selectedOptions: [outputSelection]);

final selectedOutput = inputs.valueOf(outputSelection);
```

The default constructor permits zero or more selections. The required
constructor requires at least one. Set `single: true` to allow at most one;
combine it with the required constructor to require exactly one.

### Accessors

Use `AccessorListOption` for nested options with dotted names:

```dart
enum LogLevel { debug, info, warning, error }

static final server = AccessorListOption('server', [
  AccessorStringOption.required('host'),
  AccessorIntOption.withDefault('port', defaultValue: 443),
  AccessorDoubleOption('timeout'),
  AccessorChoiceOption.withDefault(
    'log-level',
    choices: LogLevel.values,
    defaultValue: LogLevel.info,
  ),
  AccessorListOption('tls', [
    AccessorStringOption('certificate'),
  ]),
]);

new() : super(accessors: [server]);

final serverValues = inputs.valueOf(server);
```

This parses spellings such as `--server.host`, `--server.port`, and
`--server.tls.certificate` into an immutable nested map. Accessor leaves
provide direct optional constructors plus `.required(...)` and
`.withDefault(...)` factories.

### Conflicts and aliases

Register incompatible named inputs in `conflicts`. Use the complete dotted
name for an accessor leaf:

```dart
new()
  : super(
      aliases: ['publish'],
      flags: [replace],
      options: [output],
      accessors: [server],
      conflicts: {
        'replace': ['output', 'server.host'],
      },
    );
```

Conflicts may name flags, ordinary options, paired or selected option members,
and accessor leaves. They do not name positionals, variadics, or accessor
groups.

## Standard input

Enable standard-input processing by mixing `HookRunner` into the selected
command and implementing `preRun`. Mamba supplies a
`ProcessedStandardInput?` before `run` executes.

```dart
final class ImportCommand extends Command with HookRunner {
  ProcessedStandardInput? _input;

  @override
  String get name => 'import';

  @override
  String get shortDescription => 'Import piped JSON.';

  @override
  void preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {
    _input = input;
  }

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final input = _input;
    if (input == null) {
      throw MambaException('Pipe JSON into this command.');
    }

    final document = input.json;
    return 'Imported ${document['name']}.';
  }

  @override
  void postRun(ParsedInputs inputs, MambaReadContext context) {
    _input = null;
  }
}
```

Read input through:

- `bytes` for the original byte values;
- `text` for direct character-code decoding;
- `utf8Text` for UTF-8 text; or
- `json` for JSON decoded from UTF-8 text.

`Executor.create()` uses Mamba's system process adapter and reads standard
input only when the process input is a pipe. No executor option is required:

```console
Get-Content payload.json | dart run bin/app.dart import
```

Test standard input through the fake executor:

```dart
final result = await Executor(
  'app',
  'Import data.',
  '1.0.0',
  [ImportCommand()],
).fake(
  standardInput: ProcessedStandardInput(
    utf8.encode('{"name":"tasks"}'),
  ),
).execute(['import']);

expect(
  result,
  isA<MambaSuccessResult>().having(
    (value) => value.output,
    'output',
    'Imported tasks.',
  ),
);
```

Import `dart:convert` when constructing UTF-8 input in a test. Treat malformed
UTF-8 or JSON as a CLI failure when those formats are part of the command's
contract.

## Group commands

A group may declare the same local inputs as a command.

Use `propagatedFlags` and `propagatedOptions` for inputs that descendants must
receive. Keep other inputs local to the group.

A group without a default subcommand produces no domain behavior when selected
by itself. Set `defaultSubCommandPath` when the group should delegate to a
specific descendant.

## Specialized behavior

- Read [Completion commands](references/completion-commands.md) when adding or
  changing Bash, Zsh, Fish, PowerShell, or Carapace generation.
- Read [Hook runners](references/hook-runners.md) when adding lifecycle behavior
  before or after execution or around a group's descendants.
