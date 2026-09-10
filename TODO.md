# Handoff

## Goal

Make command input consumption type-safe, add unique repeated choices, and replace
`PairedOptions(variant: true)` with a distinct `SelectedOptions` concept.

These changes are related and should be implemented in this order:

1. Introduce typed input handles and typed parsed-value lookup.
2. Return enum members rather than enum names for choice inputs.
3. Add uniqueness to repeated choice options.
4. Introduce `SelectedOptions<R>` on top of typed input handles.
5. Make execution results report exit codes and phase-tagged hook failures.
6. Migrate registry records, help, completions, examples, and scaffolding.

Treat this as a breaking value-access change. Do not preserve the current
string-keyed records as a second long-term interface; that would retain the
complexity this work is intended to remove.

Preserve the current constructor-based registration method. Commands continue
to register lists through `super(...)`; do not replace registration with a
`CommandInputs` getter, builder, annotation, or generated definition.

---

## 1. Make inputs type-safe

### Design decision

Separate the metadata interface used by the parser and registry from the typed
handle used by command authors.

```dart
abstract interface class InputDefinition {
  String get name;
  String? get description;
}

sealed class Input<T> implements InputDefinition {
  const Input();
}
```

Each concrete declaration carries the type returned to the command:

| Declaration | Value type |
| --- | --- |
| `BooleanFlag` | `bool` |
| `CountFlag` | `int` |
| `StringOption` | `String` |
| `IntOption` | `int` |
| `DoubleOption` | `double` |
| `ChoiceOption<T>` | `T` |
| `RepeatableStringOption` | `List<String>` |
| `RepeatableIntOption` | `List<int>` |
| `RepeatableDoubleOption` | `List<double>` |
| `RepeatableChoiceOption<T>` | `List<T>` |
| normal positional | `String` |
| choice positional `<T>` | `T` |
| repeated positional `<T>` | `List<T>` |
| accessor leaf `<T>` | `T` |

Keep a non-generic metadata interface because registries and heterogeneous
input lists do not need to know each value type. Keep the unavoidable
`Object?` cast inside one parsed-values module rather than spreading casts and
string-key lookups across every command.

### Parsed values interface

Replace `ParsedNamedInputs`, `ParsedPositionals`, and their type-bucket maps
with one small interface keyed by declaration object:

```dart
final class ParsedInputs {
  ParsedInputs._(this._values);

  final Map<InputDefinition, Object?> _values;

  T? valueOf<T>(Input<T> input) => _values[input] as T?;

  T require<T>(Input<T> input) {
    final value = valueOf(input);
    if (value == null) {
      throw StateError('Parser omitted required input --${input.name}.');
    }
    return value;
  }

  bool contains(InputDefinition input) => _values.containsKey(input);
}
```

Positionals, named inputs, selected options, and accessor leaves all use this
one parsed-value store. `CommandInvocation` owns that store and command context.
Validated variadic arguments after `--` are deliberately excluded from both
types.

Use declaration-object identity as the key. Input definitions are immutable and
must not override equality. Names remain in registry metadata for parsing,
help, errors, and completion, but command code must not use names to retrieve
values.

`require` represents a parser invariant failure, not normal user validation.
The parser must reject a missing required input before command execution.

### Preserve constructor registration

A command must retain the exact input instances it passes to the existing
`super(...)` constructor. Immutable definitions for a normal command can be
static final fields:

```dart
enum OutputFormat { text, json }

final class ExportCommand extends Command {
  static final source = NormalPositional('source');
  static final format = ChoiceOption<OutputFormat>(
    'format',
    choices: OutputFormat.values,
    defaultValue: OutputFormat.text,
  );

  ExportCommand()
    : super(
        mandatoryPositionals: [source],
        options: [format],
      );

  @override
  String run(CommandInvocation invocation, List<String> args) {
    final sourceValue = invocation.inputs.require(source);
    final formatValue = invocation.inputs.require(format);
    return switch (formatValue) {
      OutputFormat.text => 'Exporting $sourceValue as text',
      OutputFormat.json => 'Exporting $sourceValue as JSON',
    };
  }
}
```

