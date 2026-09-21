---
name: mamba
description: Use when Mamba is installed in a Dart project
compatibility: For Dart and Mamba projects 
---

Mamba is a CLI Framework that's used to develop CLIs. When using Mamba! Be aware of the `Executor`.
`Executor.create` is supposed to be called in the main entry point of the program!
`Executor.fake` is only supposed to be called in files with `_test` in their names.

When using the Mamba framework you need to use the CLI to make commands! 

To make a command use `mamba command <name>`.
To make a grouped command use `mamba command <name> --group`.

Prefer to make commands in the same file as group commands too, so use this `mamba command <name> --append` to do that.

When testing with Mamba `Executor.fake` will give you either a `MambaSuccessResult` or a `MambaFailureResult`.
When a command's `run()` throws an `Exception` the `MambaFailureResult` will be returned with the error message.
When a command's `run()` completes successfully the `MambaSuccessResult` will be returned.

## Executor 

The executor is class activates the CLI and provides global flags, options and accessors.
The parameters are in this order.
1. The name of the app
2. The short description of the app
3. The version
4. The List of commands 

A longer description is written using the `longDescription` prop. 
Flags are registered using the `flags` prop.
Options are registered using the `options` prop.
Options that use dots in their names are called the accessors they are registered in the `accessors` prop.
You can use the `defaultCommandPath` to decide which command is one that will be executed by default!
It's an array that references the command path relative to the name of the program.

The executor also allows something called a context to be used! 
The `context` is the place where values that need to be available to all commands typically go!
It's created by using the `MambaContext`. 

The `create` function will set the exit code
 
## Commands 

There are two commands to pick from a single or group command! 
A single command is a command that is a standalone command it's the class that extends the `Command` class.
A group command is a command that is a collection of commands it's the class that extends the `GroupCommand` class.

Either command can register flags, options, accessors, and arguments. 

Flags are registered using the `flags` prop. 
Options are registered using the `options` prop.
Accessors are registered using the `accessors` prop.
Options that need to be passed together are registered using the `pairedOptions` prop.
Options that need to be selected from are registered using the `selectedOptions` prop.


When it comes to **arguments**
There are two kinds:
_Mandatory positionals_: a list of required arguments that will make the first arguments that must be satisfied
_Discretionary positionals_: a list of optional arguments that can only be satisfied when the required ones are satisfied

In Mamba the arguments that go after `--` are called _variadics_! All commands can accept them!

The `mandatoryPositionals` prop is used to register mandatory positionals.
The `discretionaryPositionals` prop is used to register discretionary positionals.
The `variadic` prop is used to register validation for variadics. It's not required for unparsed arguments to be able to be passed through.

The `conflicts` prop is supposed to be used to list the names of registered entities that don't belong together.
When referring to accessor flags use the full name using the dot syntax!

Command aliases can be registered using the `aliases` prop it's an array of names.

Commands accept parsed, flags, options, and arguments through the `run()` function! 

```dart
FutureOr<String?> run(
  ParsedInputs inputs,
  List<String> args,
) {
  
}
```

To get a value from the parsed inputs you pass in the class you used to register the flag, option, accessor or positional you used to `inputs.valueOf`.
To get the variadics all you need is use the `args`.

When it comes to group commands all the mentioned options are allowed to be used!
By default group commands don't do anything when they run! 
You can supply a default command for them to run by using the `defaultSubCommandPath` prop.

The `propagatedFlags` prop is used to register flags that can be accessed by its child commands.
The `propagatedOptions` prop is used to register options that can be accessed by its child commands.

Only use the `MambaException` exception to throw exceptions! 

Whenever there are no problems always return a message in the Run function!
If the user doesn't test for or ask for a message to be returned from a command please ask! 
Tell the user it's not good to return an empty message! 
If the user doesn't care write one based on the context of the command! Think about what the command does it's a success message!
Messages returned from the run function should be green by default!
