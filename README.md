# Mamba

[![pub package](https://img.shields.io/pub/v/mamba.svg)](https://pub.dev/packages/mamba)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

Mamba is a list-defined Dart framework for command-line applications. Commands
declare their inputs as fields, so the command surface, parser, and help output
all come from one definition.

## Architecture

Mamba keeps definition, validation, and execution separate:

1. Commands register names, descriptions, inputs, and behavior.
2. An `Executor` builds a `CommandRegistry` that organizes and validates those
   definitions.
3. A `Parser` reads the selected registry and decides whether an invocation is
   valid, producing typed values when it is.
4. The executor selects the matching command and gives it parsed values,
   trailing arguments, and global context established by hooks.

This separation keeps command definitions declarative, parsing deterministic,
and execution responsible for orchestration and I/O.

## Getting started

Add Mamba to an application with `dart pub add mamba`. Construct an `Executor`
once in the executable's composition root, then call `create()` for the
production executor. It writes successful command output to standard output and
failures to standard error. An empty invocation displays help.

```dart
import 'package:mamba/mamba.dart';

final executor = Executor(
  'git',
  'Manage source repositories.',
  commands: [Commit()],
).create();

Future<void> main(List<String> args) => executor.execute(args);
```

For tests, call `fake()` in one shared test-support file and import that fake
executor into test files. It returns a `MambaSuccessResult` or
`MambaFailureResult` instead of writing to process streams.

```dart
// test/support/git_executor.dart
import 'package:mamba/mamba.dart';

final testExecutor = Executor(
  'git',
  'Manage source repositories.',
  commands: [Commit()],
).fake();
```

Do not use `create()` in tests or `fake()` to build the production executable.

## Commands

A `Command` registers its `name`, `shortDescription`, optional
`longDescription`, input lists, and `run` behavior. `run` receives positional
values, typed named inputs, and arguments after `--`; its returned string is
sent to the executor's output environment.

```dart
import 'dart:async';

import 'package:mamba/mamba.dart';

final class Commit extends Command {
  Commit() : super();

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository.';

  @override
  FutureOr<String> run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => 'Committed.';
}
```

### Positionals

**Registers.** `Positional` contributes a named, regular-expression-validated
value. Register it in `mandatoryPositionals` to require it or
`discretionaryPositionals` to accept it only when present. Its default
expression accepts one non-whitespace token.

**Parser.** After identifying command names and named inputs, the parser
assigns positional tokens in declaration order. Each expression must match the
whole token. Missing mandatory values, invalid discretionary values, and extra
values are errors. Values are returned by name in `ParsedPositionals`.

**Help.** Mandatory names appear as red `< name >`; discretionary names appear
as dim `[ name ]` in the usage line.

```dart
final class Switch extends Command {
  Switch()
    : super(
        mandatoryPositionals: [Positional('branch')],
        discretionaryPositionals: [Positional('start-point')],
      );

  @override
  String get name => 'switch';

  @override
  String get shortDescription => 'Switch branches.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => 'Switching to ${positionals!['branch']}.';
}
```

### Flags

**Registers.** `BooleanFlag` contributes a boolean name, optional one-letter
`short` alias, default value, and optional negated form. `CountFlag`
contributes a counter name and optional short alias. `hidden` keeps a flag
parseable while removing it from help.

**Parser.** Boolean flags accept `--name`, `-s`, and bundles such as `-abc`.
Negatable boolean flags also accept `--no-name`. Every registered boolean
appears in `inputs.boolFlags`, using `defaultValue` when absent. Count flags
accept the same long and short forms and increment on every occurrence in
`inputs.countFlags`. Flags do not accept `=value`.

**Help.** Visible flags appear in **Flags**, together with the built-in
`--help` / `-h` flag. Entries use optional brackets and show the long name,
short alias, and description.

```dart
final class Commit extends Command {
  Commit()
    : super(
        flags: [
          BooleanFlag(
            name: 'interactive',
            short: 'i',
            description: 'Select changes interactively.',
          ),
          CountFlag(
            name: 'verbose',
            short: 'v',
            description: 'Increase output verbosity.',
          ),
        ],
      );

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final interactive = inputs.boolFlags!['interactive'];
    final verbosity = inputs.countFlags!['verbose'] ?? 0;
    return 'Interactive: $interactive; verbosity: $verbosity.';
  }
}
```

### Single-value and repeated options

**Registers.** `StringOption`, `IntOption`, `DoubleOption`, and `ChoiceOption`
register one value by name. Strings use their supplied expression; integers and
doubles select numeric values; choices accept an enum-member name.
`RepeatableStringOption`, `RepeatableIntOption`, and `RepeatableDoubleOption`
register accumulating forms. Ordinary options can have a one-letter short
alias, be required or hidden, and choices can have a default enum value.

**Parser.** Options accept `--name value`, `--name=value`, or `-s value`. A
separate value beginning with `-` is rejected unless it is a negative number.
Integers accept signed decimal integers; doubles accept signed decimal integers
or fractions. Strings must match their full expression. Choices are stored as
their enum-member names. Repeated values append to typed lists; ordinary
options retain the last value. Missing required options and invalid values are
errors; omitted choices receive their default when configured.

**Help.** Visible entries appear in **Options**. Required entries use red angle
brackets, optional entries use dim square brackets, and repeated entries begin
with `...`. The formatter prints each registered name, its short alias when
present, and its yellow description.

```dart
enum FixupMode { amend, reword }

final class Commit extends Command {
  Commit()
    : super(
        options: [
          StringOption(
            name: 'message',
            short: 'm',
            description: 'Commit message.',
            regex: RegExp(r'.+'),
            required: true,
          ),
          ChoiceOption<FixupMode>(
            name: 'fixup',
            description: 'How to update the previous commit.',
            choices: FixupMode.values,
            defaultValue: FixupMode.amend,
          ),
          RepeatableStringOption(
            name: 'pathspec',
            description: 'Limit the commit to a path.',
          ),
        ],
      );

  @override
  String get name => 'commit';

  @override
  String get shortDescription => 'Record changes to the repository.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) {
    final message = inputs.stringOptions!['message'];
    final mode = inputs.stringOptions!['fixup'];
    final paths = inputs.repeatedStringOptions!['pathspec'] ?? const [];
    return 'Committing $paths with $mode: $message';
  }
}
```

### Paired options and pair members

**Registers.** A `PairedOption` registers a primary option and a non-empty list
of `PairOption` members. `PairedStringOption`, `PairedIntOption`,
`PairedDoubleOption`, and `PairedChoiceOption` use the ordinary value rules;
`RepeatablePaired*Option` types make a primary repeatable. `Pair*Option` and
`RepeatablePair*Option` types register the companion values. With the default
`variant: false`, members form a required-together group when any is supplied.
With `variant: true`, members are alternatives. `required` requires a group or
one variant.

**Parser.** Every primary and member accepts ordinary option syntax. A
non-variant group requires every member and its primary when any one is passed.
A variant permits at most one member and a required variant needs one. Values
are returned in the same typed maps as ordinary and repeated options.

**Help.** A paired registration appears once in **Options**. Grouped members
join with ` & ` and variants with ` | `. Required groups use angle brackets,
optional groups use square brackets, repeatable members have `...`, and member
descriptions are joined with `; `.

```dart
enum Format { json, text }

final credentials = PairedStringOption(
  name: 'username',
  description: 'Account name.',
  options: [
    PairStringOption(name: 'password', description: 'Account password.'),
  ],
);

final outputFormat = PairedChoiceOption<Format>(
  name: 'json',
  description: 'Produce JSON.',
  choices: Format.values,
  variant: true,
  options: [
    PairChoiceOption<Format>(
      name: 'text',
      description: 'Produce text.',
      choices: Format.values,
    ),
  ],
);
```

### Accessor options

**Registers.** `AccessorStringOption`, `AccessorIntOption`,
`AccessorDoubleOption`, and `AccessorChoiceOption` register leaf values.
`AccessorListOption` registers a named object that contains nested accessors;
lists can nest. They use the same string, numeric, choice, and default rules as
ordinary options. A hidden accessor list hides its complete subtree from help.

**Parser.** Address a leaf with a dotted long name, such as
`--database.port 5432` or `--database.port=5432`. Unknown and non-leaf paths
are errors. The parser validates values, merges supplied paths into nested maps,
and returns them in `inputs.accessors`. Choice defaults are merged into those
maps.

**Help.** Visible leaves appear under **Accessor flags** using dotted paths and
their descriptions. Accessors are optional and do not have short aliases.

```dart
final class Serve extends Command {
  Serve()
    : super(
        accessors: [
          AccessorListOption(
            name: 'database',
            description: 'Database connection settings.',
            options: [
              AccessorStringOption(
                name: 'host',
                description: 'Database host.',
              ),
              AccessorIntOption(
                name: 'port',
                description: 'Database port.',
              ),
            ],
          ),
        ],
      );

  @override
  String get name => 'serve';

  @override
  String get shortDescription => 'Start the service.';

  @override
  String run(
    ParsedPositionals positionals,
    ParsedNamedInputs inputs,
    List<String> trailingArguments,
  ) => 'Serving with ${inputs.accessors!['database']}.';
}
```

## Group commands

**Registers.** A `GroupCommand` has all the command registrations above plus
child `commands`. It may publish `inheritedFlags` and `inheritedOptions` to
every descendant; a local same-name definition replaces an inherited one. A
relative `defaultSubCommandPath` can select a child when no explicit child is
supplied.

**Parser.** Command names can follow the root name or omit it. Registered
inputs can appear before, between, or after command path segments. The selected
command's registry determines valid inputs and positionals. Parsing ends at
`--`, and all following tokens become `trailingArguments`.

**Help.** A group lists its direct children in **Commands** with their short
descriptions. Like every command, its usage begins with name, positionals, and
quoted short description.

```dart
final class Remote extends GroupCommand {
  Remote()
    : super(
        [RemoteAdd(), RemoteRemove()],
        inheritedFlags: [
          BooleanFlag(
            name: 'verbose',
            short: 'v',
            description: 'Show detailed output.',
          ),
        ],
      );

  @override
  String get name => 'remote';

  @override
  String get shortDescription => 'Manage remote repositories.';
}
```

Use `defaultSubCommandPath` for a declarative default, or override `run` and
call `runChildCommand` with a non-empty path relative to the group. A relative
path cannot include the group's own name.

## Registry

`CommandRegistry.create` turns a list-defined command surface into a validated,
navigable command tree. It indexes boolean and count flags, single and repeated
options, paired primaries and pair members, mandatory and discretionary
positionals, and accessors in separate maps keyed by long name. This keeps each
input category's meaning intact, supports direct lookup, and avoids scanning a
heterogeneous list.

A group produces a child registry for each direct child. Inherited flags and
options are carried down the tree, while local same-name definitions take
precedence. Command registries remain separate because command names form a
hierarchy rather than an input namespace.

Registry construction rejects invalid command or input names, reserved help
names, invalid short aliases, empty paired groups, duplicate names or aliases,
accessor collisions, duplicate positionals, and sibling command collisions.
`requestsHelp`, `registryForArguments`, and `isRegisteredFlagToken` support
help targeting and registry navigation.

## Parser syntax and results

`Parser.parse` accepts tokens and returns a record containing the command path,
positional map, typed named-input maps, and trailing tokens. It supports:

* root-qualified and root-omitted command paths;
* `--long value` and `--long=value` options and accessor leaves;
* `-s value` short options;
* `--flag`, `-f`, and bundled short flags such as `-vvv`;
* `--no-name` for negatable boolean flags;
* positional, paired, repeated, and accessor forms; and
* `--` as an end-of-options separator.

It rejects unknown inputs and commands, malformed or missing values, invalid
regular-expression or numeric values, unsupported negation, unsatisfied
required inputs, invalid paired combinations, and invalid positional layouts.
It validates input; it does not execute commands.

## Help formatting

`HelpFormatter` is the customization boundary for rendering a
`CommandRegistry`. `MambaHelpFormatter` produces ANSI-styled usage, an optional
long description surrounded by dashed lines, and non-empty **Flags**,
**Accessor flags**, **Options**, and **Commands** sections. Hidden inputs remain
accepted but are omitted from this output.

`FormattedString` and its subclasses protect styled help fragments.
`RequiredString` and `OptionalString` reject their own delimiters; `PairString`
and `OrString` express grouped and alternative syntax. Custom formatters
implement `format` and `formatLongDescription` and can reuse these helpers.

## Hooks and context

Mix `HookRunner` into a command to run `preRun` before its selected command and
`postRun` afterward. The pre-hook receives piped standard input, a read-only
`MambaReadContext`, positionals, and non-repeated ordinary options.

Mix `PersistentHookRunner` into a group to run around a selected descendant
path. It receives mutable `MambaContext`; its mutations are visible to
children. Persistent post-hooks run in reverse group-path order.
`MambaContextKey<T>` provides typed identity keys for context values.
