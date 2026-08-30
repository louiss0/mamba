## 0.3.0

- Made `Parser.parse` return a sealed `ParseOutcome`: `ParsedInvocation` or
  parser-owned `ParsedHelp`.
- Made `-h` and `--help` exact parser tokens; help is not valid inside bundles.
- Rejected required choice inputs that declare defaults and empty choice sets.
- Enforced documented long/short option dash forms.
- Applied paired defaults before final group validation, including all-of
  completion and variant-default suppression.
- Made `ChoiceVariadic` single-valued; use `RepeatedChoiceVariadic` for many
  trailing choices.
- Deep-froze and semantically strengthened `RegistryMap`; removed legacy
  description-only accessor maps.
- Added negated boolean flags to Carapace specs.
- Added `MambaExecutionError` to preserve non-recoverable primary and cleanup
  failures together.

See `MIGRATION.md` for breaking-change guidance.

## 0.2.0

- Added standalone `PairedOptions` groups with group-level `description`,
  `required`, and `variant` registered in their own list.
- Removed the legacy primary `PairedOption` types; pair members now resolve
  directly from their group.
- Missing required pair members are now reported by name.

## 0.1.0

- Added Carapace completion-spec conversion and platform-aware spec writing.
- Added validated, self-describing `RegistryMap` inputs for integrations.
- Added variadics, repeated positionals, persistent inputs, and nested command
  support across command registration, parsing, help, and integrations.
- Updated parser and command APIs to use list-defined input schemas.

## 0.0.1

- Restored the README from the pre-release revision.
- Repeated choice positionals now render one bounded Carapace `positional` slot
  per accepted value (`times` repetitions plus the original) instead of the
  unbounded `positionalany` field, which Mamba does not support.
- Variadics now validate only values after `--` and no longer absorb extra
  ordinary positionals.
- Numeric options now complete a bounded default range of 0 to 1000 through
  `$carapace.number.Range`; doubles format money-style with at most two
  decimal places. String options and non-choice positionals and variadics
  complete `$files` by default.



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
