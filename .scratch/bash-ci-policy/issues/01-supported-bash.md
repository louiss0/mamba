# Require supported Bash in CI

Type: task
Status: claimed

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

## Comments
