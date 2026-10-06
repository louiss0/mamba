# 08 — Configured Executor ownership, context, and overlap guard

Status: ready-for-agent
Type: task
Depends on: 03, 06

Planning authorization only. Source: [spec section 7](../spec.md), design Q17–Q18, Q24, Q33–Q37, ADR-0013; review defect 6.

## Outcome

Bind each command instance to one valid configured Executor and one path, prevent framework-metadata rebinding, and define sequential adapter reuse.

## Work

Inspect `lib/executor.dart` construction/_Execution/adapters, completion registry injection, GroupCommand help injection, and scalar context allocation. Fully validate the command tree/default paths before atomically claiming command identities or mutating metadata. Do not bind immutable input declarations to owners.

## Acceptance

- A second configured owner using an already-owned completion/group/ordinary command raises a declaration error at construction. The first owner's metadata/output remains unchanged.
- Duplicate object placement in one tree is invalid; fresh same-class instances are valid at different paths, node aliases are valid, and sharing immutable declaration handles remains valid.
- Failure due to an invalid descendant/default/spelling or a later ownership conflict claims no previously unowned commands. Test failed-tree rollback and prior-owner preservation.
- One valid owner may create multiple fake/create adapters without rejections or incorrect registry/help data. Repeated sequential invocation uses the same owner.
- Default scalar context is one retained bag per configured owner, visible across adapters. Explicitly injected context retains identity. No domain object container or framework I/O mocking.
- Use an owner-wide in-flight guard. Overlap, including reentrant execute from hooks and calls through different adapters, raises StateError before second hooks/run; do not queue or make a CLI result. First execution continues unaffected.
- Release the guard in all exits: success, parse failure, pre/run/post Exception, and escaping Error. Sequential execution after each remains usable.
- Preserve Exception-only hook cleanup, successful-pre pairing/reverse persistent cleanup, first-failure status, success=0, and application-owned effects. No Error-unwinding expansion.

## Migration and tests

Adapt the shared-completion probe to expect rejected reuse and verify the first owner still emits `first`. Add ownership/rollback/context/concurrency tests driven by controlled Futures, not timing sleeps. Document fresh instances, earlier validation timing, retained cross-adapter context, parallel configurations, and awaiting sequential execute calls.
