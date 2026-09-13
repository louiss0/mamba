---
title: Arguments
description: Reference for Mamba positional and variadic arguments
---

Arguments are unnamed command inputs. Positionals are parsed before `--`;
variadics validate values after `--`.

## Positional presence and order

Positionals are mandatory by default. Use `.optional` or `.withDefault` to
create a discretionary positional:

```dart
final source = NormalPositional('source');
final destination = NormalPositional.optional('destination');

Command(
  mandatoryPositionals: [source],
  discretionaryPositionals: [destination],
);
```

The registration lists enforce these categories at compile time:

- `mandatoryPositionals` accepts `MandatoryPositional` declarations;
- `discretionaryPositionals` accepts `DiscretionaryPositional` declarations.

Position remains determined by list order. The declaration category ensures
that an input's output type cannot contradict its registration.

## `NormalPositional`

Parses one complete `String` using `regExp`, which defaults to `\S+`:

```dart
final target = NormalPositional(
  'target',
  regExp: RegExp(r'.+\.txt'),
);
final String targetValue = invocation.valueOf(target);
```

A discretionary normal positional produces `String?`:

```dart
final target = NormalPositional.optional('target');
final String? targetValue = invocation.valueOf(target);
```

## `ChoicePositional<T>`

Accepts an enum member name and returns the corresponding enum member:

```dart
final format = ChoicePositional<Format>(
  'format',
  choices: Format.values,
);
```

Use `ChoicePositional.optional(...)` for a nullable discretionary output, or
`ChoicePositional.withDefault(...)` for a non-null discretionary output:

```dart
final format = ChoicePositional.withDefault(
  'format',
  choices: Format.values,
  defaultValue: Format.text,
);
```

Generic factories infer their type from `choices` and `defaultValue`.

## Repeated positionals

`RepeatedStringPositional` and `RepeatedChoicePositional<T>` greedily parse at
most `times + 1` values in registration order. `times` defaults to `1`.
Mandatory declarations produce non-null lists:

```dart
final files = RepeatedStringPositional('files', times: 2);
final List<String> fileValues = invocation.valueOf(files);
```

Use `.optional` for nullable discretionary lists. Repeated choices also support
`.withDefault`, whose configured list is returned when no token is supplied:

```dart
final formats = RepeatedChoicePositional.withDefault(
  'formats',
  choices: Format.values,
  defaultValue: [Format.text],
);
```

## Variadics

A `Variadic` validates tokens after the first `--`. Validated values remain
strings and are passed to `Command.run` as the immutable `args` list; they are
not stored in `ParsedInputs`.

### `NormalVariadic`

Validates every trailing token against `regExp`, which defaults to `\S+`:

```dart
NormalVariadic(regExp: RegExp(r'.+'))
```

### `ChoiceVariadic<T>`

Accepts at most one trailing enum member name:

```dart
ChoiceVariadic<Format>(choices: Format.values)
```
