# Resolving the framework review

Source: [review.md](review.md). Current baseline: `bf2bb12`.

This document records the design interview. Q50 confirms shared understanding and authorizes [spec.md](spec.md) and separately numbered implementation issues, not framework implementation or release actions. Entries are chronological: later answers settle or refine pending points in earlier entries. The spec consolidates the effective first-milestone contract; framework code remains unchanged.

## Settled decisions

### Q1 — Compatibility

The user permits individually justified breaking changes to the public API and documented argument grammar. Evaluate each change explicitly, document its migration, and preserve existing behavior where it remains coherent. This is not approval for a wholesale rewrite or for any particular semantic change.

### Q2 — Framework boundary

The user chose a general-purpose CLI core. Administrative command trees, filters, and process wrappers should be expressible without bypassing the parsing and fake-execution model. Grammar, typed inputs, relationships, and testable invocation I/O/status are core responsibilities. Business services, configuration-file formats, and terminal UI remain application responsibilities. This settles the target, not the individual API designs.

See [ADR-0002](../../docs/adr/0002-general-purpose-cli-core-boundary.md).

### Q3 — Delimiter semantics

The user chose to retain the separate trailing-argument list after the first `--`. Those tokens do not satisfy ordinary positional declarations. This deliberately differs from conventional positional continuation after option termination. Dash-leading positional support, typed trailing declarations, and wrapper behavior remain separate open questions; the general-purpose target does not silently override this decision.

See [ADR-0003](../../docs/adr/0003-separate-trailing-arguments.md).

### Q4 — Conflict presence

Syntax conflicts apply to explicit CLI occurrences, not defaults or resolved values. `--replace` is valid when `output` merely has a declaration default; `--replace --output=text` is a conflict. Effective-value conditions are a separate mechanism. This settles the previously ambiguous policy and requires preserving occurrence information independently of defaulted parsed values.

See [ADR-0004](../../docs/adr/0004-explicit-occurrences-for-syntax-conflicts.md).

### Q5 — Unconstrained strings

The user chose to accept any supplied string when no validator is configured, including whitespace-containing and empty strings. Requiredness concerns supply, not nonempty content; authors may explicitly validate content. The token-ownership policy is not settled by admitting a broader value domain and is the next dependent decision.

### Q6 — Token ownership

The user chose to reject a missing separate-form string value when the next token looks like a named input. `run --label --help` reports a missing value; `--label=--help` supplies literal text. Numeric declarations retain signed-number handling. Token ownership is determined by syntax independently of a value validator.

Q5 and Q6 are recorded together in [ADR-0005](../../docs/adr/0005-token-ownership-and-string-values.md).

### Q7 — Ordinary positional repetition stays finite

The user chose to keep finite repeated positionals only. `times` remains a finite maximum; unbounded lists use another channel, such as separate trailing arguments or repeated named options. This does not yet decide allocation between a finite repeated positional and a following required operand, nor whether value validation may determine the boundary.

### Q8 — Finite repeated allocation reserves required suffixes

The user chose to reserve following required operands before collecting a finite repeated positional. With sources capped at 3 and one required destination, `copy a.txt out/` yields sources `[a.txt]` and destination `out/`. Validation checks assigned values and does not transfer rejected values to another positional. Q7 and Q8 together replace the current validator-delimited allocation contract while keeping finite capacities.

See [ADR-0006](../../docs/adr/0006-finite-repetition-and-required-suffixes.md).

### Q9 — Closed value family with selected domain built-ins

The user chose selected framework-provided domain value types rather than application-defined converters or primitive-only outputs. The public declaration value family remains closed. Arbitrary domain conversion remains application-owned; the exact built-in set and each type's syntax/metadata contracts are not yet selected.

See [ADR-0007](../../docs/adr/0007-closed-value-family-with-domain-built-ins.md).

### Q10 — Built-in domain types in scope

