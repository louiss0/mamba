# Framework correctness and expressiveness: first milestone

Status: ready-for-agent

Design confirmed in Q50. Specification and issue publication are authorized; framework implementation and release actions are not.

## Problem Statement

As a CLI author, I want Mamba's typed input declarations to reliably describe what parsing, command execution, help, and completion actually do. Today, valid-looking declarations can omit promised non-null values, silently lose constraints or metadata, collide with inherited spellings, or generate completion candidates that cannot be parsed. Reusing command objects can also overwrite another application's framework metadata.

Several documented behaviors make ordinary command patterns unnecessarily fragile: already-tokenized strings containing whitespace are rejected by default; validators influence token ownership; repeated positionals consume a required destination; defaults accidentally activate syntax conflicts; propagated settings do not apply to their declaring group; and ancestor hooks cannot reliably read compatible overridden handles.

I also want two bounded improvements: equals-attached short option values, including a flag prefix, and enum-owned choice spellings that differ from Dart member names without losing typed enum outputs.

The review is not a mandate to reproduce every mature CLI grammar. My previously confirmed boundaries must survive the fixes: finite ordinary positionals, separate trailing arguments, existing input relationships, application-owned command effects and mocks, exception-driven nonzero statuses, and a closed declaration value family.

## Solution

Deliver a coherent first milestone that fixes reproduced correctness and metadata defects, applies the confirmed core semantics, and adds only the selected short-option and enum-spelling capabilities.

A CLI author will retain typed declarations, receive predictable values through retained handles, get early actionable declaration errors, and use help/completion derived from faithful declaration metadata. Compatible overrides will preserve ancestor reads. Syntax conflicts will describe explicit input occurrences rather than defaults. Each configured Executor will own its commands, retained scalar hook context, and execution-overlap guard.

Support `-o=file` and `-vo=file` without introducing no-equals attached values or mixed bundles taking a separate value. Let enums implement MambaEnumValue to supply exact String choice spellings, while ordinary enums keep member-name syntax and commands keep reading typed enum members.

Verify the behavior primarily through the existing fake-execution boundary. Use existing public declaration/registry and artifact boundaries where appropriate, plus real PowerShell regression tests for the reproduced isolation bug. Publish individual migrations, preserve historical review evidence, and explicitly distinguish fixes from intentional limitations and deferred extensions.

## User Stories

