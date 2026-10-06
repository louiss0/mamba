# 02 — Finite positional allocation reserves required suffixes

Status: ready-for-agent
Type: task
Depends on: 01

Planning authorization only. Source: [spec section 2](../spec.md), design Q7–Q8, Q28, Q39, ADR-0006.

## Outcome

Keep finite repeated positionals but reserve following required operands instead of using content validation to discover a boundary.

## Work

Inspect `lib/parser.dart` `_parsePositionals`, registry cardinality interpretation, argument docs, and positional completion consumers. For each repeated declaration, allocate up to its capacity while reserving the minimum supply for all following mandatory declarations. Each mandatory scalar or repeated declaration requires at least one token. Validate only after assigning ownership; invalid content belongs to the selected declaration and cannot move to another positional.

## Acceptance

- Sources with `times: 3` followed by one mandatory destination parse `copy a.txt out/` as `[a.txt]` and `out/`.
- `copy a.txt b.txt c.txt out/` fills the capacity and retains destination; a destination-only invocation fails required sources rather than returning an empty required list.
- Multiple finite repeats reserve all following mandatory minima; capacity is a maximum, not exact required length. Cover insufficient supply and leftover tokens.
- A rejected assigned source is reported for sources, not retried as destination. Changing a validator does not change allocation boundaries.
- Discretionary positionals retain declaration-order allocation without reserving optional/defaulted tokens as mandatory supply.
- Ordinary positionals never consume the post-`--` list. A lone dash retains existing operand behavior; other dash-leading operands remain outside this milestone.
- Existing positive-capacity/default-capacity validation remains. Completion metadata conveys supported finite cardinality, with shell allocation enforcement limits honestly documented.

## Migration

Replace validator-delimited examples and expectations with finite layout rules. Tell authors to use a separate trailing channel or repeated named options for unbounded lists. Do not add conventional positional continuation after `--`, a compatibility parser mode, or unbounded repetition.

## Verification

Add focused Parser/fake tests to `test/parser_test.dart` and execution tests where relevant. The empty-default storage regression belongs to issue 04; this issue must not reject an otherwise valid empty discretionary default to avoid that fix.
