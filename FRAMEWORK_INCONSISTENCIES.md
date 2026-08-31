# Mamba Framework Inconsistencies

## Resolution status

All findings in this report have been addressed. This file is retained as the
historical baseline for the fixes below:

- Completion suggestions are exclusively derived from enum choice inputs.
  Regex-backed inputs no longer expose completion metadata in the public API,
  registry map, or Carapace converter.
- Registry maps synthesize the parser-owned canonical help flag and reject a
  caller attempt to redefine it. They validate local/persistent input and
  short-alias collisions with the same override semantics as live registries.
- Explicit help always targets the path the user named; defaults are applied
  only for dispatch. Nested usage lines contain the full command path, and
  unowned tokens after help are consistently ignored while command discovery
  continues.
- Required repeated positionals report an invalid supplied token rather than
  calling it missing.
- `ChoicePositional` and `RepeatedChoicePositional` exist and supply bounded
  Carapace positional completions. Carapace cannot encode the at-least-one
  half of a required variant group, so generated descriptions explicitly keep
  that runtime requirement visible; the parser remains authoritative.

This report is based exclusively on the current implementation in `lib/` and
the behavior specified in `test/`. It replaces the previous assessment after
the parser, registry validation, executor cleanup, and completion contracts
changed again.

Current verification:

- `dart test`: 487 tests passed.
- `dart analyze lib test`: no issues found.

The suite now covers many of the earlier cross-feature boundaries directly.
The active findings below are current gaps, not a restatement of resolved
history.

## Severity guide

- **High**: makes a declared public feature unusable or permits an ambiguous
  command surface.
- **Medium**: creates materially surprising help, parsing, or integration
  behavior.
- **Low**: primarily affects diagnostics, documentation, or maintainability.

## Summary

The most important current inconsistencies are:

- `NormalPositional.completions` is exported by `CommandRegistry.toMap()` but
  rejected as an unsupported property by `RegistryMap`.
- Manual `RegistryMap` values do not detect collisions between local and
  persistent inputs even though live registration does.
- A default command redirects conventional root or group help to the default
  descendant, making the authoritative parent overview difficult to reach.
- Explicit completion suggestions are not checked against their runtime regex.
- Required Carapace variant groups still cannot enforce “at least one,” though
  the generated descriptions now disclose the runtime requirement.

## Registry and serialization inconsistencies

### INC-001: Positional completion metadata breaks executor construction

**Severity: High**

`NormalPositional` now implements `CompletionSuggestions`, and
`CommandRegistry._mapPositional()` exports a non-empty list as the
`completions` property. `RegistryMap._parsePositional()` contains code to parse
and validate that property, but `completions` is missing from its
`optionalProperties` set.

The generic property check therefore rejects the property before the dedicated
completion validation can run:

```text
NormalPositional(..., completions: ['src', 'test'])
  -> CommandRegistry.toMap() includes positionals.<name>.completions
  -> RegistryMap(...) throws MambaIntegrationException
  -> Executor.fake() and Executor.create() fail during setup
```

This is particularly significant because the authoring API explicitly offers
the feature and the Carapace converter already contains positional-completion
logic.

**Recommendation:** add `completions` to the positional optional-property set
and add an executor-level regression test proving that declared positional
suggestions reach `completion.positional` in generated YAML.

### INC-002: RegistryMap misses local/persistent collisions

**Severity: High**

Live child registration merges inherited and local inputs before duplicate and
short-alias validation. It therefore rejects, for example, an inherited
`--color/-c` flag combined with a local `--config/-c` option.

`RegistryMap._validateCommandSemantics()` instead tracks local and persistent
names and short aliases in separate sets. It does not compare the sets after
collection. A manually constructed map can consequently declare:

- A local flag that overrides an inherited global flag, which live
  registration forbids
- A local option whose name collides with an inherited flag
- Different local and persistent inputs sharing one short alias