1. As a CLI author, I want successful execution to provide every declared non-null value, so that retaining a typed handle is a reliable contract.
2. As a CLI author, I want an omitted repeated positional with an accepted empty default to return an empty list, so that a legal declaration does not cause an invariant failure.
3. As a CLI author, I want omitted optional accessor trees to retain their root and nested container handles, so that I can read containers even when their leaves are absent.
4. As a CLI author, I want optional leaf absence to remain nullable and required leaf absence to fail parsing, so that declaration requiredness remains meaningful.
5. As a CLI author, I want parsed collections to remain immutable, so that downstream code cannot mutate shared invocation results.
6. As a CLI user, I want a supplied string containing spaces to remain one accepted argv value, so that shell tokenization is respected.
7. As a CLI author, I want supplied empty strings to be distinct from missing values, so that I can decide whether empty content is meaningful.
8. As a CLI author, I want explicit validators to remain authoritative for content and defaults, so that broader unconstrained strings do not weaken intentional constraints.
9. As a CLI user, I want an option-looking token after a value-taking string option to report missing supply, so that a missing value does not swallow another input.
10. As a CLI user, I want inline syntax to supply literal dash-leading option text, so that I can distinguish content from named-input syntax.
11. As a CLI user, I want signed numeric inputs to retain numeric handling, so that negative numbers are not mistaken for omitted option values.
12. As a CLI user, I want both lone-short separate values and equals-attached short values, so that the approved short forms work predictably.
13. As a CLI user, I want a flag prefix followed by an equals-attached value-taking short, so that `-vo=file` can select verbosity and an output value together.
14. As a CLI user, I want everything after the first equals sign to belong to the option value, so that embedded equals signs are preserved.
15. As a CLI user, I want malformed bundles and values attached to flag-only bundles to fail, so that unsupported syntax is not silently reinterpreted.
16. As a CLI author, I want command resolution and control detection to agree with value ownership, so that values equal to command names or help text do not change dispatch.
17. As a CLI user, I want help/version to preserve the agreed order-sensitive bypass, so that requesting controls retains predictable existing behavior.
18. As a CLI author, I want the complete control-bearing short token to be validated, so that a control letter does not hide an invalid short or attached value in the same token.
19. As a CLI user, I want help to describe my explicit command scope rather than its implicit default, so that I can inspect the requested group or root.
20. As a CLI author, I want repeated positionals to retain finite positive capacities, so that their maximum cardinality remains declared and testable.
21. As a CLI author, I want repeated positionals to reserve following mandatory operands, so that a bounded sources list does not consume its required destination.
22. As a CLI user, I want insufficient positional supply to fail rather than manufacture required values, so that missing operands remain visible.
23. As a CLI author, I want validation to check assigned positional values without reassigning rejected tokens, so that changing content constraints does not change the argument layout.
24. As a CLI author, I want tokens after the first delimiter to remain separate raw trailing arguments, so that wrappers can forward them unchanged.
25. As a CLI author, I want current optional trailing validation and ChoiceVariadic cardinality to remain intact, so that the delimiter decision does not silently redesign variadics.
26. As a CLI author, I want local inputs to apply only to their selected declaring command, so that token placement does not introduce a second scope-parsing model.
27. As a CLI author, I want propagated inputs to apply to the declaring group and all descendants, so that one setting can serve the whole subtree.
28. As a CLI author, I want every effective long, short, generated negative, and accessor spelling to have one owner, so that advertised inputs remain selectable.
29. As a CLI author, I want cross-kind and grouped/standalone collisions to fail declaration validity, so that incompatible inputs cannot silently shadow each other.
30. As a CLI author, I want generated negations to be checked against explicit spellings, so that a negatable flag does not compete with a separate negative-named flag.
31. As a CLI author, I want compatible standalone overrides to preserve ancestor and descendant retained reads, so that persistent hooks continue to use their original handles.
32. As a CLI author, I want the effective override's validation and defaults to govern its value, so that local customization remains meaningful.
33. As a CLI author, I want accessor overrides to preserve every ancestor container and leaf path while allowing added fields, so that retained accessor handles remain structurally compatible.
34. As a CLI author, I want omitted or retyped ancestor paths to fail instead of being implicitly merged, so that an accessor override explicitly declares its complete compatible shape.
35. As a CLI author, I want syntax conflicts to depend on explicit input occurrences, so that declaration defaults do not make ordinary invocations unusable.
36. As a CLI author, I want explicitly negated flags to count as occurrences even when their values are false, so that conflict behavior follows syntax rather than truthiness.
37. As a CLI author, I want conflicts to reference applicable global, propagated, grouped, and accessor inputs, so that supported relationships can span effective scope.
38. As a CLI author, I want conflict edges to inherit with applicable declaration identities and compatible overrides, so that descendant commands retain meaningful ancestor constraints.
39. As a CLI author, I want edges with unavailable parent-local endpoints to become inactive without same-name resurrection, so that unrelated child declarations do not inherit accidental relationships.
40. As a CLI author, I want ParsedInputs.contains to retain stored-value meaning, so that this milestone does not silently change my existing presence checks.
41. As a CLI author, I want malformed numeric bounds, steps, and defaults to fail declaration validity, so that constraints cannot silently do nothing.
42. As a CLI author, I want stepped double declarations to require finite ordered bounds and finite positive steps, so that their supported domain is established before invocation.
43. As a CLI author, I want defaults and explicit numeric inputs to obey the same range and step interpretation, so that defaults cannot bypass declared constraints.
44. As a CLI user, I want every finite completion candidate to satisfy its own declaration, so that selecting a candidate does not immediately produce a parse failure.
45. As a CLI author, I want tiny stepped decimal ranges to generate distinct valid candidates, so that exponent-form numeric representations do not collapse to zero.
46. As a CLI author, I want enums to supply choice spellings through MambaEnumValue, so that CLI terminology can differ from source-code member names.
47. As a CLI author, I want ordinary enums to retain Enum.name behavior, so that existing choices do not require migration.
48. As a CLI author, I want adopting enums to use their explicit values without implicit name aliases, so that accepted spelling is deliberate and unambiguous.
49. As a CLI author, I want choice parsing to return the actual enum member, so that independent spelling does not erase static output types.
50. As a CLI author, I want exact case-sensitive choice strings, including empty, whitespace-containing, and dash-leading values, so that value syntax is not incorrectly limited to command-name grammar.
51. As a CLI author, I want duplicate offered choice spellings and repeated choice entries rejected, so that matching never silently chooses the first ambiguous member.
52. As a CLI author, I want narrowed enum choices to ignore unoffered members, so that collisions outside a declaration do not invalidate its unambiguous subset.
53. As a CLI author, I want the same choice interpretation across declarations, defaults, help, metadata, completion, and trailing validation, so that consumers do not drift back to member names.
54. As a CLI author, I want complete composition validation at configured Executor construction, so that invalid descendants and default paths fail before adapter creation.
55. As a CLI author, I want command ownership claiming to be atomic, so that failed construction neither reserves otherwise reusable commands nor changes an existing owner's metadata.
56. As a CLI author, I want each command object to have one configured owner and one canonical path, so that framework metadata cannot be rebound by another composition.
57. As a CLI author, I want fresh same-class command instances, aliases, and shared immutable declarations to remain valid, so that ownership restrictions do not prohibit legitimate composition.
58. As a CLI author, I want multiple adapters from one configured Executor to remain supported, so that fake and production delivery can share the same configuration.
59. As a CLI author, I want one retained scalar hook context across that owner's adapters, so that documented executor-scoped state matches actual behavior.
60. As a CLI author, I want overlapping calls across an owner's adapters to raise StateError before the second execution enters hooks, so that accidental shared-state races fail deterministically.
61. As a CLI author, I want the overlap guard released after every exit, including escaping Errors, so that a failed invocation does not permanently disable sequential reuse.
62. As a CLI author, I want existing Exception-only hook cleanup and first-failure status preserved, so that this milestone does not silently change the failure boundary.
63. As a CLI author, I want command effects and their mocks to remain application-owned, so that fake execution orchestrates commands without pretending to capture external effects.
64. As an integration author, I want registry records to preserve supported conflicts and default dispatch paths, so that limited shell enforcement does not cause metadata loss.
65. As a CLI user, I want required accessor leaves correctly represented in completion metadata, so that generated artifacts do not advertise them as optional.
66. As a CLI author, I want hidden accessor containers to hide descendant advertised spellings, so that flattening respects visibility without claiming it is security.
67. As a CLI user, I want child help to advertise the controls it accepts, so that help, parsing, and completion agree about availability.
68. As a CLI author, I want distinct accepted names to keep isolated PowerShell artifacts when sourced together, so that installing another application's completions does not overwrite mine.
69. As a maintainer, I want real PowerShell runtime regressions alongside existing Bash runtime and shell syntax checks, so that the reproduced leakage is tested at the boundary where it occurs.
70. As a maintainer, I want tests to assert public behavior rather than private representation, so that internal refactoring does not invalidate meaningful acceptance coverage.
71. As a CLI author, I want individually justified breaking-change migrations and compiling examples, so that I can adapt applications without guessing which review proposals were accepted.
72. As a maintainer, I want every review finding classified as fixed, intentional, or deferred, so that milestone completion is not confused with eliminating all expressiveness gaps.
73. As a maintainer, I want reported verification to distinguish executed tests, local skips, and CI shell results, so that support claims reflect actual evidence.
74. As a CLI author, I want the selected milestone to avoid unrelated hierarchy rewrites and public-export removals, so that correctness work does not become an unapproved API redesign.

