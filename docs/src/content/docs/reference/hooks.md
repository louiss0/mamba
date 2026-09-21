---
title: Hooks
description: Run lifecycle behavior around Mamba commands
---

Hooks receive the same `ParsedInputs` as the selected command, so they can
read retained input handles through `inputs.valueOf`. Context is passed to
hook methods as a separate argument; it is not part of `ParsedInputs` and
is not available to `Command.run`.

## Command hooks

Mix `HookRunner` into a command to run behavior immediately before and after
its `run` method:

```dart
final class DeployCommand extends Command with HookRunner {
  @override
  String get name => 'deploy';

  @override
  String get shortDescription => 'Deploy the application.';

  @override
  FutureOr<void> preRun(
    ParsedInputs inputs,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  FutureOr<void> postRun(
    ParsedInputs inputs,
    MambaReadContext context,
  ) {}

  @override
  String run(ParsedInputs inputs, List<String> args) => 'Deployed.';
}
```

Ordinary command hooks receive a read-only `MambaReadContext`. `preRun` also
receives piped standard input when available. `postRun` runs only when the
matching pre-hook completed. Eligible cleanup hooks still run after command
failure. Pass `standardInput` to `Executor.fake()` to supply this value in a
test.

## Persistent group hooks

Mix `PersistentHookRunner` into a `GroupCommand` to wrap descendant command
execution:

```dart
final class WorkspaceCommand extends GroupCommand
    with PersistentHookRunner {
  new() : super([DeployCommand()]);

  @override
  String get name => 'workspace';

  @override
  String get shortDescription => 'Manage the workspace.';

  @override
  FutureOr<void> prePersistentRun(
    ParsedInputs inputs,
    MambaContext context,
  ) {}

  @override
  FutureOr<void> postPersistentRun(
    ParsedInputs inputs,
    MambaContext context,
  ) {}
}
```

Persistent hooks receive the mutable `MambaContext`. Persistent pre-hooks run
from the outermost group inward. Their matching post-hooks run in reverse
order, so nested groups behave like wrappers.

## Context

`MambaContext` is an executor-scoped, identity-keyed scalar hook-state bag.
Use one `MambaContextKey<T>` instance wherever a value is written or read. The
key's primitive type determines which sealed wrapper can be stored, while
`get` returns that primitive directly:

```dart
final workspaceKey = MambaContextKey<String>();
final verboseKey = MambaContextKey<bool>();
final retryKey = MambaContextKey<int>();

context.set(workspaceKey, const MambaContextString('/workspace'));
context.set(verboseKey, const MambaContextBool(true));
context.set(retryKey, const MambaContextInt(3));
final String? workspace = context.get(workspaceKey);
final bool? verbose = context.get(verboseKey);
final int? retries = context.get(retryKey);
```

`MambaContextDouble` stores a `double` in the same way. Only the four built-in
variants (`String`, `bool`, `int`, and `double`) are supported; applications
cannot define additional variants. An unset key returns `null`, but `null`
cannot be stored. Collections and domain objects are not supported, because
context is not a dependency container. A reused executor retains its context
between executions. Create a separate executor when state must be isolated.
Applications remain responsible for reading environment variables or
configuration files.

## Failures

Mamba records hook failures as `MambaExecutionError` values tagged with their
execution phase and command path. One failing cleanup hook does not prevent
remaining eligible cleanup hooks from running. The first failure determines
the execution result's exit code.
