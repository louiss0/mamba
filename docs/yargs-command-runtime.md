# Yargs-inspired command runtime

`YargsCommandRuntime` is a dependency-free, Dart-native command layer over the
package's `YargsParser` port. It ports the useful command-framework behavior of
Yargs without copying its JavaScript builder API, command-string DSL, Node
module loading, terminal UI dependencies, or localization system.

## Explicit declarations instead of a command DSL

Yargs uses strings such as `deploy <file> [region]` and transforms them into a
command name and positional schema. This runtime intentionally does not. Define
commands and positionals as typed Dart values instead:

```dart
final runtime = YargsCommandRuntime(
  options: const [YargsCommandOption.boolean('verbose', alias: 'v')],
  commands: [
    YargsCommand(
      'remote',
      aliases: const ['r'],
      commands: [
        YargsCommand(
          'add',
          positionals: const [YargsPositional('name', required: true)],
          options: const [
            YargsCommandOption.string('region', choices: {'eu', 'us'}),
            YargsCommandOption.boolean('fetch', alias: 'f'),
          ],
          handler: (arguments) {
            print(arguments.commandPath); // [remote, add]
            print(arguments.positional('name'));
            print(arguments.flag('fetch'));
          },
        ),
      ],
    ),
  ],
);

final result = await runtime.run([
  '--verbose', 'remote', 'add', 'origin', '--region', 'eu', '--fetch',
]);
```

The runtime returns `YargsCommandSuccess` or `YargsCommandFailure`; user input
and handler failures therefore do not need to be represented as control-flow
exceptions.

## What it ports

- nested command selection and command aliases;
- root and ancestor options active at selected descendants;
- Boolean, string, number, array, count, default, alias, and `narg` parser
  hints, delegated to `YargsParser`;
- explicit required, optional, and final variadic positionals;
- required-option, choice, conflict, implication, unknown-option, and unknown-
  command validation;
- synchronous or asynchronous command handlers;
- dependency-free help text and command/option completion candidates.

Commands cannot declare both child commands and positionals. This removes the
ambiguity that Yargs solves through its string DSL and recursive parser state.
A variadic positional must be final, and conflicting command names or aliases
are rejected while constructing the runtime.

## Deliberate omissions

This is not a byte-for-byte Yargs replacement. It does not include mutable
fluent builders, command-directory module loading, shell-script completion
templates, locale catalogs, exact `cliui` formatting, package-version lookup,
or Yargs's reset/freeze internals. Those features either rely on Node-specific
libraries or are implementation machinery for the DSL-oriented API that this
Dart runtime intentionally avoids.

For raw token parsing—including arrays, config files, environment values,
coercions, and low-level `--` behavior—use `YargsParser` directly. See
[`yargs-parser-port.md`](yargs-parser-port.md).
