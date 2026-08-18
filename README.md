# Mamba

Mamba is a Dart library for defining command-line interfaces with declarative
input lists. It parses registered flags, options, positionals, and nested
accessors into typed maps that command handlers can use directly.

[![pub package](https://img.shields.io/pub/v/arg_parser.svg)](https://pub.dev/packages/arg_parser)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

## Features

- Define commands with lists of flags, options, positionals, and accessors.
- Receive Boolean flags, count flags, each single-option type, and each
  repeatable-option type in separate maps.
- Support Boolean and count flags; string, integer, double, choice, and
  repeatable options; named positionals; trailing arguments after `--`; and
  nested accessor values.
- Validate command definitions, render ANSI-styled help, and execute handlers.

## Installation

Mamba requires Dart SDK `^3.12.2`.

```sh
dart pub add arg_parser
```

## Quick start

Define inputs with lists, register a command, and parse tokens.

```dart
import 'package:arg_parser/mamba.dart';

void main() {
  final parser = Parser(
    CommandRegistry.create(
      'greet',
      'Print a greeting.',
      options: [
        StringOption(name: 'name', required: true, regex: RegExp(r'\S+')),
      ],
    ),
  );

  final (_, _, inputs, _) = parser.parse(['--name', 'Ada']);
  print('Hello, ${inputs.stringOptions!['name']}!');
}
```

## Commands

Extend `Command` to group its input lists with a handler. Nested commands are
provided through `commands`. `Executor` routes help requests and invokes the
selected command with positionals, parsed inputs, and trailing arguments.
Returned command strings are written to stdout; thrown errors are written to
stderr.

```dart
final class GreetCommand extends Command {
  GreetCommand()
    : super(
        'greet',
        'Print a greeting.',
        flags: [BooleanFlag(name: 'excited')],
        options: [StringOption(name: 'name', regex: RegExp(r'\S+'))],
      );

  @override
  String run(
    Map<String, String>? positionals,
    Inputs inputs,
    List<String> trailingArguments,
  ) {
    final name = inputs.stringOptions?['name'] ?? 'world';
    final suffix = inputs.boolFlags?['excited'] == true ? '!' : '.';
    return 'Hello, $name$suffix';
  }
}

Executor(
  'mamba',
  'Example command runner.',
  commands: [GreetCommand()],
).execute(['greet', '--name', 'Ada']);
```

`Executor` adds the Boolean `--dry-run` flag and count `--verbose` flag to
its registry and makes them available to every command. A default command path
is relative to the executor name:

```dart
Executor(
  'git',
  'Version control.',
  defaultSubCommandPath: ['status'],
  commands: [StatusCommand()],
).execute([]);
```

`GroupCommand` can use the same relative path with
`defaultSubCommandPath`; `runChildCommand` rejects empty or parent-qualified
paths. Commands using `HookRunner` receive selected-command hooks, while
persistent hooks run for each hook-enabled command on the selected path.

## Parsed inputs

`Parser.parse` returns
`(command, positionals, inputs, trailingArguments)`. `inputs` has nullable maps
for each registered input category:

```dart
typedef Inputs = ({
  Map<String, bool>? boolFlags,
  Map<String, int>? countFlags,
  Map<String, String>? stringOptions,
  Map<String, int>? intOptions,
  Map<String, double>? doubleOptions,
  Map<String, List<String>>? repeatedStringOptions,
  Map<String, List<int>>? repeatedIntOptions,
  Map<String, List<double>>? repeatedDoubleOptions,
  Map<String, dynamic>? accessors,
});
```

A `ChoiceOption` is returned in `stringOptions`. Accessors preserve their
nested structure and their primitive values, so an `AccessorIntOption` produces
an `int` in the accessor map.

## Input lists

Use `flags`, `options`, and `accessors` when creating an `Executor`.
Positionals are declared on `Command` or `CommandRegistry` instances.
Accessors accept a root `List<AccessorOption>` and may contain
nested `AccessorListOption` groups.

```dart
final registry = CommandRegistry.create(
  'config',
  'Read configuration.',
  flags: [CountFlag(name: 'verbose', short: 'v')],
  options: [RepeatableStringOption(name: 'tag')],
  accessors: [
    AccessorListOption(
      name: 'server',
      options: [AccessorIntOption(name: 'port')],
    ),
  ],
);
```

Options and accessor leaves accept either `--name value` or `--name=value`.
Arguments after `--` are not parsed and are passed as the fourth parser result
and third `Command.run` argument. Named positionals are passed as the first
`Command.run` argument.

### Context

Supply a `MambaContext` to `Executor` when it is constructed to make values
available to command hooks. `HookRunner.postRun` receives a
`MambaReadContext`, which exposes only `get`; if no context is supplied,
`Executor` creates an empty one.

```dart
final environmentKey = MambaContextKey<String>();
final context = MambaContext()..set(environmentKey, 'production');

final executor = Executor(
  'mamba',
  'Example command runner.',
  context: context,
  commands: [GreetCommand()],
);
```

### Paired options

A typed `PairedOption` defines the first CLI option and groups it with one or
more typed `PairOption` children. By default, if a caller passes the primary or
any child, they must pass every option in the group. Set `variant: true` to
make the members mutually exclusive: an optional variant accepts zero or one
member, while a required variant accepts exactly one. Children do not accept
`required`; the primary paired option owns that setting. Parsed values are
included in the same typed maps as regular options.

```dart
final credentials = PairedStringOption(
  name: 'username',
  options: [PairStringOption(name: 'password')],
);

final registry = CommandRegistry.create(
  'login',
  'Authenticate a user.',
  pairedOptions: [credentials],
);
```

### Help formatter DSLs

`MambaHelpFormatter` renders each paired group as one expression. Optional groups use
square brackets, required groups use angle brackets, repeatable members use
`...`, and member descriptions are joined with `; `:

```text
[ --username & --password ] Username; Password
< ...--header | -H & --request-id > Header; Request ID
```

`PairString` is the public formatter value behind `&`. It accepts a primary member
and an iterable of paired members; members may be plain or ANSI-styled strings.

```dart
PairString('--username', ['--password']).string;
// --username & --password
```

`OrString` is also public and joins a primary member with alternatives using ` | `.
Set `variant: true` on a `PairedOption` to have `CommandRegistry`, `Parser`,
and `MambaHelpFormatter` model an exactly-one alternative group.

```dart
final credentials = PairedStringOption(
  name: 'token',
  variant: true,
  options: [PairStringOption(name: 'api-key')],
);

OrString('--token', ['--api-key']).string;
// --token | --api-key
```

## Development

```sh
dart pub get
dart analyze
dart test
dart format lib test
```

## License

Mamba is licensed under the [MIT License](LICENSE).
