---
title: Completions
description: Generate Bash, Zsh, Fish, PowerShell, and Carapace completions
---

Mamba converts the same validated registry used for parsing and help into
completion artifacts for Bash, Zsh, Fish, PowerShell, and Carapace.

## Completion converters

Each converter accepts a `RegistryRecord` and returns the generated artifact:

```dart
final bash = ToBashCompletionConverter(registryRecord).convert();
final zsh = ToZshCompletionConverter(registryRecord).convert();
final fish = ToFishCompletionConverter(registryRecord).convert();
final powerShell = ToPowerShellCompletionConverter(registryRecord).convert();
final carapace = CarapaceSpecConverter(registryRecord).convert();
```

Converters are deterministic and do not inspect live command objects or parse
an invocation.

## Access the registry record

Extend `CompletionCommand` when a command needs the complete application
registry. The executor assigns `registryRecord` while it builds the execution
environment, before the completion command can run.

This example selects a converter and writes its output to a required path:

```dart
import 'dart:io';

import 'package:mamba/mamba.dart';

final class GenerateCompletionCommand extends CompletionCommand {
  new() : super(options: [shell, output]);

  static final shell = ChoiceOption.required(
    'shell',
    choices: ShellCompletion.values,
  );
  static final output = StringOption.required(
    'output',
    description: 'File to write.',
  );

  @override
  String get name => 'completion';

  @override
  String get shortDescription => 'Generate a shell completion artifact.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final selectedShell = inputs.valueOf(shell);
    final path = inputs.valueOf(output);
    final content = switch (selectedShell) {
      .bash => ToBashCompletionConverter(registryRecord).convert(),
      .zsh => ToZshCompletionConverter(registryRecord).convert(),
      .fish => ToFishCompletionConverter(registryRecord).convert(),
      .powershell => ToPowerShellCompletionConverter(registryRecord).convert(),
      .carapace => CarapaceSpecConverter(registryRecord).convert(),
    };
    File(path).writeAsStringSync(content);
    return 'Wrote ${selectedShell.name} completions to $path.';
  }
}
```

Register `GenerateCompletionCommand()` in the executor's command list, then
invoke it with named options:

```console
my-cli completion --shell bash --output ./my-cli.bash
my-cli completion --shell carapace --output ./my-cli.yaml
```

For Carapace specifically, `CarapaceSpecWriter` can choose the platform's
Carapace spec directory or write to an explicit `outputPath`.

## The preset constructor

`CompletionCommand.preset(...)` supplies Mamba's standard completion command
metadata:

- `completion` as the command name;
- `cmp` and `cpt` as aliases;
- a required `ShellCompletion` positional;
- an optional output-path positional;
- shell-specific path validation.

Its required named `createFile` parameter accepts a callback or `null`. The
callback receives the validated path. Passing `null` uses the selected
converter and writes the generated artifact synchronously to the destination.

```dart
final completion = CompletionCommand.preset(createFile: null);
```

Pass a callback to replace the default destination handling:

```dart
final completion = CompletionCommand.preset(
  createFile: (path) =>
    print('Write completion through custom storage at $path'),
);
```

When the optional path is omitted, the callback receives an empty string.

## `RegistryRecord` shape

`registryRecord` is an immutable, typed description of the validated command
tree, not an untyped map. `RegistryRecord` describes the application root;
each entry in `commands` is a `RegistryCommand` describing one child command.
Nullable collections mean that the command has no entries of that kind, so
read them with `?? const []` when traversing the tree.

