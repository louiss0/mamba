# Push/PR verification with a CI-only completion tier

Type: task
Status: resolved
Closes: T6, and the runtime half of T2.

The only checked-in workflow is tag-triggered publication, so ordinary changes get no
automated analysis, tests, or shell checks — which is also why the completion defects in tickets
02 and 03 could ship. Locally there is `powershell.exe` 5.1 and an unverified `bash` stub, and no
zsh, fish, or pwsh.

## Work

1. Add a push/PR workflow running `dart analyze --fatal-infos`, the full test suite, and the
   documentation build, uploading the LCOV report as an artifact.
2. Add a parse-check tier: `bash -n`, `zsh -n`, `fish --no-execute`, and PowerShell's
   `Parser.ParseFile` over generated scripts, on runners where those shells exist. Parse checks
   are the floor — they are hermetic and cheap, and they are what catches a
   `DuplicateKeyInHashLiteral`.
3. Add a CI-only test tier for real completion: source a generated script and drive an actual
   completion, asserting candidates for the collision and stepped-number cases from ticket 03.
   Gate it so `dart test` on a developer machine skips it, and have the workflow run that tier
   explicitly. Keep the local PowerShell parse check so the floor runs without CI.
4. Regenerate coverage in the workflow rather than asserting a percentage. No threshold gate:
   the review is explicit that cross-component contracts, not a number, are the investment.

## Acceptance

- A push that breaks analysis, a test, or any shell parse fails the workflow.
- The CI-only tier runs in the workflow and is skipped by a local `dart test`.
- A deliberately broken completion script (duplicate key, colliding identifier) fails the parse
  tier locally where the shell exists.

## Resolution

Shipped in `4c96845 test(mamba): check what the tests actually promise`.

`.github/workflows/verify.yml` runs on every push and pull request:

- `analyze-and-test` formats, analyzes, tests with coverage, and uploads the
  LCOV report. No threshold gate.
- `generated-artifacts` regenerates the checked-in completions and fails if the
  tree changed, so a stale artifact cannot ship.
- `shells` runs across Linux, Windows, and macOS. The per-shell parse checks
  (`bash -n`, `zsh -n`, `fish --no-execute`, PowerShell's parser) run where the
  shell exists, and the completion suite runs the generator's output for real.
- `docs` installs and tests and builds the site.

`test/completion_shell_test.dart` gates itself on `CI` and on bash being
present, so a developer machine skips it rather than passing it vacuously. It
asks `complete` for the handler name, so it does not encode the generator's
identifier scheme a second time.

**Unverified locally:** the CI-only tier and the zsh and fish parse steps cannot
run on this machine — there is no bash, zsh, or fish here. They are written to
run on the runners and have not yet been observed passing.

## Comments