# Bash 4+ CI without version-based skips

Require supported Bash in GitHub Actions rather than treating unsupported
runner versions as a reason to skip completion tests.

## Decisions

- A local reusable composite action has a fixed Bash 4 minimum.
- macOS installs Homebrew Bash and prepends its bin directory through
  GITHUB_PATH; Linux verifies its selected Bash.
- The action fails for missing, failed, unreadable or older Bash.
- The completion suite independently fails on the same unsupported conditions.
- No completion test is skipped because of a Bash version. The existing
  local-only `needs CI` opt-out and Windows PowerShell-only shell checks remain.
- Generated completions keep associative arrays and their unsupported-shell
  diagnostic guard. There is no Bash 3 compatibility implementation.

The user confirmed seams at the action's preflight command and the completion
suite command-line boundary, tested with controlled Bash executables.

## Verification

Regression tests exercise minimum/newer versions, older/missing/unreadable
versions, failed probes, and real supported-shell execution. The original
suite's Bash 3 behavior was demonstrated red: it returned exit code 0 with all
three tests skipped. The new policy must return a failing exit code with no
version-based skip. A second red run proved that an unsuccessful version probe
must not be trusted even if it prints a valid number.

Local verification passed: 11 policy regressions; 459 package tests with only
three local `needs CI` opt-outs; 2,901/2,901 measurable library lines covered;
105 documentation examples compile and 42 example tests pass; 20 docs tests
pass and the site builds. Formatting, fatal-info analysis and POSIX script
syntax checks are clean. The real supported-shell child suite runs all three
completion tests without skips on Git for Windows' Bash 5.2.

The user authorized committing, pushing to main, and watching CI. Actual
runner verification is now established by Verify run `37389052631` on
`c06edaf`: all six jobs passed. macOS selected Homebrew Bash 5.3.15 at
`/opt/homebrew/opt/bash/bin/bash`; Linux selected Bash 5.2.21 at
`/usr/bin/bash`. Both runtime completion steps executed all three named tests
and reported `+3: All tests passed!`, with no version-based skips. The
coverage gate and all-example checker also passed.

The local self-review found no outstanding standards or spec issues. The
fixed minimum is enforced in both action preflight and the suite; there is no
skip/continue-on-error escape hatch for an unsupported Bash. Bootstrap uses
POSIX sh, and shell-script LF line endings are enforced for Windows checkouts.
Windows PowerShell coverage and the confirmed local-only CI opt-out remain
unchanged.
