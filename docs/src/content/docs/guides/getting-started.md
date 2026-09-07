---
title: Getting Started
description: Use Mamba in a project scaffolded by Dart
sidebar:
  order: 1
---

If you are using Mamba for a Console project!
You need to need to start by using 

```sh
dart pub add mamba
```
After installing Mamba you should start by replacing the code in the root lib folder with this.

```dart
import "package:mamba/mamba.dart";

Future<void> main(List<String> args) {
  
  await Executor('my-app', "This is my app", [] ).create().execute(args);

}
```

:::note
After this you should do `dart run lib/my-app.dart`. 
When you run that command you should see the help menu.

It should look something like this but colored 

```sh
my-app 'This is my app'

Flags

[ -h|--help ] Show this help message.
_____________________________________
[ --dry-run ] Show what would happen without changing anything.
_______________________________________________________________
[ -v|--verbose ] Increase output verbosity.
___________________________________________
```
:::

This help menu will show the name of the CLI, the description, and global flags.

By default Mamba comes with `--help` `--dry-run` and `--verbose` flags.
These flags are useful. 

- `--dry-run` is used to stop code from running but displays what would have happened.
- `--verbose` is a flag that's used to controll how logging is done!

The executor is a factory that allows only the registration of commands, flags and options.
It's not the root command! If you want to register a command for it to execute by default.

:::tip[You must first make a command!]
 

```dart
class Run extends Command {
  Run();

  String get name => "run";
  
  String get shortDescription => "Run the application.";

  @override
  Future<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) async {

    return "This ran"
  }
}
```
:::

:::tip[Register the command] 

```dart
Future<void> main(List<String> args){
  
  await Executor(
    'my-app', 
    "This is my app",
    [Run()],
  ).create().execute(args);
}
```
:::

:::tip[Then provide the `defaultCommandPath` option.]

```dart
Future<void> main(List<String> args){
  
  await Executor(
    'my-app', 
    "This is my app",
    [Run()],
    defaultCommandPath: ['run'],
  ).create().execute(args);
}
```
:::

:::tip[Then you can run `dart run lib/my-app.dart` again!]

You'll see the default command run!

```sh
This ran
```
:::


:::tip[Wanna see the the run in help?]

Run `dart run lib/my-app.dart --help`

```sh
my-app 'This is my app'

Flags

[ -h|--help ] Show this help message.
_____________________________________
[ --dry-run ] Show what would happen without changing anything.
_______________________________________________________________
[ -v|--verbose ] Increase output verbosity.
___________________________________________

Commands 

run Run the application.
------------------------
```

:::

## Using the Mamba CLI

If you don't have a project that's created yet you should create one by using the Mamba CLI! 

You can activate it globally

```sh
dart pub global activate mamba
```

When you do you then use the mamba create command. 

```sh
mamba create curl 
```

:::note
The folder structure that's created should be similar to the CLI console project!
But it should have Mamba's executor set up.  
:::
