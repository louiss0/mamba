---
title: Hooks
description: Run lifecycle behavior around Mamba commands
---

Hooks receive the same invocation-bound `ValueOf` function as the selected
command, so they read retained input handles with `valueOf(handle)`. Context
is passed to hook methods as a separate argument; it is not part of the reader and
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
    ValueOf valueOf,
    MambaReadContext context,
    ProcessedStandardInput? input,
  ) {}

  @override
  FutureOr<void> postRun(
    ValueOf valueOf,
    MambaReadContext context,
  ) {}

  @override
  String run(ValueOf valueOf, List<String> args) => 'Deployed.';
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
    ValueOf valueOf,
    MambaContext context,
  ) {}

  @override
  FutureOr<void> postPersistentRun(
    ValueOf valueOf,
    MambaContext context,
  ) {}
}
```

Persistent hooks receive the mutable `MambaContext`. Every
`PersistentHookRunner` on the resolved command path participates, nested child
groups included, so `tool a b c` runs the hooks of both `a` and `b`. Persistent
pre-hooks run from the outermost group inward. Their matching post-hooks run in
reverse order, so nested groups behave like wrappers. A group that is not on
the resolved path contributes nothing, so a sibling group is never set up for
an unrelated command.

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

`MambaContextDouble` stores a `double` in the same way. A key's type argument
selects the variant, so only the four built-in types (`String`, `bool`, `int`,
and `double`) can be stored. `MambaContextValue` is sealed, so an application
cannot define a further variant and cannot store a domain object: context is
not a dependency container. A key typed `Object` matches none of the four and
therefore stores nothing. An unset key returns `null`, but `null` cannot be
stored.

`MambaReadContext` is the read-only view an ordinary `HookRunner` receives. It
exposes `get` and nothing else, and does not expose the instance it wraps, so a
subclass of `MambaContext` adds members that no command can reach. Subclassing
is otherwise transparent: the subclass inherits `set` and `get`, and an
overridden `get` is dispatched normally through the base-typed parameters that
hooks receive.

A reused executor retains its context between executions. Create a separate
executor when state must be isolated. Applications remain responsible for
reading environment variables or configuration files.

## Failures

Mamba records hook failures as `MambaExecutionError` values tagged with their
execution phase and command path. One failing cleanup hook does not prevent
remaining eligible cleanup hooks from running. The first failure determines
the execution result's exit code.
