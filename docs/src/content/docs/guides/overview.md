---
title: Overview
description: Understand How to make Mamba CLI Apps
sidebar:
  order: 2
---

Mamba is a framework that gives you the tools to be able to work CLI apps. 
The way you make those apps is by using the `Executor`.
To learn how to use this tool you should follow along with this page.

The first thing you should do is make a file that uses the `main()`.
Install mamba with `dart pub get mamba`.
In the braces of the main function import the Executor using `import 'mamba/mamba.dart'`.

The page should now look like this! 

```dart
import 'mamba/mamba.dart';

void main(List<String> args) {
  
}
```

Now what you need to do is call the `Executor`. 
It will make you pass in the name, short description, version and an array of commands.
Then you must call `create` then `execute`.

```dart ins={2-9}
void main(List<String> args) {
  final executor = Executor(
    'git',
    'Create and manage Git repositories',
    '2.52.0',
    [],
  );

  executor.create().execute(args);
}
```

:::caution
The version that's passed in must be a valid Semver Version you'll get an error
:::

Then you should run the file.

```sh
dart run <your_file>
```

:::note[When you run the file you should see this]
```sh
git  'Create and manage Git repositories'

Flags

[ -h|--help ] Show this help message.
_____________________________________
[ --dry-run ] Show what would happen without changing anything.
_______________________________________________________________
[ --version ] Show the application version.
___________________________________________
[ -v|--verbose ] Increase output verbosity.
___________________________________________
```
:::

:::note
As you can see this framework supports help, version. 
But you have noticed that there's `dry-run` and `verbose`
Dry run is for showing what would have been done! 
Verbose is for logging.
:::

## Commands 

To register commmands in the command list you need to first make a command. 
To do that you need to make a class that extends the `Command` class. 
So at the bottom of main write a class the extends the command class!

```dart ins={11-29}
void main(List<String> args) {
  final executor = Executor(
    'git',
    'Create and manage Git repositories',
    '2.52.0',
    [],
  );

  executor.create().execute(args);
}

class Add extends Command {

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add file contents to the index';

  

 @override
 String run(
   ParsedPositionals positionals,
   ParsedNamedInputs inputs,
   List<String> trailingArguments,
 ) => "Added to the index";
  
}
```

:::note 
As you can see the command must be given a name, shortDescription and use a `run()`.
This function takes in structured versions of arguments, flags and options, and unparsed inputs. 
:::

After creating this class call it in the list of commands

```dart ins={7}
void main(List<String> args) {
  final executor = Executor(
    'git',
    'Create and manage Git repositories',
    '2.52.0',
    [
      Add(),
    ],
  );
  
  executor.create().execute(args);
}
```

Then run the file with the command line arguments

```bash
dart run <file> add 
```

:::note[You should see the message you wrote in the run command]
```sh
Added to the index
```
:::

### Positionals 

The `Add` command is called `add` but it doesn't add anything.
To allow it to use an argument you need to register a **positional argument**.
Since this one isn't always required you'll need to register a **discretionary positional**.

Register the discretionary positional like this!

```dart ins={6-10}
class Add extends Command {

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add file contents to the index';

 new (discretionaryPositionals: [
   NormalPositional('path')
 ]);  
```

Then the the add command's run function like this! 

```dart del={6} ins={7-18}
@override
String run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) => "Added to the index";
) {

  final path = positionals?.singles['path'];

  if (path == null) {
    
   return "Added nothing to the index";

  }

  return "Added $path to the index";
}
```

Run the add command with the path added!

```sh
dart run <file> add <path>
```

:::note[Since a discretionary positional is registered]
It doesn't have to be passed as an argument! So the executor may not pass in a map of positionals.
When the path is passed in it will be stored in a map that has it's name and value! 
:::

### Flags 

The `Add` command might want to just add all path's but we don't want to have to specify all the path's
To solve this problem a flag needs to be the in the way making sure that this is the case!

Register the `--add` boolean flag flag like this! 

```dart ins={3-6}
 new (discretionaryPositionals: [
   NormalPositional('path')
 ],
 flags: [
   BooleanFlag('all'),
 ],
 );
```

Then rewrite the `run` function to use the flag!

