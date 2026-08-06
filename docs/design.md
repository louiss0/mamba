# Architecture and design decisions

This document explains the implementation in `lib/src/arg_parser_base.dart`,
the alternatives considered, and the Dart-specific reasoning behind the public
API and parser internals.

## 1. Problem interpretation

The parser has three defining requirements:

1. Parse conventional flags, string options, and positional arguments.
2. Treat a dotted option such as `--user.name=Ada` as object-shaped data,
   declared through a matching nested schema.
3. Select a command before options belonging to that command become active.

The third requirement means this is not only a token decoder. It is a parser
for a command tree. The second requirement means dotted CLI flags are not
merely unusual spellings: they affect the shape and validation of the result.

Those two requirements drove the architecture. Conventional spellings such as
`--output value`, `--output=value`, `-o value`, negated flags, short clusters,
and `--` are supported around that core.

## 2. Why the model is inspired by Yargs

The first implementation followed Dart's `package:args` mutable builder API.
That was familiar to Dart developers, but it made this package look like a
reimplementation of an existing package and did not make accessor options the
center of the design.

The replacement uses the parts of Yargs that align directly with this problem:

- options are declared as a nested schema that mirrors result objects;
- nested schema containers become nested values while leaves define options;
- a command activates a command-local schema;
- global options remain active in the selected command branch;
- the result is one merged argument object rather than a linked list of result
  objects, one per parser.

This is inspiration rather than a direct port. JavaScript's Yargs returns a
dynamic object and commonly combines parsing with command handlers. This Dart
library uses explicit schema classes, a sealed success/failure result, and
nullable typed accessors. It currently remains a parser rather than an
execution framework.

### Alternatives considered

#### Dart `package:args`

Its builder is idiomatic and established, but copying `addFlag`, `addOption`,
`addCommand`, and nested `ArgResults.command` would add little value. Dotted
object paths are also not the organizing idea of that API.

#### Rust `clap`

`clap` has an excellent typed, immutable command model. Its derive API relies
on Rust's compile-time type and attribute system, however. Reproducing that
experience in Dart would require code generation or a substantially more
verbose generic API. That would be disproportionate for this package's current
scope.

#### Java `picocli`

Command objects and reusable option groups are attractive, but picocli's
annotation-oriented model maps less naturally to a small dependency-free Dart
library. Reflection-heavy designs are also a poor default for Dart programs
that may be compiled ahead of time, and `dart:mirrors` is not generally
available across Dart's deployment targets.

## 3. Public schema model

The public schema consists of:

- `ArgOption`, the sealed option category;
- `BooleanOption` and `StringOption`, its concrete option kinds;
- `ArgPositional`, an ordered positional declaration;
- `ArgCommand`, a command branch containing ordinary options, accessor trees,
  positionals, or children;
- `ArgParser`, which validates and compiles the root schema.

A typical declaration is:

```dart
final parser = ArgParser(
  options: {
    'verbose': const BooleanOption(alias: 'v'),
  },
  commands: [
    ArgCommand(
      'create',
      accessors: {
        'user': {
          'name': const StringOption(required: true),
          'admin': const BooleanOption(),
        },
      },
      positionals: const [
        ArgPositional('workspace', required: true),
      ],
    ),
  ],
);
```

### Why schemas are constructor data instead of mutation

A constructor shows the entire command tree in one expression. The parser can
validate that tree once, before user input is handled. A mutable builder allows
partially configured states and makes it easier for duplicate aliases or path
conflicts to appear late.

Dart named parameters make declarative constructors readable without requiring
a separate configuration language. `const` option and positional declarations
also avoid allocations when their values are compile-time constants.

### Why ordinary options and accessor trees are separate

`options` is `Map<String, ArgOption>`. It contains ordinary, directly passable
options such as `--verbose` and `--format`. Every key is exactly one identifier
segment; dots are rejected.

`accessors` is `Map<String, Object>`, representing an object tree. A map entry
whose value is an `ArgOption` is a passable leaf; an entry whose value is
another map is an object container:

```dart
accessors: {
  'user': {
    'address': {
      'city': const StringOption(),
    },
  },
},
```

The split expresses the two concepts in Dart's type system and makes it clear
that `user` is structural, not a root option. It cannot accidentally become
`--user`; only leaves are flattened internally into long names such as
`user.address.city`. `Object` is necessary only at the accessor-map boundary
because those values are deliberately heterogeneous: they can be an
`ArgOption` leaf or another map.

