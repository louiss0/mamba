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
  repeatable options; named positionals; variadics; and nested accessor values.
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

  final (_, inputs, _) = parser.parse(['--name', 'Ada']);
  print('Hello, ${inputs.stringOptions!['name']}!');
}
```

## Commands

Extend `Command` to group its input lists with a handler. Nested commands are
provided through `commands`. `Executor` routes help requests and invokes the
selected command with parsed inputs and variadic values.

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
  void run(Inputs inputs, List<String> variadic) {
    final name = inputs.stringOptions?['name'] ?? 'world';
    final suffix = inputs.boolFlags?['excited'] == true ? '!' : '.';
    print('Hello, $name$suffix');
  }
}

Executor(
  'mamba',
  'Example command runner.',
  commands: [GreetCommand()],
).execute(['greet', '--name', 'Ada']);
```

## Parsed inputs

`Parser.parse` returns `(command, inputs, variadic)`. `inputs` has nullable maps
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
  Map<String, String>? positionalOptions,
});
```

A `ChoiceOption` is returned in `stringOptions`. Accessors preserve their
nested structure and their primitive values, so an `AccessorIntOption` produces
an `int` in the accessor map.

## Input lists

Use `flags`, `options`, `mandatoryPositionals`, `discretionaryPositionals`,
`variadic`, and `accessors` when creating a `CommandRegistry`, `Command`, or
`Executor`. Accessors accept a root `List<AccessorOption>` and may contain
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
Variadic values are accepted only after `--` and are passed as the third parser
result and the second `Command.run` argument.

### Paired options

A typed `PairedOption` defines the first CLI option and groups it with one or
more typed `PairOption` children. If a caller passes the primary or any child,
they must pass every option in the group. Children do not accept `required`;
the primary paired option owns that setting. Parsed values are included in the
same typed maps as regular options.

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

## Development

```sh
dart pub get
dart analyze
dart test
dart format lib test
```

## License

Mamba is licensed under the [MIT License](LICENSE).
