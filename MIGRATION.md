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
