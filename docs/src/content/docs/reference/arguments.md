---
title: Arguments
description: Reference for Mamba positional and variadic argument classes
---

Arguments are unnamed command inputs. Positionals are parsed before `--` and
variadics are validated after `--`. Register positionals and a variadic in a
`Command` constructor, then read their parsed values in `Command.run()`.

The examples below show help without its ANSI colors. Required expressions are
shown with `< ... >`; optional expressions are shown with `[ ... ]`.

## `Positional`

`Positional` is the base regex-validated positional class. Register it in
`Command.mandatoryPositionals` when the command must receive the value, or in
`Command.discretionaryPositionals` when the value may be omitted. It parses one
complete token that matches `regex`; the default pattern, `\S+`, accepts any
non-whitespace token.

:::note[The command receives]

For a command registered with `Positional('source')`, this invocation:

```console
mamba copy input.txt
```

makes the value available by its registered name in `positionals.singles`:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final source = positionals.singles!['source']!;
  return source;
}
```

A discretionary positional can be indexed without asserting that it exists:

```dart
final source = positionals.singles?['source'];
```

:::

:::note[The help formatter shows]

The registration collection changes the usage expression:

```text
mamba copy < source >  'Copy a file'
mamba copy [ source ]  'Copy a file'
```

The first form is produced by `mandatoryPositionals`; the second is produced by
`discretionaryPositionals`. The default formatter does not print positional
`description` values.

:::

## `NormalPositional`

`NormalPositional` is a convenience subclass of `Positional`. It is used in the
same `mandatoryPositionals` and `discretionaryPositionals` collections, but
names its custom pattern parameter `regExp`. It parses one complete token and
uses `\S+` when no pattern is supplied.

:::note[The command receives]

For `NormalPositional('target', regExp: RegExp(r'.+\.txt'))`, this invocation:

```console
mamba copy output.txt
```

is read from the single-value positional map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final target = positionals.singles!['target']!;
  return target;
}
```

:::

:::note[The help formatter shows]

The formatter displays the registered name, not the regular expression:

```text
mamba copy < target >  'Copy a file'
```

Registering it in `discretionaryPositionals` changes the expression to
`[ target ]`.

:::

## `ChoicePositional<T extends Enum>`

`ChoicePositional` is a `Positional` that restricts the token to the name of one
member in `choices`. Register it as a mandatory or discretionary positional.
The parser returns the selected enum member's name as a `String`, not the enum
instance. A discretionary choice may supply `defaultValue`; mandatory choices
cannot have defaults.

:::note[The command receives]

Given `ChoicePositional<Format>('format', choices: Format.values)`, this
invocation:

```console
mamba export json
```

provides the choice name through `positionals.singles`:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final format = positionals.singles!['format']!;
  return format;
}
```

When a discretionary choice is omitted, indexing `format` returns its
`defaultValue.name` if a default was registered; otherwise it returns `null`.

:::

:::note[The help formatter shows]

The formatter replaces the positional name with the available enum names:

```text
mamba export < json|yaml >  'Export data'
mamba export [ json|yaml ]  'Export data'
```

The collection still controls whether the expression is required or optional.
The default value is not shown.

:::

## `RepeatedStringPositional`

`RepeatedStringPositional` is a `RepeatedPositional` for regex-validated string
tokens. Register it in `mandatoryPositionals` or `discretionaryPositionals`.
It greedily parses at most `times + 1` values in registration order while
reserving values needed by later mandatory positionals. `times` defaults to
`1`, so the default range is one to two values when mandatory and zero to two
when discretionary.

:::note[The command receives]

For `RepeatedStringPositional('files', times: 2)`, this invocation:

```console
mamba add one.txt two.txt three.txt
```

stores all three values under one key in `positionals.repeated`:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final files = positionals.repeated!['files']!;
  return files.join(', ');
}
```

An omitted discretionary repeated positional has no map entry and can be read
with `positionals.repeated?['files']`.

:::

:::note[The help formatter shows]

