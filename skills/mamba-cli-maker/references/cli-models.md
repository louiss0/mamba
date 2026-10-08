# CLI Models Reference

Use this guide when you need a quick example of how to structure a CLI before naming commands.
These are starting patterns, not mandatory layouts. Preserve established command
paths in an existing CLI unless the user approves a redesign; justify a new
layout by discoverability and the product's workflow.

## Single-Purpose CLI Example

Use a task-list CLI when the tool exists to manage one connected workflow: creating, tracking, and finishing tasks.

Principles:

- Prefer core task actions at the top level.
- Keep the main flow shallow.
- Group secondary support actions when the grouping helps users find them.

Example shape:

```text
task add
task list
task done
task archive list
task archive clear
task config set
```

Why this is single-purpose:

- The user is doing one family of work: managing tasks.
- The top-level commands are the actions the user performs most often.
- Secondary areas such as `archive` and `config` stay grouped because they support the core workflow instead of defining it.

## Multi-Purpose CLI Example

Use a studio operations CLI when the tool spans several distinct areas of work.

Principles:

- Prefer a root overview organized around capability groups.
- Prefer nouns for those groups and verbs for their actions.
- Place related actions under the group that owns their concept.
- Retain root-level actions when they are established entry points or make the primary workflow clearer.

Example shape with three root subcommands:

```text
studio project create
studio project list
studio billing invoice
studio billing summary
studio member invite
studio member remove
```

Why this is multi-purpose:

- The user may work with projects, billing, or members, which are different conceptual areas.
- In this example, business actions sit under their capability groups; this is not a restriction on every multi-purpose CLI.
- Each root command is a grouped command that owns a separate slice of the product.
