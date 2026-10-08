---
name: mamba-cli-maker
description: Design and implement language-agnostic command-line interfaces with clear command hierarchies, help text, validation, prompts, exit codes, and completions. Use when a repo has a top-level cmd/ directory or when requests mention CLIs, command-line tools, subcommands, flags, options, help text, usage errors, prompts, shell completion, or command naming.
---

# CLI Maker

Design CLIs that match the product's theme and make the main workflow obvious.
Keep the command tree understandable from the root help alone.
Make validation errors say exactly what the user failed to provide or did incorrectly.

## Classify the CLI First

For a new CLI, choose the model that best explains the user's workflow:

- Prefer a single-purpose CLI when the tool supports one connected workflow.
- Prefer a multi-purpose CLI when the tool exposes several distinct capability groups.

For an existing CLI, inspect its commands, documentation, and user workflows
first. Preserve its established command paths and conventions unless the user
explicitly approves a redesign. The patterns below are design defaults, not
framework restrictions; justify exceptions in terms of discoverability,
compatibility, or the product's workflow.

For concrete examples of both models, read `references/cli-models.md` when you need a quick sanity check for command shape.

## Single-Purpose CLI Pattern

- Prefer primary actions at the top level.
- Prefer verbs for action commands and nouns for secondary groups.
- Add a group when it represents a useful concept, rather than nesting actions just for uniformity.
- Keep the main workflow shallow so the user can discover it quickly.

Mamba already provides robust argument parsing, validation, and error handling. This pattern guides how to structure your CLI *within* Mamba's framework rather than reinventing those mechanisms.

Example shape:

```text
tool fetch
tool push
tool status
tool config set
```

## Multi-Purpose CLI Pattern

- Prefer noun groups at the root for distinct capability areas.
- Put related actions under the group that explains their purpose.
- Mamba already handles setup and configuration (e.g., `init`, `config`). Retain root-level business actions when they are established entry points or make the primary workflow clearer; grouping is a design choice, not a universal requirement.

Example shape:

```text
tool project create
tool project list
tool secret rotate
tool config set
```

## Why, What, How

- Map the program's overall purpose to the root command.
- Map conceptual areas or user goals to subcommands.
- Map required unnamed input to positional arguments when its order is obvious.
- Map named values to options and value-less execution controls to flags.

Use this test:

- If it explains what the tool is for, keep it near the root.
- If it explains what the user wants to do, make it a command.
- If it modifies how to do it, use an option for a value or a flag for a value-less control.

## Command Hierarchy

- Make the root help menu the authoritative overview for the entire CLI.
- Let the root command prepare shared configuration, environment loading, logging, and execution context.
- Treat grouping commands as local coordinators for their own children only.
- Prefer nouns for grouping commands and verbs for action commands.
- Prefer kebab-case for new names; preserve an existing CLI's naming convention and obey the framework's accepted spelling rules.
- Place primary workflows where users can discover them quickly, using the chosen CLI model as a guide rather than a mandatory layout.

## Arguments, Options, and Flags

Use these terms consistently:

- A positional argument is unnamed input whose place determines its meaning.
- An option is named input that takes a value, such as `--format json`.
- A flag is named input that takes no value, such as `--force` or `-v`.

Mamba maps these concepts to its declared types: boolean and count declarations become flags; scalar, repeatable, paired, selected, and accessor-value inputs become options. Use Mamba's framework types rather than mixing terminology.

- Prefer no more than three positionals for a new action command, keeping the order memorable. More are acceptable when the workflow or compatibility requires them; explain their roles in help and examples.
- Prefer named value options for additional inputs whose order is unclear, optional settings, and filters.
- Name inputs in the product's language so users can connect them to the tool's theme.
- Use boolean flags to toggle behavior or mode, and count flags for occurrence-based controls such as verbosity.
- Use options for explicit named values, including required or repeated values.
- Enforce input relationships and requirements with the framework's supported declarations where possible; put unsupported business rules in application validation before performing effects.
- Phrase validation in user-facing, thematic language instead of parser-style language.

When input is missing, Mamba's parser produces messages that name the missing input, the command affected, and the fix (e.g., `Option --name is required.`); use the framework's built-in messages as the default and add extra diagnostics only with `--verbose`.

For concrete guidance on naming, validation wording, and corrective examples, read `references/args-and-flags.md` when designing command inputs.

## Errors and Exit Codes

- Return non-zero exit codes for validation, usage, and runtime failures.
- Write human-readable errors to stderr.
- Reserve stdout for normal output and machine-readable data.
- Keep error messages direct and specific.
- Mamba already provides near-match suggestions for mistyped flags, options, and commands; never suppress that guidance with a bare rejection.
- Never surface raw framework, parser, or library errors directly to the user.
- Translate internal failures into errors that describe the user's task and the command that failed.
- Keep the wording consistent with the CLI's theme, domain, and mental model.

When access to a command depends on a prerequisite such as login, setup, or initialization:

- Tell the user exactly which prerequisite is missing.
- Name the blocked command or command group.
- Tell the user how to satisfy the prerequisite.
- In an interactive session, offer a login flow only when the user experience benefits from it, and obtain explicit consent before starting it. Merely notifying the user is not consent.
- In non-interactive or scripted execution, return a non-zero failure with the corrective login command. Do not prompt, launch a browser, or start a login flow.
- If the user declines login, return a non-zero failure explaining how to authenticate manually.

Prefer messages like:

```text
missing required option --project-id for `tool deploy`
missing argument <path> for `tool import`; run `tool import --help`
`--format json` requires `--output`
`tool deploy` requires login; run `tool auth login`
`tool project list` requires workspace setup; run `tool init`
```

## Prompts and Interactivity

- Default to deterministic, non-interactive behavior.
- Use prompts only when the user experience benefits from guided structured input.
- Gate prompts behind explicit conditions or flags when automation matters.
- Mamba provides basic prompt scaffolding; the skill focuses on when and why to introduce interactive steps.

## Config Resolution

- Mamba defines a stable precedence order: command-line inputs, environment variables, config files, defaults.
- Document that precedence in help text or adjacent docs.
- Allow the config file path to be overridden with a flag (Mamba supports this natively).

## Shell vs. Scripting Environments

- In shell-oriented CLIs, favor composable stdout, terse stderr, and predictable exit codes.
- In scripting-language CLIs, allow richer prompts and guided flows, but keep automation safe by default.

## Extending the CLI

- Preserve the existing mental model when adding commands.
- Add new command groups only when they represent a real conceptual area.
- In object-oriented codebases, model commands as focused classes.
- In functional codebases, model commands as small modules with minimal side effects.


## Special Cases

- Treat meta commands such as `config` and `init` as standard action commands.
- When a meta command lives under a grouping command, let the grouping command prepare only the local context it owns.
