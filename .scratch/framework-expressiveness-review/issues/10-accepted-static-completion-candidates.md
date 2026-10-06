# 10 — Static completion candidates satisfy their declarations

Status: ready-for-agent
Type: task
Depends on: 01, 02, 06, 07, 09

Planning authorization only. Source: [spec sections 5–6/8](../spec.md), review defect 5, design Q21/Q23/Q46/Q49, ADR-0001.

## Outcome

Generate valid finite numeric and choice candidates without decimal rounding collapse or lossy spelling/escaping.

## Work

Inspect shared stepped-double enumeration/formatting and Bash/Zsh/Fish/PowerShell/Carapace conversion. Reuse declaration validation as the candidate oracle. Keep explicit decimal syntax; fix formatting rather than weakening parsing to accept scientific notation.

## Acceptance

- The finite range `[1e-7, 3e-7]` stepped by `1e-7` produces valid distinct in-range candidates, not repeated `0.0`. Each emitted value parses under its declaration.
- Test negative/fractional/small bounds, exponent-form double.toString inputs, non-exact endpoints such as step 0.3 over 0–1, and declared defaults. Do not emit an endpoint that violates the step.
- All converters share the valid candidate interpretation. Test literal candidate values after shell decoding, not only raw escaped script fragments.
- Enum candidates use selected spellings exactly, including empty, whitespace-containing, quoted, metacharacter, and dash-leading strings. Preserve actual enum outputs when candidates are supplied through the declaration's supported inline/separate syntax.
- Ordinary enum candidates remain unchanged. Hidden spellings stay unadvertised; metadata requirements from issue 09 are not lost while formatting.
- Keep existing Bash real-runtime tests and add relevant supported syntax/choice cases where needed. Other shell artifact/invariant tests do not count as full runtime coverage.
- No new shared/configurable enumeration cap; existing PowerShell integer cap stays. Explicitly retain the large stepped-double materialization risk rather than claiming a performance fix.

## Tests and migration

Promote the small-decimal probe into normal tests and run parser-backed finite candidate matrices across converters. Update snapshots only after semantic assertions pass; regenerate fixtures through the existing tool. Document that regenerated candidates now obey declarations and describe known shell enforcement/runtime limits.
