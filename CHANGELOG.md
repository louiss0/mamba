## Unreleased

- Added public `PairDSL` and `OrDSL` formatter values.
- Render paired options as grouped `&` expressions in help output.
- Added `PairedOption.variant` for exactly-one `|` alternative groups.

## 1.0.0

- Added immutable, Yargs-inspired option and command schemas.
- Added Boolean and string options with aliases, defaults, choices, and validation.
- Added strict root command selection, command aliases, and nested command branches.
- Added dotted accessor options represented as immutable nested maps.
- Added required, optional, and variadic named positional schemas.
- Added merged argument results and structured, non-throwing input errors.
- Added a JSON-backed `task_list` executable with add, delete, update, and list commands.
- Added Acanthis-backed validation for task titles and descriptions.
