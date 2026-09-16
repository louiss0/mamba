## Unreleased

## 0.9.0

- Restored styled help output with richer command, positional, flag, option,
  and option-group formatting.
- Added `--group` support to `mamba command` for scaffolding group commands.
- Added generated completion presets and capped repeated positional values at
  their declared limits.

## 0.8.2

- Adopted Dart 3.13 concise constructor declarations throughout the package,
  tests, examples, generated projects, and documentation.
- Enabled analyzer enforcement for concise constructor declarations.
- Updated public guides and examples to use `ParsedInputs`, typed registry
  records, current executor arguments, and the supported completion APIs.
- Removed root `selectedOptionses` from `Executor`; selected-option groups now
  belong exclusively to commands.
- Made executor-level accessor trees available to every selected command.

## 0.8.1

- Rejected conflicts involving required inputs during registry creation,
  including required paired members and nested accessor leaves.

## 0.8.0

- Added command-level `conflicts` maps for rejecting incompatible flags,
  options, paired or selected members, and dotted accessor leaves.
- Exposed `MambaBuiltInFlags` so built-in declarations can be read through
  `ParsedInputs.valueOf`.

## 0.7.0

### Breaking migration

- Commands and hooks now receive `ParsedInputs` directly; `CommandInvocation`
  has been removed.
- Accessor options resolve through their top-level declaration as immutable
  maps, rather than through nested declaration keys.
- `PairedOptions<T>` and `SelectedOptions<T>` resolve to immutable
  `Map<String, T>` values. Paired groups require all supplied members together;
  their ordinary form returns an empty map when omitted.
- Removed selectable option groups in favor of map-based `SelectedOptions<T>`.

## 0.6.0

- Command resolution now skips option values, including inherited, paired,
  selected, and accessor inputs; aliases resolve to canonical command paths.
- Added scalar and repeatable built-in option defaults, plus required/defaulted
  accessor leaves. Explicit repeatable values replace a configured default.
- Context writes use sealed scalar wrappers (`MambaContextString`,
  `MambaContextBool`, `MambaContextInt`, and `MambaContextDouble`); reads now
  return the primitive directly. Migrate `context.set(key, value)` to
  `context.set(key, MambaContextString(value))` (or the matching wrapper).

## 0.5.0

### Breaking migration

- Input handles now encode required, optional, and defaulted output
  availability. `valueOf` returns the declared type directly; runtime
  `required` modes, `ParsedInputs.require`, and `CommandInvocation.inputs` were
  removed. Mandatory and discretionary positional lists accept only matching
  declaration categories.
- Paired option groups now map their members into one typed aggregate output.
- Commands, hooks, and groups now consume `CommandInvocation` and typed input
  handles instead of string-keyed parsed records. Values after `--` are passed
  as the separate validated `args` list.
- Choice declarations return their registered enum members. Repeatable choices
  support `unique: true`, which rejects duplicate selections.
- Replaced `PairedOptions(variant: true)` with `SelectedOptions<R>` and
  `SelectableOption`; paired groups remain all-or-nothing.
- Execution results now provide exit codes and phase-tagged errors, including
  cleanup failures that retain command output.

## 0.4.0

- Removed defaults from `PairChoiceOption`; paired groups are completed only by
  explicit member input.
- Made inherited option overrides resolve cardinality before typed map
  construction, preventing shadowed options from being resurrected.
- Made built-in help a defaulted global boolean parsed like other flags; the
  executor skips command execution when it is enabled.
- Validated synthesized negated flag spellings, reserved help aliases, and
  serialized positional/name namespaces consistently.
- Preserved every cleanup failure in callback order and broadened closed-pipe
  stdin detection.
- Replaced guessed numeric completion ranges with explicit completion metadata.

## 0.3.0

- Made `Parser.parse` return a sealed `ParseOutcome`: `ParsedInvocation` or
  parser-owned `ParsedHelp`.
- Made `-h` and `--help` exact parser tokens; help is not valid inside bundles.
- Rejected required choice inputs that declare defaults and empty choice sets.
- Enforced documented long/short option dash forms.
- Added paired default handling (superseded in 0.4.0, where pair members no
  longer accept defaults).
- Made `ChoiceVariadic` single-valued; use `RepeatedChoiceVariadic` for many
  trailing choices.
- Deep-froze and semantically strengthened `RegistryMap`; removed legacy
  description-only accessor maps.
- Added negated boolean flags to Carapace specs.
- Added `MambaExecutionError` to preserve non-recoverable primary and cleanup
  failures together.

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
