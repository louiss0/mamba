# Framework inconsistency handoff

## Tests that are failing

- None. `dart test` passed: 476 tests.

## What bugs are present

- Definition-time validation is not yet consistently `MambaRegistryError`; several constructors and registry paths still expose `MambaException` or raw Dart errors.
- Executor cleanup reports only one failure; it does not provide the agreed structured aggregate execution exception, async pre-hooks, or full entered-hook lifecycle semantics.
- Context remains executor-scoped by implementation but its documentation needs to state that contract.
- Public parser/registry messages are not centralized; remaining spelling and wording inconsistencies persist.
- Registry maps still omit regex constraints and built-in help metadata; integration failures lack the agreed Mamba integration error hierarchy.
- Carapace still uses bounded numeric examples without documenting them as illustrative, assumes file completion for strings, and needs paired-member completion alignment.

## What to do next

1. Continue TDD in `test/executor_test.dart`: introduce the structured aggregate execution exception; support async pre-hooks; preserve all cleanup failures while maintaining the Error/Exception boundary.
2. Finish registry definition-error normalization: replace remaining definition-time `MambaException`/`ArgumentError` paths with `MambaRegistryError`, retaining `ArgumentError` diagnostics.
3. Centralize public diagnostics and finish parser behavior coverage, especially full paired-default explicit-supply semantics.
4. Export regex pattern metadata and built-in help in `RegistryMap`; add integration-specific error types and tests.
5. Update Carapace completion behavior: mark numeric suggestions illustrative, remove implicit string file completions, and complete paired-member values.
6. Update README/docs and run `dart format` plus the full `dart test` suite after each completed slice.
