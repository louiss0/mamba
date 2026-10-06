# 06 — Numeric declaration validity and default invariants

Status: ready-for-agent
Type: task
Depends on: none

Planning authorization only. Source: [spec section 5](../spec.md), review defect 4, registry-owned validity in ADR-0001.

## Outcome

Reject malformed numeric declarations rather than silently ignoring constraints or delivering non-finite defaults.

## Work

Inspect `lib/registry.dart` numeric traversal, `lib/src/input_validation.dart`, numeric declarations in `lib/command.dart`, and parser value checks. Share existing range/step semantics for defaults and explicit values. Issue 08 makes these failures eager for configured Executors.

## Acceptance

- A DoubleOption step requires both finite ordered bounds. `DoubleOption('ratio', step: 0.25)` is invalid, not an unconstrained parse accepting 0.3.
- Reject NaN/infinite double defaults, bounds, and steps; steps must be finite and positive. Test NaN, both infinities, zero/negative steps, one missing bound, inverted bounds, and valid negative ranges.
- Defaults obey supported numeric syntax-domain, range, step alignment, and repeated capacity rules. An out-of-range/off-step default fails declaration validity just like an explicit value fails content validation.
- Traverse all supported local/propagated/grouped/repeated/accessor numeric shapes, recursively for accessors. Do not accidentally omit validation when a declaration is not an ordinary scalar option.
- Preserve signed-decimal explicit syntax and existing shared step tolerance/origin behavior. Do not admit exponent notation/NaN/infinity to rescue completion output.
- Valid declarations/defaults continue to deliver their original statically promised output types. No new numeric positional or custom conversion family.

## Tests and migration

Promote the missing-bound and NaN probes. Add constructor/registry/Parser parity cases to normal suites, with failures at the declared validation boundary. Document finite bounds for stepped doubles and replacement of invalid defaults. Enumeration precision/caps are issue 10; do not mix a new cap into this issue.
