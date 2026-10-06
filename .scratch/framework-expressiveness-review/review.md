# Mamba: correctness and CLI expressiveness review

Reviewed snapshot: `bf2bb12`, package version `0.16.0`.

This is a review of the current framework, not a branch diff or a promise of exhaustive bug discovery. The primary focus was declarations, registration, parsing, dispatch, hooks, help, and completion. Scaffolding was inspected but not exhaustively audited. No framework implementation was changed.

## Executive judgment

Mamba has a strong typed declaration model for conventional command trees, but it is a better **typed argument-declaration framework** than a complete model of CLI logic. Its central weakness is not a shortage of input classes. It is that grammar, input provenance, relationships, and execution capabilities are modeled unevenly.

The strongest foundations are retained typed handles, required/optional/defaulted output types, defensive copies of declarations, registration-time validation, nested commands, shared help/completion metadata, fake execution, and orderly cleanup for caught exceptions. These are worth preserving.

The hardest real-world CLI patterns currently require escaping the declarative model: unbounded positional lists, standard post-`--` positionals, custom value types, conditional requirements, exclusive flag groups, layered configuration, streaming I/O, and non-error nonzero exit statuses. Writing Dart in `run` can implement many of these behaviors, but then parsing, help, completion, and test execution no longer describe the same behavior automatically.

## Verification

Before creating the review artifacts:

- `dart analyze --fatal-infos`: no issues.
- `dart test --reporter compact`: 459 passed, 3 skipped. The skipped tests were the CI-gated real Bash completion tests; the local suite is not equivalent to running the complete CI shell matrix.

Focused review suite:

```sh
dart test .scratch/framework-expressiveness-review/reproduction_test.dart --reporter expanded
```

Observed: **5 passing behavior controls and 10 failing assertions**. These are intentionally red review probes, not fixes. Nine red assertions cover implementation or metadata-contract defects; one asks for a proposed explicit-input interpretation of conflicts and is marked as a policy question below. Counts are assertions, not independent bug counts.

The five controls distinguish behavior from opinion: whitespace rejection, separate post-`--` arguments, parent-local options not accepted with children, string options consuming control-looking values, and explicit `no-cache` taking precedence over a generated negation.

Real Windows PowerShell reproduction:

```sh
dart run .scratch/framework-expressiveness-review/powershell_reproduction.dart
```

Observed on Windows PowerShell 5.1:

```text
Before: blue
foo-bar run --color: red
foo_bar run --color: red
FAIL: completion state leaked between applications.
```

The script creates temporary generated artifacts, executes them in a real shell, checks the resulting completion candidates, and deletes the temporary artifacts. It exits nonzero on the bug. Bash, Zsh, Fish, and Carapace were not all functionally exercised locally; do not generalize this runtime verification to them.

## Confirmed defects

Severity here reflects impact and likelihood, not a formal security score.

### 1. High: an accepted empty default breaks the non-null typed contract

Locations: `lib/parser.dart:505-516`, `lib/command.dart:1540-1548`, `lib/executor.dart:316`.

Declare:

```dart
final values = RepeatedChoicePositional.withDefault(
  'values',
  choices: ShellCompletion.values,
  defaultValue: <ShellCompletion>[],
);
```

Register it as a discretionary positional, omit it, and read its retained handle in `run`. Registration accepts the declaration. The parser adds the empty default into its local collection but only stores a value if that collection is nonempty. `valueOf` then throws:

```text
Bad state: Parser omitted a non-null input value.
```

This is an `Error`, not an `Exception`, so it escapes the executor's recovery boundary. The declaration promises a non-null list and should produce `[]`, or the empty default must be rejected during registration. Producing a valid declaration and then omitting its promised value is not defensible.

### 2. High: effective long spelling validation misses cross-kind inheritance collisions

Locations: `lib/registry.dart:310-338`, `lib/registry.dart:596-616`, `lib/parser.dart:88-122`.

Give the executor `BooleanFlag('mode')` and a child command `StringOption('mode')`. Registration accepts both. In the child, both remain applicable: flags and options are merged separately, and effective spelling validation checks shorts but not duplicate longs across input kinds.

Observed:

```text
run --mode fast -> success: flag=false, option=fast
```

The option wins parser lookup; the flag cannot be selected with its advertised long spelling. This violates the glossary's "no two applicable inputs answering to the same spelling" invariant. Either implement an explicit cross-kind override policy or reject the collision. Keeping both applicable is wrong.

### 3. Medium: different application names overwrite each other's PowerShell completion state

Location: `lib/integrations.dart:1702-1714`.

`foo-bar` and `foo_bar` are legal, distinct application names. `_pascalCase` maps both to `FooBar`, so both artifacts define the same `MambaFooBar` variables and helper functions. Sourcing the second script changes completion for the first executable. The real-shell reproduction above proves this, rather than merely comparing generated text.