```dart ins={7-13}
@override
String run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {

  final all = inputs?.boolFlags['all'];

  if (all != null) {
     return "Added all paths to the index";
  }
  
  final path = positionals?.singles['path'];

  if (path == null) {
    
   return "Added nothing to the index";

  }

  return "Added $path to the index";
}
```

:::note[We do not check if the all is true?]
It's not negatable! We know that it will be true when passed! 
:::

### Options

We are going to register an option to a command! But it's going to be a different one instead!
So just copy the `Add` command and replace it with this!

```dart
class Commit extends Command {

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository';

  
 new (
   discretionaryPositionals: [
    NormalPositional('path')
 ],
 flags: [
   BooleanFlag('all'),
 ],
 );

 @override
 String run(
   ParsedPositionals positionals,
   ParsedNamedInputs inputs,
   List<String> trailingArguments,
 ) {
 
   final all = inputs?.boolFlags['all'];
 
   if (all != null) {
      return "Committed all paths in the index";
   }
   
   final path = positionals?.singles['path'];
 
   if (path == null) {
     
    return "Committed nothing";
 
   }
 
   return "Committed $path";
 }
  
}

```

Then register the command into the executor.

```dart ins={8}
void main(List<String> args) {
  final executor = Executor(
    'git',
    'Create and manage Git repositories',
    '2.52.0',
    [
      Add(),
      Commit(),
    ],
  );
  
  executor.create().execute(args);
}
```

Finally register the `--message` option!

```dart ins={5-7}
new (
  discretionaryPositionals: [
   NormalPositional('path')
],
options:[
  RepeatableStringOption('message', required: true),
],
flags: [
  BooleanFlag('all'),
],
);
```

After doing that then change `Commit` to use the `message` flag! 

```dart ins={7-11}
@override
String run(
  ParsedPositionals positionals,
  ParsedNamedInputs inputs,
  List<String> trailingArguments,
) {

  final message = inputs!.repeatedStringOptions!['message']!.join("\n");
  

  final all = inputs?.boolFlags['all'];

  if (all != null) {
     return "Added all paths to the index $message";
  }
  
  final path = positionals?.singles['path'];

  if (path == null) {
    
   return "Added nothing to the index";

  }

  return "Added $path to the index $message";
}

```

Now run the command as intended! 

```sh
dart run  <file> commit --message "Initial commit" 
```

## Group Commands 

To add a command that can have subcommands! We create something called a `GroupCommand`.

So you need to create a class called `Stash` and make it a group command  by extending the `GroupCommand` class

```dart 
class Stash extends GroupCommand {


  @override
  String get name => "stash"; 

  @override
  String get shortDescription => "Stash the changes in a dirty working directory away";

  new([]);

}
```

:::note[There's no run override]
By default group commands have a run already defined.
It's job is to trigger when a sub command path is registered.
:::

Now register the Stash command!

```dart ins={8}   
final executor = Executor(
  'git',
  'Create and manage Git repositories',
  '2.52.0',
  [
    Add(),
    Commit(),
    Stash(),
  ],
);
```

After registering the command you can copy the add command and change it to this!


```dart
class Push extends Command {

  @override
  String get name => 'push';

  @override
  String get shortDescription => 'Save your modified file to a stash';

  

 @override
 String run(
   ParsedPositionals positionals,
   ParsedNamedInputs inputs,
   List<String> trailingArguments,
 ) => "Pushing changes into the stash";
  
}
```

Then register this command into the `Stash`.

```dart del={10} ins={11-13}
class Stash extends GroupCommand {


  @override
  String get name => "stash"; 

  @override
  String get shortDescription => "Stash the changes in a dirty working directory away";

  new([]);
  new([
    Push(),
  ]);
  

}
```

Now run the stash push command.

```sh
dart run <file> stash run
```

Now that you have got the result! Now make the group command do something buy adding the `defaultSubCommandPath`.

```dart del=3 ins={4-5}
new([
  Push(),
  ],
],
 defaultSubCommandPath:['push']
);
```

Run the stash command now! 

```sh
dart run <file> stash
```

## Conclusion 

If you followed the steps above you should have a functioning CLI! 
This tutorial was about making CLI's the way they are normally built! 
We didn't cover everything! But you should learn more about the framework by reading references.
I suggest reading about the [executor](/references/executor) first.
