# 03 — Effective scope, spelling ownership, and compatible overrides

Status: ready-for-agent
Type: task
Depends on: none

Planning authorization only. Source: [spec section 3](../spec.md), design Q11–Q13, Q22, Q25, Q27, Q38; ADR-0008 and ADR-0009.

## Outcome

Produce one effective owner per spelling, validate compatible override lineages, and include the declaring group in propagated scope.

## Work

Inspect `lib/registry.dart` applicable/published inputs, effective validation, accessor traversal, conflict lookup, and declaration output/cardinality metadata. Preserve a lineage of compatible overridden handles rather than reconstructing ancestry from names. Issue 04 consumes that lineage for retained reads; issue 05 consumes it for conflicts.

## Acceptance

- A propagated input applies to its group and every descendant; a local input never becomes applicable merely because it precedes a child token.
- Reject applicable flag/option collisions in both directions, incompatible standalone overrides, and paired/selected-member collisions with standalone inputs.
- Validate all effective primary longs, shorts, generated negative names, and dotted accessor paths. Negatable `cache` plus explicit `no-cache` is invalid; collision checks are order-independent and cover inherited/generated combinations.
- Compatible standalone overrides require identical kind, output type, and cardinality; the descendant's defaults/content rules are effective. Effective spelling checks do not retain shadowed ancestor aliases as separate owners.
- Accessor overrides explicitly preserve every ancestor container/leaf path with compatible kind/type/cardinality, may add fields, and reject omitted or retyped paths. There is no automatic deep merge.
- Carry sufficient identity/lineage information for ancestor root/container/leaf reads and inherited edges. An unrelated same-name declaration is not an override.
- Preserve reserved help/version protection and ordinary opt-in dry-run handling. Immutable handles may be shared without assigning them executor ownership.
- Traverse all descendant declarations; direct registry construction must still validate, while issue 08 makes configured Executor construction eager.

## Migration and tests

Promote the cross-kind probe, replace generated-negation precedence assertions with declaration-error tests, and add scope/override/structural matrices to registry tests. Document disabling negation or renaming collisions, auditing newly applicable group inputs, and explicitly preserving accessor paths. Group propagation and grouped/standalone adaptation are excluded.
