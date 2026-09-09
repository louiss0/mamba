---
title: Options
description: This is how options are defined in mamba
---

Options are named inputs that take values. Ordinary options are registered in
`Command.options`, `Executor.options`, or `GroupCommand.propagatedOptions`.
Paired options are registered as groups in `Command.pairedOptions`. Accessor
options are registered as trees in `Command.accessors` or `Executor.accessors`.

Long options accept both `--name value` and `--name=value`. Ordinary and paired
options can also have a one-letter short alias. The examples below show help
without its ANSI colors: `< ... >` means required and `[ ... ]` means optional.

## `StringOption`

`StringOption` is a single-value `Option`. Register it in an ordinary options
collection to parse one complete `String` matching `regex`; the default `\S+`
pattern accepts one non-whitespace token. If it occurs more than once, the last
value is stored.

Set `required: true` to reject an omitted option. `description` supplies its
help text, `short` adds a one-letter alias, and `hidden: true` keeps it parseable
but removes it from help.

:::note[The command receives]

For `StringOption('output', short: 'o')`, this invocation:

```console
mamba build --output result.txt
```

is indexed from the string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final output = inputs.stringOptions!['output']!;
  return output;
}
```

:::

:::note[The help formatter shows]

```text
Options

[ -o|--output OUTPUT ] Write output to this file.
```

With `required: true`, the outer brackets become
`< -o|--output OUTPUT >`. The formatter converts hyphens and camel-case word
boundaries in the name to an uppercase underscore placeholder. It does not show
`regex`; `hidden: true` removes the complete entry.

:::

## `IntOption`

`IntOption` is a single-value `Option` registered in an ordinary options
collection. It parses a signed decimal integer into an `int`. `min` and `max`
set inclusive bounds. It also supports `short`, `description`, `required`, and
`hidden`.

:::note[The command receives]

For `IntOption('retries', short: 'r', min: 0, max: 5)`, this invocation:

```console
mamba fetch --retries 3
```

is indexed from the integer map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final retries = inputs.intOptions!['retries']!;
  return '$retries';
}
```

:::

:::note[The help formatter shows]

```text
Options

[ -r|--retries RETRIES ] Number of retries.
```

`required: true` changes the outer delimiters to `< ... >`. The formatter does
not show the numeric bounds, and `hidden: true` omits the entry.

:::

## `DoubleOption`

`DoubleOption` is a single-value `Option` registered in an ordinary options
collection. It parses a signed decimal number into a `double`. `min` and `max`
are inclusive. When `step` is set, both finite bounds are required and accepted
values must be increments of `step` from `min` through `max`.

It also supports `short`, `description`, `required`, and `hidden`.

:::note[The command receives]

For `DoubleOption('ratio', min: 0, max: 1, step: 0.25)`, this invocation:

```console
mamba sample --ratio=0.75
```

is indexed from the double map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final ratio = inputs.doubleOptions!['ratio']!;
  return '$ratio';
}
```

:::

:::note[The help formatter shows]

```text
Options

[ --ratio RATIO ] Sampling ratio.
```

A short alias adds `-r|`, and `required: true` changes `[ ... ]` to `< ... >`.
The formatter does not show `min`, `max`, or `step`; `hidden: true` omits the
entry.

:::

## `ChoiceOption<T extends Enum>`

`ChoiceOption` is a single-value `Option` registered in an ordinary options
collection. It accepts the name of one enum member in `choices` and stores that
name as a `String`, not as the enum instance. When an optional choice is
omitted, `defaultValue.name` is stored if a default was registered. A required
choice cannot declare a default.

:::note[The command receives]

Given choices named `json` and `yaml`, this invocation:

```console
mamba export --format yaml
```

is indexed from the string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final format = inputs.stringOptions!['format']!;
  return format;
}
```

The same index receives `defaultValue.name` when the option is omitted.

:::

:::note[The help formatter shows]

```text
Options

[ -f|--format (json|yaml) ] Output format.
```

The enum member names replace the ordinary value placeholder. `required: true`
uses `< ... >`. The default value is not shown, and `hidden: true` omits the
entry.

:::

## `RepeatableStringOption`

`RepeatableStringOption` is a `RepeatableOption` registered in an ordinary
options collection. Every occurrence parses one complete `String` matching
`regex`, which defaults to `\S+`, and appends it to an ordered list. It supports
`short`, `description`, `required`, and `hidden`.

:::note[The command receives]

