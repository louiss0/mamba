# Handoff TODO

## Tests that are failing

- None currently.
- `dart analyze` passes.
- `dart test` passes all 64 tests.

## What bugs are present

- No confirmed runtime bugs are currently known.
- The remaining risk is untested behavior rather than a demonstrated failure:
  - Invalid command paths and default-command paths.
  - Piped standard input and the default `HookRunner` lifecycle methods.
  - Invalid choices, missing option values, short paired options, accessor
    defaults, and invalid positional values.
  - Registry name collisions and reserved-name validation.
  - `MambaException` error formatting.

## What to do next

1. Add focused tests for the uncovered command, parser, executor, registry, and
   error-handling paths listed above.
2. Prioritize `command.dart` factory helpers and `ProcessedStandardInput`, then
   cover parser validation and choice/default handling.
3. Add executor tests for piped stdin, unknown help command paths, combined
   short flags, and invalid default-command paths.
4. Run `dart format lib test`, `dart analyze`, and `dart test` after each batch.
5. Regenerate coverage with `dart test --coverage=coverage` and track progress
   toward higher line coverage.