```text
RegistryRecord
|- commands -------- RegistryCommand (recursive)
|- positionals ------ RegistryPositional
|- flags ------------ RegistryFlag
|- options ---------- RegistryOption
|- optionGroups ----- RegistryOptionGroup
`- accessors -------- RegistryAccessor (recursive)
```

The root record has these fields:

| Field | Type | Contents |
| --- | --- | --- |
| `name` | `String` | Canonical application name used to invoke the executable. |
| `description` | `String` | Short description followed by the long description, separated by a blank line when both exist. |
| `commands` | `List<RegistryCommand>?` | Child command records in declaration order. |
| `positionals` | `List<RegistryPositional>?` | Ordered positional declarations. Records produced by `CommandRegistry.toMap()` leave this `null` on the application root. |
| `variadic` | `RegistryVariadic?` | Validation metadata for trailing values after `--`. |
| `flags` | `List<RegistryFlag>?` | Flags available at this command. |
| `persistentFlags` | `List<RegistryFlag>?` | Flags that converters should also make available to descendants. |
| `options` | `List<RegistryOption>?` | Value-taking options available at this command. |
| `persistentOptions` | `List<RegistryOption>?` | Options that converters should also make available to descendants. |
| `optionGroups` | `List<RegistryOptionGroup>?` | All-or-nothing paired-option groups. |
| `accessors` | `List<RegistryAccessor>?` | Recursive trees that become dotted option names. |

`CommandRegistry.toMap()` places each command's effective inherited inputs in
`flags`, `options`, and `accessors`. It currently leaves `persistentFlags` and
`persistentOptions` `null`; those fields let converters also consume manually
assembled records that express inheritance separately.

### `RegistryCommand`

`RegistryCommand` represents one node below the application root. It carries
the same input collections as `RegistryRecord`, plus command-specific identity
and recursion:

| Field | Meaning |
| --- | --- |
| `name` | Canonical token that selects the command. |
| `description` | Combined short and optional long help text. |
| `aliases` | Alternative tokens that select the same command. |
| `commands` | Direct child commands; traverse recursively for deeper paths. |
| `positionals` | Positional inputs in parse order. |
| `variadic` | Trailing values accepted after `--`. |
| `flags` / `options` | Inputs available on this command. |
| `persistentFlags` / `persistentOptions` | Inputs inherited by descendants when supplied explicitly in a record. |
| `optionGroups` | Paired-option relationships owned by this command. |
| `accessors` | Dotted option trees available on this command. |

Build the command path while descending through `commands`. Completion
converters use that path to distinguish identically named inputs belonging to
different commands.

### `RegistryPositional`

`RegistryPositional` describes one positional input. Its location in the list
is its parse position.

| Field | Meaning |
| --- | --- |
| `name` | Human-readable input name used by help and completion descriptions. |
| `required` | Whether the positional must be supplied. |
| `description` | Optional help text. |
| `choices` | Allowed enum names when the positional is choice-backed. |
| `defaultValue` | Default rendered as text; repeated defaults are comma-separated. |
| `repeatable` | `true` for a repeated positional and `null` otherwise. |
| `times` | Exact repetition count for a repeated positional. |
| `pattern` | Regular-expression source used to validate non-choice values. |

Use `choices` for finite completion candidates. `pattern` describes
validation, but shells generally cannot turn an arbitrary regular expression
into useful candidates.

### `RegistryFlag`

`RegistryFlag` describes a named input that consumes no following value:

| Field | Meaning |
| --- | --- |
| `name` | Long spelling without the leading `--`. |
| `short` | Optional one-character spelling without the leading `-`. |
| `defaultValue` | Boolean default for a `BooleanFlag`; `null` for other flag kinds. |
| `negatable` | Whether a boolean flag also accepts `--no-<name>`. |
| `hidden` | Whether completion output should omit the flag. |
| `description` | Optional help text shown beside the candidate. |

`defaultValue` and `negatable` are nullable because count flags do not have
boolean semantics. A hidden flag remains parseable even though converters do
not advertise it.

### `RegistryOption`

`RegistryOption` describes a named input that consumes a value. Its fields
cover spelling, cardinality, validation, and group relationships:

| Field | Meaning |
| --- | --- |
| `name` / `short` | Long and optional one-character spellings, without dashes. |
| `required` | Whether the option must occur. |
| `hidden` | Whether completion output should omit the option. |
| `description` | Optional help text shown beside the candidate. |
| `valueType` | One of `string`, `int`, `double`, or `choice`. |
| `repeatable` | `true` when the option can occur more than once; otherwise `null`. |
| `unique` | `true` when repeated values may not repeat; otherwise `null`. |
| `choices` | Finite enum names to offer as values. |
| `defaultValue` | Default rendered as text; list defaults are comma-separated. |
| `pattern` | Regular-expression source for string validation. |
| `min` / `max` | Inclusive numeric bounds when range validation is present. |
| `step` | Required numeric interval when step validation is present. |
| `pairedOptions` | Names of all members in the same paired group. |

Converters can offer `choices` directly and may derive bounded numeric
candidates from `min`, `max`, and `step`. `pairedOptions` lets a converter
recognize that selecting one member requires the other members as well.

### `RegistryOptionGroup`

`RegistryOptionGroup` captures an all-or-nothing `PairedOptions` declaration:

| Field | Meaning |
| --- | --- |
| `required` | `true` when the entire group must be present; `false` when the entire group may be omitted. |
| `members` | Option names belonging to the group, in declaration order. |

Supplying any member requires every member regardless of `required`.
`required` controls whether omitting the whole group is valid. Selected-option
groups are flattened into `options`; they are not emitted as
`RegistryOptionGroup` values.

### `RegistryAccessor`

`RegistryAccessor` is a recursive tagged object. A group is an intermediate
branch, while a value is a completable leaf:

| `kind` | Populated fields | Meaning |
| --- | --- | --- |
| `group` | `name`, `hidden`, `description`, `options` | A named branch containing more accessors. |
| `value` | `name`, `valueType`, `description`, `choices`, `defaultValue`, `pattern` | A leaf that consumes a value. |

Join ancestor names with `.` to obtain the long option spelling. For example,
a `server` group containing a `tls` group containing a `certificate` value
becomes `--server.tls.certificate`. `hidden` belongs to groups, so hiding a
group hides its descendant leaves. Leaf `valueType` uses the same `string`,
`int`, `double`, and `choice` values as `RegistryOption`.

Use the record's named getters and ordinary list traversal to inspect the
root and descendants:

```dart
void visitCommand(RegistryCommand command, List<String> parentPath) {
  final path = [...parentPath, command.name];
  print('${path.join(' ')}: ${command.description}');

  for (final option in command.options ?? const <RegistryOption>[]) {
    print('--${option.name}: ${option.valueType}');
  }
  for (final child in command.commands ?? const <RegistryCommand>[]) {
    visitCommand(child, path);
  }
}

for (final command in registryRecord.commands ?? const <RegistryCommand>[]) {
  visitCommand(command, [registryRecord.name]);
}
```