For `RepeatableStringOption('tag', short: 't')`, this invocation:

```console
mamba build --tag stable -t public
```

is indexed from the repeated string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final tags = inputs.repeatedStringOptions!['tag']!;
  return tags.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
Options

[ (-t|--tag TAG)+ ] Add a tag.
```

The `+` shows that the complete option-and-value expression can repeat. With
`required: true`, the outer brackets become angle brackets. The formatter does
not show `regex`; `hidden: true` removes the entry.

:::

## `RepeatableIntOption`

`RepeatableIntOption` is a `RepeatableOption` registered in an ordinary options
collection. Every occurrence parses a signed decimal integer, validates the
inclusive `min` and `max` bounds, and appends an `int` to an ordered list. It
also supports `short`, `description`, `required`, and `hidden`.

:::note[The command receives]

For `RepeatableIntOption('port', short: 'p')`, this invocation:

```console
mamba serve --port 80 -p 443
```

is indexed from the repeated integer map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final ports = inputs.repeatedIntOptions!['port']!;
  return ports.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
Options

[ (-p|--port PORT)+ ] Listen on a port.
```

`required: true` changes the outer delimiters to `< ... >`. Numeric bounds are
not displayed, and `hidden: true` omits the entry.

:::

## `RepeatableDoubleOption`

`RepeatableDoubleOption` is a `RepeatableOption` registered in an ordinary
options collection. Every occurrence parses a signed decimal number, validates
its inclusive `min` and `max` bounds and optional `step`, and appends a
`double` to an ordered list. A step requires both finite bounds.

:::note[The command receives]

For `RepeatableDoubleOption('weight', short: 'w')`, this invocation:

```console
mamba score --weight 0.5 -w 1.5
```

is indexed from the repeated double map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final weights = inputs.repeatedDoubleOptions!['weight']!;
  return weights.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
Options

[ (-w|--weight WEIGHT)+ ] Add a weight.
```

`required: true` uses `< ... >`. The formatter does not show bounds or the
step, and `hidden: true` omits the entry.

:::

## `RepeatableChoiceOption<T extends Enum>`

`RepeatableChoiceOption` is a `RepeatableOption` registered in an ordinary
options collection. Every occurrence accepts one enum member name from
`choices` and appends that name as a `String`. Its `choices` argument is the
second positional constructor argument. It supports `short`, `description`,
`required`, and `hidden`, but it has no default value.

:::note[The command receives]

Given choices named `json` and `yaml`, this invocation:

```console
mamba export --format json --format yaml
```

is indexed from the repeated string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final formats = inputs.repeatedStringOptions!['format']!;
  return formats.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
Options

[ (--format (json|yaml))+ ] Add an output format.
```

A short alias changes the inner expression to
`(-f|--format (json|yaml))+`. `required: true` uses `< ... >`; `hidden: true`
omits the entry.

:::

## `PairedOptions`

`PairedOptions` is a registration group, not a parsed value. Register it in
`Command.pairedOptions` and place `PairOption` instances in its `options` list.
By default, supplying one member requires every member. Set `variant: true` to
allow exactly one member instead. Set `required: true` to require the complete
all-of group or one member of a variant group.

:::note[The command receives]

For a group containing `PairStringOption('username')` and
`PairIntOption('port')`, this invocation:

```console
mamba connect --username mamba --port 42
```

stores each member in its own typed map rather than storing a group value:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final username = inputs.stringOptions!['username']!;
  final port = inputs.intOptions!['port']!;
  return '$username:$port';
}
```

:::

:::note[The help formatter shows]

An optional all-of group uses `&`:

```text
[ --username USERNAME & --port PORT ] Connection details.
```

A variant group uses `|`:

```text
[ --json JSON|--text TEXT ] Output destination.
```

`required: true` changes the outer delimiters to `< ... >`. The group
`description` is shown when present; otherwise the formatter joins the member
descriptions with `; `.

:::

## `PairStringOption`

`PairStringOption` is a single-value `PairOption`. Put it inside a
`PairedOptions` group to parse one complete `String` matching `regex`, which
defaults to `\S+`. It supports a one-letter `short` alias and a `description`.
Requiredness and all-of versus variant behavior come from its group.

:::note[The command receives]

For `PairStringOption('username', short: 'u')`, this supplied member:

```console
mamba connect -u mamba --port 42
```

is indexed from the ordinary string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final username = inputs.stringOptions!['username']!;
  return username;
}
```

:::

:::note[The help formatter shows]

