---
title: Testing
description: Test your Commands by using the fake Executor.
sidebar:
  order: 3
---

When testing commands, use the fake executor instead of the production
executor. The production executor writes to stdout and stderr and manages
failure exit codes; the fake executor returns a `MambaExecutionResult` that you
can assert against in tests.

A `MambaSuccessResult` is returned when a command produces output or `null`.
A `MambaFailureResult` is returned when parsing, a command, or a hook reports
a recoverable failure.

## Write a test

Create a file in the `test/` folder:

```dart
import 'package:mamba/mamba.dart';
import 'package:test/test.dart';

final class AddCommand extends Command {
  new() : super(mandatoryPositionals: [word]);

  static final word = NormalPositional('word');

  @override
  String get name => 'add';

  @override
  String get shortDescription => 'Add a word.';

  @override
  String run(ParsedInputs inputs, List<String> args) {
    final wordValue = inputs.valueOf(word);
    return 'Added $wordValue';
  }
}

void main() {
  test('add command succeeds', () async {
    final result = await Executor(
      'my-app',
      'This is my app.',
      '1.0.0',
      [AddCommand()],
    ).fake().execute(['add', 'something']);

    expect(result, isA<MambaSuccessResult>());
    expect((result as MambaSuccessResult).output, 'Added something');
  });
}
```

## Triggering a failure

To trigger a failure, either:

1. Throw an `MambaException` from within `run`.
2. Pass an invalid value that the parser rejects, such as omitting a required
   input or supplying a value that fails validation.

### Option 1: Throw an `MambaException`

```dart
@override
String run(ParsedInputs inputs, List<String> args) {
  throw MambaException('Something went wrong.');
}
```

### Option 2: Trigger a parse error

The command above registers `word` as a mandatory positional. Invoke it
without that positional:

```dart
final result = await Executor(
  'my-app',
  'This is my app.',
  '1.0.0',
  [AddCommand()],
).fake().execute(['add']);
```

The invocation fails before `run` is called. The fake executor returns a
`MambaFailureResult` whose `exitCode` and `errors` describe the parse failure.

## Test standard input

Pass a `ProcessedStandardInput` to `fake()` when the selected command reads
piped input through `HookRunner.preRun`:

```dart
import 'dart:convert';

final input = ProcessedStandardInput(
  utf8.encode('{"enabled":true}'),
);
final result = await Executor(
  'my-app',
  'This is my app.',
  '1.0.0',
  [ImportCommand()],
).fake(standardInput: input).execute(['import']);

expect(result, isA<MambaSuccessResult>());
```

Use `bytes`, `text`, `utf8Text`, or `json` on the value received by `preRun`.
When `standardInput` is omitted, the pre-hook receives `null`.
