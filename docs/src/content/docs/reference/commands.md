---
title: Commands
description: Learn about Commands in Mamba
---

In Mamba there are only two kinds of commands! group and single commands!
A group command is a command that can take in a series of other commands.
A single command is standalone! 

To make single command you make a class inherit from the `Command` class! 

```dart
import 'package:mamba/mamba.dart';

class Commit extends Command {
  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'send this file to the git index';

  @override
  FutureOr<String?> run(
    ParsedInputs inputs,
    List<String> args,
  ) => 'Committed the files';
}
```

To make a group command you use the `GroupCommand` class!

```dart
import 'package:mamba/mamba.dart';

class Stash extends GroupCommand {

  @override
  String get name => 'stash';

  @override
  String get shortDescription => 'Hold on to changes for later use';


}

```

## Single Command

A single command is a command that has a name and a description. 
The long description is added by using the `longDescription` option.
They are the kinds of commands that can use [normal hooks](/reference/hooks/#normal-hooks).

## Group Command

A group command is a command that allows other commands to be nested within it.
It can have it's own [flags](/reference/flags) and [options](reference/options). 
It can also have options called `propagatedFlags` and `propagatedOptions`.
Those are going to be the options and flags that the sub commands have access to!

This command does inherit from the `Command` class. but it's run function is one that waits for a **sub command path**.
When that path is written it the command will be run if the group command is selected! 
Otherwise nothing will happen.

These kinds of commands can run [persistent](/reference/hooks/#persistent-hooks) and [normal hooks](/reference/hooks/#normal-hooks)
