---
title: Getting Started
description: Scaffold a Dart CLI project with Mamba and add your first command
sidebar:
  order: 1
---

Mamba can scaffold a Dart console package and generate command skeletons for
it. You can use the generated project as a starting point, then register your
commands with an `Executor`.

## Install the Mamba CLI

Mamba requires Dart SDK `^3.13.2`. Install the `mamba` executable globally
with Dart:

```sh
dart pub global activate mamba
```

This installs the `mamba` command. If Dart's pub-cache `bin` directory is not
on your `PATH`, run the same commands through Dart instead:

```sh
dart pub global run mamba --help
```

Check that the CLI is available:

```sh
mamba --help
```

## Create a project

Run `mamba create` from the directory that should contain your new project.
The command takes a package name and creates a directory with that name:

```sh
cd ~/code
mamba create my_app
cd my_app
dart pub get
```

The package name must start with a lowercase letter and may contain lowercase
letters, numbers, and underscores. For example, `my_app` is valid, while
`MyApp` is not.

If the `mamba` executable is not on your `PATH`, replace
`mamba create my_app` with `dart pub global run mamba create my_app`.

The generated project contains:

```text
my_app/
├── bin/
│   └── my_app.dart
└── pubspec.yaml
```

The generated executable uses Mamba's `Executor` and starts with no
application commands. Run it to see the generated help output:

```sh
dart run bin/my_app.dart
```

Run the create command from the parent directory, not after entering
`my_app`.

## Scaffold a command

From the root of the generated project, create a command skeleton with
`mamba command`:

```sh
mamba command greet
```

This creates `lib/greet.dart` with a typed `Command` class. The generated
command is intentionally small: edit its description and `run` method to
implement your behavior.

For example, update the generated file to:

```dart
import 'package:mamba/mamba.dart';

final class GreetCommand extends Command {
  @override
  String get name => 'greet';

  @override
  String get shortDescription => 'Greet the user.';

  @override
  String run(CommandInvocation invocation, List<String> args) =>
      'Hello from Mamba!';
}
```

Use `mamba command --help` to see the command-scaffolding options. You can
also use the equivalent Dart invocation when the global executable is not on
your `PATH`:

```sh
dart pub global run mamba command greet
```

## Register the command

Scaffolding creates the command file, but it does not modify your executable's
command list. Import the command in `bin/my_app.dart` and register an instance
with the executor:

```dart
import 'package:mamba/mamba.dart';
import 'package:my_app/greet.dart';

Future<void> main(List<String> args) => Executor(
  'my_app',
  'A command-line application.',
  '1.0.0',
  [GreetCommand()],
).create().execute(args);
```

Now run the command:

```sh
dart run bin/my_app.dart greet
```

The output is:

```text
Hello from Mamba!
```

Mamba generates help from the same command definitions used for parsing and
execution. View it with:

```sh
dart run bin/my_app.dart --help
```

You should see `greet` listed under `Commands`. Use the command-specific help
while developing it:

```sh
dart run bin/my_app.dart greet --help
```

## Choose a default command

If one command should run when no command name is supplied, pass its path as
`defaultCommandPath`:

```dart
Future<void> main(List<String> args) => Executor(
  'my_app',
  'A command-line application.',
  '1.0.0',
  [GreetCommand()],
  defaultCommandPath: ['greet'],
).create().execute(args);
```

With this setting, running `dart run bin/my_app.dart` executes `greet`. An
explicit command name, such as `dart run bin/my_app.dart greet`, still selects
the command directly.

## Next steps

- Add typed positionals, flags, and options to your command.
- Use `GroupCommand` for nested commands such as `remote add`.
- Use `Executor.fake()` to test commands without writing to process streams.
- Add `CompletionCommand` to generate shell completions.
