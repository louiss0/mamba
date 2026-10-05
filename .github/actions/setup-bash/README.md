# Set up supported Bash

This local composite action selects Bash 4 or newer and fails if that
requirement cannot be verified. The minimum is fixed; there is no input to
allow an unsupported version or bypass the check.

Use it after checkout and before steps that run Bash or Bash completion tests:

```yaml
- uses: actions/checkout@v5
- uses: ./.github/actions/setup-bash
- run: bash --version
```

On macOS it installs Homebrew Bash and prepends `$(brew --prefix bash)/bin`
to the path of subsequent steps through `GITHUB_PATH`. It does not replace
`/bin/bash`. On Linux it verifies the Bash already on `PATH`.

Bootstrapping and preflight use POSIX `sh`, so they do not depend on the
unsupported system Bash's extended features. Preflight probes the `bash` that
subsequent commands and Dart subprocesses will resolve from `PATH`, rejects
missing/unreadable/older versions, and prints the selected path and version.
Installation or verification failures fail the job.

`verify.yml` uses this action in Linux jobs and the Linux/macOS shell matrix.
Windows retains PowerShell verification; its shell job does not run Bash
completion tests. The completion suite also verifies Bash independently so
calling it directly on CI cannot silently skip an unsupported version.
Local completion tests still opt out when `CI` is unset; that is not a
version-based skip.

Regression tests: `dart test test/bash_policy_test.dart`. Controlled native
executables stand in for Bash at the process boundary; actual completions are
also driven on the supported Bash installed on the test machine. Windows
policy tests use Git for Windows' Bash to run the POSIX preflight.
