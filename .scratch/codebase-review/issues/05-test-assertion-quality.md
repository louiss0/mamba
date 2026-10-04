# Test assertions that can pass without proving anything

Type: task
Status: resolved
Closes: T1, T3, T4, T5.

Several tests pass while asserting less than their names promise, and the coverage number
conceals it. Fix the assertions rather than adding lines.

## Work

1. **T5** — `mamba_cli_test.dart:1003` greps formatter stdout for `Changed` lines without
   checking the subprocess exit status. A formatter that fails with no such lines reads as "all
   formatted". Validate the result and surface stderr before interpreting the output. Separate
   format checks from compilation and execution checks in the generated project's test suite so
   a failure names the stage that failed.
2. **T3** — `command_test.dart:269`, "writes … completions to the global path", only checks that a
   callback received an empty string. Rename it to describe callback behavior, then add separate
   tests for the default destination and for a missing-path rejection.
3. **T4** — the generated starter suite only requests help and asserts `MambaSuccessResult`. It
   can pass without running the command. Generate a real invocation with observable output, plus
   one rejection case, and say plainly in the generated guidance that the smoke test is a floor.
   The invocation must also respect ticket 02's rule that a command path never begins with the
   application name.
4. **T1** — add the cross-component invariants the review lists as explicit assertions: the
   resolved command path identifies the command that actually runs; an invalid declaration is
   rejected at every registration scope; equivalent option spellings parse equivalently; a finite
   completion candidate satisfies the declaration's validation; distinct accepted command paths
   stay distinct in generated artifacts.

## Acceptance

- The formatter test fails when the formatter exits non-zero without printing `Changed`.
- The renamed callback test's name matches what it asserts, and destination behavior has its own
   coverage.
- A generated project's smoke test fails when the command does not run.
- Each new T1 assertion is shown to fail against the pre-fix implementation.

## Resolution

Shipped in `4c96845 test(mamba): check what the tests actually promise`.

- T5: the format check asserts `dart format`'s exit status is 0 or 1 and
  reports stderr otherwise, so a formatter that fails quietly no longer reads as
  "everything is formatted".
- T3: the completion callback test is named for what it asserts and now checks
  that generated content arrives alongside the empty path; the default writer's
  rejection of a missing destination has its own test.
- T4: the generated suite gains a rejection case and a comment saying it is a
  floor, and the scaffold test asserts both.
- T1: every invariant on the list is now asserted by the ticket 01-03 tests —
  the resolved path names the command that ran, invalid declarations fail at
  every scope, equivalent spellings parse equivalently, a finite candidate
  validates, and distinct names keep distinct artifacts.

## Comments