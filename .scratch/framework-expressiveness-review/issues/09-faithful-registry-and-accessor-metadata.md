# 09 — Faithful registry records, accessor metadata, and controls

Status: ready-for-agent
Type: task
Depends on: 03, 05, 07

Planning authorization only. Source: [spec section 8](../spec.md), review defects 7–8/tension A, design Q20–Q21/Q49, ADR-0001.

## Outcome

Preserve supported declarations through registry records and integration flattening rather than relying on contradictory shell-specific reconstruction.

## Work

Inspect `lib/registry.dart` RegistryRecord/RegistryAccessorValue/toRecord, help formatting, and `lib/integrations.dart` accessor flattening/Carapace/control metadata. Add or refine metadata while preserving coherent existing manually built-record behavior. Document any necessary record-shape migrations.

## Acceptance

- Effective inherited conflicts and root/group default paths survive records. Canonical paths/aliases follow the registry's dispatch authority, not a separate guessed route.
- Accessor leaves retain independent requiredness/default/choice information. Required host emits Carapace `--config.host!=`, optional host remains optional, and required selected groups do not make every member mandatory.
- Hidden accessor roots or nested containers make all descendant advertised leaves hidden. Help and every static completion consumer honor inherited visibility; hidden is not a security boundary.
- Every scope's help/completion metadata faithfully represents help/version accepted at that scope. Remove contradictory independently invented availability while retaining reserved controls and explicit-scope help.
- New MambaEnumValue spellings remain exact in records; no regression to Enum.name on accessors, groups, repeats, or defaults.
- Supported paired/selected metadata stays intact. Shell inability to enforce relationships does not justify discarding conflicts/defaults/requiredness. Do not implement five independent parsers.
- Tests verify records and generated outputs, not merely snapshots. Preserve/document best-effort shell enforcement limits and manual-record compatibility.

## Migration and verification

Promote the accessor requiredness/hidden probes into normal registry/help/integration tests and add deep hidden containers, optional/defaulted leaves, selected groups, inherited conflicts, and default routes. Document metadata fields and any constructor changes, regenerate fixtures through the repository tool, and explain reinstalling artifacts. Numeric candidate correctness is issue 10 and PowerShell runtime isolation is issue 11.