The user selected all four proposed types: Duration, Uri, filesystem path, and DateTime. This selects the type scope only. Duration syntax/precision, URI acceptance policy, path representation/filesystem checks, timestamp formats/timezones, availability across declaration shapes, defaults, and metadata contracts remain open.

### Q11 — Cross-kind collisions are invalid

The user chose to reject a collision between an applicable propagated flag and a local option, or the reverse. Every effective spelling must have one owner. Same-kind override behavior is provisional until output compatibility and ancestor retained-handle semantics are settled.

### Q12 — Compatible overrides preserve retained-handle reads

The user chose same-kind overrides with identical output type and cardinality. Ancestor and descendant retained handles both read the effective descendant value, with the descendant's validation/default rules applied. Flag/option cross-kind replacement stays invalid under Q11. Accessor-tree structural compatibility and grouped-input cases still need specification rather than an assumption that map output types alone establish compatibility.

See [ADR-0008](../../docs/adr/0008-compatible-overrides-and-stable-handles.md).

### Q13 — Propagation includes the declaring group

The user chose to change propagated inputs to apply to the declaring group and all descendants, rather than add a separate whole-subtree scope. Local inputs remain local. This intentionally replaces the existing descendant-only definition and requires migration notes for the group-level behavior change.

See [ADR-0009](../../docs/adr/0009-propagation-includes-declaring-group.md).

### Q14 — Existing relationship vocabulary remains the boundary

The user chose current conflicts and paired/selected value-option groups only, not generalized relationship rules or additional specialized relationship families. Exactly-one flag groups, directed dependencies, and effective-value conditional requirements remain application logic. Documentation must limit automatic metadata claims to the supported declarations; the heterogeneous aggregate-map trade-off is retained rather than silently replaced with a new relationship API.

See [ADR-0010](../../docs/adr/0010-existing-relationship-vocabulary.md).

### Q15 — Nonzero statuses remain exception-driven

The user chose to retain success=0 and exception-driven nonzero statuses. An expected application outcome such as no matches with code 1 remains represented as a failure exception, not a distinct normal completion result. This narrows Q2's proposed normal-nonzero-status capability; the general-purpose target must not be described as eliminating that application adaptation.

See [ADR-0011](../../docs/adr/0011-exception-driven-nonzero-statuses.md).

### Q16 — Command I/O and mocks are application-owned

The user clarified that the fake executor must not know about or automatically capture command-owned I/O, then chose application-owned injected services and mocks rather than Mamba-defined I/O interfaces. The fake drives parsing, hooks, and command execution and returns a result; application tests verify their mocks separately. Mamba retains its own production process adapter and returned-text/error delivery. Streaming capability through application services is not a core automatic-capture requirement, refining Q2 and the review's I/O criticism.

See [ADR-0012](../../docs/adr/0012-application-owned-command-io.md).

### Q17 — Command instances have one executor owner

The user chose to bind each command instance to one executor and reject reuse by a different owner, rather than support reuse through invocation-scoped metadata. Authors create fresh command instances for different executors; typed input declaration handles are not thereby restricted to one executor. The identity of that owner (configured Executor versus each fake/create adapter) is still to be settled.

### Q18 — The configured Executor owns command instances

The user chose the configured Executor composition root as the owner. Multiple fake/create adapters from that same configuration are allowed; a different configured Executor must use fresh command instances. Ownership does not imply thread safety, automatic mocking, or a restriction on sharing immutable typed declaration handles. Failure timing, duplicate placement within one tree, and simultaneous execution remain to be specified where relevant to the delivery slice.

See [ADR-0013](../../docs/adr/0013-command-instances-have-one-executor-owner.md).

### Q19 — First milestone: defects and settled core semantics

The user chose a first milestone containing reproduced defects plus approved core semantic corrections. Duration, Uri, filesystem paths, and DateTime remain selected for a later separately specified milestone; their open per-type questions do not block this slice. Remaining core acceptance details must be settled before writing agent-ready issues or requesting implementation approval.

