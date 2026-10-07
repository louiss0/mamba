# Migration

## 0.17.0: Clix components

Terminice is replaced by Clix. Mamba's argument parser is unchanged.

| Before | After | Author action |
| --- | --- | --- |
| `terminice` and Terminice types re-exported from Mamba | Clix re-exported; toolkit text input is `ClixInput`, while `Input` remains Mamba's declaration | Replace Terminice calls/types. Import Clix directly with a prefix if you prefer its original `Input` name. |
| Synchronous built-in setup prompts | Clix install/Git adapters return Futures; prompt interfaces accept `FutureOr` | Await direct adapter calls. Existing synchronous injected install/Git prompt implementations still work. |
| Optional positional description and a description prompt | Optional `--description` option, defaulting to `This is a CLI app` without prompting | Use `mamba create my_app --description "Manage my application."`. Remove `DescriptionPrompt`/`ClixDescriptionPrompt` implementations and the `descriptionPrompt` constructor argument. |
| Arrow-driven generated selectors and directory pickers | `ClixSelector` and `ClixDirectoryPicker` use typed/numbered line input | Regenerate or update existing component files; enter a number, filter with text, or submit a blank line to cancel. |
| Esc cancellation in rich generated input | Blank-line cancellation in generated prompts, selectors, and pickers | Update interaction instructions; a raw-key cancellation contract is not retained. |
| `LoadingSpinner`, `SpinnerStyle`, and a non-started spinner factory | Clix `Spinner` starts on construction; `SpinnerType` chooses frames | Replace spinner types and use `whileRunning` for automatic completion/failure/stop. `SpinnerType.line` uses ASCII frames. |
| Missing setup input could fall through to defaults | Closed input raises a command failure | Supply complete piped answers or run interactively. Bare Enter still means install yes / Git no. |

Clix has no native filesystem picker; `ClixDirectoryPicker` is Mamba's
Clix-backed adapter. Native Clix `Select`/`Search` are still re-exported, but are
not used by the generated components. Mamba no longer pulls in `intl` through
Terminice; dependencies declared by an application remain its responsibility.

## Framework correctness and expressiveness migration

These changes are included in Mamba 0.16.0. They repair retained-handle guarantees
and make syntax, scope, declaration validity, and generated metadata agree.

## Individual behavior changes

| Change and rationale | Before | After | Author action |
| --- | --- | --- | --- |
| Syntax owns values; shell tokenization is already complete | Unconstrained strings rejected empty/whitespace values, and validators could swallow options | Every supplied String is accepted by default; a separate option-looking string token reports missing supply | Add an explicit whole-content regex when needed. Replace `--label --help` with `--label=--help` for literal text. Signed numeric handling remains numeric. |
| Equals-attached short syntax is deliberate and bounded | `-o=file` was split into short letters | `-o file`, `-o=file`, `-vo=file`, `-vo=`, and `-o=a=b` work | Use equals when bundling a final value-taking short. `-ofile`, `-vo file`, valued flag-only bundles, and value-taking prefix members remain invalid. |
| Finite positional ownership preserves required suffixes | A repeat could consume a destination or stop at validator rejection | `copy a out/` allocates one source and one destination for sources `times: 3` followed by a required destination | Replace validator-delimited grammars with a declared finite layout. For unbounded lists use repeated named inputs or the separate trailing channel. |
| Propagation includes the declaring group | Propagated settings only applied below the group | The group and all descendants accept/validate the setting | Audit direct group invocations and defaults. Keep local declarations local; placement before a child does not change applicability. |
| Each effective spelling has one owner | Cross-kind/generated collisions could silently win by order | Long, short, generated negative, and accessor collisions fail declaration validity | Rename a competing input or disable negation. `cache` with generated `no-cache` cannot coexist with an explicit `no-cache`. |
| Compatible overrides preserve retained types | Incompatible shapes could shadow; ancestor reads could be unknown | Same kind/output type/cardinality overrides use descendant validation/defaults; both handles read the effective value | Preserve the ancestor type. Accessor overrides explicitly retain every ancestor container and leaf path; added fields are allowed, implicit deep merging is not. |
| Total typed storage honors accepted defaults | An empty default list or empty nested accessor container could be omitted | Accepted empty defaults and all accessor containers are immutable, non-null stored values | Retain and read root, nested, and leaf handles normally. Optional leaves remain nullable; required leaves still fail when missing. |
| Conflicts describe CLI syntax rather than defaults | Defaults activated conflicts; ancestor edges could be lost | Explicit occurrences activate conflicts, including `--no-cache` resolving false; applicable edges inherit by identity | Keep effective-value business rules in application code. Do not use `contains` as an explicit-supply query: it still means stored-value presence. |
| Configured ownership prevents metadata rebinding | Reusing a command could mutate an existing application's completion/help metadata | Construction validates the entire tree/defaults, then claims identities atomically; duplicate placement/cross-owner reuse fails early | Create fresh command instances for different owners or paths. Aliases, same-class fresh instances, and shared immutable declarations remain valid. |
| Context lifetime and overlap match the owner | Different adapters could allocate separate default context | One retained scalar context is shared across adapters; injected context retains identity; overlap/reentrancy raises StateError | Await sequential execute calls. Use separate configurations with fresh commands for parallel work. The guard releases after every exit, including escaping Errors. |
| Numeric constraints cannot silently do nothing | Missing stepped bounds/non-finite values could be accepted as declarations | Bounds/defaults are finite; a step is finite/positive and needs both ordered bounds; defaults obey range/step rules | Add finite bounds and replace malformed defaults. Explicit numeric supply remains signed decimal, not exponent/NaN/infinity syntax. |
| Enum-owned spelling is opt-in, with unambiguous offered sets | All enums used member names; duplicate choices could pick the first match | Implementing MambaEnumValue uses its exact String value without name aliases; ordinary enums retain names | Update CLI callers only when adopting the interface. Remove duplicate offered spellings/entries; collisions among unoffered members do not invalidate narrowed choices. |
| Metadata and artifacts faithfully describe declarations | Accessor requiredness/visibility, conflicts/default paths, or tiny decimals could be lost; PowerShell namespaces could collide | Metadata retains relationships/default paths/requiredness; hidden containers hide descendants; finite decimal candidates use full decimal text; PowerShell names use injective namespaces | Regenerate and reinstall completion scripts. Adapt manual RegistryRecord literals to include `conflicts` (an empty map if none) and nullable `defaultCommandPath`. RegistryCommand adds optional equivalents; RegistryAccessor.value adds `required`, defaulting false. |