### Why commands and positionals are lists

Command and positional declarations are entities with their own names, so they
are represented as objects. Positional order is semantically significant,
which requires a list. Commands are also accepted as a list so each command can
own its canonical name and aliases together. Compilation converts commands to
maps for efficient lookup.

### Why aliases and choices are sets

Both collections represent uniqueness rather than order. `Set<String>` makes
that intent explicit and prevents duplicate values from being stored.

### Why there are separate Boolean and string option classes

The option hierarchy is sealed, and its implementations are final. Dart can
therefore check switches over `ArgOption` exhaustively. The parser does not
need a default branch that could hide a newly added option kind.

Concrete classes also keep configuration clear:

```dart
const BooleanOption(negatable: false)
const StringOption(choices: {'json', 'text'})
```

A generic `ArgOption<T>` would not remove runtime branching because all parsed
values eventually share one heterogeneous argument object. It would make the
schema noisier without providing end-to-end static typing.

### Why only Boolean and string options exist now

These are the primitive forms required to model flags and ordinary CLI values.
Numeric, enum, path, repeated, and custom-converter options can later become
additional final subclasses. The sealed hierarchy and exhaustive switches
make such an extension visible at every implementation point.

## 4. Immutability and snapshotting in Dart

Dart's `final` prevents reassigning a variable; it does not make a collection's
contents immutable. The implementation accounts for that in two places.

`ArgCommand` copies its top-level aliases, ordinary options, accessor trees,
positionals, and child commands using `Set.unmodifiable`, `Map.unmodifiable`,
and `List.unmodifiable`. `ArgParser` then recursively walks accessor maps,
compiles a private schema tree, and snapshots each option. In particular, a
mutable `choices` set is copied before parsing can occur.

This decision guarantees that changing an input collection after parser
construction does not silently change parser behavior:

```dart
final choices = {'text'};
final parser = ArgParser(
  options: {'format': StringOption(choices: choices)},
);
choices.add('json');

// `json` is still invalid for this parser instance.
```

Successful results are also deeply frozen. Nested maps and captured positional
lists are recursively wrapped before being exposed. A caller can safely pass
`ArgArguments` to another part of a program without that program changing what
was parsed.

## 5. Schema compilation and validation

`ArgParser` compiles public declarations into private `_SchemaNode` and
`_RegisteredOption` objects. This is intentionally separate from token
parsing. Configuration mistakes are found once rather than on every parse.

### Why configuration errors throw

An invalid schema is a programming error, not bad command-line input. Examples
include duplicate aliases, an impossible positional order, and a default value
outside its configured choices. Throwing `ArgumentError` during parser
construction fails close to the faulty declaration.

Malformed tokens come from an end user and follow a different path: they are
returned as `ArgParseFailure`. This separates developer defects from expected
runtime validation failures.

### Nested-schema and path validation

Every nested-map key is one identifier segment, so public schemas cannot use
dotted keys. A container has to contain at least one option leaf, and every
leaf must be an `ArgOption`. This prevents malformed or root-passable object
schemas such as `{'user': null}`.

The compiler flattens leaves to private paths and rejects active paths where
either is a prefix of the other. This can occur across command levels:

```dart
// Root:
options: {'user': const StringOption()}

// Selected child:
accessors: {'user': {'name': const StringOption()}}
```

The root leaf would need `user` to be a scalar while the child needs it to be a
map. Rejecting the schema prevents order-dependent behavior or silent data
loss. Siblings such as `user.name` and `user.admin`, created by the same
nested `user` map, merge safely.

Path conflicts are checked across ancestor and selected-command options, not
between unrelated sibling commands. Sibling command schemas are never active
at the same time, so they may safely reuse names and aliases.

### Alias validation

Short aliases are one character because the parser supports clusters such as
`-vf`. Aliases must be unique across every simultaneously active ancestor and
child schema. Otherwise the same token could have two meanings after selecting
a command.

### Positional validation

Positionals obey three structural rules:

1. names are unique;
2. a required positional cannot follow an optional one;
3. a variadic positional must be last.

Without these rules, the same token sequence could have multiple valid
bindings. Positional names also cannot conflict with active option paths
because both are merged into one result object.

A node cannot declare both child commands and positionals. A bare token at such
a node would be ambiguous: it could be a command name or the first positional.
Grouping nodes therefore select children, while leaf nodes bind positionals.
This keeps command selection deterministic.

## 6. Command activation