### Q20 — Conflicts may reference applicable ordinary inputs

The user chose to allow an existing command conflict to refer to any applicable ordinary named input, including global and propagated inputs. Reserved help/version control paths remain outside ordinary conflict validation. This changes conflict-name validation, not the relationship vocabulary; parent-rule inheritance is not implied by expanding which names a selected command may reference.

### Q21 — Faithful metadata with best-effort shell enforcement

The user chose to preserve supported declaration metadata in registry records and guarantee accepted finite value candidates, visibility, and artifact isolation, while allowing documented shell-side relationship enforcement limits. Supported conflicts and default dispatch must not be silently discarded merely because converters do not fully enforce them. This retains ADR-0001's best-effort enforcement boundary while strengthening metadata fidelity; it does not authorize five independent full parsers.

### Q22 — Generated and explicit spelling collisions are invalid

The user chose to reject generated/explicit spelling collisions, including negatable `cache` plus an explicit boolean `no-cache`, rather than keep explicit precedence. Effective spelling validation includes generated negative spellings as well as primary names and shorts. The prior precedence test becomes a migration/regression case: rename the explicit flag or make `cache` non-negatable.

### Q23 — No new numeric enumeration cap in this milestone

The user chose to fix decimal candidate validity without introducing a new shared/configurable enumeration cap. The existing PowerShell integer cap remains unchanged. Arbitrarily large stepped-range materialization remains an explicitly deferred inspection risk; tests must not claim that this milestone resolves it.

### Q24 — One command instance occupies one canonical path

The user chose to reject duplicate placement of one command object within the same configured executor. Fresh instances of the same class may occupy different paths; aliases of one node and sharing immutable input declaration handles remain valid. This closes the same-tree metadata/path ambiguity left by the one-configuration ownership rule.

### Additional confirmed fact — Nested accessor handles

A normal parse of an omitted optional nested accessor tree stores the root map but omits the known, non-null nested container handle. The focused probe printed `Root handle: {auth: {}}` and then threw `StateError: Bad state: Parser omitted a non-null input value.` when reading the nested `auth` handle. See `nested_accessor_reproduction.dart`. This is an additional instance of the typed non-null storage defect, not a reason to widen the relationship vocabulary or I/O scope.

### Q25 — Accessor compatibility preserves ancestor paths

The user chose accessor overrides that explicitly preserve every ancestor container/leaf path with compatible kind, output type, and cardinality, while allowing added local fields. This is structural compatibility, not automatic deep merging; omitted or retyped ancestor paths are invalid. Compatible retained ancestor container/leaf handles read the effective local values under local defaults/validation, extending Q12's stable-handle contract to accessor trees.

### Q26 — Conflicts inherit with their referenced declarations

The user chose inherited conflict edges wherever both referenced declarations remain applicable, including compatible overrides. Edges involving unavailable parent-local declarations are inactive for that descendant. An unrelated same-name child declaration must not reactivate the edge. This extends existing conflict scope without adding new relationship kinds or a separate propagated-conflict API.

### Q27 — Local inputs apply only to the selected command

The user chose to keep selected-command applicability. A group's local inputs are invalid when a child is selected, even if supplied before the child token. Authors use propagated inputs for settings shared by a group and its descendants; this milestone does not introduce per-scope parsing or parent-only parsed values.

### Q28 — Dash-leading ordinary positional support is deferred

The user chose to retain the current limitation for this milestone. Dash-leading tokens other than a lone `-` remain named-input syntax, and unknown inputs are not reassigned to ordinary positionals. The separate trailing channel remains unchanged. Documentation should explain the limitation and the `./-report.txt` workaround for filenames; a general positional escape mechanism is deferred.

### Q29 — Equals-attached short values are requested

The user explicitly wants `-o=file` and `-vo=file` to work. This expands the first milestone to include equals-attached short option values and a flag prefix before the value-taking short. The exact bundle ownership contract and whether no-equals forms (`-ofile`, `-vo file`) are included remain open; neither is silently authorized by this answer.

