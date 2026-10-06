# 12 — Migration documentation and milestone verification

Status: ready-for-agent
Type: task
Depends on: 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11

Planning authorization only. Source: [complete spec](../spec.md), design Q1/Q19/Q21/Q49/Q50 and review tensions A–G.

## Outcome

Deliver a coherent, honestly bounded contract with individual breaking-change migrations and reproducible verification evidence. No release publication is included.

## Work

Update relevant README/reference/options/arguments/executor/hooks/architecture prose, compile-tested examples, and changelog/migration guidance. Preserve the historical review and interview as evidence, but make current public docs describe the effective spec rather than stale behavior or unaccepted recommendations. Regenerate completion fixtures using `tool/regenerate_fixtures.dart`.

## Acceptance

- Reconcile default-command docs: defaults remain usable with flags/options; root/group/default-chain behavior and explicit help scope match the established contract. No prose says a default only applies to empty argv.
- Explain new equals short forms and MambaEnumValue with compiling enum `implements` examples. Document absence of implicit aliases and exact strings/duplicate validation.
- Include before/after/action guidance for string supply/validation, required-suffix allocation, propagation, invalid collisions/structural overrides, explicit inherited conflicts, eager ownership, context/overlap, numerics, and regenerated metadata/artifacts. Justify each breaking behavior individually.
- Explicitly retain the separate raw trailing channel, finite repetition, group-local applicability, closed value family, existing relationships/aggregate maps, application-owned effects/mocks, exception-driven statuses, and Exception-only hook cleanup.
- Domain built-ins, optional values, dynamic providers, new provenance/codecs/relationship types, unbounded positionals, Error cleanup, and a new enumeration cap remain deferred. Unrelated public dependency reexports remain untouched.
- Every review finding has its adopted/intentional/deferred disposition; old review controls that now intentionally change are not promoted unchanged. Completion-command reuse tests expect rejection, not an unselected invocation-scoped redesign.
- Formatting/analyzer/full tests/measurable coverage/example execution/fixture freshness/docs tests and build pass. Existing shell matrix remains and the real PowerShell isolation gate runs. Report actual versions, commands, results, and skips.
- State separately what was executed locally and what CI verified; no shell runtime claims from syntax snapshots. Keep the large double-enumeration risk visible.

## Completion evidence

Use the repository's `.github/workflows/verify.yml` as the verification baseline. Capture test counts and relevant shell results after implementation, not from the review snapshot. Confirm all issues meet acceptance and no unauthorized extensions slipped in. Version selection, tag creation, pub.dev publication, and any release wizard are separate explicitly authorized work.
