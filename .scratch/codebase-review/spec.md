# Address CODEBASE_REVIEW.md

Close the confirmed findings in `CODEBASE_REVIEW.md` and correct the documentation that
contradicts them. Findings are regrouped by the component that owns the fix rather than by the
review's recommended work order, because several findings turn out to have the same owner once
the boundaries are settled.

## Scope

In scope: findings `F1`–`F7`, `D1`–`D8`, `T1`–`T6`, and the vocabulary corrections that are not
deferred. Out of scope: everything `CODE_REVIEW.md` already resolved — diff the two reviews before
starting and drop anything already fixed.

## Settled decisions

| Decision | Resolution |
| --- | --- |
| Ownership | The registry decides whether any declaration is legal, including reserved spellings, effective inherited/local spellings, and declared counts and capacities. The executor resolves command paths and renders control output. |
| Reserved spellings | Help and version only (`--help`, `-h`, `--version`, `-V`). Opt-in built-ins (`--dry-run`, `-v`, `-V` when verbose is enabled) are ordinary declarations. A declaration colliding with a reserved spelling is rejected at registration. |
| Command paths | A path never begins with the application name. No implicit prefix stripping. An invocation that repeats the application name is rejected with a hint stating the rule. |
| Integers | Signed decimal in every spelling. One scanner, one value parser, one rule. |
| Counts and capacities | Zero is never a legal declared count or capacity, anywhere. |
| Completions | Every finite candidate satisfies the declaration's own validation; generated identifiers are independent of user spellings. |
| Output fidelity | Exact bytes on both stdout and stderr. `MambaSuccessResult.output` is what the process writes. |
| Renames | `CommandRegistry.toMap()` becomes `toRecord()` now. The `Accessor flags` help heading and the propagated/inherited/published/persistent synonym cluster are deferred (ticket 07). |
| Versioning | Unreleased working-tree changes. No version bump, no changelog entry, no deprecation window. A `toMap()` alias is not kept. |

## Tickets

| # | Owner | Closes |
| --- | --- | --- |
| 01 | Registry — declaration validity | F5, F6, F7, `toRecord()` rename |
| 02 | Executor — dispatch and process output | F1, D6 |
| 03 | Integrations — completion artifacts | F2, F3, F4 |
| 04 | Docs — claims that contradict behavior | D1, D2, D4, D5, D7, D8, D3 |
| 05 | Tests — assertion quality and templates | T1, T3, T4, T5 |
| 06 | CI — push/PR verification | T6, T2 runtime completion |
| 07 | Deferred — renames and vocabulary | Vocabulary table, `persistentFlags` collision |

## Verification

| Check | Result |
| --- | --- |
| `dart analyze --fatal-infos` | No issues found |
| `dart test` | 402 passed, 2 skipped (the CI-only shell tier) |
| `pnpm --dir docs test` | 20 passed |
| `dart format --output=none --set-exit-if-changed .` | Clean |

Not verifiable on this machine: no `bash`, `zsh`, or `fish`, so the CI-only
runtime completion tier and the zsh and fish parse steps are written but
unobserved. PowerShell 5.1 is present, and the PowerShell parse check ran and
reproduced F2 before the fix.

## Out of scope

Raising line coverage toward 100%. The review is explicit that cross-component contracts matter
more, and no ticket here is justified by a coverage percentage.

## Notes

The domain model moved with these decisions: `CONTEXT.md` gained *declaration validity*,
*reserved spelling*, *propagated input*, *accessor option*, and *completion candidate*, and
*command path* now excludes the application name. ADR-0001 carries the amendment.

A two-axis review of the branch (`05cef54...HEAD`) found no standards violations and five
unasserted regression cases. All five are now covered: UTF-8 output and multiple errors in the
process suite, aliases reused across scopes, nested identifier collisions, and a
precision-boundary step in the completion suite, and the integer syntax across repeatable,
paired, and accessor inputs. Shell detection moved into `test/shell_support.dart` so the two
suites cannot disagree about what is installed.