Definitions that vary by command instance can still be created outside the
public constructor and passed into a private constructor, or accepted as
constructor dependencies. They must still be registered through the same
`super(...)` list parameters. Do not add a second registration path.

Changing execution to
`run(CommandInvocation invocation, List<String> args)` does not change
registration. The constructor declares the command surface; the invocation and
validated args are the runtime values passed to that surface.

### Validated args after `--`

Treat everything after the first `--` as command arguments validated by the
registered `Variadic` declaration:

- pass them as the second `Command.run` parameter named `args`;
- exclude the `--` separator itself;
- validate every value before command execution;
- preserve value order and duplicates when the variadic permits them;
- use an immutable empty list when no values follow `--`;
- keep the validated values as strings rather than adding them to
  `ParsedInputs`; and
- exclude them from `CommandInvocation`.

Preserve the current `NormalVariadic`, `ChoiceVariadic`,
`RepeatedChoiceVariadic`, and `_validateVariadic` behavior. Variadic metadata
continues to drive validation, help, registry records, and completion, while
only the validated argument list crosses the execution interface.

### Choice parsing

Stop converting enum choices to `.name` in parsed command values. The registry
record can continue serializing choice names for help and completion, but the
parser must map the accepted name back to the registered enum member and store
that member under its input handle.

### Accessors

Keep dotted accessor paths in registry metadata, but return each leaf through
its typed leaf handle. Do not expose `Map<String, dynamic>` to commands.

```dart
static final host = AccessorStringOption('host');
static final port = AccessorIntOption('port');
static final server = AccessorListOption('server', [host, port]);

final hostValue = invocation.inputs.valueOf(host); // String?
final portValue = invocation.inputs.valueOf(port); // int?
```

The registry owns path construction; command code owns typed handles.

`AccessorListOption` is a registration and path-grouping node, not a value
handle. It implements metadata needed by the registry but does not implement
`Input<T>`, so `valueOf(server)` is intentionally a compile-time error. Only
accessor leaves are stored in `ParsedInputs`.

The parser resolves a full spelling such as `--server.host` to the exact `host`
leaf instance, validates its value, and stores the result under that instance.
Distinct branches may contain leaves with the same name because identity, not
the leaf name, is the lookup key. Reusing the same leaf instance in multiple
paths must be rejected during registry construction because its path would be
ambiguous.

Do not attempt to turn a map into a record. Dart records have a compile-time
shape and are not dynamically iterable. A command that wants an aggregate
creates it explicitly from typed leaves:

```dart
typedef ServerSettings = ({String? host, int? port});

final ServerSettings settings = (
  host: invocation.inputs.valueOf(host),
  port: invocation.inputs.valueOf(port),
);
```

This keeps CLI path grouping separate from the application's domain model. If
many callers later need the same aggregate, consider a separate explicit
mapper that constructs a class or record; do not make dynamic record conversion
part of the parser.

### Hooks

Pass the same `CommandInvocation` or a deliberate read-only view to hooks.
Do not create another partial record equivalent to `ParsedSingleOptions`.
Typed flags, repeatable values, selected options, accessors, and positionals
must remain available consistently wherever hooks are allowed to inspect input.

### Tests first

- [ ] A `StringOption` handle retrieves only `String?`.
- [ ] An `IntOption` handle retrieves only `int?`.
- [ ] A choice handle retrieves its enum type, not `String`.
- [ ] A repeated choice handle retrieves `List<T>`.
- [ ] A positional handle retrieves its declared type.
- [ ] An accessor leaf retrieves its declared type without a dynamic map.
- [ ] An `AccessorListOption` cannot be passed to `valueOf` or `require`.
- [ ] Same-named leaves in separate accessor branches retain distinct values.
- [ ] Reusing one leaf instance in multiple accessor paths is rejected during
  registry construction.
- [ ] A command can construct a typed class or record explicitly from leaf
  values.
