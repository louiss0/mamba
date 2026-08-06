# arg_parser

Dart command-line parsing tools: a schema-driven command parser with command
isolation and native object-shaped options, plus a direct `yargs-parser` port
for low-level token decoding.

The design is inspired by **Yargs**, rather than Dart's `package:args` builder:

- option definitions are declarative schema values snapshotted by the parser;
- selecting a command activates only that command branch;
- global options remain available throughout the selected branch;
- dotted CLI flags such as `--user.name` natively produce nested values;
- named positionals and options are returned in one argument object.

Malformed command-line input is returned as an `ArgParseFailure`, not thrown.

## `yargs-parser` port

The package also exports `YargsParser` and the convenience `yargsParser()`
function. This low-level parser accepts a command string or token iterable and
returns a map containing parsed options and the positional `_` list; it does
not select commands or enforce a schema.

```dart
final argv = yargsParser(
  '--output-file=report.txt -v',
  const YargsParserOptions(
    alias: {'verbose': ['v']},
    boolean: ['verbose'],
    string: ['output-file'],
  ),
);

// {_: [], output-file: report.txt, outputFile: report.txt, v: true, verbose: true}
```

`yargsParserDetailed()` provides aliases, generated aliases, defaults, the
effective configuration, and a captured parser error, matching the upstream
`.detailed()` API. See [`docs/yargs-parser-port.md`](docs/yargs-parser-port.md)
for the complete typed API and Dart-specific configuration decisions.

For command trees without Yargs's command-string DSL or external dependencies,
use the separate `YargsCommandRuntime`. It layers explicit command,
positional, option, validation, handler, help, and completion-candidate
behavior on `YargsParser`; see
[`docs/yargs-command-runtime.md`](docs/yargs-command-runtime.md). Its
standalone task-list example is
[`bin/yargs_command_task_list.dart`](bin/yargs_command_task_list.dart); see
[`docs/yargs-command-task-list-cli.md`](docs/yargs-command-task-list-cli.md).

## Schema-driven parser

```dart
final parser = ArgParser(
  options: {
    'verbose': const BooleanOption(alias: 'v'),
  },
  commands: [
    ArgCommand(
      'create',
      aliases: const {'new'},
      accessors: {
        'user': {
          'name': const StringOption(required: true),
          'admin': const BooleanOption(),
        },
      },
      positionals: const [
        ArgPositional('workspace', required: true),
      ],
    ),
  ],
);
```

Unlike a mutable builder, the complete command tree is visible in the parser's
construction and validated before any tokens are parsed.

## Parse arguments

```dart
final outcome = parser.parse([
  '--verbose',
  'create',
  'example',
  '--user.name=Ada',
  '--user.admin',
]);

switch (outcome) {
  case ArgParseSuccess(:final arguments):
    print(arguments.commandPath); // [create]
    print(arguments.values);
    // {
    //   verbose: true,
    //   user: {name: Ada, admin: true},
    //   workspace: example,
    // }
  case ArgParseFailure(:final error):
    print(error.message);
}
```

## Option schemas

Boolean options support defaults, short aliases, and negation:

```dart
'color': const BooleanOption(
  alias: 'c',
  defaultValue: true,
  negatable: true,
)
```

Accepted forms include `--color`, `--no-color`, `-c`, and Boolean short-option
clusters such as `-vc`.

String options support aliases, defaults, required values, and choices:

```dart
'format': const StringOption(
  alias: 'f',
  defaultValue: 'text',
  choices: {'text', 'json'},
)
```

Accepted forms include `--format json`, `--format=json`, `-f json`, and
`-fjson`. Repeated options use the last value.

## Accessor options

Accessor trees are configured separately from ordinary options. A nested map
mirrors the object returned by the parser and is a container, not an option:
its leaves are the only passable options.

```dart
final parser = ArgParser(
  accessors: {
    'server': {
      'host': const StringOption(defaultValue: 'localhost'),
      'port': const StringOption(),
    },
  },
);

final outcome = parser.parse(['--server.port=8080']);
final arguments = (outcome as ArgParseSuccess).arguments;

print(arguments.values);
// {server: {host: localhost, port: 8080}}

print(arguments.value('server.port')); // 8080
print(arguments.object('server'));
// {host: localhost, port: 8080}
```

The CLI spelling remains dotted because it is conventional and unambiguous,
but the schema never uses dotted keys. `--server` is rejected: only leaves such
as `--server.host` and `--server.port` are registered.

## Commands

A parser with commands requires one known root command. Subcommand options and
defaults do not exist until their branch is selected:

```dart
final parser = ArgParser(
  commands: [
    ArgCommand(
      'remote',
      commands: [
        ArgCommand('add'),
        ArgCommand('remove', aliases: {'rm'}),
      ],
    ),
  ],
);
```

Aliases are normalized in `commandPath`, so parsing `remote rm` reports
`['remote', 'remove']`.

Root and parent-command options are global within the selected branch. Both of
these are valid:

```text
--verbose build src
build src --verbose
```

Sibling command schemas remain inactive and unknown sibling options produce a
structured error.

## Positional schemas

Positionals are named and included in `values`:

```dart
positionals: const [
  ArgPositional('input', required: true),
  ArgPositional('outputs', multiple: true),
]
```

A variadic positional must be last. Tokens not claimed by a positional schema
remain available through `arguments.rest`. The `--` terminator treats every
following token as positional input.

## Error handling

```dart
switch (parser.parse(tokens)) {
  case ArgParseSuccess(:final arguments):
    run(arguments);
  case ArgParseFailure(:final error):
    print('${error.message} (token ${error.index})');
}
```

`ArgParseError` includes a stable `code`, the offending `token` when available,
and its absolute token `index`. Invalid schemas throw during parser creation
because duplicate names, aliases, and conflicting accessor paths are
programming errors.

## Task-list CLI example

The package includes two separate JSON-backed task-list executables. The
original `task_list` uses the schema-driven `ArgParser` and stores `.tasks.json`:

```text
dart run bin/task_list.dart add "Write release notes"
dart run bin/task_list.dart list --status=incomplete
```

The separate `yargs_task_list` demonstrates the low-level YargsParser port and
uses `.yargs_tasks.json`, so it cannot modify the original example's data:

```text
dart run bin/yargs_task_list.dart add "Write release notes"
dart run bin/yargs_task_list.dart list --status=incomplete
```

See [`docs/task-list-cli.md`](docs/task-list-cli.md) and
[`docs/yargs-task-list-cli.md`](docs/yargs-task-list-cli.md) for their command
references and CLI-design rationale.

## Design rationale

See [`docs/design.md`](docs/design.md) for a detailed walkthrough of the
architecture, parsing algorithm, alternatives considered, and Dart-specific
decisions. The cloned Yargs framework and its installed parser engine are
explained in [`docs/yargs-architecture.md`](docs/yargs-architecture.md) and
[`docs/yargs-parser-internals.md`](docs/yargs-parser-internals.md).

## Development

```text
dart pub get
dart test
dart analyze
```
