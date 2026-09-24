---
name: mamba
description: Develop and test Dart CLI applications that use Mamba. Use when adding or changing executors, commands, command groups, typed inputs, injected dependencies, hooks, context, standard input, output, errors, help, or shell completions.
compatibility: requires mamba cli and dart cli
---


Mamba is the CLI framework for making CLI's! It's main focus is on `Executor.create` and `Executor.fake`.
The call to `create` always belongs in a root dart file! The `fake` function should always be called in test files.

It's framework that supports flags and options as separate concepts.
Flags that make a boolean are called boolean flags! The ones that return an incrementing number are called count flags.

When it comes to options there's a difference between single and repatable options! 
The single options are the ones that will make scalar values! While the repeatable ones will make value lists.
An option that has dots it's name is called an _accessor_. These types of flags are meant to represent nested dot operator access!

When it comes to arguments they are called _positionals_. 
The required ones are the ones mandatory positionals they are always on the left.
The optional ones are the ones that are not required and are after mandatory positionals.
Any unparsed values are called _variadics_.


Before the first task always look for a file that looks like this! 

```dart
import 'package:mamba/mamba.dart';

void main(List<String> args) {
  Executor().create();
}
```

If there are multiple files that have calls to `Executor.create` then please ask which one will be the one that's worked on!
When it's clear which file has the executor that needs to be changed then work!

## Executor

The `Executor` is the class that's responsible for activating the CLI! 
If you need to register a set of flags, options and that will be used by many commands that are registered at the root.
Place them there! Be aware that the `Executor` has `dry-run`, `version` short `V`, `verbose` short `v` as flags already.

The executor's create is in charge of setting the `exitCode` variable when an error happens.

Make sure that the fake method is never called in files other than test files!
Testing the `Executor` should always be done using the fake method. 

Make sure the create method is never called in a function that isn't `main`.

When you find the main file that's meant to be focused on! Follow these instructions.

Edit the call to `Executor` to register flags, options, and accessors when they must be accessed across multiple commands.

When there are scalar values that must be accessed across multiple commands register a `MambaContext` using the `context` named parameter! 


## Commands

When working with commands You'll be making either single or group ones!
They are classes that inherit the `Command` class. A group command inherits the `GroupCommand` class!

Read the matching API reference before registering command inputs:


When making a group command follow these steps:

1. Use `mamba command <name> --group`.
2. Look at the file 
3. Use the `mamba command <name> --append` to make commands associated with that command
4. Edit the file with the logic that's needed

When making a single command follow these steps:

1. Use `mamba command <name>`.
2. Look at the file 
3. Edit the file with the logic that's needed

When editing commands make sure that everything that's suppossed to be registered is private!
Then when they are used to retrive values make sure that the public name is used as the variable name in `run`.

## References 

- [Arguments](references/arguments.md) for mandatory and discretionary
  positionals or values after `--`.
- [Flags](references/flags.md) for boolean switches and occurrence counters.
- [Options](references/options.md) for scalar, repeatable, paired, selected, or dotted accessor values.
- [Completions](references/completion-commands.md) for how to register completions 
- [Hooks](references/hook-runners.md) for how to use hooks