- [ ] Looking up an omitted optional input returns `null`.
- [ ] Looking up a parsed required input with `require` returns non-null.
- [ ] Input identity prevents two same-typed declarations from crossing values.
- [ ] Inherited and overridden inputs retain the correct handle identity.
- [ ] `args` contains every accepted token after `--` in exact order,
  including permitted duplicates and dash-prefixed values.
- [ ] The separator itself is not included in `args`.
- [ ] Invalid values are rejected by the registered `Variadic` before the
  command runs.
- [ ] Validated variadic values do not appear in `CommandInvocation` or
  `ParsedInputs`.
- [ ] Commands receive an immutable empty `args` list when `--` is absent.
- [ ] Command and hook tests no longer construct large nullable records.

---

## 2. Add unique repeated choice values

### Interface

Add `unique`, defaulting to `false`, to `RepeatableChoiceOption<T>`:

```dart
RepeatableChoiceOption<OutputFormat>(
  'format',
  OutputFormat.values,
  unique: true,
)
```

This change applies to `RepeatableChoiceOption` first. Do not silently extend it
to repeated strings, numbers, positionals, or variadic arguments without a
separate use case and interface decision.

### Semantics

- `unique: false` preserves the current behavior and order, including
  duplicates.
- `unique: true` preserves first-seen order and **rejects** a duplicate; it does
  not silently deduplicate user input.
- Compare parsed enum members, not their string spellings.
- The parse error must identify the option and duplicate value, for example:

  ```text
  Option --format accepts each choice once; json was provided more than once.
  ```

- `required: true` still means at least one value must be supplied.
- Registry construction should reject no additional state: a unique repeatable
  choice with one available choice is valid.

### Registry and completion metadata

Add uniqueness to the typed registry record so integrations do not need to
infer it:

```dart
bool? unique;
```

Use `true` when enabled and `null` otherwise to match the existing optional
modifier metadata. Generated completions should stop suggesting values already
used for that option where the target shell can reliably determine prior
values. Runtime parsing remains authoritative.

### Tests first

- [ ] Duplicates remain accepted when `unique` is omitted or false.
- [ ] A duplicate is rejected when `unique` is true.
- [ ] Distinct choices preserve invocation order.
- [ ] Long, short, and `--name=value` forms share the same uniqueness check.
- [ ] Inherited repeated choice options enforce uniqueness.
- [ ] Registry records export `unique: true` only when enabled.
- [ ] Help/completion snapshots represent uniqueness consistently.
- [ ] Every completion converter is tested with a previously selected value.

---

## 3. Replace `variant: true` with `SelectedOptions<R>`

### Why this should be a separate type

`PairedOptions` and its `variant` flag represent different invariants:

- paired options: all members are supplied together;
- selected options: zero or one member is selected, or exactly one when
  required.

A boolean changes the meaning of the entire object and forces conditionals
through the parser, help formatter, registry exporter, and completion
converters. Separate types make invalid combinations unrepresentable and give
selection a place to return a typed domain result.

After migration:

```dart
PairedOptions([...], required: true);       // all members
SelectedOptions<OutputSelection>(           // exactly one member
  [...],
  required: true,
);
```

Remove `variant` from `PairedOptions`; do not deprecate it indefinitely.

### Result mapping

`SelectedOptions<R>` should itself be a typed input handle. Each selectable
member knows how to convert its parsed value into the caller's result type:

```dart
sealed class OutputSelection {
  const OutputSelection();
}

final class JsonOutput extends OutputSelection {
  const JsonOutput(this.path);
  final String path;
}

final class TextOutput extends OutputSelection {
  const TextOutput(this.path);
  final String path;
}

static final json = PairStringOption('json');
static final text = PairStringOption('text');
static final output = SelectedOptions<OutputSelection>(
  [
    SelectableOption(json, JsonOutput.new),
    SelectableOption(text, TextOutput.new),
  ],
  required: true,
);

ExportCommand()
  : super(selectedOptions: [output]);
```

The exact helper names can change, but preserve these type relationships:

