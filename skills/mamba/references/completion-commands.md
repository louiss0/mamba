# Completion commands

Use a `CompletionCommand` to turn Mamba's validated command registry into a
completion artifact for Bash, Zsh, Fish, PowerShell, or Carapace. The registry
contains the command tree and its flags, options, positionals, aliases, and
descriptions, so completion generation stays aligned with parsing and help.

## Use the preset command

Register `CompletionCommand.preset(null)` in the executor's command list to
use Mamba's built-in generators:

```dart
Future<void> main(List<String> args) => Executor(
  'my-cli',
  'Manage application resources.',
  '1.0.0',
  [CompletionCommand.preset(null)],
).create().execute(args);
```

The preset creates a `completion` command with `cmp` and `cpt` aliases. It
accepts a required shell positional followed by an optional output path:

```console
my-cli completion bash ./my-cli.bash
my-cli completion powershell ./my-cli.ps1
my-cli completion carapace ./my-cli.yaml
```

When a path is present, its extension must match the selected shell and its
file name must contain the application name:

| Shell | Extension |
| --- | --- |
| `bash` | `.bash` |
| `zsh` | `.zsh` |
| `fish` | `.fish` |
| `powershell` | `.ps1` |
| `carapace` | `.yaml` |

`CompletionCommand.shellInput` and `CompletionCommand.pathInput` expose the
same retained declarations used by the preset. Use them with
`ParsedInputs.valueOf` when extending or testing the command.

## Replace destination handling

Pass a callback instead of `null` when another system should handle the
validated path:

```dart
final completion = CompletionCommand.preset(
  (path) => print('Handle completion output at $path'),
);
```

The callback replaces built-in artifact generation; it does not receive
generated content. It receives an empty string when the optional path is
omitted. Extend `CompletionCommand` when custom handling also needs access to
the registry or different input declarations.

## Build a custom completion command

The executor assigns `registryRecord` before execution. Select the converter
for the requested output and call `convert()`:

```dart
final content = switch (shell) {
  ShellCompletion.bash =>
    ToBashCompletionConverter(registryRecord).convert(),
  ShellCompletion.zsh => ToZshCompletionConverter(registryRecord).convert(),
  ShellCompletion.fish =>
    ToFishCompletionConverter(registryRecord).convert(),
  ShellCompletion.powershell =>
    ToPowerShellCompletionConverter(registryRecord).convert(),
  ShellCompletion.carapace => CarapaceSpecConverter(registryRecord).convert(),
};
```

Use the unnamed `CompletionCommand` constructor to supply custom positionals
or options. Access `registryRecord` during `run`, after the executor has
initialized the command tree.
