---
title: Flags
description: Make flags in Mamba
---

Flags are named inputs that do not accept values. Mamba provides boolean flags
and count flags. The tables below list every constructible flag class and the
behavior it provides.

## Shared configuration

The following parameters are shared by both flag classes.

| Parameter | Behavior |
| --- | --- |
| `description` | Optional help text. |
| `short` | Optional one-letter short alias. |
| `hidden` | Keeps the flag parseable while omitting it from help. Defaults to `false`. |

## Flags

Register these classes in `Command.flags` for command-local flags or in
`Executor.flags` for global flags. A `GroupCommand` can publish them to its
descendants with `propagatedFlags`.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `BooleanFlag` | `BooleanFlag(name, {defaultValue, negatable})` | A flag that stores a boolean value. `defaultValue` defaults to `false`. When `negatable` is `true`, the flag also accepts the `--no-<name>` spelling. |
| `CountFlag` | `CountFlag(name)` | A flag that stores the number of times it appears. Its value is `0` when it is not supplied. |
