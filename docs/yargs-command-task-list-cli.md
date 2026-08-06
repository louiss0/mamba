# Yargs command-runtime task-list CLI

`bin/yargs_command_task_list.dart` is a separate task-list executable built on
`YargsCommandRuntime`, rather than the original schema-driven `ArgParser` or
the low-level `YargsParser` example.

```text
yargs_command_task_list add <title> [--description <description>]
yargs_command_task_list delete <id> | --completed
yargs_command_task_list update <id> (--title <title> | --description <description> | --complete <true|false>)
yargs_command_task_list list [--status all|complete|incomplete]
```

Run it during development:

```text
dart run bin/yargs_command_task_list.dart add "Write release notes"
```

The command declarations in
`lib/src/task_list/yargs_command_task_list_cli.dart` demonstrate the runtime's
explicit typed API: each command supplies typed options, named positionals,
descriptions, choices, and an asynchronous handler. No command signature
string or builder DSL is used.

It stores data in `.yargs_command_tasks.json` by default. That distinct file
ensures the three task-list examples can be run in the same directory without
modifying one another's data.

The runtime handles command selection, option ownership, required positionals,
option choices, and unknown command/option failures. The CLI handles the
application rules that span inputs: delete mode selection, exactly one update
field, positive task IDs, task-text validation, and JSON storage failures.

Successful output goes to standard output. Usage/validation failures go to
standard error with exit code `64`; storage failures use exit code `1`.
