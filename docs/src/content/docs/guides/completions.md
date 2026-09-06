---
title: completions
description: "Mamba's support for completions for common shells and using tools"
---

Mamba has support for Bash, ZSH, Fish and Powershell completions!
It's also supports a tool called [Carapace](https://carapace.sh/)
It does this by supplying a completion command!
You can use the preset method or you can extend it by making your own!
Either way the completion command will have it's registry map set by the executor!


## Preset 

When you call `Command.preset` you'll get a completion command that will do these things:

- Make the user select between `bash|zsh|powershell|fish|carapace` as the first argument 
  - When the user selects a shell, the completion command will be generated for that shell
- Allow the user to override the path for which shell that's used using the optional second argument
  - If the user makes a path with the correct extension for the shell the user will get the right file
  - If the path extension is incorrect then the user get's an error 
- Make the aliases for the preset command will be `cmp` and `cpt`. 
- Allow a long description to be passed in when `longDescription` is used. 


## Manual

To create manual completions for which ever tool that you use for completions extend the `CompletionCommand` class.
When this class is extended you can use the `registryMap` to generate compeltions!

## Registry map

`registryMap` is a validated, immutable description of the complete command
tree. The executor assigns it before a `CompletionCommand` runs, so a
completion generator can use it without retaining a live `CommandRegistry`.
The root map describes the executor. Nested command maps add command-owned
positionals, variadics, and inputs published to descendants.

| Field | Root map | Nested command maps | Contents |
| --- | --- | --- | --- |
| `name` | Required | Required | The command name. A child command's name matches its key in the parent `commands` map. |
| `description` | Required | Required | The short description, followed by the long description when one exists. |
| `aliases` | Optional | Optional | A list of alternative command spellings. |
| `flags` | Optional | Optional | A map of command-local flag names to flag maps. Mamba always adds the built-in `help` flag map. |
| `persistentFlags` | Not allowed | Optional | A map of flag names to flag maps inherited by descendant commands. |
| `options` | Optional | Optional | A map of command-local option names to option maps. |
| `persistentOptions` | Not allowed | Optional | A map of option names to option maps inherited by descendant commands. |
| `optionGroups` | Optional | Optional | A list of maps that describe paired-option groups. |
| `positionals` | Not allowed | Optional | A map of positional argument names to positional maps. |
| `variadic` | Not allowed | Optional | A map that describes the trailing positional argument. |
| `accessors` | Optional | Optional | A map of accessor names to accessor maps. |
| `commands` | Optional | Optional | A map of child command names to command maps with this same shape. |

### Flag maps

`flags` and `persistentFlags` use the flag name as the map key. Boolean flags
contain every field in the first table; count flags contain the fields in the
second table.

| Field | Required | Contents |
| --- | --- | --- |
| `short` | Yes | A one-letter short alias, or `null` when the flag has none. |
| `default` | Yes | The boolean default value. |
| `negatable` | Yes | Whether the flag accepts a `--no-<name>` spelling. |
| `hidden` | Yes | Whether to omit the flag from completions and help. |
| `description` | Yes | The flag description, or `null`. |

| Field | Required | Contents |
| --- | --- | --- |
| `short` | No | A one-letter short alias. |
| `hidden` | Yes | Whether to omit the flag from completions and help. |
| `description` | Yes | The flag description, or `null`. |

### Option maps

`options` and `persistentOptions` use the option name as the map key.

| Field | Required | Contents |
| --- | --- | --- |
| `short` | Yes | A one-letter short alias, or `null` when the option has none. |
| `required` | Yes | Whether the option must be supplied. |
| `hidden` | Yes | Whether to omit the option from completions and help. |
| `description` | Yes | The option description, or `null`. |
| `valueType` | Yes | One of `string`, `int`, `double`, or `choice`. |
| `repeatable` | No | Present and `true` when the option accepts repeated values. |
| `variant` | No | Present and `true` for a variant option. |
| `choices` | No | The available choice names; required when `valueType` is `choice`. |
| `default` | No | The selected choice name for an optional choice option. |
| `pattern` | No | The regular-expression pattern for the option value. |
| `min` / `max` | No | The inclusive numeric bounds for an `int` or `double` option. |
| `step` | No | The increment between valid `double` values. |

### Option-group maps

Each `optionGroups` entry has the following fields.

| Field | Required | Contents |
| --- | --- | --- |
| `mode` | Yes | `all` when every member is required together, or `oneOf` when one member may be selected. |
| `required` | Yes | Whether this group must be supplied. |
| `members` | Yes | A non-empty list of option names from `options`. |

### Positional and variadic maps

Only nested command maps contain positional and variadic inputs.
`positionals` uses the positional name as its key.

| Field | Required | Contents |
| --- | --- | --- |
| `required` | Yes | Whether the positional argument is mandatory. |
| `description` | Yes | The positional description, or `null`. |
| `pattern` | Yes | The regular-expression pattern for the argument. |
| `choices` | No | The available choice names. |
| `default` | No | The selected choice name for an optional choice positional. |
| `repeatable` | No | Present and `true` when the positional repeats. |
| `times` | No | The number of times a repeatable positional is accepted. |

The `variadic` map uses these fields.

| Field | Required | Contents |
| --- | --- | --- |
| `description` | Yes | The variadic argument description, or `null`. |
| `choices` | No | The available choice names. |
| `default` | No | The selected default choice name. |
| `repeatable` | No | Present and `true` when repeated values are accepted. |
| `pattern` | No | The regular-expression pattern for a non-choice value. |

### Accessor maps

`accessors` uses the accessor name as the map key. An accessor is either a
group map or a value map.

| Field | Required | Contents |
| --- | --- | --- |
| `kind` | Yes | `group`. |
| `hidden` | Yes | Whether to omit the accessor group from completions and help. |
| `description` | Yes | The group description, or `null`. |
| `options` | Yes | A map of nested accessor names to accessor maps. |

| Field | Required | Contents |
| --- | --- | --- |
| `kind` | Yes | `value`. |
| `valueType` | Yes | One of `string`, `int`, `double`, or `choice`. |
| `description` | Yes | The accessor description, or `null`. |
| `choices` | No | The available choice names; required when `valueType` is `choice`. |
| `default` | No | The selected default choice name. |
| `pattern` | No | The regular-expression pattern for the accessor value. |
