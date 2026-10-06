# 07 — Opt-in MambaEnumValue choice spellings

Status: ready-for-agent
Type: task
Depends on: 01

Planning authorization only. Source: [spec section 6](../spec.md), design Q40, Q43–Q47, ADR-0015.

## Outcome

Expose `abstract interface class MambaEnumValue { String get value; }` through the normal public API and use enum-owned CLI spellings without weakening typed outputs.

## Work

Enums implement the interface. Keep current enum-constrained choice declarations; add one shared spelling interpretation: interface implementers use value, others use Enum.name. Apply it consistently in registry validation, parser matching/default validation/diagnostics, help, registry records, static converter input, and ChoiceVariadic. Completion escaping and candidate-level tests continue in issue 10.

## Acceptance

- An enum member `jsonLines('json-lines')` parses from `json-lines` and returns the same enum member. Its name `jsonLines` is not an implicit alias when the two differ.
- Ordinary enums such as ShellCompletion retain name-based behavior. Public imports and documentation examples compile using `implements`, not invalid enum inheritance.
- Cover scalar, required/optional/defaulted, repeated, grouped, positional, accessor, and trailing choice shapes where currently supported. Do not create unsupported declaration families.
- Defaults stay typed, must belong to offered choices, and use the same representation in metadata/help. Trailing ChoiceVariadic stays at most one raw string, using the shared spelling for validation.
- Any exact case-sensitive String is a legal spelling, including empty, whitespace, dash-leading strings, quotes, and metacharacters. Do not trim, case-fold, stringify arbitrary objects, or apply command-name grammar.
- Reject duplicate offered spellings and repeated choice entries at registration. A narrowed choice subset remains valid when only unoffered members collide. Distinct case-sensitive spellings remain distinct.
- Preserve all required/optional/defaulted output types and immutability; no map-based aliases or custom codec hook.

## Migration and verification

Explain opt-in spelling change and caller updates; existing nonadopting enums need no migration. Add compile/type tests plus exhaustive consumer matrices in existing suites. Issue 09 preserves metadata and issue 10 proves artifact escaping/candidate validity. All three are needed before calling the feature complete.
