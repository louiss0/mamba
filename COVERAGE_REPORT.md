# Coverage gap report

Generated from `coverage/lcov.info` after running the remaining 52 tests.

## Summary

- Reported line coverage: **82.66%** (`653/790`)
- Recorded uncovered lines: **137**
- `executor.dart`, `main.dart`, and `mamba.dart` were not loaded by the test suite and therefore do not appear in the LCOV denominator.
- An absent file is not the same as a file with 100% uncovered lines: LCOV has no execution data for it at all.
- Coverage is line-based. A function listed below may be partially covered while one validation branch, switch case, callback, or getter remains uncovered.

| File | Hit | Coverable | Missed | Coverage |
|---|---:|---:|---:|---:|
| `lib/context.dart` | 0 | 7 | 7 | 0.00% |
| `lib/errors.dart` | 2 | 4 | 2 | 50.00% |
| `lib/command.dart` | 73 | 104 | 31 | 70.19% |
| `lib/parser.dart` | 347 | 424 | 77 | 81.84% |
| `lib/registry.dart` | 112 | 125 | 13 | 89.60% |
| `lib/help_formatter.dart` | 119 | 126 | 7 | 94.44% |
| `lib/executor.dart` | — | — | — | Not loaded |
| `lib/main.dart` | — | — | — | Not loaded |
| `lib/mamba.dart` | — | — | — | Not loaded |

## `lib/context.dart` — 0.00%

This entire file is recorded but uncovered. It implements type-safe shared state for command hooks.

### `MambaContext.set<T>`

Stores a value under a typed `MambaContextKey<T>`. The key object, rather than a string, identifies the value and associates it with the expected Dart type. No test currently writes context state.

**Test gap:** Set values of multiple types under distinct keys, replace an existing value, and verify that keys with the same generic type remain independent.

### `MambaContext.get<T>`

Looks up a value and casts it back to the type represented by the key. It returns `null` when the key has not been set.

**Test gap:** Read existing and missing values, and verify the value returned after replacement.

### `MambaReadContext` constructor

Wraps a mutable `MambaContext` to expose a read-only API to command-specific hooks. The wrapper retains the original context internally.

**Test gap:** Construct the wrapper around a populated context.

### `MambaReadContext.get<T>`

Delegates typed reads to the wrapped `MambaContext` without exposing `set`. This is the mechanism that limits mutation during `preRun` and `postRun` hooks.

**Test gap:** Verify that values written through `MambaContext` are visible through `MambaReadContext`, including changes made after the wrapper is created.

## `lib/errors.dart` — 50.00%

### `MambaRegistryError` constructor

Creates an `Error` used for invalid command definitions, such as reserved names and unsupported symbols. Construction is covered indirectly by registry validation, although LCOV does not show every constructor line as hit.

### `MambaException` constructor

Creates the framework's base recoverable exception with a message. Parser and command exceptions inherit from it and exercise this path.

### `MambaException.toString` — uncovered

Formats an exception as `<runtime type> <message>`. This is particularly relevant to `Executor`, which catches errors and writes them to `stderr`, causing this method to determine user-visible output.

**Test gap:** Construct `MambaException` and a subclass such as `MambaParseException`, then assert their exact string representations.

## `lib/command.dart` — 70.19%

This file contains command contracts and nearly every public input-definition type. Many basic constructors are covered, but several factories, accessors, stream conversions, and command-routing branches are not.

### `Option.stringOption` — partially/uncovered factory path

Creates a `StringOption` with a caller-supplied regular expression, alias, description, and requiredness. The resulting option validates one string value.

**Test gap:** Build a string option through the factory rather than its constructor and parse matching and nonmatching values.

### `Option.intOption` — uncovered factory

Creates an `IntOption` for a single signed integer value.

**Test gap:** Verify all forwarded metadata and parse positive, negative, and invalid integer input.

### `Option.doubleOption` — uncovered factory

Creates a `DoubleOption` for a single integer-like or decimal numeric value.

**Test gap:** Verify metadata and parse integer-form, decimal-form, signed, and invalid values.

### `Option.choiceOption<T>` — uncovered factory

Creates a generic enum-backed `ChoiceOption`. The parser stores the selected enum member name in the string-options map.

**Test gap:** Build through the factory, accept known enum names, and reject unknown names.

