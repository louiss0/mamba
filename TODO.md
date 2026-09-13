# Critique remediation backlog

This backlog captures the accepted findings from the framework critique and the
sealed-context decision.
Tasks are ordered by release priority. Start every behavior change with a failing,
behavior-focused test and run the quality gate after each vertical slice.

## Accepted scope decisions

- [x] Preserve constructor-based input registration.
- [x] Preserve identity-keyed typed input handles.
- [x] Keep context available only to hooks.
- [x] Keep persistent-hook context mutable and ordinary-hook context read-only.
- [x] Restrict context to a sealed set of scalar wrapper values.
- [x] Keep environment-variable extraction outside Mamba.
- [x] Keep configuration-file loading outside Mamba.
- [x] Keep custom file, URL, and application-domain input types out of this
  backlog.
- [x] Do not add `ValueParser<T>` or another user-defined conversion API.
- [x] Do not add source precedence, provenance, environment-key mapping, or
  configuration adapters.

All remaining accepted corrections and capabilities are in scope below.

---

# Milestone 1: release correctness

Complete this milestone before publishing 0.5.0.

## R1. Prevent option values from selecting commands

### Tests

- [ ] Prove `--target deploy` treats `deploy` as a value rather than a child
  command.
- [ ] Prove `--target=deploy` treats `deploy` as a value.
- [ ] Prove `-t deploy` treats `deploy` as a value.
- [ ] Prove paired-option values cannot select commands.
- [ ] Prove accessor values cannot select commands.
- [ ] Prove inherited option values cannot select nested commands.
- [ ] Prove a child name after a long flag still selects the child.
- [ ] Prove a child name after a valid short-flag bundle still selects the child.
- [ ] Prove no token after `--` can select a command.
- [ ] Prove command aliases still produce canonical path segments.
- [ ] Prove parse-error command paths exclude command-like option values.

### Implementation

- [ ] Introduce one command-path traversal shared by parser and executor.
- [ ] Advance over long options with separate values.
- [ ] Advance over long options with inline values.
- [ ] Advance over short options and their values.
- [ ] Distinguish short value options from short-flag bundles.
- [ ] Recognize accessor spellings during traversal.
- [ ] Include inherited inputs when determining token ownership.
- [ ] Stop command resolution at `--`.
- [ ] Remove obsolete duplicate command-token scans.
- [ ] Verify parser dispatch, help selection, and error paths use one resolution.

## R2. Restore `defaultCommandPath`

### Tests

- [ ] Reject an empty configured path.
- [ ] Reject an unknown root segment.
- [ ] Reject an unknown nested segment.
- [ ] Reject a path ending at a non-executable group.
- [ ] Accept a valid nested path.
- [ ] Decide and test whether configured aliases are accepted.
- [ ] Prove caller mutation cannot change the configured path.
- [ ] Execute a root-level default command for an empty invocation.
- [ ] Execute a nested default command for an empty invocation.
- [ ] Let an explicit command override the default.
- [ ] Keep root `--help` on the root help path.
- [ ] Keep `--version` on the version path.
- [ ] Decide and test whether root inputs without a command trigger the default.
- [ ] Prove fake and production execution share the behavior.

### Implementation

- [ ] Defensively copy the configured path.
- [ ] Add registry path validation and canonicalization.
- [ ] Resolve the default while composing the reusable execution environment.
- [ ] Apply it only when the documented trigger is satisfied.
- [ ] Keep explicit help, version, and command paths unchanged.
- [ ] Update README and executor documentation with tested behavior.

## R3. Validate short aliases and command namespaces

### Rules

- [ ] Document the accepted short-alias spelling.
- [ ] Document short-alias case sensitivity.
- [ ] Document inherited long-name and short-name shadowing.

### Tests

- [ ] Reject empty short aliases.
- [ ] Reject multi-character short aliases.
- [ ] Reject aliases containing a leading dash.
- [ ] Reject aliases outside the documented character set.
- [ ] Reject duplicate local flag aliases.
- [ ] Reject duplicate local option aliases.
- [ ] Reject collisions between flags and options.
- [ ] Put ordinary, paired, and selected members in one short namespace.
- [ ] Reject collisions with built-in `-h` and `-v` at the root.
- [ ] Reject ambiguous inherited short aliases.
- [ ] Test the documented inherited override exception.
- [ ] Allow sibling command surfaces to reuse short aliases.
- [ ] Reject duplicate sibling command names.
- [ ] Reject duplicate sibling command aliases.
- [ ] Reject an alias matching a sibling's canonical name.
- [ ] Validate command-alias spelling.

