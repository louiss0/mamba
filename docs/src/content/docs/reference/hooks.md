---
title: Hooks
description: Run lifecycle behavior around Mamba commands
---

Hooks receive the same `CommandInvocation` as the selected command. They can
read retained input handles through `invocation.valueOf` and access shared
state through `invocation.context`.

## Command hooks

Mix `HookRunner` into a command to run behavior immediately before and after
its `run` method:

```dart
final class DeployCommand extends Command with HookRunner {
  @override
  FutureOr<void> preRun(
    ProcessedStandardInput? input,
    CommandInvocation invocation,
  ) {}

  @override
  FutureOr<void> postRun(CommandInvocation invocation) {}
}
```

`preRun` receives piped standard input when available. `postRun` runs only when
the matching pre-hook completed. Eligible cleanup hooks still run after command
failure.

## Persistent group hooks

Mix `PersistentHookRunner` into a `GroupCommand` to wrap descendant command
execution:

```dart
final class WorkspaceCommand extends GroupCommand
    with PersistentHookRunner {
  WorkspaceCommand(super.commands) : super();

  @override
  FutureOr<void> prePersistentRun(CommandInvocation invocation) {}

  @override
  FutureOr<void> postPersistentRun(CommandInvocation invocation) {}
}
```

Persistent pre-hooks run from the outermost group inward. Their matching
post-hooks run in reverse order, so nested groups behave like wrappers.

## Failures

Mamba records hook failures as `MambaExecutionError` values tagged with their
execution phase and command path. One failing cleanup hook does not prevent
remaining eligible cleanup hooks from running. The first failure determines
the execution result's exit code.