## Implementation Decisions

### 1. Grammar and token ownership

- Update typed string declarations, token interpretation, parsing, dispatch, control detection, and completion routing to use one coherent syntactic ownership contract. Internal factoring is flexible; the milestone does not require a wholesale rewrite.
- Unconstrained strings accept every supplied String, including empty and embedded-whitespace values. Requiredness concerns supply; explicit validators continue to check content and defaults.
- A following option-looking token is not a separate-form string value. Inline supply preserves literal dash-leading option content. Numeric declarations retain signed-decimal handling and distinguish invalid numeric content from missing supply.
- Preserve long inline/separate forms, lone-short separate values, and flag-only bundles. Add equals-attached lone shorts and bundles with a flag-only prefix followed by exactly one final value-taking short.
- Split at the first equals sign only. The final option owns the remaining text, including empty text and further equals signs. Unknown shorts, value-taking prefix members, and attached values on flag-only bundles are invalid.
- Do not add no-equals attached text or mixed bundles taking a separate value.
- Help/version retain order-sensitive validation. Errors before the recognized request fail; later ordinary tokens are ignored, and required-input, relationship, positional, and trailing checks are bypassed. Validate the entire control-bearing short token, including any attached value, before bypassing later tokens.
- Values that contain control-looking text are never control requests. Values equal to command names are never command selections. Explicit-scope help remains independent of default dispatch, and requesting both controls retains combined version/help output.
- Local inputs apply only when their declaring command is selected, even when supplied before a child token. Unknown dash-leading operands do not become positionals; a lone dash retains existing behavior.