### Implementation

- [ ] Centralize short spelling validation.
- [ ] Collect short aliases from every named-input shape.
- [ ] Validate every effective inherited command surface.
- [ ] Include built-in flags in root validation.
- [ ] Validate sibling command and alias namespaces.
- [ ] Report the spelling and both conflicting declarations.

## R4. Reject unknown optional declaration handles

### Tests

- [ ] Keep `null` for an omitted registered optional option.
- [ ] Reject a fresh unregistered optional option handle.
- [ ] Reject a fresh handle with the same name and type as a registered handle.
- [ ] Reject unknown nullable positional handles.
- [ ] Reject unknown nullable accessor leaves.
- [ ] Reject unknown optional paired or selected aggregate handles.
- [ ] Preserve non-null results for registered required and defaulted handles.
- [ ] Preserve the same behavior through `CommandInvocation.valueOf`.

### Implementation

- [ ] Give `ParsedInputs` an immutable set of known declaration identities.
- [ ] Populate it from the complete selected command surface.
- [ ] Expose aggregate handles rather than internal pair or selection members.
- [ ] Check identity before output nullability.
- [ ] Preserve the distinction between “known” and “was supplied.”
- [ ] Name the unknown declaration in the invariant error.

## R5. Remove stale public language

- [ ] Replace “typed map inputs” in `pubspec.yaml`.
- [ ] Search public docs for obsolete string-keyed or type-bucket consumption.
- [ ] Correct parsed-result language in the architecture reference.
- [ ] Correct default-command diagrams after R2 is complete.
- [x] Correct the hook documentation: context is not on `CommandInvocation`.
- [ ] Verify examples use current declaration handles and result types.
- [ ] Add public behavior changes to `CHANGELOG.md`.
- [ ] Run `dart pub publish --dry-run` and address metadata warnings.

---

# Milestone 2: sealed context values

## Goal

Restrict `MambaContext` to a closed set of scalar state values. Context values
must extend one sealed framework type; applications cannot store arbitrary
objects or add new context value variants.

The supported variants wrap:

- `String`
- `bool`
- `int`
- `double`

This makes the restriction visible to the Dart analyzer instead of relying only
on runtime inspection of `Object` values.

Context remains:

- keyed by typed `MambaContextKey<T>` instances;
- mutable from persistent hooks;
- read-only from ordinary command hooks;
- unavailable to `Command.run`;
- scoped to an executor and retained when that executor is reused; and
- unrelated to environment-variable or configuration-file loading.

---

## 1. Finalize the public type shape

Use this relationship as the design constraint; exact public names may be
adjusted before implementation:

```dart
sealed class MambaContextValue<T extends Object> {
  const MambaContextValue(this.value);

  final T value;
}

final class MambaContextString extends MambaContextValue<String> {
  const MambaContextString(super.value);
}

final class MambaContextBool extends MambaContextValue<bool> {
  const MambaContextBool(super.value);
}

final class MambaContextInt extends MambaContextValue<int> {
  const MambaContextInt(super.value);
}

final class MambaContextDouble extends MambaContextValue<double> {
  const MambaContextDouble(super.value);
}
```

Keys remain typed by the extracted primitive. `set` accepts the matching sealed
wrapper, while `get` extracts and returns the primitive directly:

```dart
final workspaceKey = MambaContextKey<String>();

context.set(workspaceKey, const MambaContextString('/workspace'));
final String? workspace = context.get(workspaceKey);
```

### API decisions

- [x] Use primitive types as `MambaContextKey<T>` type arguments.
- [x] Make `set` accept a `MambaContextValue<T>` matching the key's primitive.
- [x] Make `get` return `T?` directly rather than returning the wrapper.
- [x] Confirm the exported base name `MambaContextValue<T>`.
- [x] Name variants `MambaContextString`, `MambaContextBool`,
  `MambaContextInt`, and `MambaContextDouble`.