### Q30 — Help/version keep the order-sensitive bypass

The user chose to preserve the existing control-path bypass: errors before help/version still fail, ordinary tokens after a recognized control request are ignored, and required-input/relationship checks are bypassed. Q6 still applies: `--label --help` reports a missing label value. Command resolution and control detection must agree with token ownership, and registry/help/completion metadata must faithfully represent available controls.

### Q31 — Equals-attached shorts only

The user chose to add only equals-attached forms: `-o=file` and `-vo=file`, while retaining separate values for a lone short option (`-o file`) and flag-only bundles. A mixed equals bundle consists of a flag-only prefix followed by exactly one value-taking short, which owns everything after the first `=`; `-vo=` supplies an empty value subject to validation, and `-v=file` is invalid when `v` is a flag. No-equals attached text (`-ofile`, `-vofile`) and mixed bundles with a separate value (`-vo file`) remain unsupported. Dispatch, parsing, control detection, and completion must share this ownership contract.

### Q32 — Explicit-occurrence tracking stays internal

The user chose internal occurrence tracking for framework conflicts, not a new public provenance query. `ParsedInputs.contains` retains its stored-value meaning; the milestone does not add `wasProvided` or an environment/config origin model. Explicit negation remains an explicit occurrence regardless of its resolved false value.

### Q33 — Eager, atomic command ownership

The user chose complete composition validation and ownership claiming at configured Executor construction. All command instances are claimed only after validation succeeds; a failed construction must neither reserve otherwise reusable commands nor mutate an existing owner's metadata. Duplicate placement and cross-owner reuse fail before adapter creation, while multiple adapters from the same owner remain valid.

### Q34 — Reject overlapping invocations per owner

The user chose to reject a second in-flight invocation across all adapters belonging to one configured Executor. Sequential reuse remains valid. Rejection occurs without entering the second invocation's hooks or command, and the owner guard must be released even when the first invocation throws. The failure representation remains to be specified; parallel application execution requires fresh command instances in separate configurations.

### Q35 — One retained hook context per configured Executor

The user chose one retained scalar hook context shared by all adapters from a configured Executor. Sequential invocations retain state regardless of which adapter they use; an explicitly injected context remains that same object. This corrects the current default adapter-local allocation to match the documented executor-scoped concept. Context does not become a domain dependency container or a command-I/O boundary.

### Q36 — Overlap rejection is a StateError

The user chose `StateError` for rejected overlapping invocation. The second execute Future fails without a Mamba failure result, execution phase, or CLI-status mapping. This is application orchestration misuse; the first invocation continues unaffected, and the owner guard must still be released on every exit.

### Q37 — Preserve Exception-only hook cleanup

The user chose to retain the current lifecycle boundary. Successfully completed pre-hooks earn corresponding post-hooks; caught Exceptions trigger cleanup, persistent post-hooks run in reverse order, and the first failure determines the returned exit code. A Dart Error escapes without guaranteed remaining post-hooks. The owner overlap guard must nevertheless always be released; broader Error-unwinding is deferred.

### Q38 — Grouped members cannot replace standalone inputs

The user chose to reject a paired/selected member colliding with an applicable standalone input, even when scalar output types match. Compatible overrides remain within standalone declaration families or structurally compatible accessor trees. This milestone does not propagate option groups or adapt ancestor standalone handles to local grouped-member values; grouped effective spellings must remain unique.

### Q39 — Preserve raw trailing arguments and Variadic validation

The user chose to retain the current raw trailing contract. Commands receive the immutable post-`--` string list; absent a Variadic declaration it is unrestricted, NormalVariadic optionally validates each string, and ChoiceVariadic validates at most one enum-name string without returning a typed enum handle. Q5's unconstrained-string policy applies where relevant. Typed trailing handles, new trailing cardinalities, and Variadic API renaming are excluded from this milestone. Q40's requested enum-value spelling mechanism may refine choice trailing validation if included; its contract is not yet settled.