Use an injective identifier encoding that also respects PowerShell's case-insensitive identifier namespace. The existing Bash/Zsh encoding is closer to the desired model than lossy PascalCase normalization.

### 4. Medium: numeric declaration validation does not establish the parser's advertised invariants

Locations: `lib/registry.dart:1102-1158`, `lib/parser.dart:303-322`; documented contract: `docs/src/content/docs/reference/options.md`, DoubleOption section.

Two independently reproduced cases:

- `DoubleOption('ratio', step: 0.25)` is accepted without bounds, despite the documentation requiring finite bounds. `--ratio=0.3` succeeds because the step check only runs when `min` exists. A declared constraint silently does nothing.
- `DoubleOption.withDefault('ratio', defaultValue: double.nan)` is accepted and delivers `NaN` to `run`, although explicit values are restricted to signed decimal syntax.

Check finite bounds, finite positive steps, and finite defaults during registration. Reject unsupported combinations rather than silently weakening a declaration.

### 5. Medium: small stepped decimals produce completion candidates the parser rejects

Location: `lib/integrations.dart:71-83`.

For `DoubleOption('ratio', min: 1e-7, max: 3e-7, step: 1e-7)`, generated PowerShell candidates are:

```text
[0.0, 0.0, 0.0]
```

The parser rejects each as outside the declared range. Decimal precision is derived by splitting `double.toString()` on `.`, which does not handle exponent notation. The helper is shared by the shell converters, so the faulty candidate-generation algorithm is not PowerShell-specific, even though that was the tested artifact.

This directly contradicts the ADR/glossary claim that every finite completion candidate satisfies its declaration. Also review the absence of an enumeration cap for stepped double ranges; unlike PowerShell integer ranges, this path can request arbitrarily large static candidate lists. The latter is a code-inspection risk, not a measured performance finding in this review.

### 6. Medium: executor construction mutates reusable completion commands

Locations: `lib/executor.dart:496-499`, `lib/completion_command.dart:24`.

Register one `CompletionCommand` instance with executor `first`, then with executor `second`. Execute completion through `first`. It generates:

```text
Register-ArgumentCompleter -Native -CommandName 'second' ...
```

The second executor overwrites the shared command's public `registryRecord`. A composition root should not silently change another already-created executor's behavior. Supply execution metadata per invocation or bind it to executor-owned state instead of mutating the command definition. Alternatively, explicitly prohibit and detect reuse, though that is a less composable API.

`GroupCommand.help` is another executor-injected mutable field and deserves the same ownership review; its concurrency behavior was not separately reproduced here.

### 7. Medium: required accessor leaves become optional in completion metadata

Locations: `lib/registry.dart:189-208`, `lib/registry.dart:838-866`, `lib/integrations.dart:20-36`, `lib/integrations.dart:1515-1529`.

The parser correctly requires `AccessorStringOption.required('host')`. But `RegistryAccessorValue` has no requiredness field, accessor conversion supplies `required: false`, and the Carapace writer emits:

```text
--config.host?=
```

rather than its mandatory spelling `--config.host!=`. This is not merely a shell declining to enforce relationships; the integration model has discarded an existing declaration's requiredness.

### 8. Medium/low: Bash completion advertises hidden accessor leaves

Locations: `lib/integrations.dart:20-36`, `lib/integrations.dart:592-608`.

An `AccessorListOption('internal', [...], hidden: true)` is hidden by help, but `--internal.token` is emitted into Bash completion candidate tables. The Bash accessor walker ignores the group hidden flag, and flattening marks every leaf visible.

Preserve inherited hidden state when flattening. This leaks an input spelling, not its value; `hidden` must never be treated as an authorization or secret-storage boundary.

## Conflict/default policy: demonstrated inconsistency, intent needs a decision

Locations: `lib/parser.dart:172-181`, `lib/parser.dart:439-457`.

Declare a defaulted `output` option and a `replace` flag with `conflicts: {'replace': ['output']}`. `run --replace` fails with:

```text
Input --replace conflicts with --output.
```

The user did not supply `--output`; option defaults are inserted before conflicts. Boolean defaults, by contrast, are inserted afterward. Thus the same relationship mechanism mixes explicit presence and resolved values according to input kind.

The failing review assertion proposes that conflicts are about explicit input occurrences. That is a recommendation, not an established repository rule. If conflicts should instead apply to effective values, implement that policy consistently for flags, options, and accessor leaves and specify how false/negated flags participate. The current API needs input provenance to make either policy unambiguous.

## Can the existing constructs express common CLI logic?