Inside an all-of group, the member appears as:

```text
[ -u|--username USERNAME & --port PORT ] Connection details.
```

The group controls the outer delimiters and separator. The formatter does not
show `regex`.

:::

## `PairIntOption`

`PairIntOption` is a single-value `PairOption` placed inside `PairedOptions`.
It parses a signed decimal integer into an `int`; `min` and `max` are inclusive.
It supports `short` and `description`, while the group controls requiredness
and pairing behavior.

:::note[The command receives]

For `PairIntOption('port', short: 'p')`, this supplied member:

```console
mamba connect --username mamba -p 42
```

is indexed from the integer map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final port = inputs.intOptions!['port']!;
  return '$port';
}
```

:::

:::note[The help formatter shows]

```text
[ --username USERNAME & -p|--port PORT ] Connection details.
```

The group can replace `&` with `|` or the optional brackets with required angle
brackets. Numeric bounds are not shown.

:::

## `PairDoubleOption`

`PairDoubleOption` is a single-value `PairOption` placed inside
`PairedOptions`. It parses a signed decimal number into a `double`. `min` and
`max` are inclusive, and `step` restricts values to increments from the finite
minimum through maximum. It supports `short` and `description`.

:::note[The command receives]

For `PairDoubleOption('ratio')`, this supplied member:

```console
mamba sample --ratio 0.5 --count 2
```

is indexed from the double map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final ratio = inputs.doubleOptions!['ratio']!;
  return '$ratio';
}
```

:::

:::note[The help formatter shows]

```text
[ --ratio RATIO & --count COUNT ] Sampling controls.
```

The group controls the separator and outer delimiters. Bounds and step are not
shown.

:::

## `PairChoiceOption<T extends Enum>`

`PairChoiceOption` is a single-value `PairOption` placed inside
`PairedOptions`. It accepts one enum member name from `choices` and stores the
name as a `String`. Pair choices do not have defaults, so an omitted optional
group remains unset. It supports `short` and `description`.

:::note[The command receives]

Given choices named `json` and `yaml`, this supplied member:

```console
mamba export --format json --path result.txt
```

is indexed from the string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final format = inputs.stringOptions!['format']!;
  return format;
}
```

:::

:::note[The help formatter shows]

```text
[ --format (json|yaml) & --path PATH ] Export settings.
```

The member's choices replace its placeholder. The group controls the separator
and required or optional delimiters.

:::

## `RepeatablePairStringOption`

`RepeatablePairStringOption` is a repeatable `PairOption` placed inside
`PairedOptions`. Each occurrence parses a complete `String` matching `regex`,
which defaults to `\S+`, and appends it to an ordered list. It supports `short`
and `description`; its group controls pairing and requiredness.

:::note[The command receives]

For `RepeatablePairStringOption('header', short: 'H')`, these members:

```console
mamba fetch -H first -H second --url example.com
```

are indexed from the repeated string map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final headers = inputs.repeatedStringOptions!['header']!;
  return headers.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
[ (-H|--header HEADER)+ & --url URL ] Request settings.
```

The member's `+` appears inside the group DSL. The group controls `&` versus
`|` and the outer delimiters; `regex` is not shown.

:::

## `RepeatablePairIntOption`

`RepeatablePairIntOption` is a repeatable `PairOption` placed inside
`PairedOptions`. Every occurrence parses a signed decimal integer, validates
inclusive `min` and `max` bounds, and appends an `int` to an ordered list. It
supports `short` and `description`.

:::note[The command receives]

For `RepeatablePairIntOption('port', short: 'p')`, these members:

```console
mamba serve -p 80 -p 443 --host localhost
```

are indexed from the repeated integer map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final ports = inputs.repeatedIntOptions!['port']!;
  return ports.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
[ (-p|--port PORT)+ & --host HOST ] Server addresses.
```

The group controls the separator and outer delimiters. Numeric bounds are not
shown.

:::

## `RepeatablePairDoubleOption`

`RepeatablePairDoubleOption` is a repeatable `PairOption` placed inside
`PairedOptions`. Every occurrence parses a signed decimal number, validates its
inclusive bounds and optional step, and appends a `double` to an ordered list.
A step requires finite `min` and `max` values. It supports `short` and
`description`.

:::note[The command receives]

For `RepeatablePairDoubleOption('weight', short: 'w')`, these members:

```console
mamba score -w 0.5 -w 1.5 --label release
```

are indexed from the repeated double map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final weights = inputs.repeatedDoubleOptions!['weight']!;
  return weights.join(', ');
}
```

