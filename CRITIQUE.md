# Mamba critique

Date: 2026-03-27

## Executive summary

Mamba has a strong foundation for type-safe Dart CLI development: command inputs are declared once, declaration identity is retained, availability is represented in output types, enum values remain enums, and execution can be tested without writing to process streams.

The framework does not yet get everything right. Several parsing and registry regressions should block the 0.5.0 release, and the type-safe model currently stops at Mamba's built-in value types. The most important product opportunity is user-defined typed conversion without annotations or code generation.

## What Mamba gets right

- A declaration is both parser metadata and a typed lookup handle.
- Input identity prevents same-named or same-typed declarations from sharing values accidentally.
- Required, optional, and defaulted declarations express availability through Dart types.
- Choice inputs return enum members instead of strings.
- Paired options map related values into one cohesive result.
- Selected options represent mutual exclusion separately from all-or-nothing pairing.
- Constructor-based registration avoids global command wiring, annotations, and generated code.
- `Executor.fake()` returns structured results instead of forcing output or process termination.
- Registry metadata drives parsing, help, and completion from the same definitions.

These choices address common complaints about schema drift, global state, duplicated parsing logic, and difficult tests.

## Release-blocking correctness issues

### Option values can select commands

`CommandRegistry.registryForArguments()` examines every argument for child command names without skipping registered named inputs and their values (`lib/registry.dart:299`).

Given a `deploy` subcommand, this invocation can execute it accidentally:

```text
tool --target deploy
```

Here, `deploy` belongs to `--target`; it is not a command token. This contradicts the documented resolution process in `docs/src/content/docs/reference/architecture.md:70`.

**Required correction:** command-path resolution must understand token consumption, including long options, inline values, short aliases, flag bundles, `--`, and inherited inputs.

### `defaultCommandPath` is ignored

`Executor` accepts and stores `defaultCommandPath` (`lib/executor.dart:96`, `lib/executor.dart:113`), but execution never reads it. An empty invocation renders root help rather than executing the configured default command.

The behavior is advertised in `README.md:232` and `docs/src/content/docs/reference/executor.md:102`.

**Required correction:** validate and resolve the configured path during executor construction, then apply it when parsing selects no explicit command.

### Ambiguous short aliases are accepted

Registry validation checks long names but does not reject duplicate or malformed short aliases (`lib/registry.dart:590`). For example, two options can both register `short: 'x'`; parsing then selects whichever declaration appears first.

This violates the architecture's promise that input namespaces are validated before parsing (`docs/src/content/docs/reference/architecture.md:54`).

**Required correction:** validate short spelling format and uniqueness across applicable flags, options, paired members, and selected members. Any intentional inherited-shadowing rule must be explicit and tested.

## Type-safety limitation

### Unknown optional handles silently return `null`

`ParsedInputs.valueOf()` only rejects an absent declaration identity when its output type is non-nullable (`lib/command.dart:1242`). A newly constructed optional handle that was never registered therefore returns `null`:

```dart
invocation.valueOf(StringOption('name'));
```

The result is indistinguishable from an omitted registered option. This masks declaration-identity mistakes at runtime and weakens the central safety claim.

**Required correction:** distinguish known-but-omitted declarations from unknown declarations. Possible designs include storing every registered optional declaration with `null`, or retaining a separate identity set alongside parsed values. Every unknown handle should fail clearly.

## Missing type-safe capabilities

### User-defined value conversion

Mamba supports strings, integers, doubles, and enum choices. `Input<T>` is sealed and concrete declarations are closed, so applications cannot declaratively define domain inputs such as:

```dart
Option<Uri>
Option<DateTime>
Option<Duration>
Option<ProjectId>
```

Users must parse these values inside `Command.run`, which moves validation past the parser boundary and weakens the promise that commands receive validated values.

**Recommendation:** introduce a declarative converter abstraction such as `ValueParser<T>` that:

- converts one untrusted token into `T`;
- reports a structured validation error;
- provides metadata for help and completion;
- works with optional, required, defaulted, and repeatable declarations; and
- does not require annotations, mirrors, or code generation.

This is the highest-value capability missing from the type-safe design.

### Scalar defaults

Defaulted choices exist, but corresponding factories are missing for ordinary strings, integers, doubles, and repeatable options.

Desired examples:

```dart
final host = StringOption.withDefault(
  'host',
  defaultValue: 'localhost',
);
final retries = IntOption.withDefault(
  'retries',
  defaultValue: 3,
);
```

Defaults should participate in registry validation and produce non-null output types.

### Required and defaulted accessor leaves

Accessor strings, integers, and doubles are always optional. Configuration-oriented commands need required and defaulted leaves while preserving typed lookup through the leaf identity.

### General input relationships

Paired and selected options model two relationships, but real command surfaces also need declarative constraints such as:

- one input requires another;
- two inputs conflict;
- at least one member is required;
- exactly a given number of members is required;
- a requirement depends on another parsed value.