### 2. Finite positionals and trailing arguments

- Ordinary repeated positionals retain a positive finite times maximum. Allocate in declaration order while reserving the minimum supply needed by following mandatory positionals; a mandatory scalar or repeated declaration needs at least one supplied token.
- Capacities are maxima, not exact required lengths. Discretionary suffixes do not reserve mandatory supply. Insufficient required supply and leftover tokens remain errors.
- Validate assigned values without validator-delimited boundary discovery, reassignment, or backtracking. A rejected source is an error for sources, not another positional's value.
- A bounded sources declaration followed by a required destination assigns one source and one destination when given two operands, rather than greedily consuming the destination.
- The first delimiter starts separate immutable raw trailing arguments. They never satisfy ordinary positional declarations; subsequent delimiters remain literal trailing text.
- Without a Variadic declaration, trailing strings remain unrestricted. NormalVariadic validates each string when configured; ChoiceVariadic validates at most one offered choice spelling and still supplies raw strings rather than a typed enum handle.

### 3. Effective scope, spellings, and overrides

- Propagated inputs apply to their declaring group and every descendant. Local inputs remain local.
- Registry validation establishes one effective owner for each applicable long, short, generated negative, and dotted accessor spelling. Reject cross-kind, grouped/standalone, and generated/explicit collisions after resolving effective declarations.
- Help/version spellings remain reserved. Opt-in framework declarations such as dry-run remain ordinary inputs.
- Standalone same-kind overrides require identical output type and cardinality. Compatible ancestor and descendant handles read the effective descendant value, under its defaults and content validation.
- Preserve actual compatible declaration lineage; matching names alone do not establish ancestry. Shadowed ancestor short aliases do not remain independent effective owners.
- Accessor overrides explicitly preserve every ancestor container/leaf path with compatible kind, output type, and cardinality. Added local fields are permitted; omitted or retyped paths are invalid. There is no implicit deep merge.
- Ancestor accessor root, nested container, and leaf handles read the effective local data. Paired/selected members cannot replace applicable standalone declarations even when scalar types match; groups remain local.

### 4. Typed storage and input relationships

- Every successful ordinary parse stores the values promised by all known non-null retained handles, including accepted empty default lists and every accessor container. Optional absence stays nullable; parsed collections retain immutability.
- Control requests do not execute commands and need not fabricate required operands whose validation was bypassed.
- ParsedInputs.contains retains stored-value meaning. Explicit input occurrence tracking stays internal; do not add a public provenance query.
- Syntax conflicts use explicit CLI occurrences independently of defaults and resolved values. Explicit negations count even when false; defaults alone never activate conflicts.
- Conflict references may name applicable ordinary local, global, propagated, grouped-member, and supported dotted-leaf inputs. Reserved controls remain outside ordinary conflict validation.
- Inherit edges wherever both endpoint declaration identities remain applicable, including compatible overrides. An unavailable parent-local endpoint deactivates its edge; unrelated same-name child declarations cannot reactivate it.
- Retain paired/selected group behavior and heterogeneous aggregate maps. No new relationship families or independently readable grouped-member API is introduced.

### 5. Numeric declarations and finite candidates

- Registry validation rejects non-finite supplied double bounds/defaults, unordered bounds, and non-finite or nonpositive steps. A declared double step requires both finite bounds.
- Defaults obey the same supported range, step, content, and repeated-capacity rules as explicit values. Validation traverses supported local, propagated, grouped, repeated, and nested accessor shapes.
- Preserve signed-decimal explicit syntax and shared step alignment. Do not admit NaN, infinity, or scientific notation to accommodate broken completion output.
- Correct decimal candidate generation when numeric string representations use exponents. The range from one ten-millionth to three ten-millionths, with a one ten-millionth step, must produce distinct valid candidates rather than zeroes.
- Every finite emitted candidate must satisfy its own declaration; non-exact maximum endpoints must not be emitted when they violate the step.
- No new shared/configurable enumeration cap is selected. Preserve the existing PowerShell integer cap and explicitly retain large stepped-double materialization as a deferred risk.

### 6. Opt-in enum choice spellings

