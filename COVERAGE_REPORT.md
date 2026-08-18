# Coverage report

Generated from the current test suite with coverage ignore directives enabled.

## Summary

- **Line coverage:** 100.00%
- **Covered lines:** 783
- **Coverable lines:** 783
- **Missed lines:** 0
- **Tests:** 94 passed

| File | Coverage |
|---|---:|
| `lib/command.dart` | 100.00% |
| `lib/context.dart` | 100.00% |
| `lib/errors.dart` | 100.00% |
| `lib/help_formatter.dart` | 100.00% |
| `lib/parser.dart` | 100.00% |
| `lib/registry.dart` | 100.00% |

## Exclusions

### `lib/executor.dart`

`Executor` remains intentionally excluded through its existing
`coverage:ignore-start` and `coverage:ignore-end` directives. It is not unit
tested.

### `HookRunner` default output

The default hook implementations in `lib/command.dart` print lifecycle
messages. Their output is intentional executor-integration behavior, so the
hook declarations and default print implementations are enclosed by coverage
ignore directives rather than tested as unit behavior.

### Impossible parser branches

Defensive parser branches that cannot be reached through a valid
`CommandRegistry` are excluded from coverage:

- A non-option `NamedInput` reaching option-value dispatch.
- A `PairedOption` reaching ordinary required-option validation.
- Ordinary options reaching paired-option presence validation.

The unreachable short-negation state machine was removed instead of excluded.
A token with two leading dashes is handled by long-option parsing, so that
state could not be reached through the parser's public API.

### `lib/main.dart` and `lib/mamba.dart`

`main.dart` is a process entry point and is not loaded by unit tests.
`mamba.dart` is an export-only barrel with no executable behavior. Neither is
part of the recorded unit coverage denominator.

## Newly covered behavior

The current tests now cover:

- Command discovery after a negated inherited Boolean flag.
- Repeated long count flags.
- Paired primary and member short aliases, including negative numeric values.
- Missing and regex-invalid mandatory positionals.
- Required ordinary-option help grammar.
- Recursive validation of nested accessor names.
