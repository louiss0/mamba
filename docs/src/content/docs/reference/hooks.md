---
title: Hooks
description: Run lifecycle behavior around Mamba commands
---

Hooks receive the same `CommandInvocation` as the selected command, so they can
read retained input handles through `invocation.valueOf`. Context is passed to
hook methods as a separate argument; it is not part of `CommandInvocation` and
is not available to `Command.run`.

## Command hooks

Mix `HookRunner` into a command to run behavior immediately before and after
its `run` method:

```dart
final class DeployCommand extends Command with HookRunner {
  @override
  FutureOr<void> preRun(
    CommandInvocation invocation,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  FutureOr<void> postRun(
    CommandInvocation invocation,
    MambaReadContext context,
  ) {}
}
```

Ordinary command hooks receive a read-only `MambaReadContext`. `preRun` also
receives piped standard input when available. `postRun` runs only when the
matching pre-hook completed. Eligible cleanup hooks still run after command
failure.

## Persistent group hooks

Mix `PersistentHookRunner` into a `GroupCommand` to wrap descendant command
execution:

```dart
final class WorkspaceCommand extends GroupCommand
    with PersistentHookRunner {
  WorkspaceCommand(super.commands) : super();

  @override
  FutureOr<void> prePersistentRun(
    CommandInvocation invocation,
    MambaContext context,
  ) {}

  @override
  FutureOr<void> postPersistentRun(
    CommandInvocation invocation,
    MambaContext context,
  ) {}
}
```

Persistent hooks receive the mutable `MambaContext`. Persistent pre-hooks run
from the outermost group inward. Their matching post-hooks run in reverse
order, so nested groups behave like wrappers.

## Context

`MambaContext` is an executor-scoped, identity-keyed map for state shared
between hooks. Use one `MambaContextKey<T>` instance wherever a value is written
or read:

```dart
final workspaceKey = MambaContextKey<String>();

context.set(workspaceKey, '/workspace');
final workspace = context.get(workspaceKey);
```

A reused executor retains its context between executions. Create a separate
executor when state must be isolated. Applications are responsible for reading
environment variables or configuration files and may place the resulting
domain state in context when hooks need it.

## Failures

Mamba records hook failures as `MambaExecutionError` values tagged with their
execution phase and command path. One failing cleanup hook does not prevent
remaining eligible cleanup hooks from running. The first failure determines
the execution result's exit code.