### Q40 — Requested MambaEnumValue contract

Instead of deferring independent choice spellings, the user proposed `MambaEnumValue`: enums supply values which the parser checks instead of member names. The user described enums extending a class; Dart enum implementation constraints and the precise public contract need clarification. Value representation, ordinary-enum compatibility, duplicate/alias policy, consumer consistency, and milestone inclusion remain open.

### Q41 — Optional option values are deferred

The user chose to defer an optional-value/implicit-value declaration mode. Every occurrence of a current value-taking option must supply a value; declaration optionality does not make its supplied occurrence's value optional.

### Q42 — Dynamic completion providers are deferred

The user chose to defer declaration-level live completion providers. This milestone fixes static candidates, faithful supported metadata, visibility, and artifact isolation under Q21. Existing shell fallbacks are not described as framework-declared typed completion providers.

### Q43 — MambaEnumValue is a String-valued interface

The user chose `abstract interface class MambaEnumValue { String get value; }`, implemented by enum declarations rather than extended. A local SDK probe confirmed that enum implementation compiles and supplies `json-lines`, while `enum ... extends ...` is rejected. The string is the CLI spelling; typed choice parsing still returns the actual enum member, not the string or an arbitrary stringified object.

### Q44 — Opt-in enum values, ordinary-enum fallback

The user chose to preserve Enum.name spelling for ordinary enums. Enums implementing MambaEnumValue use their explicit string values instead; member names are not implicit aliases. This preserves existing enums and choice declaration shapes while providing independent spelling for adopting enums.

### Q45 — MambaEnumValue belongs to the first milestone

The user chose to include this bounded enum-spelling addition in the first milestone alongside equals-attached shorts. It must be consistent across choice declarations, explicit/default validation, registry records, help, completions, and ChoiceVariadic validation while preserving typed enum outputs and Q39's raw trailing result contract. The other selected domain built-ins and deferred extensions remain out of scope. Exact spelling validity and ambiguity rules still need settlement.

### Q46 — Choice spellings are arbitrary exact strings

The user chose to allow any exact, case-sensitive String as a MambaEnumValue choice spelling, including empty, whitespace-containing, and dash-leading strings. There is no trimming, normalization, or declaration-name grammar restriction. Dash-leading named-option values follow Q6's inline-supply rule. Help and completion must preserve spellings faithfully; raw trailing choice validation uses the same spelling contract.

### Q47 — Offered choices must have unique spellings

The user chose registration-time duplicate rejection within each declaration's offered choices, including duplicate entries of the same enum member. Exact-string comparison preserves case distinctions. A declaration may offer an enum subset; unoffered enum members are not inspected or rejected merely because their values collide elsewhere. First-match ambiguity is invalid.

### Q48 — Validate the entire control-bearing short token

The user chose to validate every short and the attached value within a help/version-bearing bundle before bypassing later ordinary tokens. An unknown short or invalid attached value in that token fails. Equals-attached values such as `-o=--help` and `-o=h` never become control requests. This extends Q30's existing intra-bundle validation without granting help/version unconditional precedence over malformed syntax.

### Q49 — Targeted real PowerShell runtime regression

The user chose to retain the existing CI matrix and add real PowerShell completion-state isolation regression coverage on Windows, covering Windows PowerShell 5.1 and pwsh where available. Shared candidate validity, visibility, and metadata invariants must be tested across converters. This does not promise newly added functional runtime infrastructure for every shell; existing Bash runtime coverage and generated-script syntax checks remain, with shell enforcement limits documented.

### Q50 — Shared understanding confirmed; specification and issues authorized

The user confirmed the consolidated first-milestone contract and authorized writing the implementation spec and separately numbered agent-ready issues. Each review finding must be classified as a fix, intentional behavior, or deferral; breaking changes require individual rationale and migration guidance. This authorizes planning artifacts only, not implementation, a version bump, tagging, or publication. Release scheduling/version selection belongs to a separate release task.

