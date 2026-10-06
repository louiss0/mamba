# 11 — PowerShell artifact isolation and real runtime regression

Status: ready-for-agent
Type: task
Depends on: 09

Planning authorization only. Source: [spec section 8](../spec.md), review defect 3, `powershell_reproduction.dart`, design Q21/Q49, ADR-0001.

## Outcome

Distinct valid application and command names do not overwrite one another's generated PowerShell state/helper identifiers, including under its case-insensitive identifier namespace.

## Work

Replace lossy PascalCase namespace construction in `lib/integrations.dart` with an injective shell-safe encoding. Cover full scope/path components and generated helpers/variables, not just one top-level symbol. Preserve public executable names and registration; do not rename applications to work around generator bugs.

## Acceptance

- `foo-bar` and `foo_bar` have distinct generated namespaces. Include valid hyphen/underscore/digit and component-boundary cases; symbol uniqueness must survive PowerShell case-insensitive comparison.
- Source blue-only and red-only application scripts together and use CommandCompletion.CompleteInput to prove each executable retains its own candidates. Test both load orders and repeat sourcing; stale shared state cannot contaminate either application.
- Distinct command paths within an application remain separate. Keep unavoidable case-insensitive executable-name behavior documented instead of promising case-only executable registrations are independently addressable.
- Promote the temporary-file scratch harness into normal runtime tests, with cleanup, surfaced stderr, checked exit codes, and actual candidate assertions.
- Add a Windows CI runtime gate covering Windows PowerShell 5.1 and pwsh where available. Print tested versions. Required CI shells fail clearly when missing; unavailable local shells are explicit skips/unverified, not passes.
- Keep existing generated-script syntax checks and Bash runtime infrastructure. This does not authorize new Zsh/Fish/Carapace functional runtime infrastructure.

## Migration and verification

Explain regenerating and reinstalling affected completion scripts. Artifact-text uniqueness alone is insufficient: record real runtime proof after the fix. Preserve supported shell versions and use encoding consistent with identifier restrictions rather than string substitution that only handles this two-name example.
