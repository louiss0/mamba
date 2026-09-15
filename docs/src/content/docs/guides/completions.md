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

Its callback receives the validated path. Passing `null` uses the default
synchronous file-creation callback. The preset creates the destination file;
use a converter or override `run` when the command also needs to write an
artifact's contents.

```dart
final completion = CompletionCommand.preset(
  (path) => print('Create completion at $path'),
);
```

When the optional path is omitted, the callback receives an empty string.

## `RegistryRecord` shape

`registryRecord` is a typed Dart record, not an untyped map. Its main fields
are:

| Field | Type | Contents |
| --- | --- | --- |
| `name` | `String` | Application name. |
| `description` | `String` | Root short and optional long description. |
| `commands` | `List<RegistryCommand>?` | Child command records in declaration order. |
| `positionals` | `List<RegistryPositional>?` | Root positional metadata. |
| `variadic` | `RegistryVariadic?` | Root trailing-argument metadata. |
| `flags` / `persistentFlags` | `List<RegistryFlag>?` | Local and inherited flag metadata. |
| `options` / `persistentOptions` | `List<RegistryOption>?` | Local and inherited option metadata. |
| `optionGroups` | `List<RegistryOptionGroup>?` | Paired and selected group membership. |
| `accessors` | `List<RegistryAccessor>?` | Recursive dotted accessor metadata. |

`RegistryCommand` carries the same command-level collections plus `aliases`
and nested `commands`. Option records include type, required, repeatable,
unique, choice, default, pattern, numeric-range, and paired-option metadata.
Accessor records use `kind == 'group'` for branches and `kind == 'value'` for
leaves.

Use the record's named getters and ordinary list traversal to inspect the
root:

```dart
print(registryRecord.name);

for (final command in
    registryRecord.commands ?? const <RegistryCommand>[]) {
  print('${command.name}: ${command.description}');
}
```
