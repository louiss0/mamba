---
title: Arguments
description: Reference for Mamba positional and variadic argument classes
---

Arguments are values supplied to a command without an option or flag name.
Mamba supports positional arguments before `--` and variadic arguments after
`--`. They are parsed and returned separately.

## Positional arguments

Positional arguments are consumed in registration order before `--`. Register
required arguments in `Command.mandatoryPositionals` and optional arguments in
`Command.discretionaryPositionals`. Parsed single values are available in
`ParsedPositionals.singles`; repeated values are available in
`ParsedPositionals.repeated`.

All positional classes accept an optional `description` for help text.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `Positional` | `Positional(name, {regex})` | One non-whitespace token by default. Use `regex` to require a complete match against another pattern. |
| `NormalPositional` | `NormalPositional(name, {regExp})` | One non-whitespace token by default. This convenience class uses `regExp` for the validation pattern parameter. |
| `ChoicePositional<T extends Enum>` | `ChoicePositional(name, {required choices, defaultValue})` | One name from the supplied enum members. `defaultValue` is used when the positional is omitted. |
| `RepeatedStringPositional` | `RepeatedStringPositional(name, {regExp, times})` | A sequence of non-whitespace tokens by default. `times` defaults to `1`, so the positional accepts up to two values; it cannot be negative. |
| `RepeatedChoicePositional<T extends Enum>` | `RepeatedChoicePositional(name, {required choices, defaultValue, times})` | A sequence of names from the supplied enum members. `times` defaults to `1`, so the positional accepts up to two values; it cannot be negative. `defaultValue` is used when no value is supplied. |

## Variadic arguments

Variadic arguments are values after `--`. Register one variadic definition in
`Command.variadic`. Mamba validates these values but leaves them in the
`trailingArguments` argument passed to `Command.run`; they are not stored in
`ParsedPositionals`.

All variadic classes accept an optional `description` for help text.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `NormalVariadic` | `NormalVariadic({regExp})` | Any number of non-whitespace trailing tokens by default. Use `regExp` to require a complete match against another pattern. |
| `ChoiceVariadic<T extends Enum>` | `ChoiceVariadic({required choices, defaultValue})` | At most one trailing value whose name is in the supplied enum members. |
| `RepeatedChoiceVariadic<T extends Enum>` | `RepeatedChoiceVariadic({required choices, defaultValue})` | Any number of trailing values whose names are in the supplied enum members. |