The Carapace converter may then remove the persistent same-name input as an
“override” or emit ambiguous short spellings, even though no equivalent live
registry can exist.

**Recommendation:** validate local names and shorts against persistent names
and shorts. Permit only the same-name inherited-option override supported by
the live model, while rejecting cross-kind and global-flag overrides.

### INC-003: Manual help metadata need not match the built-in flag

**Severity: Medium**

The live registry always exports one built-in `help` flag with short alias `h`,
default `false`, `negatable: false`, visible state, and the framework's help
description.

The map validator recognizes a help entry merely when it is under `flags`, is
named `help`, has short alias `h`, and contains `default` and `negatable`
properties. It does not require the canonical values, and it does not require
the help entry to exist at all.

A manual map can therefore describe default-on or negatable help and make
Carapace emit `--no-help`, despite those states being impossible through
`CommandRegistry` and meaningless to the parser contract.

**Recommendation:** either require the exact built-in help entry at every
command level or remove help from the caller-supplied schema and synthesize it
inside `RegistryMap`/the converter.

## Command and help inconsistencies

### INC-004: Default commands redirect conventional parent help

**Severity: High**

The executor inserts root and group default paths before parsing the global
help flag. Consequently, both of these conventional requests select the
default descendant:

```text
tool --help
tool group --help
```

when the addressed root or group has a default path. The tests now explicitly
define the group behavior, so this is a deliberate contract rather than an
accidental regression. It is still inconsistent with help as an overview of
the command the user named, and it makes root help non-obvious precisely when a
root default command exists.

The current accidental escape hatch is to prevent default insertion with `--`;
an invocation such as `tool -- --help` selects no command and therefore causes
the executor to format root help even though the parser treats `--help` as a
trailing value.

**Recommendation:** let an explicit help flag bind to the command path named by
the user before defaults are inserted. If default-target help is desired, make
that an explicit documented mode rather than replacing conventional parent
help.

### INC-005: Default help omits the full command path

**Severity: Medium**

`CommandRegistry` now exposes `fullPath`, and command-not-found errors use it.
`MambaHelpFormatter`, however, builds its first usage line from
`registry.name` only. Help for a deeply nested action begins with only the leaf:

```text
serve  'Start the server.'
```

rather than the copyable invocation context:

```text
tool environment serve  'Start the server.'
```

This makes nested help less useful as command usage and diverges from the
framework's improved path-aware diagnostics.

**Recommendation:** build the usage prefix from `registry.fullPath`, while
keeping child entries in the Commands section relative to their parent.

### INC-006: Post-help validation depends on token shape and command depth

**Severity: Medium**

Help parsing intentionally stops named-input validation but continues command
discovery so `--help deploy` can target `deploy`. Unknown dash-prefixed tokens
after help are skipped. Unknown bare tokens are ignored at a leaf but become
`MambaCommandNotFoundException` when the current registry has children and no
positionals.

As a result, these superficially similar help requests have different
validation behavior:

```text
tool --help --unknown   # ignored
tool leaf --help value  # ignored at a leaf
tool --help missing     # command-not-found when root has children
```

The distinction follows internal command-discovery needs rather than a simple
user-facing rule about what help does with later tokens.

**Recommendation:** document one grammar explicitly. Prefer accepting only
registered command tokens after help and handling every other unowned token
consistently, regardless of its prefix or the selected registry's depth.

## Option and argument inconsistencies

### INC-007: Completion suggestions can violate runtime validation

**Severity: Medium**

`CompletionSuggestions` lists are copied and serialized, but neither live
registration nor `RegistryMap` checks them against the associated regex. This
applies to string options, repeatable string options, paired strings,
positionals, variadics, and accessor strings.

For example, an input can require `^[0-9]+$` while advertising `latest` as its
only Carapace completion. The generated integration then recommends a value the
parser always rejects.

