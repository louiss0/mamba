# Framework expressiveness: post-implementation review

Resolution: Both findings fixed in the working tree. The review below records the original `7ca6493` behavior; see the fix verification at the end.

## Scope

Reviewed `53c0880...7ca6493`: the domain/spec commit and the five subsequent implementation, test, fixture, example, and reference-documentation commits. The working tree was clean when review began. The baseline is the parent of `a4c2da2`, not the parent of the latest documentation-only commit.

Primary contract: [spec.md](spec.md), its numbered issues, root `CONTEXT.md`, relevant ADRs, and current public documentation. This report preserves the historical [review.md](review.md). No implementation changes were made.

## Standards

No separate coding-style violations or actionable baseline code-smell findings identified. Tool-enforced formatting/style observations are not counted as review findings. The declaration-validity documentation cited below is a behavioral contract, reported under Spec rather than counted twice.

## Spec

### 1. [P2] Reject equals attachment with an empty short name

**Location:** `lib/parser.dart:128-130` (short-token splitting and iteration).

`run -=oops` and `run -=` both return `MambaSuccessResult` and execute the command. Splitting the token at `=` produces an empty short-name string; `short.split('')` yields no letters, so the validation loop does nothing and its outer `continue` silently discards the token. This is not the supported empty *value* form `-o=`: no option owns the attachment.

**Contract:** spec, Grammar and token ownership: "Unknown shorts, value-taking prefix members, and attached values on flag-only bundles are invalid." [Issue 01](issues/01-syntax-owned-values-and-equals-shorts.md) and ADR-0014 require an actual final value-taking short before `=`.

**Impact:** a malformed option is silently ignored and ordinary command effects occur instead of returning a parse failure. This is introduced by the new equals-splitting path; the prior parser would reject the `=` as an unknown short.

**Suggested correction:** reject an empty short-name portion before iterating. Add public fake-execution regressions for both `-=` and `-=text`; retain acceptance of `-o=` when its declaration permits empty content.

### 2. [P2] Revalidate inherited conflicts against effective override requiredness

**Location:** `lib/registry.dart:332-348` (`_effectiveConflictEdges`); compare the required-endpoint checks at `350-389` (`_resolveConflicts`).

A group may declare defaulted non-null `output`, propagated `replace`, and a conflict between them. Its child may compatibly override `output` with `StringOption.required('output')`: both handles return `String`. The configured Executor accepts this composition and retains the conflict. However, no successful child invocation can ever supply `replace`: omitting `output` fails requiredness, and supplying it fails the inherited conflict.

The required-endpoint checks run only when resolving the group's original conflict declarations. The inherited-edge path substitutes descendant handles but does not validate the effective endpoints again.

**Contract:** the spec requires complete eager composition validation and inheritance through compatible overrides. Current `README.md:314-316` says: "Registry creation rejects a conflict between a required input and another input because the other input could never be supplied." `docs/src/content/docs/reference/commands.md:167-168` makes the same guarantee.

**Observed behavior:** construction succeeds; `scope run --output=x` succeeds; `scope run --replace` fails with `Option --output is required.`; `scope run --output=x --replace` fails with `Input --output conflicts with --replace.` The advertised flag is unusable in this child scope.

**Suggested correction:** apply required-endpoint validity checks to effective inherited edges after lineage resolution, including required accessor-leaf overrides. Keep defaulted endpoints legal and unavailable parent-local edges inactive. Assert the error at configured Executor construction, before ownership is claimed.

## Reproducible regression checks

Save the following as a temporary `review_regressions_test.dart` in the repository and run:

```powershell
dart test review_regressions_test.dart --reporter expanded
```

Both tests were run against `7ca6493` from an external temporary file and failed with the expected symptoms: the first received `MambaSuccessResult` instead of `MambaFailureResult`; the second returned an Executor instead of throwing `MambaRegistryError`.

```dart
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

final class Leaf extends Command {
  Leaf({super.options});
  @override
  String get name => 'run';
  @override
  String get shortDescription => 'Run.';
  @override
  String run(ParsedInputs inputs, List<String> args) => 'EXECUTED';
}

final class Scope extends GroupCommand {
  Scope(super.commands, {
    super.propagatedOptions,
    super.propagatedFlags,
    super.conflicts,
  });
  @override
  String get name => 'scope';
  @override
  String get shortDescription => 'Scope.';
}

void main() {
  test('rejects equals attachment without a short name', () async {
    final fake = Executor('app', 'App.', '1.0.0', [Leaf()]).fake();
    for (final token in ['-=oops', '-=']) {
      expect(await fake.execute(['run', token]), isA<MambaFailureResult>(),
          reason: token);
    }
  });

  test('revalidates inherited conflicts after a required override', () {
    expect(
      () => Executor('app', 'App.', '1.0.0', [
        Scope(
          [Leaf(options: [StringOption.required('output')])],
          propagatedOptions: [
            StringOption.withDefault('output', defaultValue: 'text'),
          ],
          propagatedFlags: [BooleanFlag('replace')],
          conflicts: {'output': ['replace']},
        ),
      ]),
      throwsA(isA<MambaRegistryError>()),
    );
  });
}
```

## Verification evidence

Environment: Windows, Dart SDK `3.13.2`.

- `dart analyze`: no issues.
- `dart test --reporter expanded`: **489 passed, 6 skipped**, no failures in the existing suite. The skips were the unavailable `pwsh` runtime and five CI-only Bash functional checks.
- `dart test test/completion_shell_test.dart --name PowerShell --reporter expanded`: **2 passed, 1 skipped**. Windows PowerShell literal-choice and artifact-isolation regressions executed successfully; `pwsh` was unavailable locally.
- `dart run tool/check_examples.dart`: **106 Dart examples** analyzed and compiled; **43 example tests** passed.
- The two targeted regression tests above: **2 failures**, confirming the findings despite the green existing suite. A separate public-execution probe also confirmed that both empty-short tokens execute the command and that the inherited-conflict child can never successfully supply `replace`.
- `git diff --check 53c0880...HEAD` reported trailing whitespace in historical review prose and `FINAL_SUMMARY.md`; not counted as a behavioral bug.

Coverage measurement, the documentation website build, non-Windows shell runtime checks, and remote CI results were not independently rerun for this review. Passing local tests do not establish those gates.

**Summary:** Standards: 0 separate findings. Spec: 2 confirmed P2 bugs at the reviewed baseline; the highest-impact finding was silent command execution after a malformed empty-short token.

## Fix verification

Both findings now have permanent public-boundary regressions in `test/executor_test.dart`. Each regression was observed failing before its implementation fix.

- `lib/parser.dart` rejects empty short names before dispatching an attached value. Tests cover `-=`, `-=oops`, an error preceding help, and absence of command execution; existing `-o=` acceptance remains green.
- `lib/registry.dart` validates required endpoints after resolving effective conflict edges, so both local and inherited edges use the same checks. Tests cover required source/target overrides, a nested accessor leaf across multiple scopes, and command reuse after failed ownership validation. Existing defaulted conflicts and inactive parent-local edges remain green.
- `dart analyze --fatal-infos`: no issues.
- Changed Dart files pass the formatter; `git diff --check` is clean.
- Full suite with coverage: **492 passed, 6 skipped**. Coverage formatting with `--check-ignore` reports **0 uncovered measurable lines** in `lib`.
- Documentation examples: **106 compiled**, **43 example tests passed**.
- Completion fixtures regenerated without a diff.

The six local skips remain the unavailable `pwsh` runtime and five CI-only Bash checks. These results were recorded before committing the fixes; no release was created.