```dart
final class SelectableOption<Value, Result> {
  const SelectableOption(this.option, this.toResult);

  final PairOption<Value> option;
  final Result Function(Value value) toResult;
}

final class SelectedOptions<Result> extends Input<Result> {
  // members and required metadata
}
```

For an optional group, `valueOf(output)` returns `R?`. For a required group,
command code uses `require(output)`. If the caller wants an explicit “nothing
selected” case rather than `null`, allow an optional `whenAbsent` mapper in a
later change; do not complicate the first implementation until a real caller
needs it.

This is a selection result, not a success/failure result. Parse failures should
continue to use Mamba's parse-error path. Do not add a generic `Result` package
or conflate selection with error handling.

### Sealed-class constraint in Dart

Dart cannot express “the generic argument must be declared `sealed`” as a
generic bound. `sealed` controls where subtypes may be declared and enables
exhaustiveness analysis; it is not a supertype that can appear in
`R extends ...`.

Therefore:

- type `SelectedOptions` as `SelectedOptions<R extends Object>`;
- let the user define and own `R`;
- recommend a sealed base class when exhaustive pattern matching is wanted;
- do not add mirrors, annotations, code generation, or a marker interface just
  to pretend the sealed modifier is enforced;
- do not add a runtime check—the property is relevant to static analysis and
  is not part of Mamba's runtime parsing invariant.

A marker interface would only prove that a type implements the marker. It would
not prove that the user's result hierarchy is sealed, and it would not make a
switch exhaustive.

### Parser semantics

- Optional `SelectedOptions`: accept zero or one member.
- Required `SelectedOptions`: accept exactly one member.
- Reject two occurrences of different members.
- Decide and test repeated occurrences of the same member. Recommended:
  reject them unless that member is explicitly repeatable, then collect its
  typed list and invoke its mapper once.
- Apply the selected member's existing value validation before calling
  `toResult`.
- Invoke only the selected member's mapper.
- Store the mapped `R` under the `SelectedOptions<R>` handle, not under a
  string result key.
- Keep individual member presence internal unless a demonstrated use case
  requires exposing it.

### Registry, help, and completion migration

- Replace `RegistryOption.variant` with group-level selection metadata.
- Replace stringly `mode: 'oneOf'`/`'all'` with a Dart enum internally, only
  serializing strings at integration formats that require them.
- Emit `PairedOptions` as an all-members group.
- Emit `SelectedOptions` as an exclusive selection group.
- Render selected members with `|` and paired members with `&`.
- Preserve the existing required distinction: optional is zero-or-one;
  required is exactly-one.
- Keep Carapace exclusivity output and equivalent shell behavior generated from
  the new group type.

### Tests first

- [ ] `PairedOptions` accepts all members and rejects partial groups.
- [ ] `PairedOptions` no longer has `variant`.
- [ ] Optional `SelectedOptions` accepts no member.
- [ ] Optional `SelectedOptions` maps one selected value to `R`.
- [ ] Required `SelectedOptions` rejects no member.
- [ ] `SelectedOptions` rejects multiple different members.
- [ ] The selected mapper receives the correct typed value.
- [ ] Unselected mappers are never invoked.
- [ ] A command can exhaustively switch over its user-defined sealed result.
- [ ] Registry records distinguish paired and selected groups.
- [ ] Help uses `&` for pairs and `|` for selections.
- [ ] Bash, Zsh, Fish, PowerShell, and Carapace tests retain exclusivity.
- [ ] Existing `variant: true` tests are migrated rather than duplicated.

---

## 4. Return exit codes and post-hook failures

### Result interface

Every execution result should expose an exit code. Success always reports zero;
failure always reports a non-zero value.

