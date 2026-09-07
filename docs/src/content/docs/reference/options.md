---
title: Options
description: This is how options are defined in mamba
---

Options are named inputs that accept values. Mamba provides single-value,
repeatable, paired, and accessor options. The tables below list every
constructible option class and the behavior it provides.

## Shared configuration

The following parameters are shared by multiple option families. Parameters not
shown in a class's simplified signature are listed here.

| Parameter | Applies to | Behavior |
| --- | --- | --- |
| `description` | All option, paired-option, and accessor classes | Optional help text. |
| `short` | Single-value options, repeatable options, and paired option members | Optional one-letter short alias. |
| `required` | Single-value options, repeatable options, and `PairedOptions` | Whether the option or group must be supplied. Defaults to `false`. |
| `hidden` | Single-value options, repeatable options, and `AccessorListOption` | Keeps the input parseable while omitting it from help. Defaults to `false`. An accessor list hides all of its descendants. |

## Single-value options

Register these classes in `Command.options` for command-local options or in
`Executor.options` for global options. A `GroupCommand` can publish them to its
descendants with `propagatedOptions`.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `StringOption` | `StringOption(name, {regex})` | One non-whitespace token by default. Use `regex` to require a complete match against another pattern. |
| `IntOption` | `IntOption(name, {min, max})` | One signed decimal integer. `min` and `max` are inclusive bounds. |
| `DoubleOption` | `DoubleOption(name, {min, max, step})` | One signed decimal number. `min` and `max` are inclusive bounds. `step` requires both bounds and accepts increments from `min` that reach `max`. |
| `ChoiceOption<T extends Enum>` | `ChoiceOption(name, {required choices, defaultValue})` | One name from the supplied enum members. `defaultValue` is used when the option is omitted. |

## Repeatable options

Register these classes in `Command.options` or `Executor.options`. A
`GroupCommand` can publish them to descendants with `propagatedOptions`. Each
occurrence adds one value to the parsed list for that option.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `RepeatableStringOption` | `RepeatableStringOption(name, {regex})` | Repeated non-whitespace tokens by default. Use `regex` to require a complete match against another pattern. |
| `RepeatableIntOption` | `RepeatableIntOption(name, {min, max})` | Repeated signed decimal integers. `min` and `max` are inclusive bounds. |
| `RepeatableDoubleOption` | `RepeatableDoubleOption(name, {min, max, step})` | Repeated signed decimal numbers. `min` and `max` are inclusive bounds. `step` requires both bounds and accepts increments from `min` that reach `max`. |
| `RepeatableChoiceOption<T extends Enum>` | `RepeatableChoiceOption(name, choices)` | Repeated names from the supplied enum members. |

## Paired options

Register a `PairedOptions` group in `Command.pairedOptions`. Its member
classes are supplied in the group's `options` list; they are not registered
individually. By default, the members form an all-or-none group. Set `variant`
to `true` to make members alternatives instead.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `PairedOptions` | `PairedOptions(options, {variant})` | A group of paired members. `required` makes the group mandatory; `variant` allows one member instead of requiring all members together. |
| `PairStringOption` | `PairStringOption(name, {regex})` | One non-whitespace token by default. Use `regex` to require a complete match against another pattern. |
| `PairIntOption` | `PairIntOption(name, {min, max})` | One signed decimal integer. `min` and `max` are inclusive bounds. |
| `PairDoubleOption` | `PairDoubleOption(name, {min, max, step})` | One signed decimal number. `min` and `max` are inclusive bounds. `step` requires both bounds and accepts increments from `min` that reach `max`. |
| `PairChoiceOption<T extends Enum>` | `PairChoiceOption(name, {required choices})` | One name from the supplied enum members. Paired choice members do not have defaults. |
| `RepeatablePairStringOption` | `RepeatablePairStringOption(name, {regex})` | Repeated non-whitespace tokens by default. Use `regex` to require a complete match against another pattern. |
| `RepeatablePairIntOption` | `RepeatablePairIntOption(name, {min, max})` | Repeated signed decimal integers. `min` and `max` are inclusive bounds. |
| `RepeatablePairDoubleOption` | `RepeatablePairDoubleOption(name, {min, max, step})` | Repeated signed decimal numbers. `min` and `max` are inclusive bounds. `step` requires both bounds and accepts increments from `min` that reach `max`. |

## Accessor options

An accessor is a dotted option path. Register top-level `AccessorListOption`
instances in `Command.accessors` for command-local accessors or in
`Executor.accessors` for global accessors. Put nested lists and primitive
accessors in an accessor list's `options` collection.

| Class | Simplified signature | Accepts and behavior |
| --- | --- | --- |
| `AccessorListOption` | `AccessorListOption(name, options)` | A named path segment that groups nested accessor lists or primitive accessor values. |
| `AccessorStringOption` | `AccessorStringOption(name, {regex})` | One non-whitespace token by default. Use `regex` to require a complete match against another pattern. |
| `AccessorIntOption` | `AccessorIntOption(name)` | One signed decimal integer. |
| `AccessorDoubleOption` | `AccessorDoubleOption(name)` | One signed decimal number. |
| `AccessorChoiceOption<T extends Enum>` | `AccessorChoiceOption(name, {required choices, defaultValue})` | One name from the supplied enum members. `defaultValue` is used when the accessor is omitted. |