- Introduce the public MambaEnumValue interface with a String-valued value getter. Enums implement it; enum extension of a class is not supported by Dart. The interface form was validated by a local SDK probe.
- Ordinary enums use Enum.name. Implementing enums use their explicit value instead, without implicit member-name aliases. Choice declarations remain enum-constrained and typed parsing returns the actual enum member.
- Spellings are any exact, case-sensitive String, including empty, whitespace-containing, dash-leading, punctuation, quotes, and shell metacharacters. Do not trim, normalize, case-fold, apply command-name grammar, or stringify arbitrary objects.
- Reject duplicate spellings within each declaration's offered choices, including repeated entries of one member. Unoffered enum members do not invalidate an unambiguous narrowed choice set.
- Use the same spelling interpretation for supported choice options, positionals, repeats, groups, accessors, defaults, diagnostics, help, registry records, static completion, and ChoiceVariadic validation.
- Defaults remain typed enum values belonging to offered choices. Raw trailing output and current trailing cardinality remain unchanged.
- Preserve literal spellings through generated-artifact escaping rather than interpreting their contents as shell code or controls.

### 7. Configured Executor ownership and lifecycle

- Validate the complete composition eagerly at configured Executor construction, including every descendant and default path. Only after validation succeeds may command ownership be claimed atomically and mutable framework metadata be bound.
- Failed construction leaves otherwise unowned commands reusable and cannot modify an existing owner's metadata. Cross-owner command reuse and duplicate object placement within one tree are declaration errors.
- Each command object belongs to one configured Executor and one canonical path. Fresh same-class instances may occupy different paths; node aliases do not create placements. Immutable typed declarations may be shared.
- Multiple fake/create adapters from the same configuration remain valid and use that owner's framework metadata.
- Each owner has one retained scalar hook context shared by all its adapters. An explicitly injected context preserves its object identity. Context does not become a domain dependency container.
- An owner-wide guard rejects a second in-flight invocation, including reentrant or cross-adapter calls, with StateError before the second invocation enters hooks or command execution. Do not queue or return a normal Mamba failure result; the first invocation continues unaffected.
- Always release the guard after success, recoverable failure, or escaping Error, so sequential reuse remains possible.
- Preserve success with status zero, exception-driven nonzero results, application-owned effects/mocks, and Exception-only hook cleanup. Successful pre-hooks earn post-hooks; persistent cleanup reverses order, and the first caught failure determines the returned status. Errors escape without guaranteed remaining post-hooks.

### 8. Registry metadata, help, and completion

- Registry records retain supported effective conflicts, root/group default dispatch paths, independent accessor requiredness, inherited visibility, choice spellings, and available reserved controls.
- A required selected group requires a selection, not every member. Preserve coherent existing manually constructed-record behavior and document necessary public record-shape migrations.
- Child help advertises accepted controls; converters must not independently invent contradictory availability. Default dispatch remains usable with flags/options, and explicit-scope controls do not silently follow defaults.
- Required accessor leaves receive mandatory completion metadata, including Carapace representation. Hidden accessor roots or nested containers hide all descendant advertised spellings. Hidden remains visibility, not an authorization boundary.
- Shell-side relationship enforcement remains best-effort. Metadata must not be discarded merely because a shell consumer does not fully enforce it.
- PowerShell state/helper identifiers use a shell-safe injective encoding of accepted names and path components under its case-insensitive identifier namespace. Distinct hyphenated/underscored application names remain isolated when scripts are sourced together in either order.
- Preserve public executable names and acknowledge unavoidable case-insensitive executable-name behavior rather than promising independent case-only registrations.

## Testing Decisions

### Primary seam: public fake execution

Use the existing configured Executor and fake adapter as the highest practical seam for behavioral acceptance. Declare real test commands, execute argv, and observe public results, retained-handle reads, trailing arguments, hook events, and application-owned mock interactions. Do not introduce a new framework test interface.

This seam covers parsing, defaults, explicit occurrences, inherited relationships, command/default dispatch, compatible overrides, required-suffix allocation, hook sequencing, typed storage, scalar context retention, and sequential adapter reuse together. It catches consumer drift that isolated private-helper tests can miss.

Prior art includes existing executor result/hook/default-path/context tests, fake standard-input injection, retained-handle assertions, and the focused review reproductions. Direct public Parser tests remain useful for focused grammar matrices and candidate acceptance, but do not replace executor-level dispatch/control tests.

### Necessary existing public boundaries

