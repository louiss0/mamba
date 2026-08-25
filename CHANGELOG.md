## 0.0.1

- Restored the README from the pre-release revision.
- Repeated choice positionals now render one bounded Carapace `positional` slot
  per accepted value (`times` repetitions plus the original) instead of the
  unbounded `positionalany` field, which Mamba does not support.
- Variadics now validate only values after `--` and no longer absorb extra
  ordinary positionals.
- Numeric options now render signed, prefix-paged Carapace completions with no
  fixed upper bound or completion-time command execution.



## 0.0.0

- Added immutable, list-defined command and option schemas.
- Added typed flags, options, accessors, command groups, hooks, and help output.
- Added parsing and validation for typed, paired, repeatable, and inherited inputs.
- Tokens after `--` are passed through as trailing arguments.
- Added `PairString` and `OrString` formatter values for paired-option help.
- Added `PairedOption.variant` for exactly-one `|` alternative groups.


- Added immutable, Yargs-inspired option and command schemas.
- Added Boolean and string options with aliases, defaults, choices, and validation.
- Added strict root command selection, command aliases, and nested command branches.
- Added dotted accessor options represented as immutable nested maps.
- Added required, optional, and discretionary named positional schemas.
- Added merged argument results and structured, non-throwing input errors.
- Added a JSON-backed `task_list` executable with add, delete, update, and list commands.
- Added Acanthis-backed validation for task titles and descriptions.