### `RepeatableOption.intOption` — uncovered factory

Creates an option that can occur multiple times and accumulates integer values in order.

**Test gap:** Parse repeated occurrences and verify metadata forwarding and ordering.

### `RepeatableOption.doubleOption` — uncovered factory

Creates a repeatable numeric option that accumulates doubles.

**Test gap:** Parse mixed integer-form and decimal-form values and reject malformed numbers.

### `RepeatableOption.stringOption` — uncovered factory

Creates a repeatable regex-constrained string option.

**Test gap:** Verify accumulation, regex enforcement, and requiredness.

### `AccessorIntOption.regex` — uncovered getter

Returns the built-in `\d+` expression used to describe unsigned integer accessor syntax. Parsing itself uses the parser's signed integer logic rather than this getter.

**Test gap:** Assert the getter's matching behavior, or reconsider whether an unused public regex getter should be part of this class.

### `AccessorDoubleOption.regex` — uncovered getter

Returns the built-in `\d+\.\d+` expression for decimal accessor syntax. As with the integer getter, parsing does not currently consume this getter.

**Test gap:** Assert matching behavior and clarify whether integer-form doubles should be represented consistently with parser behavior.

### `AccessorChoiceOption<T>` constructor — uncovered constructor path

Defines a nested enum-backed accessor and optional default value.

**Test gap:** Parse a choice accessor both with an explicit value and with its default.

### `GroupCommand` constructor — partially uncovered validation paths

Copies and validates a default subcommand path. It rejects a path containing the group command's own name because paths must be relative.

**Test gap:** Existing tests cover some invalid paths; add direct coverage for all constructor branches and immutable path copying.

### `GroupCommand.runChildCommand`

Walks the command's child tree using a relative list of names, then invokes the final child's `run` method with already-parsed values.

Uncovered behavior includes:

- Rejecting an empty runtime path.
- Rejecting a runtime path containing the parent command's name.
- Handling an unresolved nested child and creating `MambaException`.
- Traversing deeper command levels where each next search uses the previous command's children.

**Test gap:** Cover successful multi-level routing plus each validation and command-not-found branch.

### `GroupCommand._copyDefaultSubCommandPath`

Returns `null` unchanged, rejects empty paths and empty path segments, and returns an unmodifiable copy for valid paths.

**Test gap:** Verify null, empty list, empty segment, copy isolation after mutation of the source list, and unmodifiable output.

### `GroupCommand.run`

Returns an empty string if there is no default path; otherwise delegates to `runChildCommand`.

**Test gap:** Exercise both branches directly and verify argument forwarding.

### `ProcessedStandardInput.text` — uncovered getter

Converts raw bytes with `String.fromCharCodes`, which performs direct code-unit conversion and is distinct from UTF-8 decoding.

### `ProcessedStandardInput.utf8Text` — uncovered getter

Decodes raw standard-input bytes as UTF-8.

### `ProcessedStandardInput.json` — uncovered getter

UTF-8 decodes the bytes and passes the text to `jsonDecode`, returning a dynamic JSON value.

**Test gap for all input getters:** Use ASCII, multibyte UTF-8, valid JSON, and malformed JSON. The malformed case should document the propagated `FormatException`.

### `HookRunner.preRun` — uncovered default implementation

Prints a default message before the selected command runs. Implementing commands may override it to process standard input and inspect read-only context.

### `HookRunner.postRun` — uncovered default implementation

Prints a default completion message after the selected command succeeds.

### `HookRunner.postPersistentRun` — uncovered default implementation

Prints a message after command execution. `Executor` calls persistent post-hooks in reverse command-path order.

### `HookRunner.prePersistentRun`

This method is abstract and has no implementation line to cover. Implementers receive mutable context and parsed single options before execution.

**Test gap for hooks:** A future executor test should use a command mixed with `HookRunner`, record invocation order, inspect arguments, and capture the default printed messages where defaults are intentionally retained.

## `lib/parser.dart` — 81.84%

The parser has the largest gap: **77 lines**. Most uncovered lines are less common option forms, error branches, default merging, and command-token arrangements.

### `Parser.parse` — partially covered

Coordinates command discovery, token consumption, option/flag/accessor parsing, defaults, validation, positional parsing, and construction of typed result maps.

Uncovered branches include:

- Rejecting an unknown dotted long option as an unregistered accessor.
- Rejecting an inline value supplied to a flag.
- Less common command/flag orderings.
- Output-map decisions for input categories represented only by paired members.

**Test gap:** Add table-driven cases for every long-token form (`--name`, `--name=value`, dotted accessors, unknown dotted names), flags with illegal values, and commands mixed with inherited flags.

### `_hasStringOptions`

Determines whether `ParsedNamedInputs.stringOptions` should be a map or `null`. It checks ordinary string/choice options, paired primary options, and pair members.

**Test gap:** Isolate each source category, especially paired choice and pair choice members.

### `_hasSingleOptionType<T>`

Determines whether integer or double result maps should exist. Besides ordinary single options, it recognizes paired primary and child options of the requested type.

**Test gap:** Cover int and double maps created solely by each paired primary/member type, plus a registry with none.

### `_hasRepeatedOptionType<T>`

Performs the same map-presence decision for repeatable string, integer, and double options, including repeatable paired primary/member types.

**Test gap:** Cover all six paired repeatable branches and the false case.

### `_findCommand`

Scans the start of the argument list, accepts an optional root command name, walks child registries, skips registered flags, and stops at the first non-command token or `--`.

Uncovered paths include explicit root names, nested traversal, flag skipping in some positions, and termination behavior.

**Test gap:** Test root-qualified and unqualified paths, nested paths, flags before/between path segments, `--`, and unknown segments.

### `_commandTokenIndexes`

Finds argument indexes corresponding to the discovered command path so those tokens are not later interpreted as positionals.

**Test gap:** Cover repeated token text and flags interspersed with command segments to ensure only path tokens are marked.

### `_isRegisteredFlagToken`

Recognizes long Boolean/count flags, negated Boolean flags, and bundles containing only registered short flags. It is used during command discovery, not general option parsing.

**Test gap:** Cover long count flags, valid and invalid negations, mixed short bundles, empty/one-dash tokens, and unknown short members.

### `_registryForCommand`

Walks child registries for a parsed command path while ignoring the root registry's own name.

**Test gap:** Resolve root-only and multi-level paths.

### `_findOption`

Searches ordinary, repeatable, paired-primary, and pair-member maps by long name, then repeats those searches by short alias.

**Test gap:** Cover long and short lookup for each category and a missing option.

### `_splitLongOption`

Splits the first `=` from a long option into name and optional inline value.

**Test gap:** Cover no separator, empty inline value, and values containing additional equals signs.

### `_takeOptionValue`

Uses an inline value when present; otherwise consumes the following argument. It rejects missing values and a following token beginning with `-`.

**Test gap:** Cover all branches, including the current inability to provide a separate negative number such as `--count -1` (inline `--count=-1` remains possible).

### `_parseLongFlag`

Handles normal/negated Boolean flags and increments count flags. It rejects negation of non-negatable flags and returns `false` for unknown names.

**Test gap:** Cover repeated count flags, unknown names, all Boolean polarity combinations, and disallowed negation.

### `_parseShortInputs`

First attempts to treat the entire short token as an option alias. Otherwise it parses a character bundle of Boolean/count flags and supports the codebase's short-negation marker behavior.

Uncovered branches include negative Boolean handling, invalid negative count handling, count incrementation callbacks, and unknown characters.

**Test gap:** Cover exact option alias precedence, bundled flags, repeated count characters, supported short negation, dangling negation markers, and unknown characters.

### `_addOptionValue`

Dispatches each concrete input definition to string, integer, double, choice, or repeated storage. Several switch cases remain uncovered, particularly choice variants and less frequently used paired/repeatable types.

**Test gap:** Use a table covering every concrete `NamedInput` accepted by this method:

- Single string/int/double/choice.
- Paired string/int/double/choice.
- Pair-member string/int/double/choice.
- Repeatable ordinary, paired-primary, and pair-member string/int/double types.
- An unsupported `NamedInput` that reaches the `StateError` fallback, if reachable through the public API.

### `_addRepeatedValue<T>`

Creates the first list for an option or appends immutably to an existing list.

**Test gap:** Ensure both first and subsequent occurrence callbacks execute.

### `_parseStringOption`

Requires a regular expression to match the complete value, not merely a substring, and returns the original value.

**Test gap:** Cover a partial regex match that must be rejected, in addition to complete match and no match.