| Pattern | Assessment |
| --- | --- |
| Nested CRUD commands, aliases, required/optional/defaulted named values | Good fit. |
| Global flags and options | Supported, with override/collision concerns described above. |
| Counts, negatable flags, repeated named options | Supported. |
| Fixed positional sequences | Supported; required inputs precede discretionary inputs. |
| All-or-none value-taking options | `PairedOptions` supports this. |
| At least one / exactly one value-taking option | `SelectedOptions.required`, optionally `single: true`, supports this. |
| Exactly one of several boolean flags | No selected-flag construct. Pairwise conflicts can express at most one, but not at least one. |
| Directional dependency: A requires B, but B does not require A | No declarative construct. Paired options are symmetric and too strong. |
| Conditional requirement: `--mode=remote` requires `--host` | No declarative value-dependent relationship. |
| Conflict between a local flag and a root/global flag | Conflict registration is local; redeclaration or application validation is needed. |
| `tool files a b c ...` with unbounded positional inputs | No unbounded pre-`--` typed repeated positional. `times` is a finite capacity; trailing `args` require `--`. |
| `copy SOURCE... DESTINATION` | Greedy repeated inputs do not reserve a final required positional; a broad source validator can consume the destination. |
| `tool -- -filename` feeding ordinary required positionals | Unsupported by the current grammar. `--` switches into a separate trailing list, so the required positional remains missing. |
| `-ofile`, `-o=file`, or mixed `-vo file` option bundles | No attached short-option values or value-taking final member of a short bundle. |
| `--color` meaning auto, but `--color=always` selecting a value | No optional option-value/implicit-value construct. |
| Typed dates, paths, URIs, durations, identifiers | Must parse/validate strings in application code; sealed input families expose no general custom codec. There are also no native numeric positional declarations. |
| Enum value spelled `json-lines` independently of Dart member `jsonLines` | No explicit choice-spelling mapping; choices use `Enum.name`. |
| CLI > environment > config > default precedence | Explicitly left to applications, with no integrated value-origin model. |
| Streaming stdin/stdout, binary output, progress to stderr | Outside the `run -> String?` abstraction; direct process I/O bypasses fake executor capture. |
| Normal nonzero statuses such as "no matches" | Requires an exception or out-of-band process exit assignment; command return values cannot carry a normal status. |
| Live completion of files, branches, resources | No declaration-level dynamic completion provider. Some shells may supply their own filename fallback, which is not equivalent to declaring a typed provider. |

This supports many ordinary administrative CLIs, but it does not justify a blanket claim to naturally express the behavior of most mature CLIs. Git-like command trees are a strong fit; grep-like filters, compiler front ends, command wrappers, copy-like argument grammars, and configuration-heavy tools encounter fundamental gaps.

## Contradictions and design tensions

### A. "Define once" versus a lossy integration model

The registry record does not carry conflicts, root/group default command paths, or required accessor state. Some relationship metadata survives but is intentionally not enforced by current converters. That is acceptable if documented as approximate completion; it is not semantic equivalence between consumers.

Help is also not entirely definition-driven: child commands accept `--help`, but child `applicableFlags` omit the help declaration, so their help pages do not advertise it. PowerShell injects it separately. The parser, help formatter, and integration therefore disagree about whether this is registry metadata or special framework behavior.

### B. "Typed values" versus closed primitive syntax

Required/optional/defaulted scalar handles are an excellent idea. But choice spellings are tied to Dart enum names, custom domain codecs are unavailable, and heterogeneous paired groups infer `Object` and return string-keyed maps. 
Accessors mitigate map type erasure by retaining readable leaf handles; paired members do not provide the same independently readable typed handle contract.

The framework specializes many combinations of primitive kind, repetition, requiredness, defaults, and grouping while offering no general route to one new domain value type. 
That is breadth without equivalent extensibility.

### C. "CLI arguments" versus treating argv as unquoted text

Default strings use `\S+`, so one already-tokenized argument `hello world` is rejected unless every declaration overrides the regex. The shell has already done tokenization; embedded whitespace is not an extra argv element.

At the same time, a default string option accepts a dash-led next token when that token matches its regex. `run --label --help` executes with label `--help` instead of displaying help. 
This is not asserted as an accidental bug: it demonstrates a token-ownership policy coupled to value validation. Model lexical ownership separately from semantic validation.

### D. "Variadic" versus a separate delimiter-only argument channel

Mamba's `Variadic` is not an unbounded positional declaration: it validates the separate `args` list after `--`. `ChoiceVariadic` even accepts at most one value. 
Both are documented choices, but the conventional meaning of "variadic" and conventional POSIX `--` behavior differ from this model.

A clearer model would separate option termination, positional cardinality, and child-process passthrough. 
One delimiter need not permanently change the category of all remaining arguments.