The formatter displays the inclusive value count as `{1,times + 1}`:

```text
mamba add < files{1,3} >  'Add files'
mamba add [ files{1,3} ]  'Add files'
```

The second form is optional because it was registered in
`discretionaryPositionals`, even though the inner expression describes the
number accepted once values are supplied. The custom regular expression is not
shown.

:::

## `RepeatedChoicePositional<T extends Enum>`

`RepeatedChoicePositional` is a `RepeatedPositional` that accepts only enum
member names. It parses at most `times + 1` values and returns their names as a
`List<String>`. A discretionary registration may use `defaultValue`, which is
inserted as the only list item when no value is supplied; a mandatory
registration cannot declare a default.

:::note[The command receives]

Given a `times: 2` positional whose choices are `Format.json` and
`Format.yaml`, this invocation:

```console
mamba export json yaml
```

is indexed from the repeated-value map:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final formats = positionals.repeated!['formats']!;
  return formats.join(', ');
}
```

:::

:::note[The help formatter shows]

The formatter shows both the choice DSL and the inclusive count:

```text
mamba export < (json|yaml){1,3} >  'Export data'
mamba export [ (json|yaml){1,3} ]  'Export data'
```

Mandatory versus discretionary registration controls the outer delimiters.
The default value is not shown.

:::

## `NormalVariadic`

`NormalVariadic` is a regex-validated `Variadic`. Register one instance in
`Command.variadic`. It validates every token after `--` against `regExp`, which
defaults to `\S+`. Variadic values are not added to `ParsedPositionals`; the
executor passes them unchanged to `run()` as `trailingArguments`.

:::note[The command receives]

For a command with `variadic: NormalVariadic()`, this invocation:

```console
mamba forward -- first second
```

provides each trailing token by list index:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final firstArgument = trailingArguments[0];
  return firstArgument;
}
```

:::

:::note[The help formatter shows]

The formatter marks the start of the trailing arguments in the usage line. It
also repeats the DSL with `description` in the Arguments section:

```text
mamba forward -- ...  'Forward arguments'

Arguments

-- ... Values forwarded to the child process.
```

The regular expression is not shown.

:::

## `ChoiceVariadic<T extends Enum>`

`ChoiceVariadic` is a `Variadic` that accepts at most one token after `--`, and
that token must name a member of `choices`. Register it in `Command.variadic`.
The selected value remains a `String` in `trailingArguments`. Although the
constructor accepts `defaultValue`, omitting the variadic does not add that
default to `trailingArguments`.

:::note[The command receives]

Given choices named `json` and `yaml`, this invocation:

```console
mamba export -- json
```

provides the selected name at the first trailing index:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final format = trailingArguments[0];
  return format;
}
```

:::

:::note[The help formatter shows]

The formatter places the choices after the `--` separator and shows
`description` in the Arguments section:

```text
mamba export -- (json|yaml)  'Export data'

Arguments

-- (json|yaml) Format forwarded to the exporter.
```

It does not show the registered default value.

:::

## `RepeatedChoiceVariadic<T extends Enum>`

`RepeatedChoiceVariadic` is a `ChoiceVariadic` subtype that removes the
single-value limit. Register it in `Command.variadic` to validate any number of
trailing tokens against the enum member names. The values remain ordered
`String` entries in `trailingArguments`.

:::note[The command receives]

Given choices named `json` and `yaml`, this invocation:

```console
mamba export -- json yaml
```

provides each selected name by list index:

```dart
@override
FutureOr<String?> run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {
  final firstFormat = trailingArguments[0];
  final secondFormat = trailingArguments[1];
  return '$firstFormat, $secondFormat';
}
```

:::

:::note[The help formatter shows]

The ellipsis distinguishes this DSL from the single choice variadic. The same
DSL introduces `description` in the Arguments section:

```text
mamba export -- (json|yaml)...  'Export data'

Arguments

-- (json|yaml)... Formats forwarded to the exporter.
```

The default value is not shown.

:::
