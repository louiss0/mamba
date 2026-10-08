---
title: Options
description: Define typed named inputs in Mamba
---

Options are named inputs that take values. Register ordinary options in
`Command.options`, `Executor.options`, or `GroupCommand.propagatedOptions`.
Register paired and selected groups in their corresponding command lists.
Accessor options are registered as trees.

Long options accept `--name value` and `--name=value`. A one-letter `short`
alias accepts `-n value` and `-n=value`. A flag-only prefix may precede one
final value-taking short: `-vo=file`. Everything after the first `=` is the
value, including empty text and additional equals signs. `-ofile` and `-vo file`
remain unsupported. Separate-form string supply cannot start with a dash other
than a lone `-`; use inline supply for literal option-looking values.

## Output availability

An option declaration determines the exact type returned by `valueOf`.
Ordinary options are optional by default:

```dart
final label = StringOption('label');
final String? labelValue = valueOf(label);
```

Use `.required` when the user must provide the option:

```dart
final output = StringOption.required('output');
final String outputValue = valueOf(output);
```

Choice options use `.withDefault` when omission supplies a fallback:

```dart
final format = ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
final OutputFormat formatValue = valueOf(format);
```

The ordinary constructors no longer accept `required` or `defaultValue`
modifiers because runtime booleans cannot change a declaration's static output
type.

## Single-value options

### `StringOption`

Accepts every supplied `String` by default, including empty strings and
whitespace. Requiredness checks supply, not content. An explicit `regex` checks
the entire value and any configured defaults.

```dart
StringOption('label', short: 'l');
StringOption.required('output', short: 'o');
```

### `IntOption`

Parses a signed decimal `int`. `min` and `max` define inclusive bounds.

```dart
IntOption('retries', min: 0, max: 5);
IntOption.required('port', min: 1, max: 65535);
```

### `DoubleOption`

Parses a signed decimal `double`. `min` and `max` define inclusive bounds. A
`step` requires finite bounds and restricts accepted values to increments from
`min`.

```dart
DoubleOption('ratio', min: 0, max: 1, step: 0.25);
DoubleOption.required('amount', min: 0);
```

### `ChoiceOption<T>`

Accepts an offered enum choice spelling and returns the actual enum member.
Ordinary enums use member names. Implementing `MambaEnumValue` opts in to exact
`value` spellings, with no implicit member-name aliases.

```dart
ChoiceOption<OutputFormat>('format', choices: OutputFormat.values);
ChoiceOption.required('format', choices: OutputFormat.values);
ChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
```

Generic factories infer their type from `choices` and `defaultValue`.

## Repeatable options

Repeatable options append every occurrence to an ordered list:

```console
mamba build --tag stable --tag public
```

```dart
RepeatableStringOption('tag');             // List<String>?
RepeatableStringOption.required('tag');    // List<String>
RepeatableIntOption('port');               // List<int>?
RepeatableIntOption.required('port');      // List<int>
RepeatableDoubleOption('ratio');           // List<double>?
RepeatableDoubleOption.required('ratio');  // List<double>
```

`RepeatableChoiceOption<T>` returns enum members. With `unique: true`, a
repeated member is rejected rather than silently deduplicated.

```dart
RepeatableChoiceOption<OutputFormat>(
  'format',
  OutputFormat.values,
  unique: true,
);
```

## Paired options

`PairedOptions<T>` requires all members together when any member is supplied
and maps the complete set into an immutable `Map<String, T>`:

```dart
final host = PairStringOption('host');
final password = PairStringOption('password');
final credentials = PairedOptions<String>([host, password]);

final values = valueOf(credentials);
// --host db.internal --password mamba produces
// {'host': 'db.internal', 'password': 'mamba'}
```

The ordinary group is omittable and produces an empty `Map<String, T>`.
`PairedOptions<T>.required` requires the complete group.

## Selected options

`SelectedOptions<T>` maps every supplied pair option into an immutable
`Map<String, T>`. The pair option name is the map key:

```dart
final json = PairStringOption('json');
final text = PairStringOption('text');
final output = SelectedOptions<String>([json, text]);

final values = valueOf(output);
// --json tasks.json produces {'json': 'tasks.json'}
```

