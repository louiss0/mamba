---
title: Registry maps
description: The serialised command surface returned by CommandRegistry.toMap().
---

# Registry maps

`CommandRegistry.toMap()` serialises a validated Mamba command tree into a
`Map<String, dynamic>`. The result describes the CLI surface—commands, inputs,
validation metadata, and relationships—rather than the values from a
particular invocation.

Every child in `commands` has the same shape as its parent. Map keys are the
registered names, so an individual flag, option, positional, or accessor does
not repeat its name inside its descriptor.

## Complete command shape

The following is a shape, not a literal Dart value. Properties marked
**optional** are omitted when the corresponding definition was not registered.

```text
CommandMap {
  name: String
  description: String
  aliases?: List<String>
  flags: Map<String, FlagMap>
  options?: Map<String, OptionMap>
  optionGroups?: List<OptionGroupMap>
  positionals?: Map<String, PositionalMap>
  variadic?: VariadicMap
  accessors?: Map<String, AccessorMap>
  persistentFlags?: Map<String, FlagMap>
  persistentOptions?: Map<String, OptionMap>
  commands?: Map<String, CommandMap>
}
```

`name`, `description`, and `flags` are always emitted. The other command
properties are conditional. Several descriptor properties deliberately contain
`null` (for example, an option's `short` and `description`); this is different
from an optional property that is absent.

## `name`

**Type:** `String`

The canonical name of this command. For a child command, it is also the key
used in its parent's `commands` map. An alias is never used as the map key.

```dart
'name': 'commit'
```

The command name is the name used in the CLI path, such as
`git commit`.

## `description`

**Type:** `String`

The exported description combines the command's short and long descriptions:

- with no long description, it is the short description;
- with a long description, it is `shortDescription`, followed by `\n\n`,
  followed by `longDescription`.

There is no separate `shortDescription` or `longDescription` property in the
map.

```dart
'description': 'Record changes.\n\nCreates a new snapshot of the repository.'
```

## `aliases`

**Type:** `List<String>`  
**Presence:** Optional

Alternative command tokens that select this command among its siblings. The
list contains aliases only; it is not a map from alias to canonical name.

```dart
'aliases': ['ci', 'save']
```

The root created by `CommandRegistry.create` has no command aliases. Child
commands include this property when aliases were declared.

## `flags`

**Type:** `Map<String, FlagMap>`  
**Presence:** Always

A map keyed by each flag's long name. The built-in `help` flag is always the
first logical entry, even when the command declares no flags.

```dart
'flags': {
  'help': {
    'short': 'h',
    'default': false,
    'negatable': false,
    'hidden': false,
    'description': 'Show this help message.',
  },
  'dry-run': {
    'short': null,
    'default': false,
    'negatable': true,
    'hidden': false,
    'description': 'Show what would happen without changing anything.',
  },
}
```

The map has two descriptor shapes. The presence of `default` and `negatable`
distinguishes a boolean flag from a count flag.

### Boolean flag descriptor

```text
BooleanFlagMap {
  short: String?
  default: bool
  negatable: bool
  hidden: bool
  description: String?
}
```

#### `short` (boolean flag)

The optional one-letter short spelling, without the leading `-`. The key is
still emitted with a `null` value when no short alias exists.

#### `default` (boolean flag)

The boolean value used when the flag is not supplied. It is always emitted.

#### `negatable` (boolean flag)

Whether the CLI also accepts `--no-<name>`. It is always emitted.

#### `hidden` (boolean flag)

Whether the flag remains parseable but is hidden from generated help. It is
always emitted.

#### `description` (boolean flag)

The optional human-readable flag description. The key is emitted even when
its value is `null`.

### Count flag descriptor

```text
CountFlagMap {
  short?: String
  hidden: bool
  description: String?
}
```

A count flag has no `default` or `negatable` property. Every occurrence
increments its parsed count. `short` is emitted only when a short alias was
registered; `hidden` and `description` are always emitted.

## `options`

**Type:** `Map<String, OptionMap>`  
**Presence:** Optional

A map keyed by option or pair-member name. Ordinary options and members of a
`PairedOptions` group share this map. Pair members are still listed here even
though their relationship is described separately by `optionGroups`.

```text
OptionMap {
  short: String?
  required: bool
  hidden: bool
  description: String?
  repeatable?: true
  choices?: List<String>
  default?: String
  valueType: 'string' | 'int' | 'double' | 'choice'
  pattern?: String
  min?: int | double
  max?: int | double
}
```

The base fields (`short`, `required`, `hidden`, `description`, and
`valueType`) are always emitted for every option. The remaining fields are
emitted only when the option's type supports them.

### `short` (option)

The optional one-letter alias without `-`. Unlike a count flag, this key is
always present and is `null` when no alias exists.

### `required` (option)

Whether an ordinary option must be supplied. For a pair member this is always
`false`; the group's `required` and `mode` describe the pair requirement.

### `hidden` (option)

Whether an ordinary option is omitted from help while remaining parseable.
Pair members are exported with `false` because pair options do not have their
own hidden setting.

### `description` (option)

The optional description of the option or pair member. The key is always
present and can have a `null` value.

### `repeatable` (option)

**Presence:** Only for repeatable options  
**Value:** `true`

When present, every supplied value is accumulated rather than replacing the
previous value. The key is omitted for single-value options; `false` is not
written.

### `choices` (option)

**Type:** `List<String>`  
**Presence:** Choice options only

The names of the enum members accepted by a `ChoiceOption` or
`PairChoiceOption`. Enum values are serialised using their `.name`.

### `default` (option)

**Type:** `String`  
**Presence:** Optional choice options with a default

The `.name` of the enum member used when an optional `ChoiceOption` is omitted.
Pair options never have defaults. The key is omitted when no default exists.

### `valueType` (option)

**Type:** `String`  
**Values:** `string`, `int`, `double`, or `choice`

The value type required by integration consumers. Repeatable and pair variants
use the same value type as their non-repeatable or ordinary counterpart.

### `pattern` (option)

**Type:** `String`  
**Presence:** Regex-validated string options only

The `RegExp.pattern` used by a string option or string pair member. The map
contains the pattern text, not a Dart `RegExp` object or its flags.

### `min` and `max` (option)

**Type:** `int` for integer options or `double` for double options  
**Presence:** Only when the corresponding numeric bound was declared

Inclusive numeric limits. Either bound may be emitted independently; neither
is emitted when it is `null`.

### Option metadata that is not emitted here

The current `toMap` implementation does not write `variant` or
`pairedOptions` inside an option descriptor. Pair membership and whether a
pair is an alternative are represented by `optionGroups` instead. The
`variant` branch in the private option mapper is currently always `false`.

## `optionGroups`

**Type:** `List<OptionGroupMap>`  
**Presence:** Optional; emitted when a paired-options list was provided

Each group describes the relationship between option entries already present
in `options`.

```text
OptionGroupMap {
  mode: 'all' | 'oneOf'
  required: bool
  members: List<String>
}
```

Example:

```dart
'optionGroups': [
  {
    'mode': 'all',
    'required': true,
    'members': ['username', 'password'],
  },
  {
    'mode': 'oneOf',
    'required': false,
    'members': ['json', 'yaml'],
  },
]
```

### `mode` (option group)

`all` means that if the group is used, every member is required. `oneOf`
means that the members are alternatives and at most one can be selected.
`PairedOptions.variant` is converted to `oneOf`; a non-variant group becomes
`all`.

### `required` (option group)

Whether the group must be used. For an `all` group this requires every member;
for a `oneOf` group it requires one member.

### `members` (option group)

An ordered list of option names. Each name must refer to an entry in the same
command's `options` map.

The `PairedOptions.description` field is not emitted as a separate group
property. Descriptions remain on the individual option entries.

## `positionals`

**Type:** `Map<String, PositionalMap>`  
**Presence:** Optional; emitted when mandatory or discretionary positionals
were registered

The map is keyed by positional name. Mandatory and discretionary positionals
are combined into this one map; their requiredness is recorded in each
entry.

```text
PositionalMap {
  required: bool
  description: String?
  pattern: String
  choices?: List<String>
  default?: String
  repeatable?: true
  times?: int
}
```

Example:

```dart
'positionals': {
  'source': {
    'required': true,
    'description': 'The source file.',
    'pattern': '\\S+',
  },
  'format': {
    'required': false,
    'description': 'The output format.',
    'pattern': '\\S+',
    'choices': ['text', 'json'],
    'default': 'text',
  },
}
```

### `required` (positional)

`true` for entries registered in `mandatoryPositionals` and `false` for
entries registered in `discretionaryPositionals`. It describes the positional
slot, not the presence of a default.

### `description` (positional)

The optional positional description. The key is always emitted and may be
`null`.

### `pattern` (positional)

The `RegExp.pattern` used to validate the complete positional token. It is
always emitted, including for choice and repeated choice positionals.

### `choices` (positional)

**Type:** `List<String>`  
**Presence:** Choice positionals only

The enum-member names accepted by `ChoicePositional` or
`RepeatedChoicePositional`.

### `default` (positional)

**Type:** `String`  
**Presence:** Optional choice positionals with a default

The selected enum member's `.name`. Required positionals cannot declare a
default, so this is only meaningful on discretionary choice positionals.

### `repeatable` (positional)

**Presence:** Only for `RepeatedPositional` definitions  
**Value:** `true`

Marks a positional as collecting multiple values. The key is omitted for a
single positional.

### `times` (positional)

**Type:** `int`  
**Presence:** Repeated positionals only

The configured repetition count. It is emitted together with `repeatable` and
is the maximum number of additional repetitions represented by the definition.

## `variadic`

**Type:** `VariadicMap`  
**Presence:** Optional; emitted when a variadic was registered

A variadic describes values after the `--` separator. A command has at most one
variadic descriptor, so its name is not repeated inside this map.

### Normal variadic shape

```text
{
  description: String?
  pattern: String
}
```

`pattern` is the `RegExp.pattern` from `NormalVariadic`.

### Choice variadic shape

```text
{
  description: String?
  choices: List<String>
  default?: String
  repeatable?: true
}
```

`choices` contains enum-member names. `default`, when present, contains the
selected member's `.name`. `repeatable: true` is emitted only for
`RepeatedChoiceVariadic`; it means every value after `--` is validated as a
choice. A normal `ChoiceVariadic` accepts one value and has no `repeatable`
property.

## `accessors`

**Type:** `Map<String, AccessorMap>`  
**Presence:** Optional; emitted when top-level accessor lists were registered

Accessors are recursive. The top-level map and every group `options` map are
keyed by one dotted-path segment. A leaf is represented by a `value` node and
a nested object by a `group` node.

### Accessor group shape

```text
AccessorGroupMap {
  kind: 'group'
  hidden: bool
  description: String?
  options: Map<String, AccessorMap>
}
```

#### `kind` (accessor group)

Always `group` for an `AccessorListOption`.

#### `hidden` (accessor group)

Whether the group and its subtree are hidden from help. The value is always
emitted on group nodes. It does not appear on value leaves.

#### `description` (accessor group)

The optional description of the object node. The key is always emitted.

#### `options` (accessor group)

The recursively encoded child accessors. A child can be another group or a
primitive value leaf.

### Accessor value shape

All primitive leaves include `kind`, `valueType`, and `description`.

```text
AccessorValueMap {
  kind: 'value'
  valueType: 'string' | 'int' | 'double' | 'choice'
  description: String?
  pattern?: String
  choices?: List<String>
  default?: String
}
```

#### `kind` (accessor value)

Always `value` for an accessor leaf.

#### `valueType` (accessor value)

The primitive type: `string`, `int`, `double`, or `choice`.

#### `description` (accessor value)

The optional description of the leaf. The key is always emitted.

#### `pattern` (accessor value)

The regex pattern for string, integer, and double leaves. It is omitted for
choice leaves. Integer and double accessors use their built-in numeric
patterns.

#### `choices` (accessor value)

The enum-member names accepted by an `AccessorChoiceOption`. It is emitted only
for choice leaves.

#### `default` (accessor value)

The optional enum-member name used by an `AccessorChoiceOption` when no value
was supplied. It is omitted when no default exists.

Example:

```dart
'accessors': {
  'database': {
    'kind': 'group',
    'hidden': false,
    'description': 'Database settings.',
    'options': {
      'host': {
        'kind': 'value',
        'valueType': 'string',
        'description': 'Database host.',
        'pattern': '\\S+',
      },
      'port': {
        'kind': 'value',
        'valueType': 'int',
        'description': 'Database port.',
        'pattern': '[+-]?\\d+',
      },
    },
  },
}
```

## `persistentFlags`

**Type:** `Map<String, FlagMap>`  
**Presence:** Optional; emitted on a non-root registry when that level
publishes flags to descendants

This has the same entry shapes as `flags`, but it records flags published by a
`GroupCommand` for its descendants. The root's global flags stay in `flags`;
they are not copied into `persistentFlags` on every child.

The collection is local to the registry level that published it. A consumer
walking the command tree should collect persistent definitions from the root
toward the selected command, applying nearer definitions according to the
framework's inheritance rules.

## `persistentOptions`

**Type:** `Map<String, OptionMap>`  
**Presence:** Optional; emitted on a non-root registry when that level
publishes options to descendants

This has the same entry shape as `options`, but contains published ordinary
options. Pair groups are local to their command and are not represented in
`persistentOptions`.

Like `persistentFlags`, this is not a fully merged snapshot. It preserves the
level where the published options were declared so an integration can resolve
inheritance while traversing the command tree.

## `commands`

**Type:** `Map<String, CommandMap>`  
**Presence:** Optional; emitted when child commands were registered

Each key is a canonical child command name and each value is another complete
command map. The structure is recursive:

```dart
'commands': {
  'commit': {
    'name': 'commit',
    'description': 'Record changes.',
    'flags': {
      // The child has its own built-in help entry.
    },
  },
}
```

Aliases are not duplicated as keys. If a command was given aliases, they are
stored in that child's `aliases` property. Passing an explicitly empty command
list emits an empty `commands` map; omitting the list omits the property.

## Serialization notes

- `toMap()` returns a fresh, serialisable map and recursively calls `toMap()`
  for child registries.
- Enum values become strings using `.name`.
- Regular expressions become their `.pattern` strings.
- Input names are map keys, not descriptor properties.
- The built-in `help` flag is included in every command's `flags` map.
- `toMap()` is the live-registry export. `RegistryMap(registry.toMap())`
  validates the shape and deep-copies/freezes it for integration consumers.
- This map is metadata for help and completion integrations; parsed values are
  returned separately by `Parser.parse()`.
