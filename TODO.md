# Handoff

## Tests that are failing

- `dart test` has 108 failures.
- Most failures are `test/integrations_test.dart` Carapace YAML snapshots. The
  converter now exports built-in help at root and command levels, but older
  expected YAML does not include it.
- `test/registry_test.dart` has stale error-boundary expectations. Some
  definition failures now throw `MambaRegistryError`, while tests still expect
  `MambaException`.

## What bugs are present

- Registry definition failures are still inconsistent: some invalid
  `CommandRegistry` paired-option and alias definitions use recoverable
  `MambaException` instead of eager `MambaRegistryError`.
- The test suite is red because snapshots and error-type expectations have not
  been migrated to the already-shipped integration and registry contracts.

## What to do next

1. Work TDD by registry-definition category. Convert remaining invalid command,
   paired-option, alias, and input definitions to `MambaRegistryError`; update
   only matching definition-invariant test expectations. Preserve
   `MambaException` assertions for recoverable behavior.
2. Migrate Carapace expected YAML explicitly: add built-in help as
   `persistentflags` at the root and `flags` for generated subcommands where
   the registry exports help. Retain direct assertions of help metadata rather
   than hiding it in the YAML matcher.
3. Run `dart format` and `dart test`; do not hand off until the full suite is
   green. Commit each passing logical migration slice using the required CTS
   commit format.
