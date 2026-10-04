# Completion artifacts: scoped lookup, collision-free identifiers, valid candidates

Type: task
Status: resolved
Closes: F2, F3, F4.

Three defects survive because the suite asserts on generated *text* rather than on generated
*artifacts*. Every fix here needs an oracle stronger than a string fragment: a script the shell
accepts, and candidates the declaration accepts.

## Work

1. **Scoped command lookup (F2).** `ToPowerShellCompletionConverter._native` emits one global
   name-and-alias hashtable although command names are scoped to their parent. A tree with
   `admin status` and `server status` generates duplicate `'status'` keys, and PowerShell's
   parser rejects the file with `DuplicateKeyInHashLiteral`. Look up within the command's scope.
2. **Collision-free identifiers (F3).** Generated identifiers replace hyphens with underscores
   and join path segments with underscores, so `foo-bar` and `foo_bar` collapse. Encode
   identifiers independently of user spellings and encode path boundaries unambiguously.
3. **Candidates the declaration accepts (F4).** `_steppedDoubleValues` rounds the increment
   count and forces the final candidate to `max`, offering `1.0` for `step: 0.3` while the parser
   rejects it. Derive finite candidates from the same interpretation the parser uses, so every
   candidate validates and no valid increment through the upper bound is dropped. Cover uneven
   endpoints and floating-point precision boundaries.

## Acceptance

- Generate a script for sibling groups with identically named children and parse it with
  PowerShell's parser; it parses. Aliases reused in separate scopes are covered too.
- Complete a command whose names differ only by separators (`foo-bar` vs `foo_bar`) and get that
  command's own flags. Nested paths whose flattened identifiers could collide are covered.
- Assert that every finite candidate a generator emits for a numeric declaration satisfies the
  parser's validation of that declaration, and that `DoubleOption('ratio', min: 0, max: 1,
  step: 0.3)` offers values the parser accepts.
- Regenerate `fixtures/rig/completions/{rig.bash,rig.fish,rig.ps1}` after the identifier change.
  Treat the regenerated files as a checked artifact, not a blind snapshot: each new assertion
  must fail against the pre-fix output.
- Runtime completion checks belong in ticket 06's CI-only tier; the parse checks run locally.

## Resolution

Shipped in `c0dfb5f fix(integrations): make every completion artifact stand on its own`.

- The global command-name table is gone. Each scoped child entry carries
  `Canonical`, so an alias resolves without a name shared across the tree.
- `_generatedIdentifier` escapes `_`, `-`, and `.`, shared by the Bash and Zsh
  converters instead of two copies. `foo-bar` and `foo_bar` get different
  variables, and path boundaries survive flattening.
- `_steppedDoubleValues` stops at the last value the step reaches inside the
  bounds.

The oracles are stronger than text fragments now: a PowerShell parse of a
generated script and of the checked-in `rig.ps1`, and a Bash candidate list that
is fed back through `Parser` so every offered value must validate. Both skip
where no PowerShell exists. `fixtures/rig/completions/*` were regenerated.

The scope cases are all asserted: two groups owning `status`, the same alias
under both, `foo-bar` beside `foo_bar`, and nested paths (`a-b/c` beside
`a/b-c`) that flatten to the same words. Stepped candidates are checked against
the parser for an uneven step over `0..1` and for a precision-boundary step over
`0..0.3`, where the sum lands just past the bound and must still be offered.

## Comments