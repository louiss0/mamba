---
title: Architecture
description: How Mamba registers commands, parses invocations, and executes production CLIs.
---

Mamba uses a **Register → Parse → Execute** architecture. Each phase has one responsibility:

- **Register** turns declarative command objects into a validated, searchable command tree.
- **Parse** interprets an argument list against that tree and produces typed values.
- **Execute** selects the command object, invokes it, and connects its result to the process environment.

This separation keeps command-line syntax out of command behavior. Commands declare what they accept, the registry describes the complete CLI, the parser validates one invocation, and the executor coordinates the production lifecycle.

```text
Command objects
      │
      ▼
Executor ── setup ──▶ CommandRegistry
      │                    │
      │ arguments          ├──▶ HelpFormatter ──▶ help text
      ▼                    │
    Parser ◀───────────────┘
      │
      │ ParsedArguments
      ▼
Command selection ──▶ Command.run(...) ──▶ stdout

CommandRegistry ──▶ RegistryRecord ──▶ completion converters
```

## Command definitions

A `Command` is both a declarative definition and the final behavior for one command path. Its metadata supplies the command name, descriptions, aliases, and accepted inputs. Its `run` method supplies the behavior that should occur only after the invocation is valid.

Commands are arranged as objects rather than callbacks stored in the parser. A `GroupCommand` owns child commands, so nested command syntax is represented by the same tree structure that the executor later traverses. Both root-level and group-level defaults can identify a relative command path to run when the user does not explicitly select a child.

The execution contract is deliberately narrower than the declaration:

```dart
FutureOr<String?> run(
  CommandInvocation invocation,
  List<String> args,
)
```

By the time `run` is called, command aliases have been canonicalized and values have been validated and grouped by their Dart value type. A command can complete synchronously or asynchronously, return text for the production executor to print, or return `null` when it has no output.

## Registration: `CommandRegistry`

Registration happens when the production execution environment is created. The executor passes its application metadata, global declarations, and command objects to `CommandRegistry.create`, which recursively builds one registry node for every command.

The registry performs several jobs during this phase:

1. **Validate the command surface.** Names, aliases, descriptions, defaults, ranges, command siblings, and input namespaces are checked before any arguments are parsed.
2. **Index declarations.** Commands and their inputs are stored in name-keyed collections so parsing does not repeatedly scan the original declaration lists.
3. **Canonicalize aliases.** Each registry level maps a child alias to that child's canonical name.
4. **Preserve hierarchy.** Every child registry points to its parent and can reconstruct its full path from the application root.
5. **Model inheritance.** Root declarations and values published by enclosing groups remain owned by the level that declared them. `withInheritedInputs()` creates the effective view needed at a selected command without changing the original tree.

Positionals, trailing-value rules, paired groups, accessor trees, and child commands remain local to the command that declares them. Only the inputs explicitly designed for descendants participate in inheritance. This prevents unrelated command state from being flattened into every node while still giving the parser a complete view at the selected path.

Invalid definitions raise `MambaRegistryError` during composition. As a result, a malformed CLI fails while the execution environment is being built rather than halfway through a user invocation.

## Parsing: `Parser`

`Parser` converts a `List<String>` into `ParsedArguments`; it never invokes a command or writes to process streams.

Parsing occurs in two broad passes:

1. **Find the command path.** The parser walks the registry tree, resolves aliases, and skips registered named inputs and their values while looking for child commands. The resulting path contains canonical command names.
2. **Parse the selected command.** The parser obtains the selected registry's effective inherited view, consumes the remaining tokens, validates values, applies defaults, and checks required relationships.

The result contains four pieces of execution data:

- the canonical command path;
- parsed positional values;
- parsed named values grouped by type;
- untouched arguments that appeared after `--`.

It also carries whether help was requested. Help and version requests are treated as control paths: they can be resolved without requiring an otherwise complete command invocation. This allows users to inspect a command even when its normal required values were not supplied.

Keeping parsing independent has an important consequence: command code never needs to distinguish long names from short aliases, split inline values, resolve command aliases, or convert strings into numbers. It receives only the parser's canonical result.

