# Arguments, Options, and Flags Reference

Use this guide when designing command inputs and validation messages.
Use the vocabulary in the skill's Arguments, Options, and Flags section:
positionals are unnamed, options take named values, and flags take no values.
Map those concepts to the framework's documented types. In Mamba, switches and
occurrence counters are flags; named string, numeric, and choice values are
options, including repeated, grouped, and dotted accessor inputs.

## Thematic Input Design

Make command inputs feel like part of the product instead of part of the parser.

- Name inputs after domain concepts the user already understands.
- Prefer words the product would use in help text, docs, and UI.
- Tell the user what to type next instead of describing the parser failure.
- Explain invalid values with the allowed choices in the same sentence.
- Keep validation focused on the task the user was trying to complete.

Thematic means the input language matches the CLI's world.

- A task CLI should talk about tasks, lists, assignees, and statuses.
- A studio CLI should talk about projects, invoices, members, and workspaces.
- A deployment CLI should talk about environments, services, and releases.

Do not fall back to generic wording like `missing arg`, `invalid option`, or raw framework output unless the command layer rewrites it first.

## How to Create Args

Use positional arguments for the most obvious required inputs in the main workflow.

- Use a positional argument when the user naturally thinks of the input as the next thing to type.
- Keep positional arguments short and memorable.
- Prefer at most three positionals for a new action command so their order stays memorable.
- Preserve more positionals when a clear workflow or compatibility requires them, and show each role in help and examples.
- Prefer named value options when an input's position would be ambiguous or when it represents an optional setting or filter.

Good task CLI examples:

```text
task add "write release notes"
task assign sarah --task-id 42
```

Better validation language:

```text
please type the user name
please type the task title
please type the project path
```

## Named Options and Flags

Use options for named values and flags for value-less execution controls.
Named input may be required, optional, or repeatable according to its role and
the framework's supported declarations.

- Use options when the meaning is not obvious from position alone.
- Use value options for filters, formats, and environment selection.
- Use boolean flags for switches and count flags for controls such as repeated verbosity.
- Prefer input names that match product terms and the CLI's established naming convention.
- Restrict option values when the product only supports a known set of choices.
- Show the accepted values in the validation error.

Good examples:

```text
task list --status complete
studio billing summary --format json
deploy release --environment staging
```

## Validation Style

Write validation as a correction, not as a parser complaint.

- Tell the user what to type.
- Tell the user which values are allowed.
- Mention the command when the fix is not obvious.
- Keep the tone direct and product-aware.

Prefer:

```text
please type the user name
the status must be all, complete, incomplete
please choose the environment: dev, staging, production
the format must be table, json, yaml
```

Avoid:

```text
missing arg
invalid status
invalid enum value
unknown option
```

## Wrong Input Examples

If the user types an unknown option or flag, or an invalid option value, rewrite the error around the task they were trying to perform.

Examples:

```text
please type the user name
the status must be all, complete, incomplete
please choose the environment: dev, staging, production
the format must be table, json, yaml
```

If the user typed the wrong option or flag name, guide them back to the product term:

```text
`--statuz` is not used by `task list`; use `--status`
`--member-name` is not used by `studio member invite`; use `--email`
```

## Relation to CLI Philosophy

Command inputs should reinforce the CLI model instead of fighting it.

- In a single-purpose CLI, keep core workflow inputs close to the main action commands.
- In a multi-purpose CLI, prefer options and flags local to the group that owns the concept; keep genuinely shared settings at the applicable global scope.
- Let the wording tell the user where they are in the command tree.

Examples:

- `task done 42` feels natural because the CLI is about task actions.
- `studio billing summary --format json` feels natural because `billing` owns reporting concepts.

The goal is that the user should understand both the command and the correction from the product language alone.