- [x] Make the base class `sealed` so applications cannot add variants.
- [x] Make every variant `final` and immutable.
- [x] Give every variant a `const` constructor.
- [x] Store the wrapped scalar in a final `value` field.
- [x] Decide whether variants use value equality; default to identity unless a
  concrete hook-state use case needs value equality.
- [x] Treat every `double`, including non-finite values, as supported scalar state
  unless a concrete serialization requirement is introduced.

---

## 2. Add analyzer tests first

Add analyzer fixtures before changing `lib/context.dart`.

### Accepted code

- [x] A `MambaContextKey<String>` accepts `MambaContextString`.
- [x] A `MambaContextKey<bool>` accepts `MambaContextBool`.
- [x] A `MambaContextKey<int>` accepts `MambaContextInt`.
- [x] A `MambaContextKey<double>` accepts `MambaContextDouble`.
- [x] `get` returns `String?` for a string key.
- [x] `get` returns `bool?` for a boolean key.
- [x] `get` returns `int?` for an integer key.
- [x] `get` returns `double?` for a double key.

### Rejected code

- [x] An application cannot extend `MambaContextValue` outside the Mamba library.
- [x] A string key cannot accept `MambaContextBool`.
- [x] An integer key cannot accept `MambaContextDouble`.
- [x] A primitive value cannot be passed directly to `set`.
- [x] An enum cannot be passed directly to `set`.
- [x] A record cannot be passed directly to `set`.
- [x] A list cannot be passed directly to `set`.
- [x] A map cannot be passed directly to `set`.
- [x] An application-owned object cannot be passed directly to `set`.
- [x] An application cannot construct a context-value wrapper for an unsupported
  key type.
- [x] `null` cannot be passed to `set`.

---

## 3. Add behavior tests first

Add these tests to `test/context_test.dart` before implementation.

### Supported values

- [x] Store and retrieve an empty string.
- [x] Store and retrieve a non-empty string.
- [x] Store and retrieve `true`.
- [x] Store and retrieve `false`.
- [x] Store and retrieve a negative integer.
- [x] Store and retrieve zero.
- [x] Store and retrieve a positive integer.
- [x] Store and retrieve a finite double.
- [x] Store and retrieve `double.nan`.
- [x] Store and retrieve positive and negative infinity.
- [x] Replace a value through the same key.
- [x] Keep two keys of the same primitive type separate by identity.
- [x] Return the stored primitive directly from `get`.
- [x] Return `null` when a supported key has no stored value.

### Runtime escape hatches

Static types are authoritative, but dynamic calls must not silently place an
unsupported object in the private map.

- [x] Passing an unsupported object through `dynamic` fails.
- [x] Passing a raw key through `dynamic` cannot store an unsupported value.
- [x] A failed dynamic write leaves an existing valid value unchanged.
- [x] The dynamic failure occurs before the backing map is mutated.

### Hook lifecycle

- [x] A persistent pre-hook stores a supported wrapper.
- [x] An ordinary pre-hook reads the primitive directly.
- [x] An ordinary post-hook reads the primitive directly.
- [x] A persistent post-hook replaces a supported wrapper.
- [x] A dynamically attempted unsupported write becomes a phase-tagged hook
  failure.
- [x] Reusing an executor retains a supported wrapped value between executions.

---

## 4. Implement the sealed hierarchy

- [x] Add the sealed generic context-value base in `lib/context.dart`.
- [x] Add the string variant.
- [x] Add the boolean variant.
- [x] Add the integer variant.
- [x] Add the double variant.
- [x] Keep `MambaContextKey<T>` typed by the extracted primitive.
- [x] Restrict the private backing map to context-value wrappers.
- [x] Restrict `MambaContext.set` to a key and `MambaContextValue<T>` with
  matching primitive types.
- [x] Extract the wrapper's primitive only inside `get`.
- [x] Keep state mutation adjacent to the private map declaration.
- [x] Return `T?` directly from `MambaContext.get`.
- [x] Return `T?` directly from `MambaReadContext.get`.
- [x] Ensure dynamic misuse cannot bypass the public parameter checks.
- [x] Keep the backing map private.
- [x] Keep key lookup identity-based.
- [x] Do not add string-keyed lookup.
- [x] Do not add implicit conversion from arbitrary objects.
- [x] Do not add environment or configuration loading.
- [x] Do not expose context through `CommandInvocation` or `Command.run`.

