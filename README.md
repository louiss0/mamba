# Mamba

Mamba is a declarative Dart framework for building command-line applications. It
lets Dart developers define commands and their inputs once, then uses those
definitions for parsing, validation, help output, execution, testing, and shell
completion. Mamba exists to remove the drift and repetitive glue between a
CLI's syntax and the code that implements it.

[![pub package](https://img.shields.io/pub/v/mamba.svg)](https://pub.dev/packages/mamba)
[![downloads](https://img.shields.io/pub/dm/mamba.svg)](https://pub.dev/packages/mamba)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)
[![release workflow](https://github.com/louiss0/mamba/actions/workflows/publish.yml/badge.svg)](https://github.com/louiss0/mamba/actions/workflows/publish.yml)

![Mamba logo](https://raw.githubusercontent.com/louiss0/mamba/main/assets/Mamba-CLI.png)

[Read the full documentation](https://mamba-docs.onrender.com/)

## Features

- Define commands as Dart classes with typed, validated inputs.
- Support nested commands through `GroupCommand`.
- Handle positionals, variadic arguments, boolean and count flags, typed
  options, repeatable options, paired options, and dotted accessors.
- Generate help from the same command definitions used by the parser.
- Add lifecycle hooks and typed executor-scoped context.
- Test invocations without writing to process streams through `Executor.fake()`.
- Generate Bash, Zsh, Fish, PowerShell, and Carapace completions.
- Scaffold new Dart CLI projects and commands with the `mamba` executable.

## Installation

Mamba requires Dart SDK `^3.13.2`.

Mamba uses Dart 3.13 primary constructors where appropriate and concise
in-body constructor declarations throughout its source and examples.
Constructors declared inside a class use `new` or `factory` without repeating
the class name.

Add it to an existing Dart package:

```sh
dart pub add mamba
```

To install the optional project and command scaffolding executable globally:

```sh
dart pub global activate mamba
```

## Scaffold a project

The global executable can create a Dart console package and add command
skeletons:

```sh
mamba create my_app
cd my_app
dart pub get
dart run bin/my_app.dart
mamba command greet --with-suite
```

The generated command and test files still need to be registered in the
application's command list. Run `mamba --help` or `mamba command --help` for
all scaffolding options.

## Quick start

Create an executable such as `bin/hello.dart`:

```dart
import 'package:mamba/mamba.dart';

final class HelloCommand extends Command {
  @override
  String get name => 'hello';

  @override
  String get shortDescription => 'Say hello.';

  @override
  String run(ParsedInputs inputs, List<String> args) =>
      'Hello from Mamba!';
}

Future<void> main(List<String> args) => Executor(
  'hello',
  'A small Mamba CLI.',
  '1.0.0',
  [HelloCommand()],
).create().execute(args);
```

Run it with Dart:

```sh
dart run bin/hello.dart hello
dart run bin/hello.dart --help
```

## Usage

### Define commands and inputs

Scalar options can supply typed defaults with `StringOption.withDefault`,
`IntOption.withDefault`, and `DoubleOption.withDefault`. Repeatable defaults
are immutable lists and are replaced, rather than extended, by explicit input.
Accessor leaves also offer `required` and `withDefault` constructors. Command
resolution always skips an option's value, so a value equal to a command name
cannot select that command.

A command declares its syntax in its constructor and receives parsed values in
`run`:

```dart
final class AddCommand extends Command {
  new()
      : super(
          mandatoryPositionals: [path],
          flags: [all],
          options: [message],
        );

  static final path = NormalPositional('path');
  static final all = BooleanFlag(
    'all',
    short: 'a',
    description: 'Add every path.',
  );
  static final message = StringOption.required(
    'message',
    short: 'm',
    description: 'Commit message.',
  );

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add a path.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final pathValue = inputs.valueOf(path);
    final allPaths = inputs.valueOf(all);
    final messageValue = inputs.valueOf(message);
    return 'Adding ${allPaths ? 'all paths' : pathValue} with: $messageValue';
  }
}
```

Register it with the application executor:

```dart
final executor = Executor(
  'git-like',
  'Manage source changes.',
  '1.0.0',
  [AddCommand()],
).create();
```

`run` is called only after the invocation has been parsed and validated. It may
return a `String`, return `null` for no output, or return a `Future`.

### Input types

| Input | Use |
| --- | --- |
| `NormalPositional` / `ChoicePositional` | Required or optional values in command order. |
| `NormalVariadic` / `ChoiceVariadic` | Validate values supplied after `--`. |
| `BooleanFlag` / `CountFlag` | Valueless switches, aliases, bundles, and verbosity counts. |
| `StringOption`, `IntOption`, `DoubleOption`, `ChoiceOption` | Typed named values with optional aliases, defaults, ranges, or validation. |
| `Repeatable*Option` | Collect multiple values into typed lists. |
| `PairedOptions` | Require members together and map them by option name. |
| `SelectedOptions<T>` | Map selected pair options to an immutable `Map<String, T>`. |
| `AccessorListOption` and accessor leaves | Parse nested values such as `--database.port 5432` into an immutable map. |

Long options accept `--name value` and `--name=value`; short options accept
`-n value`. Boolean short flags can be bundled, for example `-vvv`. `--` ends
option parsing and passes the remaining validated tokens to `Command.run` as
`args`. They are not stored in `ParsedInputs`.

### Conflicting inputs

Commands can reject incompatible named inputs with `conflicts`. Each map key
conflicts with every name in its list. Names may refer to flags, ordinary,
paired, or selected option members, and accessor leaves use dotted paths.
Positional names, variadics, and accessor group names are not conflict inputs.

```dart
final class DeployCommand extends Command {
  new()
      : super(
          flags: [BooleanFlag('replace')],
          options: [StringOption('output')],
          conflicts: {
            'replace': ['output'],
          },
        );

  // Command members omitted.
}
```

The map belongs to the command that owns those inputs; `Executor` does not
define conflicts. Registry creation rejects a conflict between a required input
and another input because the other input could never be supplied. When both
inputs are required, the error names both inputs and explains that they cannot
be used together.

### Group commands

Use `GroupCommand` for nested command paths such as `remote add`. Groups can
publish inherited flags and options, and can select a child by setting
`defaultSubCommandPath`.

```dart
final class RemoteCommand extends GroupCommand {
  new()
      : super(
          [RemoteAddCommand()],
          propagatedFlags: [
            BooleanFlag('verbose', short: 'v', description: 'Show details.'),
          ],
        );

  @override
  String get name => 'remote';

  @override
  String get shortDescription => 'Manage remotes.';
}
```

### Hooks and context

Mix `HookRunner` into a command for pre- and post-execution work. Mix
`PersistentHookRunner` into a group to run hooks around descendant commands.
`MambaContext` is a typed, executor-scoped scalar state bag that persistent
hooks can share and mutate. Keys use `String`, `bool`, `int`, or `double`; write
with the matching sealed wrapper (such as `MambaContextString`) and read the
primitive directly. Context is hook state, not a dependency container, so
collections and domain objects are unsupported. Environment variables and
configuration files remain application responsibilities.

### Shell completions

Add the built-in completion command to expose Mamba's registry to the supported
completion converters:

```dart
final class Completion extends CompletionCommand {
  new() : super.preset(null);
}
```

Register `Completion()` with the executor, then generate an artifact using the
shell name and an optional output path:

```sh
dart run bin/hello.dart completion bash ./hello.bash
dart run bin/hello.dart completion carapace ./hello.yaml
```

For custom completion integrations, extend `CompletionCommand` and use its
assigned `registryRecord`.

## Configuration

`Executor` is the composition root for an application. In addition to its
name, description, version, and commands, it can receive:

- `longDescription` for detailed help;
- root `flags`, `options`, and `accessors`;
- `defaultCommandPath` for a command to run when no command is selected;
- a custom `MambaContext`; and
- a custom `HelpFormatter`.

Every executor includes `--help`/`-h`, `--dry-run`, `--verbose`/`-v`, and
`--version`. Mamba parses these values; application code decides what
`--dry-run` and `--verbose` mean for its own behavior. `--version` prints the
semantic version supplied to `Executor`.

## Examples

The repository includes a persisted task-list CLI in
[`example/example.dart`](example/example.dart):

```sh
dart run example/example.dart create \
  --title "Review pull request" \
  --description "Check the parser changes"
dart run example/example.dart list --pending
dart run example/example.dart complete 1
```

The task data is stored in the system temporary directory. Use it as a compact
example of typed options, validated positionals, command errors, and a
completion command.

## Testing

Use `fake()` in tests instead of the production executor. It returns a
`MambaSuccessResult` or `MambaFailureResult` rather than writing to stdout or
stderr:

```dart
final result = await Executor(
  'hello',
  'A test CLI.',
  '1.0.0',
  [HelloCommand()],
).fake().execute(['hello']);

expect(result, isA<MambaSuccessResult>());
```

Run the package tests with:

```sh
dart test
```

## Project documentation

The complete guides and API reference are available at
[https://mamba-docs.onrender.com/](https://mamba-docs.onrender.com/). The
repository source for the documentation site is in [`docs/`](docs/).

The main library entry point is [`lib/mamba.dart`](lib/mamba.dart). The public
API is organized around these components:

- `Command` and `GroupCommand` define the CLI surface and behavior.
- `CommandRegistry` validates and indexes declarations.
- `Parser` turns tokens into typed values without executing commands.
- `Executor` handles dispatch, help, output, hooks, and the process boundary.
- `HelpFormatter` renders the selected command registry.
- Integration converters translate registry records into completion artifacts.

## Development

For the Dart package:

```sh
dart pub get
dart format .
dart analyze --fatal-infos
dart test
```

The documentation site is an Astro Starlight project. To work on it locally:

```sh
cd docs
pnpm install
pnpm dev
```

Other documentation commands are `pnpm build`, `pnpm preview`, and `pnpm
test`. See [`docs/README.md`](docs/README.md) for the page generator workflow.

## Contributing

Issues and pull requests are welcome. For code changes, include focused tests
and run formatting, analysis, and the test suite before submitting a pull
request. Documentation changes should update the relevant page under `docs/`
and be checked with the documentation build.

## License

Mamba is released under the [MIT License](LICENSE).
