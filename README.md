# Mamba

[![pub package](https://img.shields.io/pub/v/arg_parser.svg)](https://pub.dev/packages/arg_parser)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

A CLI Framework that that makes commands define their accepted inputs using fields.
There are two kinds of commands! `Command` and `GroupCommand`. 
A _command_ is a class that defines a subcommand.
A _group command_ is a sub command that allows nested subcommands.
The main class that you work with is called `Executor`
The executor is the class that executes your commands!

## Usage

To use Mamba you need to first install it `dart pub add mamba`!

Then make a `lib/main.dart` file and call the executor! With a name description. 

```dart
import 'package:mamba/mamba.dart';

void main(List<String> args) {
  final executor = Executor('git', "A tool that's used for managing the distribution of code");
  executor.execute(args);
}
```

After this you use `dart run lib/main.dart ` to run your executor!

When you run the command **you'll end up seeing nothing but the help menu**!

This is what the executor does when you run the root command it only opens the help menu!
There's no way to make it do anything! You'll need commands! 

To resgister a command you take make a class inherit from `Command`. 

```dart
import 'package:mamba/mamba.dart';

class Commit extends Command {

  @override 
  String get name => 'commit';

  @override
  String get shortDescription => "Record changes to the repository";

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    
    print("Committing...");
    
    return "Committed!";
  }
}
```

Then you register in into the `Executor`. 

```dart
import 'package:mamba/mamba.dart';

void main(List<String> args) {
  final executor = Executor(
    'git', 
    "A tool that's used for managing the distribution of code",
    commands: [
      Commit(),
    ],
  );
  executor.execute(args);
}
```

In your terminal you run `dart run lib/main.dart commit`. 

That's how this framework works!

## Commands 

A command is a class whose it's `run()` is called when it's name is word in the parsed arguments.
The run function **returns a string**! That string is automatically **printed to stdout**.

The run function takes three arguments! 
1. All registered arguments that parsed stored in a `Map<String, String>`
2. All flags, options that were parsed stored in a record. 
3. A list of all parsed arguments that were passed after `--` 

### Positionals 

To allow a command to take an mandatory argument you register `mandatoryPositionals` 

```dart
class Switch extends Command {
  @override
  String get name => 'switch';

  @override
  String get shortDescription => "Change the current branch";

  Command(
    
  ): super(
    mandatoryPositionals: [
      Positional("branch"),
    ],
  
  );
}
```

The run function will store it in the first positional argument in the map.
What you do is get the value you know will be stored in the map!

```dart
  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    
    return "Going to branch ${positionals!['branch']}";
   
  }
```

To allow a command to take an optional positional argument! Register `optionalPositionals`

```dart
class Branch extends Command {
    @override
    String get name => 'branch';

    @override
    String get shortDescription => "List, create, or delete branches";

  Command(): super(
    optionalPositionals: [
      Positional("branch"),
    ],
  );
  
}
```

The run function will then take the positional argument the same way. 

```dart
  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final branch = positionals!['branch'];
    return "Going to branch $branch";
  }
}
```

### Flags 

If you want to register a command with a flag you use the `flags`

```dart
class Commit extends Command {
  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository';

  Command(): super(
    flags: [
      BooleanFlag(
        name: 'interactive',
        description: 'Do an interactive commit',
      ),
    ],
  );
}
```

The `run` function will then take the flag value from the `inputs` record.

```dart
  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final interactive = inputs.flags!['interactive'];
    return "Interactive commit: $interactive";
  }
}
```

### Options

If you want to register options for a command, use the `options` parameter.
```dart

enum FixupMode {
  amend,
  reword,
}

class Commit extends Command {
  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository';

  Command(): super(
    options: [
      StringOption('message', description: 'Commit message', short: 'm'),
      ChoiceOption<FixupMode>("fixup", choices: FixupMode.values),
    ],
  );
}
```


The `run` function will then take the option values from the `inputs` record.

```dart
  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final fixup = inputs.options!['fixup'];
    
    final message = inputs.options!['message'];

    if (fixup == FixupMode.amend.name) {
      return "Fixup mode: $fixup, message: $message";
    }

    if (fixup == FixupMode.reword.name) {
      return "Reword mode: $fixup, message: $message";
    }
    
    return "New message: $message";
  }
}
```

## Group Command 

A group command is a command that groups multiple subcommands together.
It can register a series of flags or options that must be inherited by subcomamnds.
It can run one of it's child commands. Even ones that are not deeply nested.

To make a group command, use the `GroupCommand` class.

```dart
class Remote extends GroupCommand {
  @override
  String get name => 'remote';

  @override
  String get shortDescription => 'Manage remote repositories';

  Remote() : super([
    Add(),
    Rename(),
    Remove(),
  ]);
}
```

The remote subcommands define the positional arguments accepted by their Git
counterparts.

```dart
class Add extends Command {
  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add a remote repository';

  Add()
    : super(
        mandatoryPositionals: [
          Positional('name'),
          Positional('url'),
        ],
      );

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    return 'Added remote ${positionals!['name']} at ${positionals['url']}';
  }
}

class Rename extends Command {
  @override
  String get name => 'rename';

  @override
  String get shortDescription => 'Rename a remote repository';

  Rename()
    : super(
        mandatoryPositionals: [
          Positional('old-name'),
          Positional('new-name'),
        ],
      );

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    return 'Renamed remote ${positionals!['old-name']} to ${positionals['new-name']}';
  }
}

class Remove extends Command {
  @override
  String get name => 'remove';

  @override
  String get shortDescription => 'Remove a remote repository';

  Remove() : super(mandatoryPositionals: [Positional('name')]);

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    return 'Removed remote ${positionals!['name']}';
  }
}
```

### Inherited Options

A group command is allowed to make its children inherit its options. To do this,
use the `inheritedOptions` property. For example, `git notes` shares its
`--ref <notes-ref>` option with subcommands such as `list`, `add`, `show`, and
`remove`.

```dart
class Notes extends GroupCommand {
  @override
  String get name => 'notes';

  @override
  String get shortDescription => 'Add and inspect notes';

  Notes()
    : super(
        [
          NotesList(),
          NotesAdd(),
          NotesShow(),
          NotesRemove(),
        ],
        inheritedOptions: [
          StringOption(
            name: 'ref',
            regex: RegExp(r'\S+'),
            description: 'Notes reference to use',
          ),
        ],
      );
}

// Implement NotesList, NotesAdd, NotesShow, and NotesRemove as Command classes.
```

### Inherited Flags

A group command is allowed to make its children inherit its flags. To do this,
use the `inheritedFlags` property. For example, `git submodule` shares its
`--quiet` flag with subcommands such as `add`, `status`, `init`, `update`, and
`sync`.

```dart
class Submodule extends GroupCommand {
  @override
  String get name => 'submodule';

  @override
  String get shortDescription => 'Initialize and manage submodules';

  Submodule()
    : super(
        [
          SubmoduleAdd(),
          SubmoduleStatus(),
          SubmoduleInit(),
          SubmoduleUpdate(),
          SubmoduleSync(),
        ],
        inheritedFlags: [
          BooleanFlag(
            name: 'quiet',
            short: 'q',
            description: 'Suppress progress output',
          ),
        ],
      );
}

// Implement the Submodule* child commands as Command classes.
```

### Default Subcommands

A group command can run one of its children when the group itself is invoked.
Override `run` and call `runChildCommand` with the path to the default child.
For example, Git treats `git stash` like `git stash push`.

```dart
class Stash extends GroupCommand {
  @override
  String get name => 'stash';

  @override
  String get shortDescription => 'Stash the current changes';

  Stash() : super([StashPush(), StashPop(), StashList()]);

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    return runChildCommand(
      ['push'],
      positionals,
      inputs,
      trailingArguments,
    );
  }
}

// Implement StashPush, StashPop, and StashList as Command classes.
```