---

## 5. Migrate repository consumers

- [x] Wrap the string passed to `set` in `test/context_test.dart` with
  `MambaContextString`.
- [x] Keep that test's key typed as `MambaContextKey<String>`.
- [x] Replace executor hook writes with the appropriate context wrappers.
- [x] Search `lib`, `test`, `example`, and `fixtures` for every context write.
- [x] Keep context keys typed by their primitive output.
- [x] Remove `.value` access from context reads because `get` unwraps values.
- [x] Use wrappers only at context write boundaries.
- [x] Verify no command starts receiving context during migration.

---

## 6. Update public documentation

- [x] Document the sealed hierarchy in `lib/context.dart`.
- [x] Document each variant and its wrapped Dart type.
- [x] Document that applications cannot define additional variants.
- [x] Document that an unset key returns `null` but `null` cannot be stored.
- [x] Document that context is a scalar hook-state bag, not a dependency
  container.
- [x] Document that environment and configuration loading remain application
  responsibilities.
- [x] Update the hooks reference string example to use `MambaContextString` when
  writing and a direct `String?` when reading.
- [x] Add one boolean and one numeric hook-state example.
- [x] Add a caution showing that collections and domain objects are unsupported.
- [x] Update `README.md` context wording.
- [x] Add the breaking API change and migration snippet to `CHANGELOG.md`.
- [x] Keep the backlog and public context documentation aligned with the closed
  scalar hierarchy.

---

## 7. Quality gate

- [x] Run `dart format .`.
- [x] Run `dart analyze --fatal-infos`.
- [x] Run the context analyzer fixtures.
- [x] Run `dart test test/context_test.dart`.
- [x] Run `dart test test/executor_test.dart`.
- [x] Run the complete `dart test` suite.
- [x] Run `git diff --check`.
- [x] Confirm no parser, registry, help, or completion behavior changed.

---

## Completion criteria

- [x] Every stored context value belongs to the sealed framework hierarchy.
- [x] Only string, boolean, integer, and double variants exist.
- [x] Application code cannot add another variant.
- [x] Unsupported writes fail static analysis.
- [x] `get` returns the primitive directly with the key's static type.
- [x] Dynamic misuse cannot mutate context state.
- [x] Typed identity-key lookup remains intact.
- [x] Mutable and read-only hook access remains intact.
- [x] Executor-scoped persistence remains intact.
- [x] Public documentation explains the restriction and migration.
- [x] All quality-gate commands pass.

---

# 0.5.0 release gate

- [ ] Complete every task in Milestone 1.
- [ ] Complete the sealed-context migration in Milestone 2.
- [ ] Run `dart format .`.
- [ ] Run `dart analyze --fatal-infos`.
- [ ] Run the complete `dart test` suite.
- [ ] Regenerate and review completion fixtures if metadata changed.
- [ ] Verify README, website docs, and tested behavior agree.
- [ ] Verify every public breaking change has a changelog entry.
- [ ] Run `dart pub publish --dry-run`.
- [ ] Follow the repository's `mamba-release` process only after this gate passes.

---

# Milestone 3: built-in input improvements

Custom file, URL, and application-domain input types are out of scope. Keep the
existing built-in value families and improve only their availability and
validation behavior.

## T1. Add scalar defaults

### Singular options

- [ ] Test `StringOption.withDefault` returns non-null `String`.
- [ ] Implement `StringOption.withDefault`.
- [ ] Validate its regex during registry construction.
- [ ] Test `IntOption.withDefault` returns non-null `int`.
- [ ] Implement `IntOption.withDefault`.
- [ ] Validate its range during registry construction.
- [ ] Test `DoubleOption.withDefault` returns non-null `double`.
- [ ] Implement `DoubleOption.withDefault`.
- [ ] Validate its range and step during registry construction.

### Repeatable options

