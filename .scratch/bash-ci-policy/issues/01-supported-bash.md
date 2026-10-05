# Require supported Bash in CI

Type: task
Status: resolved

## Work

Create `.github/actions/setup-bash`, wire it into Verify's non-Windows jobs,
and remove Bash-version/missing-shell skips from the completion suite.
Use real process-boundary regression tests and retain the local-only CI opt-out
as explicitly confirmed by the user.

## Acceptance

- The action accepts Bash 4 and newer, and rejects unsupported or unverifiable
  Bash with a failing exit code.
- macOS selects Homebrew Bash for subsequent steps and Dart subprocesses.
- The completion suite returns failure rather than skip on CI when Bash is
  older, missing, unreadable, or cannot execute its version probe.
- All three runtime completion tests execute on supported Linux and macOS Bash.
- Formatting, analysis, package tests, example checks and coverage stay green.

## Resolution

Implemented in `c06edaf`. Verify run `37389052631` is green across all six
jobs. Its logs show macOS selecting
`/opt/homebrew/opt/bash/bin/bash` (Bash 5.3.15), and Linux selecting
`/usr/bin/bash` (Bash 5.2.21). Both runtime-completion steps execute the three
named tests and report `+3: All tests passed!`, without skipped tests.

All 11 policy regressions pass, including minimum/newer versions and
older/missing/unreadable/failed probes. Local verification passed formatting,
fatal-info analysis, 459 package tests (three local CI opt-outs),
2,901/2,901 measurable library lines, 105 compiled examples with 42 tests,
and the documentation tests/build. CI confirms the coverage gate and example
checker also pass on Linux. No remaining acceptance gaps.

## Comments