Parsing is recursive. Each `_SchemaNode` represents one level of the command
tree.

When the parser enters a node, it combines:

- options inherited from root and parent commands;
- options declared by the current node;
- aliases for those active options;
- values already parsed at earlier levels.

The current node's defaults are applied only when that node is entered. As a
result, an unselected sibling contributes neither options nor defaults.

Before a command token is selected, only ancestor options are recognized. For
example, if `--release` belongs to `build`, this is rejected:

```text
--release build
```

This is accepted:

```text
build --release
```

Root and parent options remain active after selection, so both of these work:

```text
--verbose build
build --verbose
```

This matches the useful Yargs concept of global options while preserving the
requirement that command-local options activate only after command selection.

Aliases select the same private node as the canonical name. `commandPath`
stores canonical names so downstream code does not need to handle `remove` and
`rm` as separate commands.

## 7. Token-scanning decisions

The parser accepts a `List<String>` rather than a command string. Shells are
responsible for quoting, escaping, and splitting command lines before invoking
a Dart program. Reimplementing shell tokenization would be platform-dependent
and incorrect for already-tokenized `main(List<String> arguments)` input.

### Long options

Supported forms are:

```text
--output dist
--output=dist
--verbose
--no-color
```

The parser separately records whether `=` was present. This matters because an
explicit empty value is valid and different from a missing value:

```text
--output=   # value is the empty string
--output    # consumes the next token or reports missingValue
```

Boolean flags reject `--verbose=true`; their presence is the value. This avoids
accepting multiple Boolean syntaxes with surprising truthiness rules.

Negation is resolved only when no exact option matches and the positive option
is a negatable `BooleanOption`. This lets an explicitly declared option whose
name starts with `no-` retain its exact meaning.

### Short options

Supported forms include:

```text
-v
-vf
-o dist
-odist
-o=dist
```

Boolean aliases may be clustered. When a string option appears in a cluster,
the remainder belongs to that option and cluster parsing stops. This is the
conventional interpretation of `-vfoarchive.zip`: `v` and `f` are flags, while
`o` receives `archive.zip`.

As with long options, the implementation distinguishes `-o=` from a missing
value so an explicit empty string survives parsing.

### Repeated options

Writing into the flat option map replaces the previous value. Therefore the
last occurrence wins. This is predictable for configuration-style CLI input
and leaves room for a future repeated/list option type with different
semantics.

### The `--` terminator

After `--`, no token is interpreted as an option. Remaining tokens go through
positional binding or remain in `rest`. If encountered before a required
command, command selection is intentionally disabled and the parser reports a
missing command.

### Trailing options

`allowTrailingOptions` defaults to `true`, matching common modern CLI behavior:

```text
build source.dart --verbose
```

When false, the first positional token ends option parsing for that leaf.
Subsequent dash-prefixed tokens remain positional data.

## 8. Flat parsing and nested results

The parser deliberately keeps two representations.

During scanning, options are stored in a flat map keyed by their exact schema
names:

```dart
{
  'user.name': 'Ada',
  'user.admin': true,
}
```

Flat storage makes option lookup, required checks, repetition, and typed
convenience methods straightforward. It avoids repeatedly traversing and
mutating nested maps while tokens are still being validated.

After parsing succeeds, `_insertNestedValue` materializes the public object:

```dart
{
  'user': {
    'name': 'Ada',
    'admin': true,
  },
}
```

Named positional values are then merged at the top level. Schema validation has
already guaranteed that this cannot overwrite an option object path.

`ArgArguments` keeps the private flat option map for `flag()` and `string()`, a
private positional map for positional accessors, and the public nested `values`
map for object-oriented access. This small duplication keeps each read API
simple and makes successful results immutable.

## 9. Why `Object?` is used instead of `dynamic`

A merged argument object is necessarily heterogeneous: values may be `bool`,
`String`, `List<String>`, or nested maps. `Object?` accurately represents that
boundary while retaining static checking. Unlike `dynamic`, it prevents callers
from invoking arbitrary members without narrowing the value first.

Convenience methods perform that narrowing:

- `flag(name)` returns `bool?`;
- `string(name)` returns `String?`;
- `positional(name)` returns `String?`;
- `positionals(name)` returns `List<String>?`;
- `object(path)` returns `Map<String, Object?>?`.

`value(path)` remains available when callers intentionally need heterogeneous
data. Missing values and type mismatches return `null`, which fits Dart's sound
null-safety model and avoids casts at common callsites.

## 10. Explicit parse outcomes