- [ ] Decide whether an empty list is a valid explicit default.
- [ ] Decide whether explicit tokens replace or extend a repeatable default.
- [ ] Test and implement `RepeatableStringOption.withDefault`.
- [ ] Test and implement `RepeatableIntOption.withDefault`.
- [ ] Validate every default integer.
- [ ] Test and implement `RepeatableDoubleOption.withDefault`.
- [ ] Validate every default double.
- [ ] Test and implement `RepeatableChoiceOption.withDefault`.
- [ ] Validate choice membership and uniqueness for defaults.
- [ ] Return immutable non-null lists.
- [ ] Export all defaults in registry metadata.
- [ ] Update help, completion, docs, and examples.
- [ ] Run the quality gate.

## T2. Add required and defaulted accessor leaves

- [ ] Define whether a required nested leaf is required globally or only when its
  parent path is used.
- [ ] Test and implement required string leaves.
- [ ] Test and implement defaulted string leaves.
- [ ] Validate string defaults against regex constraints.
- [ ] Test and implement required integer leaves.
- [ ] Test and implement defaulted integer leaves.
- [ ] Validate integer defaults against ranges.
- [ ] Test and implement required double leaves.
- [ ] Test and implement defaulted double leaves.
- [ ] Validate double defaults against ranges and steps.
- [ ] Test and implement required choice leaves.
- [ ] Preserve defaulted choice-leaf behavior.
- [ ] Test required and defaulted leaves at multiple nesting depths.
- [ ] Export required and default metadata.
- [ ] Add analyzer tests for each availability type.
- [ ] Update help and completion rendering.
- [ ] Run the quality gate.

## T3. Add reusable custom validators

- [ ] Define a validator contract returning structured failures.
- [ ] Decide whether validators receive only the parsed value or additional safe
  context.
- [ ] Test one validator on a built-in scalar.
- [ ] Test several validators in declaration order.
- [ ] Define and test first-failure versus aggregated behavior.
- [ ] Test validators on strings, integers, doubles, and enum choices.
- [ ] Test validators on repeatable values per item.
- [ ] Align regex, range, step, and choice failures with the same model.
- [ ] Add one validation example using an existing built-in input type.
- [ ] Run the quality gate.

## Milestone 3 proof

- [ ] Prove scalar defaults produce non-null static output types.
- [ ] Prove required and defaulted accessor leaves preserve their static types.
- [ ] Prove custom validation failures prevent `Command.run` from executing.
- [ ] Add analyzer fixtures for incorrect availability assignments.
- [ ] Run the complete quality gate.

---

# Milestone 4: relationships and parse diagnostics

## D1. Define structured parse diagnostics

- [ ] Inventory every `MambaParseException` construction site.
- [ ] Define stable parse error kinds independent of rendered prose.
- [ ] Add the offending token.
- [ ] Add the token index.
- [ ] Add the canonical command path.
- [ ] Add the declaration identity or name when relevant.
- [ ] Keep rendering separate from diagnostic data.
- [ ] Preserve `message` compatibility during migration if needed.
- [ ] Update tests to assert fields before text.
- [ ] Run the quality gate.

## D2. Normalize diagnostics across spellings

- [ ] Test one invalid value through `--name value`.
- [ ] Test it through `--name=value`.
- [ ] Test it through `-n value`.
- [ ] Test unknown long options.
- [ ] Test unknown short options.
- [ ] Test malformed short bundles.
- [ ] Test missing values for long and short options.
- [ ] Give equivalent failures the same kind and payload shape.
- [ ] Run the quality gate.

## D3. Add suggestions and scoped usage

- [ ] Define a conservative suggestion-distance threshold.
- [ ] Suggest sibling commands for misspelled command tokens.
- [ ] Suggest applicable long options for misspelled options.
- [ ] Exclude hidden declarations.
- [ ] Exclude declarations unavailable on the selected surface.
- [ ] Attach selected-command usage data to parse failures.
- [ ] Render concise suggestions and command-scoped usage.
- [ ] Test the no-suitable-suggestion case.
- [ ] Run the quality gate.

## D4. Design general input relationships

- [ ] Represent relationship members by declaration identity.
- [ ] Define references to paired and selected aggregate handles.
- [ ] Reject unknown relationship members during registration.
- [ ] Reject relationships spanning incompatible command surfaces.
- [ ] Define structured relationship failures.
- [ ] Decide whether conditional rules receive read-only parsed inputs.
- [ ] Define evaluation order relative to defaults and validators.
- [ ] Record the accepted model before implementation.

