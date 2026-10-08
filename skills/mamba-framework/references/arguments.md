# Arguments

Use arguments for unnamed command input. Mamba separates arguments into
positionals before `--` and variadics after `--`.

## Register arguments

Register positionals on `Command` or `GroupCommand` in list order:

```dart
final source = NormalPositional('source');
final destination = NormalPositional.optional('destination');

final class CopyCommand extends Command {
  CopyCommand()
    : super(
        mandatoryPositionals: [source],
        discretionaryPositionals: [destination],
      );

  @override
  String get name => 'copy';

  @override
  String get shortDescription => 'Copy a file.';

  @override
  String run(ValueOf valueOf, List<String> args) {
    final sourceValue = valueOf(source);
    final destinationValue = valueOf(destination);
    return 'Copy $sourceValue to ${destinationValue ?? 'the default path'}';
  }
}
```

`mandatoryPositionals` accepts `MandatoryPositional` declarations.
`discretionaryPositionals` accepts optional or defaulted
`DiscretionaryPositional` declarations. Retain each declaration and pass the
same instance to `valueOf`; declarations are identity-based typed
keys.

Register at most one `Variadic` with the `variadic` parameter. Its validated
strings are passed to `run` through `args`, not through `valueOf`.

## Positional API

All positionals accept `name` and optional `description`. Normal string
positionals accept every supplied String by default, including empty/whitespace
content. An explicit `regex` checks the complete assigned value.

| Declaration | Registration | Parsed type |
| --- | --- | --- |
| `NormalPositional(name)` | mandatory | `String` |
| `NormalPositional.optional(name)` | discretionary | `String?` |
| `ChoicePositional(name, choices: values)` | mandatory | enum `T` |
| `ChoicePositional.optional(name, choices: values)` | discretionary | `T?` |
| `ChoicePositional.withDefault(...)` | discretionary | enum `T` |
| `RepeatedStringPositional(name)` | mandatory | `List<String>` |
| `RepeatedStringPositional.optional(name)` | discretionary | `List<String>?` |
| `RepeatedChoicePositional(name, choices: values)` | mandatory | `List<T>` |
| `RepeatedChoicePositional.optional(...)` | discretionary | `List<T>?` |
| `RepeatedChoicePositional.withDefault(...)` | discretionary | `List<T>` |

Choice declarations return enum members. Ordinary enums use `.name`; enums
implementing `MambaEnumValue` use their exact String `value`, without implicit
name aliases. Offered spellings/entries must be unique:

```dart
enum OutputFormat { text, json }

final format = ChoicePositional.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
```

Repeated string positionals accept `regex`. Repeated choice positionals accept
`choices`; their default is a `List<T>`. Both accept `times`, which defaults to
`1` and is the maximum number of values that declaration consumes. `times`
must be positive. A mandatory repeated positional must still consume at
least one value.

Repeated positionals allocate up to `times` in registration order while
reserving one token for each following mandatory positional. Validators check
the assigned values without backtracking. Parsed lists and configured
choice/default lists are immutable, including accepted empty defaults.

```dart
final sources = RepeatedStringPositional(
  'source',
  regex: RegExp(r'.+\.dart'),
  times: 3,
);

final formats = RepeatedChoicePositional.optional(
  'format',
  choices: OutputFormat.values,
  times: 2,
);

final class BuildCommand extends Command {
  new()
    : super(
        mandatoryPositionals: [sources],
        discretionaryPositionals: [formats],
      );

  @override
  String get name => 'build';

  @override
  String get shortDescription => 'Build Dart sources.';

  @override
  String run(ValueOf valueOf, List<String> args) =>
      valueOf(sources).join(',');
}
```

## Variadic API

`NormalVariadic` validates every token after the first `--`. It accepts an
optional `description` and `regex`. Without an explicit validator every supplied
trailing String is accepted. The trailing list is separate from positionals.

```dart
final class ForwardCommand extends Command {
  ForwardCommand()
    : super(variadic: NormalVariadic(regex: RegExp(r'.+')));

  @override
  String get name => 'forward';

  @override
  String get shortDescription => 'Forward trailing arguments.';

  @override
  String run(ValueOf valueOf, List<String> args) => args.join(' ');
}
```

`ChoiceVariadic<T>` accepts `choices` and an optional `description`, not a
`defaultValue`. It validates at most one trailing enum name. When omitted, it
adds nothing to `args`. `run` receives the original string rather than the
enum member:

```dart
ChoiceVariadic<OutputFormat>(
  choices: OutputFormat.values,
);
```

Without a registered variadic, Mamba passes tokens after `--` to `run`
unchanged and does not validate them.

## Optional value reads

Call `valueOf(declaration)` directly. An omitted optional positional returns
null; a defaulted positional returns its parsed or fallback value. Variadics
are read from `args`, not from declaration handles.