### `_parseChoiceOption`

Converts allowed choices to names, rejects values outside that set, and returns a valid name.

**Test gap:** Cover choice types across ordinary, paired, pair-member, and accessor paths; assert the diagnostic text.

### `_parseInt`

Accepts signed whole numbers and rejects malformed values before calling `int.parse`.

**Test gap:** Include leading plus, leading minus, whitespace, embedded spaces, decimal input, and empty input.

### `_parseDouble`

Accepts signed integers or decimal forms with digits on both sides of the decimal point.

**Test gap:** Include signs, integer-form doubles, decimal values, `.5`, `1.`, exponent notation, whitespace, and invalid text to document supported syntax.

### `_matchesEntirely`

Checks that a regex match starts at zero and ends at the value length.

**Test gap:** Exercise no match, prefix-only match, suffix-only match, and complete match through public parser behavior.

### `_addBooleanDefaults`

Adds defaults only when the user did not explicitly provide a value.

**Test gap:** Explicitly verify that a supplied value wins over both true and false defaults.

### `_addChoiceDefaults`

Adds enum choice defaults for ordinary single choice options without replacing explicit values.

**Test gap:** Cover default insertion, explicit override, and a non-choice option in the same registry.

### `_addAccessorChoiceDefaults`

Computes choice defaults for every root accessor and merges them with explicitly parsed nested values.

**Test gap:** Cover no accessors, primitive choice defaults, nested defaults, and explicit sibling/leaf overrides.

### `_accessorChoiceDefaults`

Returns a choice's default name, returns `null` for a primitive without a default, and recursively computes defaults for accessor lists.

**Test gap:** Exercise every switch arm, including a choice with no default and nested lists with and without defaults.

### `_accessorListChoiceDefaults`

Builds a nested default map and returns `null` if no descendant contributes a default.

**Test gap:** Cover empty results, one default, multiple defaults, and nested defaults.

### `_mergeAccessorDefaults`

Recursively combines default maps with current values while giving explicit current values precedence. If either side is not a map, it returns the current value when present and otherwise the default.

**Test gap:** Cover map/map recursion, scalar/scalar, map/scalar, scalar/map, missing current values, and sibling preservation.

### `_validateRequiredOptions`

Checks required ordinary and repeatable options against the correct typed map. Uncovered switch cases include required int, double, and repeatable string/int/double options.

**Test gap:** For every supported type, test absent required input and present input. Also verify the differing string-option error wording.

### `_validatePairedOptions`

Counts supplied members, requires a group when configured, enforces at most one variant member, and enforces all members for a required-together group.

**Test gap:** Existing paired tests are strong, but add zero-member optional groups, required groups of each type, groups with more than two members, and every repeatable combination.

### `_isPairedOptionPresent`

Maps each paired definition type to the typed storage map that indicates its presence. Some false/fallback and repeatable branches are uncovered.

**Test gap:** Exercise every switch arm directly through paired validation, including types that intentionally return `false` because they are not paired members.

### `_parsePositionals`

Consumes mandatory positionals first, then discretionary positionals, validates regexes, and rejects extra values.

Uncovered behavior includes invalid discretionary values and some mandatory/error paths.

**Test gap:** Cover zero values, every mandatory value present, missing mandatory values at multiple indexes, invalid discretionary regex, partial regex matching behavior, and extra values.

### `_isAccessor` and `_accessorForPath`

Resolve dot-separated paths through `AccessorListOption` nodes and accept only paths ending in primitive accessors.

**Test gap:** Cover root primitives, nested primitives, a path ending at a list, traversal through a primitive, missing segments, and duplicate-looking sibling paths.

### `_parseAccessor`

Takes an accessor value, parses it according to the primitive type, and reconstructs a nested map from the path segments.

**Test gap:** Cover all primitive types and paths at depths one, two, and three or more.

### `_mergeAccessorValues` and `_mergeAccessorValuesAtLevel`

Merge separately parsed accessor paths into one nested map. Nested maps combine recursively; scalar conflicts use the latest value.

**Test gap:** Cover siblings, repeated same path, scalar replacement, nested map combination, and conflicting scalar/map shapes.

### `_parseAccessorValue`

Dispatches accessor string, integer, double, and enum choice values to the corresponding primitive parser. The choice arm is uncovered.

