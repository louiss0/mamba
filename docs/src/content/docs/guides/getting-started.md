---
title: Getting Started
description: Use Mamba in a project scaffolded by Dart
---

If you are using Mamba for a Console project! You need to need to start by using `dart pub add mamba`. 
After installing Mamba you should start by replacing the code in the root lib folder with this.

```dart
import "package:mamba/mamba.dart";

Future<void> main(List<String> args) {
  
  await Executor('my-app', "This is my app", [] ).create().execute(args);

}
```

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

This help menu will show the name of the CLI, the description, and global flags.

By default Mamba comes with `--help` `--dry-run` and `--verbose` flags.
These flags are useful. 

- `--dry-run` is used to stop code from running but displays what would have happened.
- `--verbose` is a flag that's used to controll how logging is done!

The executor is a factory that allows only the registration of commands, flags and options.
It's not the root command! If you want to register a command for it to execute by default.

You must first make a command! 

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

Register the command! 

```dart
Future<void> main(List<String> args){
  
  await Executor(
    'my-app', 
    "This is my app",
    [Run()],
  ).create().execute(args);
}
```

Then provide the `defaultCommandPath` option. 

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

Then you can run `dart run lib/my-app.dart` again!

You'll see the default command run!

```sh
This ran
```

**This is how you use Mamba!** 

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

:::tip
