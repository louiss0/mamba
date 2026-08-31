

Mamba is a list-defined Dart framework for command-line applications. Commands
declare their inputs as fields, so the command surface, parser, and help output
all come from one definition.

[![pub package](https://img.shields.io/pub/v/mamba.svg)](https://pub.dev/packages/mamba)
[![license](https://img.shields.io/github/license/louiss0/mamba.svg)](LICENSE)

![mamba logo](https://raw.githubusercontent.com/louiss0/mamba/main/assets/Mamba-CLI.png)

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

`Variadic` is separate from ordinary positionals. It names and validates the
values after `--`; it never accepts extra tokens left over after mandatory and
discretionary positionals are filled.

**Parser.** After identifying command names and named inputs, the parser
assigns positional tokens in declaration order. Each expression must match the
whole token. Missing mandatory values, invalid discretionary values, and extra
values are errors. Values are returned by name in `ParsedPositionals`, a record
with a `singles` map for `Positional` values and a `repeated` map holding the
collected lists of `RepeatedStringPositional` and `RepeatedChoicePositional`,
the two concrete `RepeatedPositional` kinds. When a variadic is registered,
its validated post-`--` values appear by name in the `variadic` map. The same
tokens remain available as raw `trailingArguments`.

**Help.** Mandatory names appear as bare red operands; discretionary names use
compact dim brackets such as `[target]`. Choice members are joined with `|`,
bounded repetitions use `{1,N}`, and a variadic uses a dash expression such as
`[-- extra*]`.

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
  ) => 'Switching to ${positionals.singles!['branch']}.';
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
            'interactive',
            short: 'i',
            description: 'Select changes interactively.',
          ),
          CountFlag(
            'verbose',
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
alias, be required or hidden, and optional choices can have a default enum
value. Required choice options must receive explicit user input and therefore
cannot declare defaults.

**Parser.** Options accept `--name value`, `--name=value`, or `-s value`. A
separate value beginning with `-` is rejected unless it is a negative number
or a string expression explicitly accepts it. Integers accept signed decimal
integers; doubles accept signed decimal integers or fractions. Strings must
match their full expression. Choices are stored as
their enum-member names. Repeated values append to typed lists; ordinary
options retain the last value. Missing required options and invalid values are
errors; omitted ordinary choice options receive their default when configured.

**Help.** Visible entries appear in **Options**. Required entries are bare and
red; optional entries use dim square brackets. The formatter prints literal
long and short tokens followed by an uppercase value placeholder, such as
`[-m|--message MESSAGE]`. Choices replace the placeholder with `(one|other)`,
and repeatable option occurrences use a trailing `+`.

```dart
enum FixupMode { amend, reword }

final class Commit extends Command {
  Commit()
    : super(
        options: [
          StringOption(
            'message',
            short: 'm',
            description: 'Commit message.',
            regex: RegExp(r'.+'),
            required: true,
          ),
          ChoiceOption<FixupMode>(
            'fixup',
            description: 'How to update the previous commit.',
            choices: FixupMode.values,
            defaultValue: FixupMode.amend,
          ),
          RepeatableStringOption(
            'pathspec',
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

**Registers.** A `PairedOptions` group registers a non-empty list of
`PairOption` members; it is not itself an option and lives in its own
`pairedOptions` list. `PairStringOption`, `PairIntOption`, `PairDoubleOption`,
and `PairChoiceOption` use the ordinary value rules; `RepeatablePair*Option`
types accumulate values into typed lists. Pair options never accept member
defaults. With the default `variant: false`,
members form a required-together group when any is supplied. With
`variant: true`, members are alternatives. `required` makes the group mandatory
or requires one variant.

**Parser.** Every member accepts ordinary option syntax. A non-variant group
requires every member when any one is passed; a required non-variant group
reports the missing member names. A variant permits at most one member and a
required variant needs one. Values are returned in the same typed maps as
ordinary and repeated options.

**Help.** A paired group appears once in **Options**. Grouped members join
with ` & ` and variants with `|`. Required groups are bare, optional groups
use compact square brackets, repeatable members use a grouped `+` quantifier,
and member descriptions are joined with `; `.

```dart
enum Format { json, text }

final credentials = PairedOptions(
  description: 'Account credentials.',
  required: true,
  options: [
    PairStringOption('username', description: 'Account name.'),
    PairStringOption('password', description: 'Account password.'),
  ],
);

final outputFormat = PairedOptions(
  description: 'Output format.',
  variant: true,
  options: [
    PairChoiceOption<Format>(
      'json',
      description: 'Produce JSON.',
      choices: Format.values,
    ),
    PairChoiceOption<Format>(
      'text',
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
            'database',
            description: 'Database connection settings.',
            options: [
              AccessorStringOption(
                'host',
                description: 'Database host.',
              ),
              AccessorIntOption(
                'port',
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
`--`, and all following tokens become `trailingArguments`. A registered
variadic also validates and names those tokens without absorbing ordinary
positionals.

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
            'verbose',
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
options, pair members and paired groups, mandatory and discretionary
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
`registryForArguments` and `isRegisteredFlagToken` support registry navigation.

## Parser syntax and results

`Parser.parse` accepts tokens and returns a `ParsedArguments` record containing
the command path, positional map, typed named-input maps, trailing tokens, and a
`help` control field. The built-in `help` boolean is parsed like any other flag,
then removed from command inputs; executors format help and skip command
execution when it is true. Exact `-h` and `--help` set it. Once help is
encountered, later options are not validated, while command names are still
resolved. It supports:

* root-qualified and root-omitted command paths;
* `--long value` and `--long=value` options and accessor leaves (registered
  input-looking values use inline `--long=value` syntax);
* `-s value` short options;
* `--flag`, `-f`, and bundled short flags such as `-vvv` (including `-h`);
* `--no-name` for negatable boolean flags;
* positional, paired, repeated, and accessor forms;
* `--` as an end-of-options separator; and
* registered variadic validation for values after `--`.

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
`RequiredString` leaves required syntax bare, `OptionalString` supplies compact
square brackets, and `PairString` and `OrString` express grouped and alternative
syntax. Custom formatters implement `format` and `formatLongDescription` and
can reuse these helpers.

## Hooks and context

Mix `HookRunner` into a command to run `preRun` before its selected command and
`postRun` afterward. The pre-hook receives piped standard input, a read-only
`MambaReadContext`, positionals, and non-repeated ordinary options.

Mix `PersistentHookRunner` into a group to run around a selected descendant
path. It receives mutable `MambaContext`; its mutations are visible to
children. Persistent post-hooks run in reverse group-path order.
Both pre-hook APIs may return a `Future`, and the executor awaits setup before
running the command. Only successfully entered hooks are unwound; every
cleanup is attempted. Multiple cleanup exceptions are preserved in a
`MambaExecutionException`. Non-`Exception` failures are rethrown as
`MambaExecutionError`, which preserves the primary failure and every cleanup
failure.

`MambaContextKey<T>` provides typed identity keys for context values. Context
is executor-scoped: repeated calls to `execute` on the same fake or production
executor share its values. Create a new executor when executions need isolated
state.

## Registry maps and completion integrations

`CommandRegistry.toMap()` exports built-in help, regular-expression patterns,
paired groups, typed accessor leaves, choice values, defaults, and inherited
inputs.
`RegistryMap` deep-copies and freezes this integration boundary, validates its
semantic invariants, and reports malformed maps as `MambaIntegrationException`.
Only canonical typed accessor maps are accepted.

Carapace completion does not assume that arbitrary strings are file paths.
Choice completions are emitted for ordinary and paired options, positionals,
and variadics. Integer and double options, including repeated and paired
options, accept optional inclusive `min` and `max` bounds. A complete numeric
range is emitted as a Carapace range completion. Carapace has no multiplier or
step setting, so Mamba does not expose one. Regex-backed inputs do not supply
completion values. Carapace can represent variant members as exclusive but
cannot require one of them, so required variant descriptions retain that
parser-enforced requirement.