## Production execution: `Executor`

`Executor` is Mamba's composition root. It owns the application name, description, semantic version, root command list, optional default command path, and help formatter. Creating the production executor builds a reusable internal execution object containing the validated registry and command tree.

For each call to `execute`, the production path is:

1. **Apply command defaults.** A root default path can be inserted when no root command was selected. Defaults on selected groups are then applied from outermost to innermost. Explicit help requests are not rewritten, so help describes the path the user actually named.
2. **Parse the arguments.** The normalized list is passed to `Parser` with the previously built registry.
3. **Resolve the command objects.** The canonical path returned by the parser is followed through the original command tree.
4. **Handle framework output.** Version requests return the application name and version. Help requests, or an invocation with no selected command, render the selected registry instead of dispatching command behavior.
5. **Run the command.** For a normal invocation, the selected command receives the parsed positionals, typed named values, and trailing arguments. `FutureOr` results are awaited uniformly.
6. **Deliver the result.** Non-null command output is written to standard output.

The registry and parser determine *which* command is valid; the executor determines *when* it runs and *where* its observable result goes. This is the main boundary between Mamba's declarative model and process-level side effects.

## Help formatting

Help is generated from the selected `CommandRegistry`, not from the raw argument list or by asking a command to describe itself again. Before formatting, the executor resolves inherited inputs so the output reflects the complete surface available at that path.

`MambaHelpFormatter` renders the command path, descriptions, usage grammar, visible inputs, and child commands. Hidden declarations remain part of parsing but are omitted from the default presentation. A custom `HelpFormatter` can replace the rendering policy without changing registration, parsing, or dispatch.

Because help consumes the same validated registry as the parser, its command names, aliases, required markers, and available values are derived from the actual CLI definition rather than a separate help model that can drift out of sync.

## Registry records and integrations

`CommandRegistry.toMap()` projects the live registry into a typed `RegistryRecord`. Despite the method name, this is a recursive Dart record and class structure rather than an untyped serialized map. It preserves the command hierarchy and the metadata needed by external integrations while removing execution behavior.

The completion converters consume this record to produce Bash, Zsh, Fish, PowerShell, or Carapace artifacts. They do not inspect command implementations and do not parse a real invocation. Instead, they translate the already validated command model into each target shell's routing and completion rules. The Carapace writer can then place its generated specification in the platform's configuration directory.

A `CompletionCommand` receives the complete root registry record when the execution environment is constructed. This gives completion behavior a snapshot of the same command surface used by production parsing and help generation, including nested commands and inherited declarations.

## Errors and the process boundary

Mamba distinguishes failures by where they occur:

- `MambaRegistryError` reports an invalid command definition during setup.
- `MambaParseException` reports arguments that do not satisfy the selected registry.
- `MambaCommandNotFoundException` reports a failed command-tree lookup and includes the available children.
- `MambaIntegrationException` reports failures while producing an external artifact.
- `MambaException` is the common recoverable framework failure used by selection, parsing, integrations, and command behavior.

The production executor is the process boundary for invocation failures. It catches thrown `Exception` values, writes them to standard error, and sets the process exit code to `1`. Successful non-null output goes to standard output. Registry construction errors occur before this invocation boundary, which keeps configuration defects distinct from user input failures.

## Architectural boundaries at a glance

| Part | Owns | Does not own |
| --- | --- | --- |
| `Command` | Metadata and valid-invocation behavior | Token parsing or process output |
| `CommandRegistry` | Validation, indexing, hierarchy, and inheritance | Running commands |
| `Parser` | Command-path discovery and typed invocation data | Command behavior or terminal I/O |
| `Executor` | Composition, control flow, dispatch, and process delivery | Input-specific validation rules |
| `HelpFormatter` | Human-readable rendering of a selected registry | Parsing or command selection |
| Integration converters | Translation of registry records into external artifacts | Live execution behavior |

The result is a single source of truth—the registered command tree—with separate consumers for runtime parsing, help, dispatch, and completion generation.