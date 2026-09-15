---
title: Overview
description: Build a command-line application with Mamba
sidebar:
  order: 2
---

Mamba defines command syntax once and uses those declarations for parsing,
validation, help, completion, and typed value consumption.

## Create an executor

```dart
import 'package:mamba/mamba.dart';

Future<void> main(List<String> args) => Executor(
  'git-like',
  'Manage source changes.',
  '1.0.0',
  [AddCommand()],
).create().execute(args);
```

The version must be semantic. Every executor includes help, version, dry-run,
and verbosity flags.

## Define a command

A command retains the same declaration handles it registers through `super`:

```dart
final class AddCommand extends Command {
  new()
    : super(
        mandatoryPositionals: [path],
        flags: [all],
        options: [message],
      );

  static final path = NormalPositional('path');
  static final all = BooleanFlag(
    'all',
    short: 'a',
    description: 'Add every path.',
  );
  static final message = StringOption.required(
    'message',
    short: 'm',
    description: 'Commit message.',
  );

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add paths to the index.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final pathValue = invocation.valueOf(path);
    final allPaths = invocation.valueOf(all);
    final messageValue = invocation.valueOf(message);
    return 'Adding ${allPaths ? 'all paths' : pathValue}: $messageValue';
  }
}
```

Run it with:

```sh
dart run <file> add README.md --message "Document Mamba"
```

## Output availability

`valueOf` returns exactly the type described by its declaration:

```dart
final label = StringOption('label');
final String? labelValue = invocation.valueOf(label);

final output = StringOption.required('output');
final String outputValue = invocation.valueOf(output);

final format = ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
final OutputFormat formatValue = inputs.valueOf(format);
```

Options are optional by default. Positionals are mandatory by default:

```dart
final source = NormalPositional('source');
final destination = NormalPositional.optional('destination');
```

Register `source` in `mandatoryPositionals` and `destination` in
`discretionaryPositionals`; the list types enforce the distinction.

## Groups and accessors

Use `GroupCommand` for nested command paths. Propagated flags and options are
available to descendants.

Paired options map an all-or-nothing set into one output. Selected options map
one mutually exclusive member into one output. Use each group's `.required`
factory when its output must be present.

Accessor lists group dotted paths such as `--database.host`. Read the value
through the top-level accessor handle; it returns an immutable nested map.

## Trailing arguments

Register a `Variadic` to validate values after `--`. Mamba passes those values
to `run` as `args`; they are deliberately separate from `ParsedInputs`.

## Testing

Use the fake executor to invoke commands without writing to process streams:

```dart
final result = await Executor(
  'tool',
  'Test tool.',
  '1.0.0',
  [AddCommand()],
).fake().execute(['add', 'README.md', '--message', 'Document Mamba']);

expect(result, isA<MambaSuccessResult>());
```
