---
title: Flags
description: Make flags in Mamba
---

Flags are named inputs that do not take values. Register them in
`Command.flags` for one command, in `Executor.flags` for the entire command
tree, or in `GroupCommand.propagatedFlags` for a group and its descendants.
The executor also registers `--dry-run`, `--verbose`, and `--version` globally;
`--help` is built into every command registry.

The examples below show help without its ANSI colors. Flag expressions are
optional and therefore appear inside `[ ... ]`.

## `BooleanFlag`

`BooleanFlag` is a concrete `Flag` that parses whether a named switch is on or
off. It accepts `--name`, an optional one-letter `-n` alias, and its short alias
inside a bundle such as `-fn`. `defaultValue` is returned when the flag is
omitted and defaults to `false`. Setting `negatable: true` also registers
`--no-name`, which sets the parsed value to `false`.

Use `description` to explain the flag in help. Set `hidden: true` to keep all of
its spellings parseable while omitting it from the default help formatter.

:::note[The command receives]

For a retained `force` declaration, both of these
invocations produce a boolean value:

```console
mamba deploy --force
mamba deploy --no-force
```

The command indexes that value by the flag's long name:

```dart
@override
FutureOr<String?> run(
  CommandInvocation invocation,
  List<String> args,
) {
  final forceValue = invocation.valueOf(force);
  return 'force: $forceValue';
}
```

`--force` and `-f` produce `true`; `--no-force` produces `false`. When the flag
is omitted, the same index returns `defaultValue`.

:::

:::note[The help formatter shows]

With `short: 'f'` and `description: 'Replace the existing deployment.'`, the
Flags section contains:

```text
Flags

[ -f|--force ] Replace the existing deployment.
```

Without a short alias, the expression becomes `[ --force ]`. Neither
`negatable: true` nor `defaultValue` changes the displayed DSL, so
`--no-force` and the default are not shown. Setting `hidden: true` removes the
entry from help without disabling parsing.

:::

## `CountFlag`

`CountFlag` is a concrete `Flag` that counts how many times its spelling is
supplied. It accepts `--name`, an optional one-letter alias, repeated long or
short spellings, and repeated short aliases in a bundle. An omitted count flag
has the value `0`.

Register it through `Command.flags`, `Executor.flags`, or
`GroupCommand.propagatedFlags`. Its `description`, `short`, and `hidden`
configuration have the same help behavior as a boolean flag.

:::note[The command receives]

For a retained `verbose` declaration, these invocations each produce a count
of `2`:

```console
mamba build -vv
mamba build --verbose --verbose
```

The command indexes the integer by the flag's long name:

```dart
@override
FutureOr<String?> run(
  CommandInvocation invocation,
  List<String> args,
) {
  final verbosity = invocation.valueOf(verbose);
  return 'verbosity: $verbosity';
}
```

The same index returns `0` when the flag is omitted.

:::

:::note[The help formatter shows]

With `description: 'Increase output verbosity.'`, the Flags section contains:

```text
Flags

[ -v|--verbose ] Increase output verbosity.
```

The formatter does not add a repetition marker: `-vv`, repeated `-v`, and
repeated `--verbose` are parser spellings rather than separate help forms.
Without `short`, the expression becomes `[ --verbose ]`; with `hidden: true`,
the entry is omitted.

:::
