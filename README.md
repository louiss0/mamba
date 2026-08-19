# Mamba

[![pub package](https://img.shields.io/pub/v/mamba.svg)](https://pub.dev/packages/mamba)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

Mamba is a typed, list-defined framework for building Dart command-line tools.
Define commands and their inputs as immutable schemas; Mamba parses arguments,
validates values, renders help, and executes the selected command.

## Install

```sh
dart pub add mamba
```

## Quick start

```dart
import 'dart:async';

import 'package:mamba/mamba.dart';

class Commit extends Command {
  Commit()
    : super(
        mandatoryPositionals: [Positional('message')],
        flags: [
          BooleanFlag(
            name: 'amend',
            short: 'a',
            description: 'Amend the previous commit.',
          ),
        ],
      );

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository.';

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final message = positionals!['message']!;
    final amend = inputs.boolFlags!['amend']!;
    return 'Committing "$message"${amend ? ' as an amendment' : ''}.';
  }
}

Future<void> main(List<String> args) async {
  final executor = Executor(
    'git',
    'A source-control tool.',
    commands: [Commit()],
  );

  await executor.execute(args);
}
```

Run it with:

```sh
dart run bin/main.dart commit "Document the release" --amend
```

Use `--help` or `-h` to print help for the root command or a selected command.

## Inputs

A command can declare the following inputs through its `Command` constructor:

- `mandatoryPositionals` and `discretionaryPositionals` accept ordered values.
- `flags` accepts `BooleanFlag` and `CountFlag` values.
- `options` accepts typed single and repeatable string, integer, double, and
  enum-choice options.
- `pairedOptions` requires related values together, or accepts exactly one
  member when `variant: true`.
- `accessors` accepts dotted options and returns nested maps.

Values are passed to `run` as `ParsedPositionals` and `ParsedNamedInputs`.
For example, boolean flags are in `inputs.boolFlags`, string and enum options
are in `inputs.stringOptions`, and integer options are in `inputs.intOptions`.
Arguments after `--` are passed unchanged as `trailingArguments`.

```dart
class Push extends Command {
  Push()
    : super(
        options: [
          StringOption(
            name: 'remote',
            short: 'r',
            regex: RegExp(r'\S+'),
            required: true,
            description: 'The remote to push to.',
          ),
          ChoiceOption<Mode>(
            name: 'force',
            choices: Mode.values,
            defaultValue: Mode.never,
            description: 'When to force the push.',
          ),
        ],
      );

  @override
  String get name => 'push';

  @override
  String get shortDescription => 'Push changes to a remote.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    return 'Pushing to ${inputs.stringOptions!['remote']}.';
  }
}

enum Mode { never, always }
```

## Nested commands

Use `GroupCommand` to organize child commands. Group commands can publish
`inheritedFlags` and `inheritedOptions` to every descendant.

```dart
class Remote extends GroupCommand {
  Remote()
    : super(
        [RemoteAdd(), RemoteRemove()],
        inheritedFlags: [
          BooleanFlag(
            name: 'verbose',
            short: 'v',
            description: 'Show detailed output.',
          ),
        ],
      );

  @override
  String get name => 'remote';

  @override
  String get shortDescription => 'Manage remote repositories.';
}
```

A group can set `defaultSubCommandPath` to run a child when the group itself is
invoked. Implement `run` only when custom default-command behavior is needed.
