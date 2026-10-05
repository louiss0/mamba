# Compile every Dart documentation example

Type: task
Status: resolved

## Work

Finish the other half of "Do both please then commit": check every Dart fence
in README.md, docs/ and skills/. Contextual fragments must receive real
supporting context, not be exempted. Execute documented assertions and gate the
check in CI.

The user confirmed test seams at `CommandRegistry.toRecord()` and the example
checker's command-line boundary.

## Resolution

`dart run tool/check_examples.dart` inventories all Markdown/MDX Dart fences,
including tilde fences and CRLF files. Explicit `.dart.template` files under
`tool/doc_examples/` insert original fences by document and Dart-block ordinal.
New fences without context and stale references fail. The checker analyzes and
kernel-compiles every library together, then executes the example test
libraries. It creates a unique workspace outside `.dart_tool/` and removes only
that workspace in `finally`.

The abandoned fragment exemption list and `example_check/` scratch directory
were removed. The Verify workflow now runs the checker on every push/PR.

Compilation/execution exposed documentation defects that are now corrected:

- the zero-argument Executor call;
- unsupported CompletionCommand constructor inputs;
- missing HelpFormatter implementations and incorrect `implements` guidance;
- incomplete concrete command skeletons and missing statement terminators;
- a nonexistent ChoiceVariadic default parameter;
- multiword messages rejected by the default string pattern;
- a parse-failure assertion using the wrong exit code;
- scope and positive-cardinality prose remaining in skill references;
- an accessor conflict that incorrectly targeted a required leaf.

Verification: all 105 Dart fences compile, and all 42 example tests pass with
no exemptions. The checker has eight command-line regression tests: success
with explicit context, broken API, incorrect assertion, missing context, stale
reference, discovery outside site content, tilde/CRLF fences, and empty
inventory. Red runs demonstrated the original exemption checker failing the
success contract and demonstrated the narrower discovery/fence bugs before
fixes. The first real all-examples run also failed on the documented API drift.

Final package verification: 448 tests passed, three CI-only shell tests skipped,
2,901/2,901 measurable library lines covered. Documentation tests: 20 passed;
site build succeeded with existing bundle/sitemap/404 warnings. No remote CI
run is claimed for these unpushed follow-up commits.

## Comments
