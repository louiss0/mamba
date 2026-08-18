# TODO

The `Executor` isn't compelete! There must be functionality that must be tested!  

The job of the executor is to:
- Select a command and run it! 
- If the command is a hook command it needs to call `preRun` and `postRun` hooks.
- If along the way a command is found before or during the time the selected command is run.
  - The `prePersitentRun` and `postPersistent` run hook is run. 
- When std input is piped it's passed into the `preRun` hook! If not it's null. 
- It runs one of it's sub commands by default when a command path is passed
- The default flag is called `dry-run` 
- The default count flag is called `verbose` 
- The registry is suppossed to mae sure that help isn't allowed to be registered! 
- The flags registered in the executor is suppossed to be availiable to all commands

The point of the dry run flag is indicate to the user what would happen 
If the code that was suppossed to run runs! 
This idea is suppossed to be tested with commands and sub commands! 
Verbose is a flag that's involved with verbosity levels! 
Mamba doesn't have an official logger it's best to just test If the user has access to it.
In commands and subcommands!

The command path variable needs to be changed to relative command path for the group command! 
It also needs to be written like this for the executor! 
The user must never use the name of the registry or the parent command! 
When passed the path must not be empty!

If you can find a way to mock the `print` command using Mocktail without having to pass parameters!
Do so! The print function is used with hooks! 

To test the execute command! I want you to make a fake `git` command using the executor! 
This one will use the typical git commands!
Add rebase and merge too! 
All sub commands must be added and you must run help and you must use the info to make the mock git command!
Use` mocktail` and the `TDD` skill to accomplish your goal!

## Coverage follow-up

The current line coverage is 86.09% (780/906 lines). The LCOV report is
available at `coverage/lcov.info`.

Potential coverage improvements:

- Cover `Option` and `RepeatableOption` factory helpers in `command.dart`.
- Test invalid group-command paths, `ProcessedStandardInput` getters, and the
  default `HookRunner` lifecycle methods.
- Test invalid and missing option values, short paired options, invalid choices,
  accessor-choice defaults, and invalid positional values in `parser.dart`.
- Test piped stdin, unknown help command paths, short-flag handling, and invalid
  executor default-command paths.
- Test registry name collisions, reserved names, and error formatting.