:::

:::note[The help formatter shows]

```text
[ (-w|--weight WEIGHT)+ & --label LABEL ] Score inputs.
```

The group controls the separator and outer delimiters. Bounds and step are not
shown.

:::

## `AccessorListOption`

`AccessorListOption` is an `AccessorOption` object node. Register top-level
lists in `Command.accessors` or `Executor.accessors`, and place nested lists or
primitive accessor options in `options`. Each list name contributes one segment
to a dotted long-option path; the list itself does not parse a value.

Set `hidden: true` on a list to hide every descendant help entry while keeping
those paths parseable. A list `description` is registry metadata but is not
shown by the default formatter.

:::note[The command receives]

For a `server` list containing `AccessorIntOption('port')`, this invocation:

```console
mamba serve --server.port 8080
```

is indexed through the nested accessor map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final port = inputs.accessors!['server']['port'] as int;
  return '$port';
}
```

:::

:::note[The help formatter shows]

The list is flattened into one entry for each visible primitive descendant:

```text
Accessor flags

[ --server.port SERVER_PORT ] Server port.
```

A nested list adds another dotted segment. The list itself has no separate
entry, and `hidden: true` removes all descendant entries.

:::

## `AccessorStringOption`

`AccessorStringOption` is an `AccessorPrimitiveOption` leaf placed inside an
`AccessorListOption`. It parses one complete `String` matching `regex`, which
defaults to `\S+`, at the leaf's dotted path. Accessor primitives have no short
alias or required setting.

:::note[The command receives]

For the path `server.host`, this invocation:

```console
mamba serve --server.host localhost
```

is indexed through the nested accessor map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final host = inputs.accessors!['server']['host'] as String;
  return host;
}
```

:::

:::note[The help formatter shows]

```text
Accessor flags

[ --server.host SERVER_HOST ] Server host.
```

The dotted name becomes an uppercase underscore placeholder. The formatter
does not show `regex`; hiding an enclosing list removes the entry.

:::

## `AccessorIntOption`

`AccessorIntOption` is an `AccessorPrimitiveOption` leaf placed inside an
`AccessorListOption`. It parses a signed decimal integer into an `int` at the
leaf's dotted path. It has no bounds, short alias, or required setting.

:::note[The command receives]

For the path `server.port`, this invocation:

```console
mamba serve --server.port=8080
```

is indexed through the nested accessor map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final port = inputs.accessors!['server']['port'] as int;
  return '$port';
}
```

:::

:::note[The help formatter shows]

```text
Accessor flags

[ --server.port SERVER_PORT ] Server port.
```

The formatter always displays accessor leaves as optional. Hiding an enclosing
list removes the entry.

:::

## `AccessorDoubleOption`

`AccessorDoubleOption` is an `AccessorPrimitiveOption` leaf placed inside an
`AccessorListOption`. It parses a signed decimal number into a `double` at the
leaf's dotted path. It has no bounds, step, short alias, or required setting.

:::note[The command receives]

For the path `server.timeout`, this invocation:

```console
mamba serve --server.timeout 2.5
```

is indexed through the nested accessor map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final timeout = inputs.accessors!['server']['timeout'] as double;
  return '$timeout';
}
```

:::

:::note[The help formatter shows]

```text
Accessor flags

[ --server.timeout SERVER_TIMEOUT ] Request timeout.
```

The formatter always displays accessor leaves as optional. Hiding an enclosing
list removes the entry.

:::

## `AccessorChoiceOption<T extends Enum>`

`AccessorChoiceOption` is an `AccessorPrimitiveOption` leaf placed inside an
`AccessorListOption`. It accepts one enum member name from `choices` and stores
that name as a `String` at the leaf's dotted path. When omitted,
`defaultValue.name` is merged into the nested accessor map if a default was
registered.

:::note[The command receives]

Given `server.mode` choices named `auto` and `always`, this invocation:

```console
mamba serve --server.mode always
```

is indexed through the nested accessor map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final mode = inputs.accessors!['server']['mode'] as String;
  return mode;
}
```

The same index receives `defaultValue.name` when the leaf is omitted.

:::

:::note[The help formatter shows]

```text
Accessor flags

[ --server.mode (auto|always) ] Server mode.
```

The enum names replace the ordinary placeholder. The formatter does not show
the default value, and hiding an enclosing list removes the entry.

:::