## D5. Implement relationships one rule at a time

- [ ] Test and implement “A requires B.”
- [ ] Test and implement “A conflicts with B.”
- [ ] Test and implement “at least one member.”
- [ ] Test and implement “exactly N members.”
- [ ] Test and implement a requirement conditional on another parsed value.
- [ ] Test every rule with omitted optionals.
- [ ] Test every rule with defaults.
- [ ] Test every rule on inherited command surfaces.
- [ ] Export serializable metadata where integrations need it.
- [ ] Render relationships in help from registry metadata.
- [ ] Run the quality gate after each rule.

---

# Milestone 5: developer experience

## X1. Investigate optional typed binding

Keep `invocation.valueOf(handle)` as the transparent baseline.

- [ ] Collect two real handlers with repetitive extraction.
- [ ] Prototype an explicit mapper to a typed record or application class.
- [ ] Preserve declaration identity.
- [ ] Avoid reflection and code generation.
- [ ] Compare handler size, error behavior, and discoverability.
- [ ] Decide whether the improvement justifies a public API.
- [ ] If accepted, test and add the smallest opt-in binding abstraction.
- [ ] If rejected, document direct lookup as intentional.

## X2. Design shell-independent dynamic completion

- [ ] Define a request with command path, current token, token index, and safely
  parsed prior inputs.
- [ ] Define an async provider result independent of shell syntax.
- [ ] Define provider failure and timeout behavior.
- [ ] Model file, directory, and plain-value suggestions.
- [ ] Keep sensitive values unavailable by default.
- [ ] Test providers without launching a shell.
- [ ] Add one path provider example.
- [ ] Add one provider dependent on another option.
- [ ] Document side-effect and performance expectations.

## X3. Complete unique repeated-choice filtering

Runtime parsing remains authoritative when a shell cannot filter reliably.

- [ ] Record current Bash behavior.
- [ ] Record current Zsh behavior.
- [ ] Retain and verify Fish behavior.
- [ ] Record current PowerShell behavior.
- [ ] Record current Carapace behavior.
- [ ] Add a unique repeated-choice fixture to every converter.
- [ ] Test prior long-form values in every converter.
- [ ] Test prior short-form values in every converter.
- [ ] Implement reliable filtering per shell or document the limitation.
- [ ] Regenerate and review checked-in fixtures.
- [ ] Run the quality gate.

## X4. Make help and error rendering composable

- [ ] Separate help data selection from terminal text formatting.
- [ ] Define seams for usage, commands, positionals, inputs, relationships, and
  diagnostics.
- [ ] Preserve `HelpFormatter` compatibility or document migration.
- [ ] Test overriding one section without replacing the whole formatter.
- [ ] Keep hidden declarations filtered before rendering.
- [ ] Add a custom formatter example.
- [ ] Run the quality gate.

## X5. Add an injectable process boundary

- [ ] Inventory direct stdin, stdout, stderr, and process `exitCode` usage.
- [ ] Define the smallest production I/O boundary.
- [ ] Preserve opt-in standard input and broken-pipe handling.
- [ ] Inject the boundary without changing parser APIs.
- [ ] Test stdout with a fake boundary.
- [ ] Test stderr with a fake boundary.
- [ ] Test exit-code assignment with a fake boundary.
- [ ] Test piped input with a fake boundary.
- [ ] Keep `Executor.fake()` structured results unchanged.
- [ ] Document embedding and integration testing.
- [ ] Run the quality gate.

---

# Critique completion criteria

- [ ] All release-blocking correctness issues are fixed.
- [ ] Unknown declaration identities always fail clearly.
- [ ] Context accepts only the closed scalar wrapper hierarchy.
- [x] Custom file, URL, and application-domain input conversion is out of scope.
- [ ] Scalar defaults and accessor availability are represented in output types.
- [ ] Accepted relationships and diagnostics are declarative and structured.
- [ ] Dynamic completion and completion-filtering decisions are documented.
- [ ] Help and process-boundary decisions are implemented or explicitly rejected.
- [x] Environment and configuration sources are explicitly out of scope.
- [ ] Every other deferred capability is implemented or rejected with rationale.
- [ ] The backlog, public docs, examples, and tested behavior agree.
