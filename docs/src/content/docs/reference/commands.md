---
title: Commands
description: Define executable and group commands in Mamba
---

Mamba has two command types:

- `Command` represents an executable command.
- `GroupCommand` owns child commands and creates a nested command path.

Both types declare their inputs through the constructor inherited from
`Command`. The executor validates the complete command tree before it handles
an invocation.

## Executable commands

Extend `Command`, provide `name` and `shortDescription`, and implement `run`:

```dart
import 'package:mamba/mamba.dart';

final class CommitCommand extends Command {
  new() : super(mandatoryPositionals: [file], flags: [amend]);

  static final file = NormalPositional(
    'file',
    description: 'File to add to the commit.',
  );
  static const amend = BooleanFlag(
    'amend',
    description: 'Replace the previous commit.',
  );

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record a source change.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final fileValue = inputs.valueOf(file);
    final amendValue = inputs.valueOf(amend);
    return amendValue ? 'Amended with $fileValue' : 'Committed $fileValue';
  }
}
```

`run` receives one identity-keyed `ParsedInputs` object and an immutable list
containing validated values after `--`. It can return `String?` or
`Future<String?>`; a non-null string becomes command output.

The `Command` constructor accepts:

| Parameter | Purpose |
| --- | --- |
| `longDescription` | Detailed help text. |
| `aliases` | Alternative command names. |
| `mandatoryPositionals` | Required positional declarations, in order. |
| `discretionaryPositionals` | Optional or defaulted positionals, in order. |
| `variadic` | Validation for values after `--`. |
| `flags` and `options` | Command-local named inputs. |
| `pairedOptions` | All-or-nothing option groups. |
| `selectedOptions` | Option groups that allow selected members. |
| `accessors` | Dotted option trees. |
| `conflicts` | Pairs of named inputs that cannot be used together. |

Retain each declaration as a static or instance field and read it through
`inputs.valueOf(declaration)`. String lookups are not part of the current API.

## Group commands

A group declares its child list as the first `super` argument:

```dart
final class GitCommand extends GroupCommand {
  new()
    : super(
        [CommitCommand()],
        propagatedFlags: [verbose],
      );

  static const verbose = CountFlag(
    'verbose',
    short: 'v',
    description: 'Increase output verbosity.',
  );

  @override
  String get name => 'git';

  @override
  String get shortDescription => 'Manage source changes.';
}
```

This produces the command path `git commit`. A group's own `flags`, `options`,
positionals, and accessors apply to the group itself. `propagatedFlags` and
`propagatedOptions` are inherited by descendants.

`defaultSubCommandPath` can name a relative child path for `GroupCommand.run`
to invoke when the group itself is selected. `Executor.defaultCommandPath` is
the separate application-level default used when the entire argument list is
empty.

## Register commands

Pass root commands to `Executor` in declaration order:

```dart
Future<void> main(List<String> args) => Executor(
  'tool',
  'Manage source changes.',
  '1.0.0',
  [GitCommand()],
).create().execute(args);
```

Sibling names and aliases must be unique. Names use a letter-led word form
with optional hyphenated or underscored segments.

## Input conflicts

Use `conflicts` to reject incompatible flags, ordinary options, paired or
selected option members, and accessor leaves:

```dart
final class DeployCommand extends Command {
  new()
    : super(
        flags: [replace],
        options: [output],
        conflicts: {
          'replace': ['output'],
        },
      );

  static const replace = BooleanFlag('replace');
  static final output = StringOption('output');

  @override
  String get name => 'deploy';

  @override
  String get shortDescription => 'Deploy the application.';

  @override
  String run(ParsedInputs inputs, List<String> args) => 'Deployed.';
}
```

Accessor leaves use dotted names such as `server.auth.token`. Positional
names, variadics, and accessor group names are not valid conflict entries. A
required input cannot conflict with another input because the other input
would become impossible to supply.
