# Handoff

## Tests that are failing

- No known failing tests. `dart analyze` and `dart test test/registry_test.dart`
  passed before the handoff.
- Run `dart test` before and after the migration because the completion
  integration suite was not rerun after commit `72d57c6`.

## What bugs are present

- `RegistryRecord`, `RegistryCommand`, and `RegistryAccessor` are currently
  unused model declarations. `CommandRegistry.toMap()` still exports the
  existing `RegistryMap` wrapper and map-based collections.
- Completion converters and `CompletionCommand.registryMap` still consume
  `RegistryMap` rather than typed registry records.

## What to do next

1. Replace `RegistryMap` with the typed `RegistryRecord` boundary. Keep
   recursive commands in `RegistryCommand` and recursive accessor groups in
   `RegistryAccessor`, as agreed with the user.
2. Make `CommandRegistry.toMap()` construct records directly; do not create an
   intermediate map for registry export.
3. Update completion converters, the executor, and completion commands to
   consume records directly.
4. Rewrite registry expectations to compare records instead of extracting maps.
   Update integration expectations after the record boundary is stable.
5. Remove the obsolete map validator/export code only after the migrated test
   suite passes.