1. **Configured Executor construction and declaration validity:** assert public declaration errors for invalid numerics, effective spelling collisions, duplicate offered choices, incompatible overrides, duplicate placement, invalid defaults, and cross-owner reuse. Prove atomicity through subsequent successful composition and unchanged prior-owner behavior, not private ownership tables.
2. **Public registry records and help output:** inspect supported exported metadata and formatted help to prove conflicts, defaults, controls, accessor requiredness, visibility, and exact choice spellings survive. Existing registry, help, and converter tests provide prior art. Metadata representation is part of the public contract; private flattening strategies are not.
3. **Generated artifacts and real shell execution:** use existing converter APIs and generated fixture infrastructure. Use real PowerShell completion to prove state isolation because fake execution cannot observe a shell's namespace. Keep existing Bash runtime tests and shell syntax checks; do not add new framework seams to simulate shell internals.

These are boundary-specific observations of public behavior, not a requirement to test every internal layer independently.

### Behavioral acceptance matrix

- **Grammar/control:** supplied empty and whitespace strings, explicit validators, missing separate values, literal inline dash-leading text, signed numbers, supported/unsupported short forms, embedded equals signs, malformed prefixes, values matching command names, root/group/default command selection, explicit help scope, combined controls, and whole-token validation before later-token bypass.
- **Positionals/trailing:** bounded sources plus required destination, multiple repeated declarations, required minima, capacity edges, optional/defaulted suffixes, rejected assigned values, insufficient supply, leftover tokens, raw trailing pass-through, subsequent literal delimiters, and unchanged ChoiceVariadic raw output/cardinality.
- **Scope/handles:** group-level propagation, local inputs with selected children, all effective spelling classes, both cross-kind directions, generated-negative collisions, compatible standalone reads from command and persistent hooks, and accessor root/container/leaf reads with explicitly preserved structure and added local fields.
- **Storage/conflicts:** omitted accepted empty defaults, empty nested accessor containers, nullable leaves, required leaf failures, immutable collections, stored-value contains semantics, defaults not activating conflicts, explicit negation activating conflicts, global/group/accessor endpoints, inherited compatible edges, unavailable local endpoints, and no unrelated-name resurrection.
- **Numerics/choices:** malformed finite bounds/steps/defaults across supported shapes, explicit/default parity, small stepped decimals, non-exact endpoints, ordinary enum fallback, opted-in spellings, rejection of implicit names, typed enum outputs, arbitrary exact strings, duplicate offered spellings, repeated entries, and valid narrowed subsets.
- **Ownership/lifecycle:** first-owner preservation after failed reuse, full-tree rollback after invalid construction, fresh instances/aliases/shared declarations, multiple adapters, cross-adapter retained scalar context, overlap and reentrancy, first execution unaffected, guard release after every failure phase and escaping Errors, and existing Exception-only cleanup/first-failure status.
- **Metadata/artifacts:** supported conflict/default fields, independent accessor requiredness, inherited hidden state, selected-group versus member requiredness, control visibility, exact enum spellings, and artifact isolation for application names and command paths.

Use controlled Futures to test overlap and reentrancy; do not depend on sleep timing. Use static/compiler tests for public typed outputs and enum implementation examples where existing test patterns support them.

### Candidate oracle and real-shell regression

Every finite generated candidate must be accepted by its declaration using the supported supply form. Compare logical values after artifact escaping/decoding rather than treating raw script fragments as candidate text. Test strings with whitespace, empty content, quotes, metacharacters, and leading dashes. Preserve supported explicit numeric syntax rather than weakening the parser for generator convenience.

Promote the PowerShell reproduction into normal runtime coverage: source two applications with distinct candidate sets, invoke CommandCompletion.CompleteInput, assert each application's own candidates, then repeat in reverse load order and after repeat sourcing. Include nested command-path isolation. Use temporary artifacts, guaranteed cleanup, checked exit codes, and surfaced diagnostics.

The confirmed shell scope is the existing CI matrix plus targeted Windows PowerShell 5.1 and pwsh runtime isolation tests where available. Existing Bash functional coverage and shell syntax checks remain. Missing required CI prerequisites must be explicit failures; unavailable local shells are reported as skipped/unverified, not successful runtime checks.

### Test quality and completion evidence

Good tests assert public accepted/rejected invocations, typed values, statuses, hook effects, exported metadata, or shell-observed candidates. Do not couple acceptance to private helper names, table layouts, ownership maps, or one preferred internal refactor. Fixture snapshots and script syntax checks complement semantic tests but cannot prove candidate validity or runtime isolation alone.