`ArgParseOutcome` is sealed with two final implementations:

- `ArgParseSuccess`, containing `ArgArguments`;
- `ArgParseFailure`, containing `ArgParseError`.

Dart's pattern matching makes consumption concise and exhaustive:

```dart
switch (parser.parse(tokens)) {
  case ArgParseSuccess(:final arguments):
    run(arguments);
  case ArgParseFailure(:final error):
    report(error);
}
```

Bad CLI input is expected behavior, not an exceptional control path. Returning
it also makes tests and command entry points responsible for deciding how to
report errors and which exit code to use.

`ArgParseErrorCode` provides stable machine-readable categories, while
`message` is suitable for users. `token` and `index` support diagnostics. The
recursive parser carries a `baseIndex` so errors inside nested commands still
report positions in the original argument list rather than positions in a
sliced child list.

Small private result objects, `_OptionParseProgress` and `_BoundPositionals`,
serve the same purpose internally: a helper returns either progress or an
error, and its caller propagates that error immediately.

## 11. Dart language features used deliberately

### Sealed and final classes

The option and outcome families are closed. This enables exhaustive switches
and communicates that consumers should use the supplied variants rather than
subclass core parser states unpredictably.

### Object and record-style patterns

Patterns such as:

```dart
case StringOption(:final defaultValue):
```

both discriminate and extract data. They avoid casts and keep behavior next to
the option kind it handles.

### Null safety

Optional defaults, aliases, error tokens, and typed lookups are represented by
nullable types. Required parser state uses `required` named parameters. The
single `selected.name!` assertion is protected by construction: only command
nodes, whose names are non-null, can be selected from a command map.

### Collection literals and spreads

Maps match option lookup semantics, lists preserve positional and command path
order, and sets model uniqueness. The command path uses a list spread to create
a new immutable-history value at each selected depth.

### Private names

Implementation types begin with `_`, keeping the package surface focused on
schemas, outcomes, and arguments. The implementation is currently colocated in
one Dart library file because Dart privacy is library-scoped. Splitting these
closely coupled internals into separate libraries would either expose
constructors or require `part` files without providing a meaningful public
abstraction boundary.

### No external runtime dependencies

The parser uses only `dart:collection`. This keeps startup and deployment
simple, avoids version conflicts in CLI packages, and works naturally with
both JIT development and AOT-compiled executables.

## 12. Complexity and performance

Schema compilation builds maps for option names, aliases, command names, and
command aliases. Normal token lookup is therefore constant-time on average.
Parsing is linear in the number of input tokens, apart from short-option cluster
length and result materialization.

Accessor conflict validation compares active paths during construction. That
work is quadratic in the number of simultaneously active option declarations,
but CLI schemas are normally small and compilation happens once. The simpler
validation is preferable to a more complex prefix tree until profiling proves
schema construction to be a bottleneck.

The parser does allocate a token sublist at each command depth and copies small
maps when entering a node. Command trees are generally shallow, and these
copies isolate recursive state clearly. Avoiding them prematurely would make
mutation and error indexing harder to reason about.

## 13. Testing strategy

Behavioral tests were written around the public contract. They cover:

- long, short, attached, empty, repeated, and clustered options;
- defaults, choices, required values, and negation;
- snapshotting mutable schema inputs;
- nested option schemas, object-container behavior, and path conflicts;
- activation before and after command selection;
- sibling isolation, aliases, and nested commands;
- named, required, and variadic positionals;
- terminator behavior;
- structured error codes, tokens, and absolute indices.

The tests avoid asserting private helper behavior. This permits refactoring the
scanner or compiled representation without changing the package contract.
`dart analyze` complements the tests by checking null safety, exhaustive
patterns, and lint compliance.

## 14. Intentional limitations and extension points

The current scope intentionally does not include:

- integer, double, enum, path, list, or custom-converter options;
- generated usage/help text;
- command handlers or dispatch;
- environment-variable and configuration-file resolution;
- shell completion generation;
- shell-string tokenization;
- interleaving positionals with subcommands at the same schema node.

These should be added as distinct features rather than hidden in the scanner.
For example, typed conversion belongs in new `ArgOption` subclasses; help text
belongs on schema metadata and a formatter; dispatch can consume
`commandPath` and `ArgArguments` without coupling side effects to parsing.

Keeping parsing deterministic and side-effect free is the main constraint for
future changes. A successful parse should remain an immutable value, and user
input failures should remain explicit outcomes.
