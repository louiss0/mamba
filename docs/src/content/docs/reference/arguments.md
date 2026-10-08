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

final class CopyCommand extends Command {
  new()
    : super(
        mandatoryPositionals: [source],
        discretionaryPositionals: [destination],
      );

  @override
  String get name => 'copy';

  @override
  String get shortDescription => 'Copy a file.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    final sourceValue = valueOf(source);
    final destinationValue = valueOf(destination);
    return 'Copy $sourceValue to ${destinationValue ?? 'the default path'}';
  }
}
```

The registration lists enforce these categories at compile time:

- `mandatoryPositionals` accepts `MandatoryPositional` declarations;
- `discretionaryPositionals` accepts `DiscretionaryPositional` declarations.

Position remains determined by list order. The declaration category ensures
that an input's output type cannot contradict its registration.

## `NormalPositional`

Parses one complete supplied `String`, including empty strings and embedded
whitespace. Supply an explicit `regex` to constrain content:

```dart
final target = NormalPositional(
  'target',
  regex: RegExp(r'.+\.txt'),
);
final String targetValue = valueOf(target);
```

A discretionary normal positional produces `String?`:

```dart
final target = NormalPositional.optional('target');
final String? targetValue = valueOf(target);
```

## `ChoicePositional<T>`

Accepts an offered enum choice spelling and returns the corresponding enum
member. Ordinary enums use their member names; enums implementing
`MambaEnumValue` use their exact `value` strings:

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

`RepeatedStringPositional` and `RepeatedChoicePositional<T>` allocate at most
`times` values in registration order, reserving one token for each following
mandatory positional. `times` defaults to `1` and must be finite and positive;
it is a maximum, not an exact required length. Validators check assigned values
without moving rejected tokens to a later declaration. Mandatory declarations
need at least one token and produce non-null lists:

```dart
final files = RepeatedStringPositional('files', times: 2);
final List<String> fileValues = valueOf(files);
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
not read through `valueOf`.

### `NormalVariadic`

Accepts every supplied trailing string by default. An explicit `regex` validates
each complete string:

```dart
NormalVariadic(regex: RegExp(r'.+'));
```

### `ChoiceVariadic<T>`

Accepts at most one trailing enum choice spelling, retaining its raw string:

```dart
ChoiceVariadic<Format>(choices: Format.values);
```