**Recommendation:** validate every declared suggestion against the full regex
at registry construction and map deserialization, or document an explicit
reason why intentionally invalid suggestions are supported.

### INC-008: Invalid repeated mandatory values are reported as missing

**Severity: Low**

Repeated positional allocation collects values only while they validate. If
the first supplied token fails a mandatory repeated positional's regex or
choice set, the collection remains empty and the parser throws:

```text
The <name> is required at <index> after this command
```

A value was supplied; it was invalid rather than absent. Ordinary positional
validation already distinguishes this case with `Invalid value for positional
...`, so the two positional forms diagnose the same user error differently.

**Recommendation:** detect a present-but-invalid token before treating the
repeated collection as absent and report the rejected positional and index.

## Hook and execution assessment

No active hook-ordering or cleanup-loss inconsistency was found in the current
implementation.

The executor now:

- Records a hook only after its pre-hook completes
- Unwinds the command hook before persistent hooks
- Unwinds persistent hooks from inner to outer
- Attempts every entered cleanup callback
- Stores every cleanup failure immediately in callback order
- Uses `MambaExecutionException` when all failures are `Exception`
- Uses `MambaExecutionError` when an `Error` or arbitrary object participates
- Delays output and failure writers until cleanup is complete

The remaining project-guideline mismatch is architectural: the supplied rules
prefer errors as explicit return values and require logging for monitoring.
Registry creation, direct parsing, integration conversion/writing, formatter
programming errors, and non-`Exception` execution failures still throw, and
the framework exposes no logging callback. Fake execution converts only the
recoverable execution subset into result values.

## Integration inconsistencies

### INC-009: Required variants remain unenforceable in Carapace

**Severity: Low**

Mamba requires exactly one member of a required `oneOf` pair group. Carapace's
generated `exclusiveflags` preserves “at most one” but cannot express “at
least one.”

The converter now mitigates this honestly: every affected member description
states that runtime requires exactly one of the listed flags. Completion still
cannot prevent omission, so the parser remains authoritative.

**Recommendation:** retain the warning and expose converter capability or
lossiness metadata if additional integrations are added. This is a target
format limitation, not a parser defect.

## Current test-coverage gaps

The most consequential untested boundaries are:

- `NormalPositional` with non-empty `completions` through executor creation
- Local/persistent name and short-alias collisions in manual `RegistryMap`
- Noncanonical or omitted help metadata in manual `RegistryMap`
- Root `--help` when a root default command is configured
- A documented way to request parent help when a default path exists
- Full-path usage text for nested help
- Unknown bare and dashed tokens after help at root, group, and leaf levels
- Regex-incompatible completion suggestions for every supported input kind
- An invalid first value for a mandatory repeated positional

## Resolved findings from the previous report

The latest implementation resolves the earlier assessment as follows:

- Positional and named inputs use separate `RegistryMap` namespaces, matching
  live registration.
- Option overrides are resolved before splitting single and repeatable shapes.
- Live definitions and executor collections are defensively copied.
- Registry maps validate descriptions, help reservations, nested accessor help
  names, aliases, and synthesized negated spellings.
- Negatable `--no-*` collisions and paired `-h` aliases are rejected.
- Pair choice defaults were removed, eliminating default-activated optional
  groups and variant-default conflicts.
- Registered named-input tokens take precedence over regex-approved
  dash-prefixed values.
- Numeric diagnostics now describe the accepted signed decimal grammar.
- Deep command-not-found messages use the complete parent path.
- Cleanup retains every `Exception`, `Error`, and arbitrary object in order.
- Closed inherited stdin pipes use structural error codes and multiple known
  platform messages, with direct tests.
- Numeric Carapace ranges are no longer invented.
- String completion domains are explicit metadata rather than regex guesses.
- Required variant limitations are disclosed in generated descriptions.
- Legacy accessor conversion branches were removed.
- Duplicate and stale pair-option documentation was corrected.
