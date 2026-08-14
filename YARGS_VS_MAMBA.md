# Yargs vs. Mamba

This comparison describes the checked-in **Yargs 18.1.0** clone in
[`yargs/`](yargs/) and the current Dart implementation of **Mamba** in
[`lib/`](lib/). It compares implemented behavior, not the intended scope of
older design documents.

## Executive summary

Yargs is a mature, general-purpose JavaScript/TypeScript CLI framework. It
combines token parsing, a mutable fluent configuration API, command dispatch,
help and version output, validation, middleware, configuration/environment
loading, localization, and shell-completion script generation.

Mamba is a smaller Dart CLI library built around declarative schema classes.
It offers typed record conversion, command classes with synchronous handlers,
regular and nested dotted options, flags, positionals, variadics, basic help,
and definition validation. Its most distinctive feature is a schema for
nested **accessor options**, which converts declared inputs such as
`--remote.origin.urls.fetch` into a nested Dart map before the schema converts
it to a record.

Mamba is **not a drop-in port or replacement for Yargs**. It is appropriate
when a Dart program benefits from its schema-to-record model and controlled
input surface. Yargs is substantially more feature-complete for a production
CLI framework, particularly when a CLI needs conventional configuration,
advanced validation, customizable presentation, async lifecycle hooks, or
shell completion.

## Feature comparison

| Area | Yargs (`yargs/`) | Mamba (`lib/`) |
| --- | --- | --- |
| Language and runtime | JavaScript/TypeScript; Node.js, Deno, and browser entry points | Dart package; requires Dart SDK `^3.12.2` |
| Primary API | Mutable fluent builder: `.option()`, `.command()`, `.parse()`, etc. | Declarative `Command`, `*Schema`, and input classes, registered through `Executor`/`CommandRegistry` |
| Parse result | Dynamic `argv` object, including `_` non-options and `$0` | An `Inputs` record whose sections are produced by each schema's `toRecord` |
| Command registration | Command string DSL, object/module forms, aliases, default commands, hidden/deprecated commands, and `commandDir()` module discovery | Statically supplied `Command` instances in a tree; exact command names only |
| Command execution | `.parse()` selects and invokes handlers; supports sync or async builders, middleware, checks, and handlers | `Executor.execute()` selects a command and calls its synchronous `void run(...)` method |
| Option scope | Root options are global by default; command-local options are lazily configured and may be local or global | The parser resolves the selected command registry and parses that registry's declared inputs; it does not merge ancestor schemas into the selected command |
| Boolean and count flags | Boolean, negated Boolean, count, defaults, aliases, parser configuration | `BooleanFlag` (optional negation/default) and `CountFlag`; short-flag clusters are supported |
| Option values | String, number, Boolean, array, count, normalized paths, fixed arity, defaults, coercions, config options, aliases, and parser-level configuration | String (with `RegExp`), integer, double, enum-choice, and repeatable string/integer/double options; schema code performs final Dart conversion |
| Positionals | Required, optional, aliases, and variadic positionals declared in a command string and refined through `.positional()` | Ordered mandatory and discretionary `Positional` declarations plus one regex-validated `Variadic`; variadic values must follow the `--` option terminator |
| Nested/dotted values | Parser dot notation turns dotted keys into object properties; behavior is configurable | Explicit recursive `AccessorListOption` declarations validate every path segment and merge values into a nested map of arbitrary depth |
| Token forms | Delegates comprehensive token syntax to `yargs-parser`, including `--key=value`, short-value forms, `--`, aliases, camel-case expansion, arrays, `narg`, and configurable parsing rules | Supports `--key value`, long flags, option short names with a separate value, flag clusters, and `--` for literal variadic values. It does not implement `--key=value`, configurable parser behavior, or general aliases. |
| Validation | Required options/commands, choices, strict options/commands, conflicts, implications, custom checks, required option values, and near-match command suggestions | Required options, enum choices, regex/numeric validation, positional shape, unknown inputs, and duplicate/invalid declaration checks |
| Help and version | Configurable usage, descriptions, examples, epilogues, option groups, defaults, choices, hidden entries, version output, wrapping, and locale-aware labels | `HelpFormatter` renders ANSI-styled command, description, flags, accessors, options, positionals, and child commands; `Executor` recognizes `-h`/`--help`. No version facility or help-layout configuration is exposed. |
| Errors and process behavior | Configurable failure handler, usage-on-failure, captured callback output, and configurable process exit behavior | Invalid schemas and user input raise Mamba exceptions; `Executor` prints help through an injectable callback but does not define exit-code or stderr policy |
| Middleware and lifecycle hooks | Global/command middleware, per-option coercion, custom checks, synchronous and asynchronous stages | Not implemented |
| Configuration sources | Defaults plus command line, environment prefix, config files/objects, package configuration, and config inheritance | Not implemented |
| Completion | Bash, Zsh, and Fish completion-script generation plus custom synchronous/callback/async candidate providers | Not implemented |
| Localization and presentation | Locale catalogs, auto-detection, terminal-width UI, and output capture | Fixed English labels and ANSI styling through `chalkdart` |
| Distribution | npm package with Node, browser, Deno, and helper exports | pub package exporting the Mamba Dart library |