Use `SelectedOptions<T>.required(...)` when at least one member must be
supplied. Set the `single` option on either constructor to limit the group to
one selection:

```dart
final optionalFormat = SelectedOptions<String>(
  [json, text],
  single: true,
);
final requiredFormat = SelectedOptions<String>.required([
  json,
  text,
], single: true);
```

The normal form accepts zero or one member. The required form accepts exactly
one member. Without an explicit type argument, Dart infers the common
pair-value type; mixed pair types infer `Object`.

## Accessor options

Accessor lists group dotted paths such as `--server.host`:

```dart
final host = AccessorStringOption('host');
final format = AccessorChoiceOption.withDefault(
  'format',
  choices: OutputFormat.values,
  defaultValue: OutputFormat.text,
);
final server = AccessorListOption('server', [host, format]);
```

Accessor leaves are omittable only when the declaration says so. An
`AccessorStringOption` leaf is omitted when it is not supplied; a
`.required` leaf must be supplied or the invocation is rejected; a
`.withDefault` leaf is always present. `AccessorListOption` is the typed,
value-producing handle for its complete accessor tree. Nested leaf handles are
readable directly as well as through the top-level declaration:

```dart
final values = valueOf(server);
final String? hostValue = values['host'] as String?;
final OutputFormat formatValue = values['format'] as OutputFormat;
```

Nested accessor lists produce nested immutable maps, so an option such as
`--server.auth.token secret` is available below `valueOf(server)`.
Every nested accessor container remains readable, even when all its optional
leaves are absent. Compatible overrides must explicitly preserve every ancestor
path with the same output type; ancestor handles read the effective local data.
Accessor trees registered on `Executor` are global and can be read by every
command through the same top-level declaration handle. Accessors registered
on a command remain local to that command.

## Conflicting inputs

`Command.conflicts` rejects incompatible named inputs before the command runs.
Each map key conflicts with every name in its list. Keys and list entries must
name a flag, ordinary option, paired or selected option member, or an accessor
leaf. Accessor leaves use their dotted spelling.

```dart
final class DeployCommand extends Command {
  new()
    : super(
        flags: [replace],
        options: [output],
        conflicts: {
          'replace': ['output'],
        },
      );

  static const replace = BooleanFlag('replace');
  static final output = StringOption('output');

  @override
  String get name => 'deploy';

  @override
  String get shortDescription => 'Deploy the application.';

  @override
  String run(ValueOf valueOf, List<String> args) => 'Deployed.';
}
```

Conflicts concern explicit CLI occurrences, including explicitly negated flags,
not defaults or truthiness. References may name applicable global, propagated,
grouped, and dotted-leaf inputs. Edges inherit only while their original endpoint
identities remain applicable, including compatible overrides; unrelated same-name
local inputs do not revive them. Explicit-occurrence tracking remains internal.
`valueOf` reads resolved values; it exposes no presence query. Effective-value
rules belong to application code.
The conflict map is not an `Executor` configuration option.

## Shared metadata

`description` supplies help text. `hidden: true` keeps ordinary options
parseable while omitting them from help. Registry records retain required,
default, range, repetition, and group metadata for help and completion
converters.

## Enum-owned choice spellings

Enums implement the interface; ordinary enums need no migration. Offered
spellings are exact and case-sensitive, may contain whitespace or be empty,
and must be unique within each declaration's offered choices. Repeating the
same member is also invalid. Unoffered members do not invalidate a narrowed set.
Use inline option supply for dash-leading choice strings.

```dart
enum const WireFormat(@override final String value) implements MambaEnumValue {
  jsonLines('json-lines'),
  text('text');
}

final wireFormat = ChoiceOption<WireFormat>(
  'wire-format',
  choices: WireFormat.values,
);
```

`--wire-format=json-lines` returns `WireFormat.jsonLines`;
`--wire-format=jsonLines` is rejected. Typed defaults, help, registry records,
completion, accessors, groups, positionals, and trailing choice validation all
use the same spelling interpretation.
