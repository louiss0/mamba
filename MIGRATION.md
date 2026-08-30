# Migrating to 0.4.0

## Parser result

`Parser.parse()` now returns the `ParsedArguments` record directly. Read its
positional fields for the command path, parsed positionals, named inputs, and
trailing arguments. The `help` field indicates that the command should not run;
the internal help flag is removed from the named input maps.

## Paired option defaults

`PairChoiceOption` no longer accepts `defaultValue`. Paired options must be
provided explicitly; remove pair-member defaults from definitions and serialized
registry maps.

## Help and option values

The built-in help flag is now parsed as the defaulted global boolean `help`.
Executors format help and skip command execution when it is true. `-h` can be
included in ordinary short bundles. A dash-prefixed value that is another
registered input must use inline `--option=value` syntax.

## Completion metadata

Carapace no longer invents numeric ranges. Add explicit `completions` values to
string inputs when completion suggestions are desired.

# Migrating to 0.3.0

## Parser outcomes

`Parser.parse()` now returns a `ParseOutcome`. Handle `ParsedHelp` by formatting
its registry and read invocation data from `ParsedInvocation.value`.

```dart
switch (Parser(registry).parse(args)) {
  case ParsedHelp(:final registry):
    return formatter.format(registry);
  case ParsedInvocation(:final value):
    final (command, positionals, inputs, trailing) = value;
}
```

`-h` and `--help` are exact help tokens. `-hv` is not help and is parsed as an
ordinary short bundle.

## Definition validation

Required choice options and mandatory choice positionals must not have defaults.
Use an optional input with a default, or require explicit user input. Empty enum
choice lists are invalid.

`ChoiceVariadic` accepts one post-`--` value. Replace it with
`RepeatedChoiceVariadic` when several choice values are accepted.

## Registry maps

`RegistryMap` now makes a deep immutable copy and validates the same canonical,
typed accessor representation exported by `CommandRegistry`. Migrate legacy
accessor maps with description-only leaves to `{kind, valueType, description}`
value nodes before constructing `RegistryMap`.

## Errors

Non-`Exception` failures during command execution or hook cleanup now throw
`MambaExecutionError`. Inspect `primaryFailure` and `cleanupFailures` rather
than expecting the raw thrown object.