**Test gap:** Exercise all four arms, especially valid/default/invalid enum choices.

## `lib/registry.dart` — 89.60%

The registry converts declarative command definitions into validated name-indexed structures and recursively builds child registries.

### `CommandRegistry.create` — partially covered

Combines inherited and local flags, validates the complete definition, indexes input categories, flattens pair members, and recursively registers child commands.

Uncovered behavior includes filtering an inherited flag when a child defines a local flag with the same name and portions of recursive inheritance.

**Test gap:** Build parent/child/grandchild commands with inherited flags, local overrides, and mixed input categories. Assert both map contents and object identity where override behavior matters.

### `_indexByName<T>`

Returns `null` for a `null` input iterable; otherwise builds a map keyed by each input's name.

**Test gap:** Distinguish `null` from an empty iterable, which currently produces an empty map.

### `_validateDefinition`

Runs command-name, description, named-input, paired-option, accessor, positional, and duplicate validation in a fixed sequence.

**Test gap:** Most behavior is covered through `create`; tests should assert which error wins when a definition has multiple simultaneous faults if ordering is intentional.

### `_validateCommandName` — partially uncovered

Rejects empty names, spaces, numbers, names consisting solely of `_` or `-`, and unsupported symbols.

**Test gap:** The unsupported-symbol branch is uncovered. Add punctuation cases while separately confirming `_` and `-` are allowed inside otherwise valid names.

### `_validateShortDescription`

Rejects empty descriptions and descriptions of 150 or more characters.

**Test gap:** Assert exact boundary behavior at 149 and 150 characters.

### `_validateNamedInputs` — partially uncovered

Reserves `help` and `-h`, and rejects unsupported symbols in option/flag names.

**Test gap:** The invalid-symbol branch is uncovered. Test each relevant input kind and aliases that are legal but unusual.

### `_validatePairedOptions`

Checks duplicate primary names, validates primary and child names, rejects groups with no children, and validates flattened pair members.

**Test gap:** Add duplicate child names within and across groups, reserved names on children, and invalid child symbols.

### `_validateAccessors` and `_validateAccessorLevel`

Recursively reject duplicate accessor names, reserved `help`, invalid names, and invalid nested structures.

**Test gap:** Cover nested duplicate and invalid-name failures at multiple depths.

### `_validatePositionals` and `_validatePositionalName` — partially uncovered

Validate mandatory and discretionary positional names using the common supported-character rule.

**Test gap:** The invalid positional-name branch is uncovered. Test both positional categories.

### `_validateDuplicates` — partially uncovered

Combines ordinary, paired-primary, and pair-member options; rejects duplicate option/flag names; detects accessor collisions with flags/options; rejects duplicate positional names; and rejects positional names matching child commands.

Uncovered behavior includes:

- Accessor/flag collisions.
- Accessor/option collisions.
- Duplicate positional names.
- Positional/command collisions.

**Test gap:** Add one focused test for each collision, including collisions against paired child members.

### `_validateDuplicateNames`

Tracks the first index of each name and reports both indexes when a duplicate is found.

**Test gap:** Test duplicates separated by multiple entries and verify the exact indexes in the message.

## `lib/help_formatter.dart` — 94.44%

This is the best-covered implementation file. Remaining gaps are primarily error formatting and less common help-layout branches.

### `OptionalString._parse` — uncovered rejection branch

Removes ANSI SGR codes before checking delimiters and rejects input containing `[` or `]`. This prevents ambiguous nested optional grammar.

**Test gap:** Pass styled and unstyled strings containing each forbidden delimiter and assert `FormatException` details.

### `MambaHelpFormatter.format` — partially uncovered command rendering

Builds the command synopsis and writes long description, flags, accessors, options, paired groups, and child commands. The child-command mapping lines are uncovered.

**Test gap:** Format a registry with multiple child commands and assert command names, descriptions, ordering, and section spacing.

### `_entry` — partially uncovered repeatable branch

Creates a formatted help entry, including optional short alias, required/optional grammar, repeatable `...` prefix, and styled description. One repeatable/display path remains uncovered.

**Test gap:** Cover all combinations of requiredness, alias presence, description presence, and repeatability.

### Other formatter functions

