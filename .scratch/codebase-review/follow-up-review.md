# Follow-up review

Baseline: `3369af2` (HEAD at the start of the resumed work).
Spec: tickets 08 and 09 and the recovered request "Do both please then commit".
Review scope: the combined staged/unstaged diff and new checker/templates.

This is a local self-review on the two prescribed axes. Parallel independent
sub-agent dispatch was unavailable in this session.

## Standards

No outstanding documented-standard violations. Formatting and fatal-info
analysis pass. Changes use typed registry records, public test boundaries,
concise constructors in new declarations, and explicit fixture context rather
than mocked framework APIs. Generated workspaces are unique and cleaned in
`finally`; document traversal does not follow symlinks or scan dependencies.

Possible duplication in template imports/enclosing functions is intentional:
each library represents a different reader context. Shared application fixtures
are in one support template; command implementations are extracted from the
actual docs, not copied into verification code.

## Spec

Both requested follow-ups are complete: selected groups retain required/single
metadata without over-requiring Carapace members, and every Dart example is
compiled with explicit context. Every documented assertion is executed. Missing
or stale context, compilation errors and runtime assertion failures fail CI.

The review corrected an overbroad ADR claim about shell languages: the actual
limitation is in current converters, not an inherent inability of those shells.
No shell-side exclusivity implementation, version bump, changelog change or
renaming work was added.

## Verification

- Formatting clean; fatal-info analysis clean.
- Package suite: 448 passed, three CI-only completion tests skipped locally.
- Measurable library coverage: 2,901/2,901, zero uncovered lines.
- Documentation checker: 105 fences compile, 42 example tests pass.
- Documentation site: 20 tests pass; production build succeeds.
- Integration suite: 19 tests pass, including local PowerShell parse checks.
- Regenerated completion artifacts match the checked-in fixtures.

No outstanding findings on either axis. No remote CI result is asserted.