## Design tree

- Compatibility: settled (Q1).
- Framework responsibility and target CLI patterns: settled (Q2).
  - Grammar: separate post-`--` trailing channel settled (Q3), syntax-owned named-input values settled (Q6); ordinary positional repetition stays finite (Q7); finite repetition reserves required suffixes without validator-based reassignment (Q8); dash-leading ordinary operands are deferred (Q28); local-input parsing retains selected-command applicability (Q27); equals-attached short values and flag-prefix bundles are selected, with no-equals attached/mixed forms excluded (Q29, Q31); the help/version bypass is retained (Q30). Raw trailing passthrough and existing Variadic validation are retained (Q39); typed trailing declarations and new cardinalities are excluded, and optional option values are deferred (Q41). Whole-token validation applies to control-bearing short bundles (Q48), while later ordinary tokens retain Q30's bypass.
  - Typed inputs: unconstrained strings accept any supplied string (Q5); the value family stays closed with selected domain built-ins (Q9); Duration, Uri, filesystem paths, and DateTime are in scope (Q10); per-type contracts and declaration-shape availability are deferred with domain built-ins. MambaEnumValue is a selected String-valued interface with ordinary-enum fallback and no implicit member-name aliases (Q43–Q45); arbitrary exact case-sensitive strings are permitted (Q46), and duplicate offered spellings are invalid (Q47). Existing required/optional/defaulted typed guarantees must be preserved.
  - Relationships: explicit CLI occurrence semantics for syntax conflicts settled (Q4); the existing paired/selected value-option groups are retained and new relationship kinds are out of scope (Q14); conflicts may reference applicable ordinary inputs (Q20), and inherit with applicable declaration identities rather than unrelated same-name declarations (Q26). Explicit-occurrence tracking stays internal and `contains` retains stored-value semantics (Q32).
  - Scope: cross-kind flag/option collisions are invalid (Q11); same-kind output-compatible overrides preserve ancestor handle reads (Q12); propagation covers the declaring group and descendants (Q13); accessor overrides explicitly preserve all ancestor node paths/types and may add fields (Q25); local-input parsing retains selected-command applicability (Q27), and conflict edges inherit with their referenced applicable declarations (Q26). Grouped/standalone replacement is invalid and group propagation is excluded (Q38).
  - Invocation: nonzero statuses stay exception-driven (Q15); command I/O services/mocks are application-owned and not intercepted by the fake (Q16); command instances have one executor owner (Q17); the configured Executor is the owner and may create multiple adapters (Q18); eager atomic ownership enforcement is settled (Q33), and overlapping invocations are rejected per configured owner (Q34). Overlap raises StateError (Q36), retained scalar hook context belongs to the configured Executor (Q35), and Exception-only hook cleanup is retained (Q37); domain dependencies remain application-owned.
  - Registry consumers: metadata fidelity and best-effort enforcement settled (Q21); hidden/required accessor metadata and control availability must be faithful. Dynamic providers are deferred (Q42). Verification retains the existing matrix and adds targeted PowerShell runtime regression coverage (Q49).
- Delivery: first milestone is defects plus settled core semantics (Q19), extended with equals-attached shorts (Q31) and MambaEnumValue (Q45); Duration, Uri, filesystem path, and DateTime are explicitly deferred. The selected contracts define core acceptance and verification. Change-specific migrations, review disposition, and separately numbered issues are required. Shared understanding and planning-artifact creation are confirmed (Q50); implementation and release actions remain unauthorized.

## Documentation discipline

- Confirmed project vocabulary belongs in root `CONTEXT.md`, using its glossary format.
- Consequential architectural choices belong in sequential `docs/adr/` documents when they record a real trade-off.
- Unresolved proposals stay here, not in the glossary or an accepted ADR.
- Implementation specs and separately numbered issues will be written after the relevant contracts are settled.
