# Mamba

Mamba is a Dart library for defining command-line interfaces with typed schemas.
It is for developers who want commands, options, flags, nested accessor values,
and positionals to be declared once and converted into application-friendly
records after parsing. Mamba keeps command registration and input conversion in
the same schema so CLI code can focus on its behavior rather than token maps.

[![pub package](https://img.shields.io/pub/v/arg_parser.svg)](https://pub.dev/packages/arg_parser)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

## Features

- Register commands through flag, option, positional, and accessor schemas.
- Convert parsed inputs into typed Dart records with each schema's `toRecord`.
- Support Boolean and count flags; string, integer, double, choice, and
  repeatable options; named positionals; variadics; and nested accessor values.
- Validate command definitions before parsing, including invalid names and
  duplicate registrations.
- Render ANSI-styled help and execute registered command handlers.

## Installation

Mamba requires Dart SDK `^3.12.2`.

```sh
dart pub add arg_parser
```

## Quick start

Import Mamba's public entry point, define an option schema, register it, and
parse command-line tokens.

```dart
import 'package:arg_parser/mamba.dart';

class GreetingOptions extends OptionSchema<({String name})> {
  @override
  final schema = [
    StringOption(name: 'name', required: true, regex: RegExp(r'\S+')),
  ];

  @override
  ({String name}) toRecord(Map<String, dynamic> args) =>
      (name: args['name'] as String);
}

void main() {
  final parser = Parser(
    CommandRegistry.create(
      'greet',
      'Print a greeting.',
      optionSchema: GreetingOptions(),
    ),
  );

  final (_, inputs) = parser.parse(['--name', 'Ada']);
  final options = inputs.options! as ({String name});
  print('Hello, ${options.name}!');
}
```

## Concepts

### Schemas register and shape input

Every schema has two responsibilities:

1. Its `schema` list declares the inputs accepted by a command.
2. Its `toRecord` method converts the parser's raw values into the record your
   application uses.

For example, a flag schema can merge a Boolean flag and a count flag into one
record:

```dart
class LoggingFlags extends FlagSchema<({bool verbose, int quiet})> {
  @override
  final schema = [
    BooleanFlag(name: 'verbose', short: 'v'),
    CountFlag(name: 'quiet', short: 'q'),
  ];

  @override
  ({bool verbose, int quiet}) toRecord(Map<String, dynamic> args) => (
    verbose: args['verbose'] as bool? ?? false,
    quiet: args['quiet'] as int? ?? 0,
  );
}
```

Use `OptionSchema`, `FlagSchema`, `PositionalSchema`, and
`AccessorOptionSchema` to model each input category. `PositionalSchema` also
owns mandatory and optional positionals plus an optional `Variadic` input.

### Commands own schemas

Extend `Command` to group schemas with a handler. Nested commands are supplied
through the `commands` constructor argument. `Executor` registers the root
command tree, parses its arguments, routes help requests, and runs the selected
command.

```dart
final class GreetCommand extends Command {
  GreetCommand() : super('greet', 'Print a greeting.');

  @override
  void run(Inputs input, List<String> variadic) {
    print('Hello!');
  }
}

Executor(
  'mamba',
  'Example command runner.',
  commands: [GreetCommand()],
).execute(['greet']);
```

## Usage

### Options and flags

Use `StringOption`, `IntOption`, `DoubleOption`, and `ChoiceOption` for one
value; use the corresponding `Repeatable...Option` classes for repeated
values. `BooleanFlag` supports a short name, a default value, and optional
negation. `CountFlag` increments each time it appears.

```dart
enum OutputFormat { text, json }

final schema = [
  BooleanFlag(name: 'color', negatable: true),
  CountFlag(name: 'verbose', short: 'v'),
  ChoiceOption<OutputFormat>(name: 'format', choices: OutputFormat.values),
  RepeatableStringOption(name: 'tag'),
];
```

### Nested accessor values

`AccessorOptionSchema` registers primitive accessor options or recursive
`AccessorListOption` groups. A dotted option such as
`--remote.origin.urls.fetch https://example.com` is provided to `toRecord` as
a nested map. Accessor paths may be nested to any depth.

```dart
final schema = [
  AccessorListOption(
    name: 'server',
    options: [AccessorIntOption(name: 'port')],
  ),
];
```

### Parse errors and help

`Parser.parse` throws `MambaParseException` for invalid command-line input and
`CommandRegistry.create` throws `MambaException` or `MambaRegistryError` for
invalid command definitions. Use `HelpFormatter` to render a
`CommandRegistry`, or `Executor` to route `--help` and `-h` automatically.

## Development

```sh
dart pub get
dart analyze
dart test
```

Format Dart sources before submitting changes:

```sh
dart format lib test
```

## Contributing

Keep changes focused, add or update behavioral tests, and run `dart analyze`
and `dart test` before opening a pull request. For substantial API changes,
open an issue first to discuss the schema and compatibility impact.

## License

Mamba is licensed under the [MIT License](LICENSE).