## Controls and default dispatch

Default commands apply when no child is explicitly selected at their scope,
including invocations with flags/options. Group defaults apply after the group
is selected. Root help without a root default does not implicitly select a
child group's default. Help describes the explicit scope, not its implicit
default; version and help may be requested together.

Controls retain order-sensitive bypass: errors before a recognized request fail,
later ordinary tokens are ignored, and required/relationship/positional/trailing
checks are bypassed. The entire control-bearing short token is validated, so
`-hx` or a valued flag-only bundle does not hide an error. Option-owned control
text and values matching command names never change controls or dispatch.

## Preserved boundaries and deferred work

- The first delimiter starts separate immutable raw trailing arguments; later
  delimiters remain literal text. ChoiceVariadic still validates at most one
  offered spelling and returns raw strings, not an enum handle.
- Ordinary repetition remains finite. Paired/selected groups remain local and
  produce immutable aggregate maps. No independently readable grouped-member,
  exactly-one flag, directed dependency, or generalized relationship API is added.
- Effects and their mocks remain application-owned. Fake execution only detaches
  process delivery; it does not capture file/network/domain effects.
- Success remains status zero. Nonzero statuses are exception-driven. Cleanup
  catches Exception, not Error; successful pre-hooks earn post-hooks, persistent
  cleanup reverses order, and the first caught failure owns the status. Guard
  release is guaranteed even when remaining Error cleanup is not.
- The declaration value family stays closed. Duration, Uri, path, DateTime,
  application codecs, numeric positionals, environment/config provenance,
  optional/implicit option values, dynamic completion, unbounded ordinary
  positionals, and a new numeric enumeration cap are deferred.
- Shell enforcement is best-effort, not five equivalent parsers. Literal choices
  are shell-escaped, and dash-leading option values use inline supply. Runtime
  tests cover Bash and PowerShell; Zsh/Fish syntax and Carapace artifacts are
  separate evidence. Carapace retains its native macro/modifier/environment
  interpretation of values: application authors own those semantics, and YAML
  quoting does not make them literal. No additional Carapace rejection policy or
  helper/provider is added. Fish uses static quoted rules for newline-containing
  choices and omits tab-containing candidates because its native protocol treats
  tabs as descriptions; those values remain legal input and faithful metadata.
  PowerShell executable registration remains case-insensitive.
- Large stepped-double materialization remains a resource risk. The existing
  PowerShell integer range cap remains; no shared configurable cap is introduced.
- Unrelated prompting/styling/YAML exports and the declaration hierarchy remain.

Historical review/interview evidence is retained under
`.scratch/framework-expressiveness-review/`. The implementation verification
report distinguishes executed checks, local skips, and CI gates; adding a gate
is not evidence that a hosted CI run has already passed.
