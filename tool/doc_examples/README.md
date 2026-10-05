# Dart documentation examples

Run `dart run tool/check_examples.dart` from the repository root. CI runs the
same command on every push and pull request.

Each `.dart.template` is a library with explicit context for the examples it
contains. `{{README.md#2}}`, for example, inserts the second Dart fence in the
README verbatim. Numbering is per document and counts only Dart fences, not
shell or text fences. References use repository-relative paths with `/`.

Every Dart fence in the README, `docs/`, and `skills/` must be referenced, and
every reference must resolve. There is no exemption list. Dependencies,
generated site output, and symlinks are excluded from document discovery.
Adding or removing a fence requires updating its context references.

Supply only what the prose leaves implicit: imports, an enclosing function or
class, earlier examples, and application-owned classes. Mamba types and APIs
must come from the real package. Reuse another generated library or reference
another fence rather than copying its implementation into a template.
`support.dart.template` contains the small application fixtures shared by
several pages.

The checker generates a uniquely named temporary directory in the repository,
so analysis sees the package configuration without ignoring the sources as it
would under `.dart_tool/`. It analyzes and kernel-compiles every generated
library, including production entry points and non-executable method/type
examples. Unused declarations and imports are allowed because the fragments
intentionally focus on just one API; compiler errors still fail the check.

Templates named `*_test.dart.template` are then executed with `dart test`.
Place documented assertions in these templates, with real executor results
rather than hand-built success/failure fixtures. Declaration-only examples may
remain compile-only; behavioral claims such as repeated cardinality and
selected-group requiredness have executable tests alongside them.

The checker removes its own workspace in `finally`, on success and failure.
It neither overwrites `example_check/` nor creates a reusable generated cache.