The following are substantially covered: required/optional positional formatting, flags, ordinary options, paired/variant groups, pair-member formatting, nested accessor flattening, section writing, long descriptions, and ANSI wrapper types. Tests should still favor behavioral output assertions rather than private implementation details.

## `lib/executor.dart` — not present in LCOV

Removing `executor_test.dart` means no remaining test imports and executes this file. Consequently, none of the functions below are measured.

### `_MambaCommandNotFoundException` constructor

Builds a user-facing error identifying the unresolved command, its parent path, and either available children or the fact that no children exist.

### `Executor` constructor

Creates the help formatter and mutable context, validates/copies a default command path, adds built-in `dry-run` and `verbose` flags, creates the root registry, enables inherited flags, and retains command instances for execution.

### `Executor.execute`

Coordinates the complete CLI lifecycle:

1. Detect help requests.
2. Select the registry whose help should be displayed.
3. Inject a default command when appropriate.
4. Parse arguments.
5. Resolve actual command instances.
6. Run persistent pre-hooks from root to leaf.
7. Read piped standard input for the selected hook runner.
8. Run the selected command and print its output.
9. Run selected-command post-hooks.
10. Run persistent post-hooks in reverse order.
11. Catch all errors and print them to `stderr`.

This is the primary integration boundary of the library and currently has no measured tests.

### `_readStandardInput`

Returns `null` for interactive/non-piped stdin. For piped stdin, it flattens byte chunks and wraps them in `ProcessedStandardInput`.

### `_registryForArguments`

Walks command arguments to select the registry used for help output. It supports an optional root name, registered flags, nested commands, and structured command-not-found errors.

### `_isRegisteredFlagToken`

Recognizes long Boolean/count flags, negated Boolean flags, and valid short-flag bundles while resolving commands and help targets.

### `_commandsForPath`

Maps a registry command-name path back to retained `Command` objects. It ignores the root registry name and descends through each command's child list.

### `_argumentsWithDefaultCommand`

Injects the configured default subcommand path. If the root name is explicitly present, insertion occurs immediately after it; otherwise the default path is prepended.

### `_needsDefaultCommand`

Determines whether default-path injection is appropriate after accounting for empty arguments, root names, registered flags, `--`, and explicit root subcommands.

### `_isRootCommand`

Checks whether a name matches one of the root registry's immediate child commands.

### `_copyDefaultSubCommandPath`

Validates that the path is nonempty, contains no empty names, is relative to the executor root, and is stored as an unmodifiable copy.

### `_requestsHelp`

Scans for `--help` or `-h` before a `--` separator. Anything after the separator is treated as trailing command input rather than an executor help request.

**Recommended test scope:** Restore executor tests as integration-style unit tests using fake commands and captured zones/process streams. Cover help, successful execution, parsing failure, unknown commands, defaults, context, hook ordering, piped input where practical, stdout, and stderr.

## `lib/main.dart` — not present in LCOV

### `main`

Creates an `Executor` named `mamba` with the description `This is the Manba CLI` and forwards process arguments to `execute`.

No commands are registered, so this entry point primarily displays root help. The description likely contains a typo: `Manba` instead of `Mamba`.

**Test gap:** An end-to-end or subprocess test could invoke the entry point and assert help output and exit behavior. If this file is merely an example binary, consider moving it outside the reusable library surface rather than forcing it into unit coverage.

## `lib/mamba.dart` — not present in LCOV

This file contains no executable functions. It is the package's barrel library and exports `command.dart`, `context.dart`, `errors.dart`, `executor.dart`, `help_formatter.dart`, `parser.dart`, and `registry.dart`.

**Test gap:** Runtime line coverage is not meaningful for export-only files. A compile-time API smoke test importing `package:arg_parser/mamba.dart` can ensure representative public symbols remain exported.

## Recommended order of work

1. **Restore executor coverage first.** It is the central orchestration layer and is currently absent from the report.
2. **Cover parser switch cases and validation edges.** This accounts for 77 currently missed lines and protects the most complex behavior.
3. **Test command factories, context, stdin wrappers, and hooks.** These are public APIs with little or no coverage.
4. **Add registry collision and invalid-symbol cases.** These are inexpensive, behavior-focused tests.
5. **Finish formatter boundary cases.** Only seven formatter lines remain uncovered.
6. **Do not chase executable coverage for `mamba.dart`.** Use an API import smoke test instead.
