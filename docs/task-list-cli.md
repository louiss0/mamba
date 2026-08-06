# Task-list CLI decisions

This document explains the command design for the JSON-backed task list in
`bin/task_list.dart`. The executable is built on this package's `ArgParser` and
stores its data in a project-local `.tasks.json` file.

## Purpose and command shape

The CLI is single-purpose: every command manages a task. Its actions are kept
at the root because they are the main workflow, not separate capability areas:

```text
task_list add <title> [--description <description>]
task_list delete <id> | --completed
task_list update <id> (--title <title> | --description <description> | --complete <true|false>)
task_list list [--status all|complete|incomplete]
```

`add`, `delete`, `update`, and `list` are concise verbs that describe exactly
what happens. The hierarchy is intentionally shallow: a user can discover all
available actions from the root command schema.

Run the executable during development with:

```text
dart run bin/task_list.dart add "Write release notes"
```

The `executables` entry in `pubspec.yaml` also exposes it as `task_list` when
the package is installed globally.

## Storage location and format

The default file is `.tasks.json` in the current working directory. This was
chosen over a user-home file so that each project or directory gets an isolated
task list. It also makes the data easy to inspect, back up, and remove with the
project.

A document has one `tasks` array. Every task persists all required values,
including a `null` description when none was supplied:

```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Write release notes",
      "description": "Summarize the shipped changes.",
      "complete": false
    }
  ]
}
```

IDs are positive integers generated as one greater than the highest currently
stored ID. The CLI never lets a user choose an ID during `add`; this prevents
collisions and makes the command short. The store validates every JSON task's
field type when reading so a malformed document does not cause an untyped
runtime failure later.

## `add`: title first, description by name

```text
task_list add "Write release notes"
task_list add "Write release notes" --description "Summarize changes"
```

The title is a required positional because it is the obvious primary input to
an add action. A description is optional and therefore named. This follows the
usual CLI convention that a command's main subject is positional while
additional detail is a flag.

Both fields are normalized with `String.trim()` and then validated through
Acanthis' `string().min().max()` schemas:

| Field | Rule | Reason |
| --- | --- | --- |
| Title | 1–120 characters after trimming | A title must identify a task, but should remain scannable in a list. |
| Description | 1–2,000 characters after trimming when supplied | A description can hold useful context without allowing accidental very large input. |

Whitespace-only text becomes empty after trimming and fails validation. A
missing description is stored as `null`; an explicitly supplied empty
description is rejected as unhelpful task content. Acanthis is used through its
non-throwing `tryParse` API, matching the CLI's explicit error-result model.

## `delete`: safe single and bulk modes

```text
task_list delete 14
task_list delete --completed
```

A positional ID is the most natural way to name one task. `--completed` is an
explicit bulk mode. The command rejects both together and rejects neither, so a
user cannot accidentally turn a one-task deletion into a bulk deletion.

Task IDs must be positive whole numbers. Deleting an unknown ID is a normal
command failure with a direct message; it does not modify the JSON file.

## `update`: exactly one property per invocation

```text
task_list update 14 --title "Publish release notes"
task_list update 14 --description "Include migration guidance"
task_list update 14 --complete=true
task_list update 14 --complete=false
```

The user requested a forced choice between title, description, and completion
updates. The CLI implements that literally: exactly one of `--title`,
`--description`, or `--complete` must be present.

Title and description use the same Acanthis validation as `add`. `--complete`
accepts only `true` or `false`, which makes both completion transitions
explicit and scriptable.

A Boolean parser option would default to `false`; with the current argument
result API that would not distinguish an omitted flag from a supplied false
value. A string option with the closed choices `true` and `false` preserves
presence, supports both states, and lets the command layer enforce the
exactly-one rule. That rule is command-specific cross-field validation, so it
belongs in the task CLI rather than in the generic parser.

## `list`: one constrained status filter

```text
task_list list
task_list list --status=complete
task_list list --status=incomplete
```

`list` defaults to `all`. Status is a named filter rather than separate
commands because it changes how the same resource is viewed. The parser limits
it to `all`, `complete`, or `incomplete`; the command never silently accepts an
unknown state.

Each task is printed as:

```text
14 [incomplete] Write release notes
  Summarize the shipped changes.
```

The description appears on a second indented line only when it exists, which
keeps common task lists compact while retaining detail when available.

## Parser integration

`TaskListCli` owns one declarative `ArgParser` command schema. The parser first
selects `add`, `delete`, `update`, or `list`; only then are that command's
options active. For example, `--status` is accepted by `list` but rejected by
`add`.

The generic parser handles token syntax, required positional input, and fixed
option choices. The command layer handles task-specific rules that span more
than one input:

- a delete needs exactly one mode: ID or `--completed`;
- an update needs exactly one update flag;
- IDs must be positive integers;
- task text must pass Acanthis validation;
- a referenced task must exist.

Keeping these responsibilities separate prevents the parser from gaining
application-specific behavior and keeps the task rules easy to test.

## Errors, output, and exit codes

Normal results go to standard output. Usage and validation errors go to
standard error and return exit code `64`; JSON read/write failures return `1`.
This makes the CLI usable in scripts without parsing successful output as an
error channel.

Error messages use task language rather than exposing raw parser exceptions.
For example:

```text
Choose exactly one update flag: --title, --description, or --complete.
Task ID must be a positive whole number.
The task title must contain 1 to 120 characters.
```

The application is deliberately non-interactive. Every mutation is explicit in
the supplied tokens, which makes commands repeatable in scripts, tests, and
shell history.

## Intentional limits

The initial CLI does not provide due dates, tags, priorities, automatic prompts,
or a configurable file path. These are separate product features, not parser
concerns. A future `--file` root option could safely add an explicit storage
override without changing task JSON or command semantics.