These rules should be represented as registry metadata and validated before command execution, not implemented manually in handlers.

### Custom validation

Regex, numeric ranges, steps, and enum membership do not cover domain validation. Applications need validators that return actionable, structured failures without throwing arbitrary exceptions.

## Developer-experience gaps

### Repetitive value extraction

Typed handles are safer than string-keyed maps, but handlers still perform one lookup for every declaration:

```dart
final sourceValue = invocation.valueOf(source);
final formatValue = invocation.valueOf(format);
```

Mamba should investigate an optional aggregation or binding API that reduces this repetition while preserving constructor registration and avoiding code generation. The simple handle API should remain available as the transparent baseline.

### Parse diagnostics

Useful additions include:

- suggestions for misspelled commands and options;
- structured parse error kinds;
- the offending token and token index;
- command-scoped usage accompanying an error; and
- consistent errors for long, short, inline, and bundled spellings.

### Dynamic completion

Static registry metadata handles finite choices, but practical tools need contextual completion for paths, Git branches, service names, package names, and values dependent on another option.

A completion provider should be shell-independent, receive parsed context safely, and be testable without invoking a shell.

Unique repeated-choice filtering also appears to be implemented meaningfully only for Fish (`lib/integrations.dart:1165`). Bash, Zsh, PowerShell, and Carapace behavior should be implemented where reliable and covered independently.

### Environment and configuration sources

Many applications resolve inputs with precedence similar to:

```text
command line > environment > configuration file > declaration default
```

Mamba currently models command-line tokens. Supporting additional value sources could be valuable, provided provenance and availability remain explicit and the core parser stays small.

### Process-boundary abstraction

Production execution uses global stdin, stdout, stderr, and process exit state. `Executor.fake()` provides a good testing path, but an injectable process/I/O boundary would improve embedding and integration testing.

## Validation and testing concerns

The current automated commands pass, but they do not cover the release-blocking behaviors above. Temporary regression tests confirmed all three failures:

1. an option value matching a child name selects and executes that child;
2. an empty invocation ignores `defaultCommandPath`; and
3. duplicate short aliases survive registry construction.

This conflicts with the repository requirement that behavior be covered before shipping. Every correction should begin with a failing behavior-focused test. Registry tests should cover both local declarations and inherited command surfaces.

The package description in `pubspec.yaml` is also stale: it calls Mamba a parser with "typed map inputs," although public map-based consumption was removed.

## Developer sentiment from Reddit

Qualitative Reddit discussions repeatedly identify these CLI framework frustrations:

- global state and registration boilerplate;
- configuration schemas drifting from handler types;
- difficult testing when parsers own process I/O or exit;
- code-generation and macro opacity;
- framework weight, compile time, and dependency cost;
- generated help that is difficult to customize; and
- weak runtime validation hidden behind attractive static types.

Representative discussions:

- [Go for CLI tools](https://www.reddit.com/r/golang/comments/1nnw74t/go_for_cli_tools/)
- [Go dependency wiring discussion](https://www.reddit.com/r/golang/comments/1ntf1bs/)
- [Rust CLI framework discussion](https://www.reddit.com/r/rust/comments/1i5np88/)
- [Rust CLI parser trade-offs](https://www.reddit.com/r/rust/comments/1bs7f83/)
- [TypeScript end-to-end CLI inference](https://www.reddit.com/r/typescript/comments/1sx37tj/tanstack_routerstyle_endtoend_inference_for/)
- [Dart CLI framework discussion](https://www.reddit.com/r/dartlang/comments/1ljeqjp/)

This evidence is anecdotal rather than a representative survey. It nevertheless suggests that Mamba's no-code-generation typed handles and fake executor are strong differentiators. Predictable parsing, eager ambiguity detection, and domain-type conversion are necessary to make that positioning credible.

## Recommended sequence

### Before releasing 0.5.0

1. Correct command-path token consumption.
2. Restore `defaultCommandPath` execution and validation.
3. Restore complete registry namespace validation.
4. Reject unknown optional declaration handles.
5. Add focused regression tests for all four behaviors.
6. Update the package description and any stale migration language.

### Next type-safety milestone

1. Design user-defined `ValueParser<T>` conversion.
2. Apply it consistently to singular, repeatable, paired, selected, positional, variadic, and accessor declarations.
3. Add scalar default factories.
4. Add structured validation errors.
5. Prove the model with `Uri`, `Duration`, and one application-owned value type.

### Later framework capabilities

1. General input relationships.
2. Dynamic completion providers.
3. Composable help and error rendering.
4. Environment/configuration value sources.
5. Injectable process and I/O boundaries.

## Product position

Mamba should not attempt to win by accumulating every feature found in mature frameworks. Its clearest position is:

> Declare an input once, validate it once, and consume its exact Dart or domain type without global registration or code generation.

The current architecture supports that direction. Correctness and extensible domain conversion are the two requirements that remain before the claim is fully realized.