Keep the established formatting, analyzer, full test suite, measurable coverage, compiling/executing documentation examples, regenerated-fixture freshness, documentation tests/build, Bash runtime, and shell syntax gates. Record actual commands, counts, versions, and skips after implementation. Do not reuse review-baseline results as proof that fixes pass.

The original reproductions are historical evidence. Promote them with the selected contracts: whitespace rejection and control-swallowing expectations change; explicit negative-name precedence becomes a declaration error; shared completion-command reuse is rejected rather than redesigned for invocation-scoped reuse. Unchanged delimiter and group-local controls remain regression checks.

## Out of Scope

- Framework implementation in this specification-writing session, release version selection, version bumps, commits, tagging, or publication.
- A wholesale declaration hierarchy rewrite, removal of unrelated public prompting/styling/YAML exports, or unrelated application tooling changes.
- Unbounded ordinary repeated positionals, conventional positional continuation after the delimiter, a new positional escape mechanism, or unknown-option fallback to positional values. Dash-leading filename documentation may explain the existing relative-path workaround.
- No-equals attached short values, mixed short bundles with separate values, optional option values, or implicit-value option declarations.
- Typed trailing handles, revised trailing cardinalities, or a renamed Variadic API.
- Duration, Uri, filesystem path, and DateTime declarations in this milestone. They remain selected for a later separately specified milestone; their syntax, outputs, and metadata are not decided here.
- Numeric positional families, application-defined codecs, arbitrary domain identifier conversion, declaration-local alias maps, or implicit enum member-name aliases for adopting enums.
- Exactly-one flag groups, directed dependencies, effective-value conditional requirements, generalized relationship APIs, propagated option groups, grouped/standalone replacement, or a new typed group-member handle API.
- Public explicit-supply queries, environment/config provenance, or framework-managed CLI/environment/config precedence.
- Framework-defined command I/O services, automatic interception/capture of command effects, streamed/binary I/O infrastructure, a domain dependency container, or replacement of the existing buffered hook-input model.
- Normal nonzero completion results, catch-all conversion of Errors into CLI failures, or guaranteed hook unwinding after Errors. The owner guard must still always be released.
- Dynamic declaration-level completion providers, complete shell-side relationship enforcement, or new functional runtime infrastructure for every shell.
- A new numeric enumeration cap or a claim that arbitrarily large stepped-double materialization is safe.
- Temporary compatibility parser modes or blanket permission for unrelated breaking changes.

## Further Notes

### Authority, publication, and delivery

This is the synthesized specification for the confirmed first milestone, published in the repository's local Markdown issue tracker. The `ready-for-agent` label records specification completeness, not authorization to implement in this session.

The baseline review covered commit `bf2bb12`, package `0.16.0`; it is not an exhaustive bug inventory. The [review](review.md) and [design interview](design.md) retain the original findings and Q1–Q50 decisions. Use the root [domain glossary](../../CONTEXT.md) and [ADRs](../../docs/adr/) for canonical language and architectural rationale. Later confirmed answers refine earlier chronological pending notes.

The existing twelve numbered issues remain the delivery breakdown; do not create a duplicate combined ticket:

1. [Syntax-owned values and equals-attached shorts](issues/01-syntax-owned-values-and-equals-shorts.md)
2. [Finite positional allocation](issues/02-finite-positional-allocation.md)
3. [Effective scope and compatible overrides](issues/03-effective-scope-and-compatible-overrides.md)
4. [Total typed-value storage](issues/04-total-typed-value-storage.md)
5. [Explicit and inherited conflicts](issues/05-explicit-and-inherited-conflicts.md)
6. [Numeric declaration validity](issues/06-numeric-declaration-validity.md)
7. [MambaEnumValue](issues/07-mamba-enum-value.md)
8. [Configured Executor ownership](issues/08-configured-executor-ownership.md)
9. [Faithful registry and accessor metadata](issues/09-faithful-registry-and-accessor-metadata.md)
10. [Accepted static completion candidates](issues/10-accepted-static-completion-candidates.md)
11. [PowerShell artifact isolation](issues/11-powershell-artifact-isolation.md)
12. [Migration and milestone verification](issues/12-migration-and-milestone-verification.md)

### Review disposition