## What Mamba already covers well

Mamba has a coherent, narrower feature set for a Dart command tree:

- **Schema-to-record conversion.** Each flag, option, positional, and accessor
  schema owns a `toRecord(Map<String, dynamic>)` method, allowing application
  code to receive meaningful Dart records rather than repeatedly reading an
  untyped argument map.
- **Typed input declarations.** Options distinguish strings, integers,
  doubles, enum choices, and repeatable values. Flags distinguish Boolean and
  count semantics.
- **Nested accessor options.** Recursive `AccessorListOption` values make
  deeply nested settings explicit in the schema and produce nested values for
  `toRecord`. This is more strongly declared than merely enabling dot notation.
- **Command tree and basic execution.** `Executor` renders root or selected
  command help, resolves nested commands, and calls the selected command's
  handler.
- **Definition-time checks.** `CommandRegistry.create()` validates names and
  duplicate declarations before parsing.
- **Input validation.** Mamba rejects unregistered inputs, missing values,
  invalid numeric/regex/choice values, missing required options, and invalid
  positional shapes.

## Important capability gaps relative to Yargs

The following are not exposed by the present Mamba implementation:

1. **Command aliases and dynamic command registration.** There is no equivalent
   to Yargs command aliases, default commands, hidden/deprecated commands,
   command modules, or `commandDir()`.
2. **Inherited/global options.** Mamba selects the deepest command registry;
   root and parent options are not automatically active for a child command.
   This differs from Yargs's default global-option model.
3. **Conventional parser forms and configuration.** Mamba has no
   `--option=value`, general option aliases, `narg`, arrays consumed from one
   occurrence, camel-case expansion, or parser-configuration switches. Its
   `--` terminator is reserved for declared variadic values. It also has no
   environment, config-file/object, or package-config integration.
4. **Cross-option validation and custom conversion.** Yargs provides
   implications, conflicts, arbitrary checks, and per-option coercion. Mamba's
   generic validation is limited to individual inputs; application handlers
   must implement cross-field rules.
5. **CLI lifecycle facilities.** Mamba has no middleware, asynchronous command
   execution API, custom failure callback, stdout/stderr routing policy, or
   exit-code policy.
6. **Completion, versioning, localization, and rich help customization.**
   Mamba's help is useful but intentionally basic compared with Yargs's
   formatter, locale catalogs, completion scripts, and version facility.

## Design trade-offs

### Schema-first Dart API vs. fluent JavaScript API

Yargs's fluent API allows applications to build command configuration
programmatically and configure a command only when it is entered. It is broad
and flexible, but its `argv` remains a dynamic object.

Mamba makes the command definition explicit in Dart classes. The schema's
`toRecord` method is an explicit boundary from parsed strings/maps to
application-friendly typed records. The trade-off is more declaration code and
a smaller generic feature set.

### Dotted accessors

Yargs's dot notation is a parser capability: a dotted key can become nested
object data, subject to parser configuration. Mamba's accessor tree is a
first-class schema feature: only declared leaf paths are accepted and nested
choice defaults are merged into the resulting map. For CLIs with
Git-config-style settings, this is Mamba's clearest differentiator.

### Errors

Yargs centralizes framework errors, help, and process exit handling. Mamba
currently uses `MambaParseException` for invalid user input and
`MambaException`/`MambaRegistryError` for definition problems. An embedding
application therefore needs to catch and translate errors into its own stderr
and exit-code policy.

## Recommended positioning

Describe Mamba as:

> A Dart, schema-driven command-line parser and lightweight command runner
> that converts declared CLI inputs—including nested dotted accessor
> options—into typed records.

Avoid positioning it as a full Yargs equivalent. If feature parity is a goal,
the highest-value additions are inherited command-option scopes; aliases and
common token forms; structured parse failures plus an exit/output policy;
cross-option validation and coercion; then completion/configuration and richer
help/version support.

## Source basis

This document was derived from the local source tree:

- Yargs package metadata and public documentation:
  [`yargs/package.json`](yargs/package.json),
  [`yargs/README.md`](yargs/README.md), and
  [`yargs/docs/api.md`](yargs/docs/api.md).
- Yargs implementation structure:
  [`yargs/lib/yargs-factory.ts`](yargs/lib/yargs-factory.ts),
  [`yargs/lib/command.ts`](yargs/lib/command.ts),
  [`yargs/lib/validation.ts`](yargs/lib/validation.ts),
  [`yargs/lib/middleware.ts`](yargs/lib/middleware.ts), and
  [`yargs/lib/completion.ts`](yargs/lib/completion.ts).
- Mamba implementation and behavioral tests:
  [`lib/registry.dart`](lib/registry.dart),
  [`lib/parser.dart`](lib/parser.dart),
  [`lib/executor.dart`](lib/executor.dart),
  [`lib/help_formatter.dart`](lib/help_formatter.dart), and
  [`test/`](test/).
