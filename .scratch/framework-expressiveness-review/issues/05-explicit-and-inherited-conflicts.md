# 05 — Explicit-occurrence conflicts and inherited declaration edges

Status: ready-for-agent
Type: task
Depends on: 01, 03, 04

Planning authorization only. Source: [spec section 4](../spec.md), design Q4, Q20, Q26, Q32; ADR-0004 and ADR-0010.

## Outcome

Evaluate syntax conflicts using explicit CLI supply, with applicable input references and identity-preserving inherited edges.

## Work

Inspect registry conflict-name validation, effective lineage, parser occurrence collection, defaults/order of validation, and registry-record serialization. Retain private occurrence data independently of parsed values; metadata preservation is completed in issue 09.

## Acceptance

- Defaulted output plus explicit `--replace` succeeds; `--replace --output=text` conflicts even though text equals the default.
- Explicit `--no-cache` counts as occurrence even when false. Unsupplied boolean/count/defaulted values do not count; repeated input occurrences preserve correct conflict behavior without a public count API.
- Conflict references accept applicable ordinary global, propagated, local, grouped-member, and supported dotted-leaf names. Invalid/nonapplicable names are declaration errors; reserved controls are outside ordinary relationships.
- Parent edges remain active where both endpoint identities remain applicable, including compatible overrides. Edges involving unavailable parent-local endpoints are inactive in children.
- An unrelated same-name child declaration does not resurrect an inactive edge. Test mixed propagation, multiple levels, overrides, and default-selected commands.
- Effective inherited edges survive registry conversion for help/completion consumers; do not discard them merely because shells cannot enforce them.
- Required/defaulted reads still satisfy their types; conflicts do not depend on the order defaults are inserted for different input kinds.
- Keep `contains` stored-value semantics and occurrence tracking internal. Preserve paired/selected groups, with no flag groups, directional dependencies, effective-value rules, or public provenance API.

## Migration and verification

Promote the default-conflict probe with the adopted expectation. Test global references, explicit negative flags, accessor leaves, local endpoint loss, and unrelated-name nonreactivation through normal fake executions and registry tests. Document that effective-value constraints remain application logic and inherited edges may now reject explicitly conflicting combinations previously accepted.