| Review finding | Selected disposition | Delivery |
| --- | --- | --- |
| Defect 1: empty default omits non-null list | Fix accepted empty-list storage | 04 |
| Additional nested accessor container probe | Fix every known non-null container handle | 04 |
| Defect 2: effective inherited long collision | Reject invalid spellings; support compatible override lineage | 03, 04 |
| Defect 3: PowerShell state leakage | Fix injective encoding and add real runtime regression | 11 |
| Defect 4: inert numeric step/non-finite defaults | Reject invalid declarations before execution | 06, 08 |
| Defect 5: rejected small decimal candidates | Fix shared candidate interpretation; cap risk remains deferred | 10 |
| Defect 6: reused completion command metadata mutation | Reject cross-owner reuse atomically, rather than support invocation-scoped reuse | 08 |
| Defect 7: required accessor metadata lost | Preserve requiredness and mandatory Carapace representation | 09 |
| Defect 8: hidden accessor leaves advertised | Preserve visibility through nested flattening | 09 |
| Conflict/default policy probe | Adopt explicit-occurrence semantics and identity-based inherited edges | 05 |
| Tension A: lossy definition-once metadata | Preserve supported information; retain best-effort shell enforcement | 09, 12 |
| Tension B: closed values, enum names, heterogeneous maps | Add opt-in enum spellings; defer built-ins and retain group-map trade-off | 07, 12 |
| Tension C: argv whitespace and regex-owned syntax | Broaden unconstrained strings; separate ownership from content validation | 01 |
| Tension D: repeated positionals and delimiter channel | Reserve mandatory suffixes; retain separate raw trailing channel | 02, 12 |
| Tension E: local/propagated scope and ancestor reads | Retain local applicability; include group in propagation; preserve compatible handles | 03, 04 |
| Tension F: context and execution capabilities | Share retained scalar context per owner; keep dependencies/effects application-owned | 08, 12 |
| Tension G: contradictory prose | Reconcile numeric/default contracts and publish migrations | 06, 12 |
| Duplicated token interpretation | Align existing ownership consumers without a mandated wholesale rewrite | 01 |
| Lossy internal metadata representation | Preserve the required public information; internal representation remains flexible | 09 |
| Combinatorial declaration hierarchy | Preserve output guarantees; no hierarchy-wide refactor | Out of scope |
| Mutable framework metadata | Enforce configured ownership and isolation | 08 |
| Broad third-party public reexports | Keep untouched in this milestone | Out of scope |

Conventional commands, aliases, global inputs, counts, repeated named options, fixed positionals, and paired/selected value-option groups remain supported. Bounded sources/destination grammars and cross-scope conflicts improve under the approved semantics. Other expressiveness gaps retain their explicit deferred or application-owned disposition.

### Change-specific migration requirements

Each behavior-changing issue supplies an individual rationale, before/after examples, and author action. Consolidate these in current public documentation and changelog/migration guidance; preserve historical review artifacts and regenerate completion fixtures through the existing tooling.

| Change | Author action |
| --- | --- |
| Unconstrained strings and syntax-owned supply | Add an explicit validator when empty/whitespace content is unwanted; supply dash-leading option text inline. |
| Required-suffix reservation | Stop using validator rejection to delimit repeated operands; use the declared finite layout or a separate argument channel. |
| Propagation includes the declaring group | Audit group-level invocation and default behavior now accepting/validating the shared declaration. |
| Effective/generated spelling collisions | Rename conflicting inputs or disable negation; use only compatible shapes for intended overrides. |
| Accessor structural compatibility | Explicitly preserve ancestor paths; do not expect implicit deep merging. |
| Explicit/inherited conflicts | Defaults no longer activate syntax conflicts; application code remains responsible for effective-value rules. |
| Eager ownership and canonical placement | Create fresh command objects for different configurations/paths; expect declaration errors at configuration construction. |
| Owner-wide retained context and overlap rejection | Await sequential calls; use fresh configurations for parallel work; account for state shared across adapters. |
| Numeric declaration validity | Supply finite ordered bounds for stepped doubles and valid finite defaults. |
| Opt-in enum values and duplicate rejection | Implement the interface only when adopting new spelling; update callers to explicit values and remove duplicate offered choices. |
| Metadata/artifact corrections | Adapt public record construction if necessary; regenerate and reinstall completion artifacts. |

Defaults remain usable with flags/options; public prose must not claim they apply only to empty argv. Help must accurately advertise controls at each scope. Documentation must not overstate automatic effects capture, arbitrary declarative relationships, nonzero normal completion, or full shell equivalence.

The milestone is complete only after implementation separately receives authorization, all numbered issues meet acceptance, migrations are published, and actual verification evidence is recorded. Writing this spec does not fix framework behavior or imply the full test suite has run.