```dart
sealed class MambaExecutionResult {
  const MambaExecutionResult();

  int get exitCode;
}

final class MambaSuccessResult extends MambaExecutionResult {
  const MambaSuccessResult(this.output);

  final String? output;

  @override
  int get exitCode => 0;
}

final class MambaFailureResult extends MambaExecutionResult {
  MambaFailureResult({
    required this.exitCode,
    required List<MambaExecutionError> errors,
    this.output,
  }) : errors = List.unmodifiable(errors) {
    if (exitCode == 0) {
      throw ArgumentError.value(exitCode, 'exitCode', 'must be non-zero');
    }
    if (errors.isEmpty) {
      throw ArgumentError.value(errors, 'errors', 'must not be empty');
    }
  }

  @override
  final int exitCode;
  final String? output;
  final List<MambaExecutionError> errors;
}
```

Retain `message` as a convenience getter during migration if existing callers
need it. It should render the first error's user-facing message rather than
exposing an exception type name.

A failure may retain command output when `run` succeeded but cleanup failed.
This matches production behavior, where useful stdout must not disappear merely
because a later hook reported a failure.

### Phase-tagged errors

Do not flatten several cleanup failures into one exception. Preserve each error
and the phase that produced it:

```dart
enum MambaExecutionPhase {
  parse,
  prePersistentRun,
  preRun,
  run,
  postRun,
  postPersistentRun,
}

final class MambaExecutionError {
  MambaExecutionError({
    required this.phase,
    required this.exception,
    required this.stackTrace,
    required List<String> commandPath,
  }) : commandPath = List.unmodifiable(commandPath);

  final MambaExecutionPhase phase;
  final MambaException exception;
  final StackTrace stackTrace;
  final List<String> commandPath;
}
```

Capture stack traces with `catch (exception, stackTrace)`. Convert an ordinary
`Exception` to `MambaException` at one execution seam while retaining the phase
and stack trace. Continue allowing non-`Exception` `Error` objects to propagate
unless the framework deliberately changes that policy in a separate decision.

Make `commandPath` immutable. It gives nested hook failures enough context for
a production renderer without baking rendered text into the result.

### Exit-code source and aggregation

Add an optional exit code to recoverable Mamba exceptions while preserving the
existing call shape:

```dart
class MambaException implements Exception {
  MambaException(this.message, {this.exitCode = 1}) {
    if (exitCode < 1 || exitCode > 255) {
      throw ArgumentError.value(
        exitCode,
        'exitCode',
        'must be between 1 and 255',
      );
    }
  }

  final String message;
  final int exitCode;
}
```

Rules:

- Keep `1` as the compatibility default.
- Reject zero on failure; validate the supported portable range during
  construction.
- Preserve a `MambaException`'s requested exit code.
- Convert an ordinary `Exception` to exit code `1`.
- When several errors occur, the first error in execution order determines the
  result's exit code. Later hook errors remain in `errors`.
- Production execution sets Dart's process `exitCode` from the returned result
  rather than assigning `1` independently.

Do not sum codes, use the last code, or let cleanup failures replace an earlier
parse/command failure's code.

### Hook lifecycle

The fake and production executors must call one shared execution implementation
and observe the same hook behavior.

- Track which pre-hooks completed successfully.
- Run the matching post-hooks for completed pre-hooks even when command
  execution fails.
- Run persistent post-hooks in reverse order.
- A failing post-hook must not prevent the remaining eligible post-hooks from
  running.
- Collect every post-hook failure in execution order.
- Return `MambaFailureResult` when command execution succeeded but any post-hook
  failed.
- Preserve successful command output on that failure result.
- Do not run a post-hook when its corresponding pre-hook did not complete.

This replaces the current fake-executor exception where post-hooks are skipped.
Tests avoid side effects through injected command dependencies, not through a
different lifecycle.

### Production rendering

Keep result collection separate from terminal rendering:

- successful output goes to stdout;
- retained output from a cleanup failure also goes to stdout;
- each collected execution error is rendered once to stderr;
- process exit code comes from `result.exitCode`;
- framework exception class names are not part of default user-facing output;
- verbose/debug rendering may include phase, command path, and stack trace.

### Tests first