### E. "Group-local" versus "propagated" configuration

A group's local inputs are rejected when a child is selected, even if supplied before the child token. 
Propagated inputs are available to descendants but not to the group itself. This prevents an uncomplicated "group and all children share this setting" declaration.

There is also a compositional tension between allowing descendants to override propagated handles by name and passing only final effective handles to ancestor persistent hooks. An ancestor reading its original overridden handle has no automatic adaptation. 
This is a design risk; that hook scenario was not reproduced as a separate test.

### F. "Executor context" versus real lifecycle data

Context intentionally holds only scalar hook state, is retained between executions, and is not passed to `run`. 
A persistent hook cannot hand a prepared domain object to command execution through this API. 
Constructor injection and application-owned services remain valid alternatives, but the shared context is not an execution environment or dependency container.

A leaf that needs piped input must also use `HookRunner`: input is read before the hook and buffered to EOF (`lib/src/system_process.dart:15`), then usually copied into a mutable command field for `run`.
This encourages invocation state on reusable command objects and excludes streaming/constant-space processing from the core abstraction.

### G. "No drift" versus conflicting documentation

`README.md` describes root defaults applying with flags/options and matches implementation. 
`docs/src/content/docs/reference/executor.md:209` says defaults apply only to an empty argument list. Both cannot be true.

The options reference says a double step requires finite bounds, but registration accepts it without them. 
Documentation-compilation checks establish that examples compile; they do not establish that prose contracts hold.

## Code-quality judgment

No new lint/formatting complaint is needed for the framework: the configured analyzer already checks those. The substantive maintenance issues are judgment calls backed by behavior:

- **Duplicated interpretation:** registry token-width scanning, parser value/flag handling, executor control scanning, and shell routing reimplement overlapping parts of token ownership. A normalized per-invocation ownership model would reduce drift.
- **Lossy metadata as type design:** string `valueType`, nullable kind-specific fields, and inferring option-group kind from each member's partner list encode important invariants indirectly. Explicit group kinds and richer typed leaf metadata would be easier to preserve.
- **Combinatorial declaration hierarchy:** `lib/command.dart` is roughly 1,700 lines of primitive/required/defaulted/repeated/paired/accessor variants. Do not remove the valuable static output guarantees, but factor independent policies so adding a domain value type does not require recreating every family.
- **Mutable runtime state in declarations:** completion registry injection and group help injection blur definition ownership with execution ownership. This already caused an observable executor-isolation defect.
- **Broad public surface:** `lib/mamba.dart` reexports terminal styling, interactive prompting, and YAML writer packages. That couples downstream API compatibility to unrelated third-party APIs and expands what "the framework" promises.

## Recommended priorities

1. Fix the non-null omission, effective spelling collisions, PowerShell namespaces, numeric validity, and reproduced metadata/completion defects. Promote focused probes into the normal suite as fixes land.
2. Decide and document input provenance: explicit versus default versus environment/config, and what relationships operate on. Do not patch conflict order without defining the policy.
3. Revisit positional grammar and delimiter semantics against concrete `copy`, `grep`, and wrapper examples. This is a public-contract decision, not a cleanup refactor.
4. Introduce extensible value codecs and independent choice spellings while keeping typed required/optional/defaulted handles.
5. Generalize relationships over typed input handles: at-most-one, at-least-one, exactly-one, requires, and conditional requirements; make global/local ownership explicit.
6. Provide an invocation environment with optional streamed I/O, domain dependencies, output/status, and an equally capable fake boundary. Keep small string-returning commands as an ergonomic convenience.
7. Strengthen semantic tests: every finite completion candidate must parse; distinct valid names must remain isolated; hidden inputs must stay hidden; declarations/defaults must honor static output types. Test real completion behavior, not only fixture snapshots and syntax validity.

These are recommendations, not architectural decisions made on the user's behalf. The review does not prescribe implementing all of them at once.

## External comparison points

These are primary-source examples of existing CLI patterns, not claims that Mamba must copy another framework wholesale:

- [Click options](https://click.palletsprojects.com/en/stable/options/): attached/mixed short options, optional option values, multi-value options, environment values, and value-source precedence.
- [Click arguments](https://click.palletsprojects.com/en/stable/arguments/): `--` permitting option-looking positional filenames.
- [clap Arg](https://docs.rs/clap/latest/clap/struct.Arg.html): extensible value parsers, argument cardinality, directional and value-dependent requirements, and environment inputs.

## Bottom line

Keep the typed handles and the declaration-first architecture. The next improvement should be a more complete model of **grammar, relationships, provenance, and invocation capabilities**, not another collection of specialized primitive input classes. Mamba currently makes many declarations precise while leaving the relationships and execution needs that make a CLI an application outside that precision.
