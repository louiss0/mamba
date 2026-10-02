## Unreleased

- Rewrote the unregistered term message to name the rejected word and the
  categories that could have matched it. A word typed at the root is reported
  against commands and aliases; once a group owns the registry the message
  says `subcommand` in place of `command`. Positionals are never offered,
  because their names are known only to the parser.
- Added suggestions for an unknown input, naming the closest command or alias
  and which of the two it was. Suggestions match on the prefix that was typed,
  so `--verb` resolves to `--verbose` and the same input always means the same
  completion.
- Named the rejected input in the unknown flag or option message and offered
  the registered flag, option, accessor, or paired or selected group member
  whose name begins with it, which includes a repeatable option.
- Named the rejected letter for an unknown short flag and listed the shorts it
  could have used, because the clustered short parser splits its input into
  single letters and a suggestion would be noise.

## 0.14.0

- Let a group command render its own help. The executor hands a selected
  `GroupCommand` the application `HelpFormatter` and the registry the command
  line resolved to, and `GroupCommand.run` formats that registry when it has no
  `defaultSubCommandPath` to run, so `my-tool remote` lists `remote add` and
  `remote remove`. A group that names a `defaultSubCommandPath` keeps invoking
  that path instead. An ordinary `Command` is never handed the formatter.
- Replaced `interact` with `terminice` for the `mamba create` prompts, and
  re-exported it from `package:mamba/mamba.dart` beside `chalkdart` and
  `yaml_writer`, so an application imports one package and still reaches the
  toolkit Mamba itself prompts with.
- Made the `mamba create` short description an optional second positional, and
  asked for it when it is left off.
- Removed the `.` `mamba create` package name. `mamba create .` is now
  rejected as an invalid package name; `mamba create my_app` still creates
  `my_app` in the current directory.

## 0.13.1

- Wrote a Dart `.gitignore` into every scaffolded project, taken from the
  Toptal gitignore template for Dart, except for its `pubspec.lock` entry so
  a scaffolded application commits its resolved dependency versions.

## 0.13.0

- Started scaffolded application executables at version `0.0.0`.
- Wrote the `mamba create` short description into the generated
  `pubspec.yaml` `description` field.
- Wrote an `AGENTS.md` of Mamba CLI usage and a `CLAUDE.md` pointer to it into
  every scaffolded project.
- Added a `--install` and a `--git` flag to `mamba create` so either setup step
  can be answered without prompting.
- Asked whether to install dependencies during `mamba create`, and reported the
  command that finishes the install when the answer is no.
- Kept installing Mamba skills for scaffolded projects when their dependencies
  are not installed.
- Accepted `.` as a `mamba create` package name to scaffold the current
  directory, which must hold nothing and be named like a Dart package.
- Replaced the implicit `dynamic` behind the bare `List<Flag>`, `List<Option>`,
  `List<Positional>`, and `List<PairOption>` shapes with `List<...<Object?>>`, so
  an input declaration read through a collection keeps a real type.
- Formatted every generated Dart source, so a scaffolded project is
  `dart format` clean before anyone edits it.
- Wrote an `analysis_options.yaml` and an `lints` development dependency into
  scaffolded projects, so `dart analyze` applies lints instead of passing
  vacuously. The generated configuration turns on strict inference and forbids
  bare generics and implicit `dynamic` casts.

## 0.12.0

- Made the project short description a required second argument to
  `mamba create` and used it in the generated executor.
- Made `MambaBuiltInFlags.dryRun` opt-in instead of registering it on every
  executor.
- Moved reusable framework flag declarations into `built_in_flags.dart`.

## 0.11.0

- Added `mamba binary` for scaffolding process-facing executors.
- Added `mamba test` for creating and appending grouped command test suites.
- Added `mamba command --test` support for commands, groups, and appended
  commands.
- Added the `test` development dependency to newly scaffolded projects.

## 0.10.1

- Made `mamba create` install dependencies, Mamba skills for generic agents and
  Claude, and offer Git repository initialization.
- Added the `mamba-framework` package skill.

## 0.10.0

- Added `Executor.fake(standardInput: ...)` for testing piped command input.
- Made `Executor.create()` always use the current process and removed the
  public `MambaProcess` adapter interface.
- Made `CompletionCommand.preset` accept its required nullable `createFile`
  callback as a named parameter.
- Replaced the `SelectedOptions.single` constructor with the `single` named
  option on both the normal and required constructors.
- Renamed command-level `selectedOptionses` to `selectedOptions`.
- Restored nullable command output without automatic success text or coloring,
  and limited process exit-code assignment to failures.
- Added `mamba command --append` for appending generated commands to an
  existing Dart file.

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