- [ ] Success results expose exit code zero.
- [ ] Parse and command failures expose the originating non-zero exit code.
- [ ] Ordinary exceptions use exit code one.
- [ ] Failure results reject exit code zero and an empty error list.
- [ ] A single post-run failure produces a phase-tagged failure result.
- [ ] Several failing post-hooks are all collected in execution order.
- [ ] Persistent post-hooks continue after an earlier post-hook failure.
- [ ] Persistent post-hooks run in reverse order.
- [ ] A command failure retains its exit code when cleanup also fails.
- [ ] A cleanup-only failure uses the first cleanup error's exit code.
- [ ] Successful command output is retained when cleanup fails.
- [ ] Post-hooks run in both fake and production execution.
- [ ] Post-hooks run after command failure only for completed pre-hooks.
- [ ] A failed pre-hook does not trigger its unmatched post-hook.
- [ ] Production writes every collected error and applies the result exit code.
- [ ] Default error rendering omits Dart/Mamba exception class names.

---

## 5. Migration checklist

### Core modules

- [ ] Add the non-generic metadata interface and generic `Input<T>` handle.
- [ ] Replace name-keyed parsed maps with identity-keyed `ParsedInputs`.
- [ ] Add `CommandInvocation` as the first command execution parameter and the
  shared hook input.
- [ ] Validate values after `--`, then pass them as the second `Command.run`
  parameter named `args`.
- [ ] Preserve variadic declarations, registry metadata, help, completion, and
  parser validation while keeping their values outside `CommandInvocation`.
- [ ] Preserve list registration through the existing `Command` and
  `GroupCommand` constructors.
- [ ] Add only the `selectedOptions:` constructor collection needed to register
  the new group type.
- [ ] Return registered enum members from every choice input.
- [ ] Migrate positionals and accessor leaves to typed handles.
- [ ] Add `unique` to `RepeatableChoiceOption<T>`.
- [ ] Make `PairOption` generic over its parsed value.
- [ ] Add `SelectableOption<Value, Result>` and `SelectedOptions<Result>`.
- [ ] Remove `PairedOptions.variant`.
- [ ] Split pair validation from selection validation in the parser.
- [ ] Add `exitCode` to the execution-result interface and recoverable errors.
- [ ] Add phase-tagged `MambaExecutionError` values with immutable command paths.
- [ ] Refactor execution into one lifecycle that accumulates eligible post-hook
  failures without stopping later cleanup.
- [ ] Remove the fake executor's special case that skips post-hooks.

### Public consumers

- [ ] Update `Command.run` to receive
  `(CommandInvocation invocation, List<String> args)`.
- [ ] Update `HookRunner` and `PersistentHookRunner` to receive the shared
  invocation without changing command registration.
- [ ] Update `CompletionCommand` without exposing runtime typed values in the
  serializable registry record.
- [ ] Update `example/example.dart` to demonstrate typed handles and an
  exhaustive sealed selection result.
- [ ] Update `fixtures/rig/rig.dart`, especially manual exclusivity checks that
  can become `SelectedOptions`.
- [ ] Update generated command scaffolding.
- [ ] Update production result rendering to preserve stdout, render every
  collected error to stderr, and apply the reported exit code.
- [ ] Update fake-executor callers to inspect `errors`, `output`, and
  `exitCode`.
- [ ] Add a migration section to the changelog when implementation begins.

### Quality gates

Follow red-green-refactor for each vertical slice rather than changing all
input classes before restoring the suite.

- [ ] `dart format .`
- [ ] `dart analyze --fatal-infos`
- [ ] `dart test`
- [ ] Regenerate and verify all checked-in completion fixtures.
- [ ] Add compile-time examples that fail if a command expects the wrong input
  type; use analyzer tests if ordinary unit tests cannot express this.

## Explicit non-goals for the first pass

- Replacing constructor/list registration with a getter, builder, annotation,
  or generated command definition.
- Enforcing Dart's `sealed` modifier through runtime machinery.
- Adding an external success/failure `Result` dependency.
- Adding code generation solely for typed input access.
- Moving validated variadic values into `CommandInvocation` or `ParsedInputs`.
- Supporting dynamic completion as part of this refactor.
- Generalizing `unique` to every repeated input before there is a concrete use
  case.
