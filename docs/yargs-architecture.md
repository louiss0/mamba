# How Yargs works as a CLI parser

This is a source-level guide to the cloned Yargs implementation in
[`../yargs`](../yargs). It describes **Yargs 18.1.0** as it exists in this
repository, rather than treating it as a model for the Dart parser.

> **Key distinction:** Yargs is a CLI *framework*, not only a token parser.
> Its `yargs-parser` dependency decodes flags into an object; Yargs adds command
> registration and dispatch, command-local configuration, positionals,
> validation, help/version/error output, middleware, config/env integration,
> localization, and completion.

## Runtime entry point

`yargs/lib/` is TypeScript source. The published entry points
[`yargs/index.mjs`](../yargs/index.mjs), [`yargs/browser.mjs`](../yargs/browser.mjs),
and [`yargs/deno.ts`](../yargs/deno.ts) import compiled files from
`yargs/build/lib/`, then call:

```ts
const Yargs = YargsFactory(platformShim);
```

So `YargsFactory` is the platform-independent composition root. The supplied
platform shim provides process, paths, filesystem access, the `yargs-parser`
parser, terminal formatting, localization, and platform-specific behavior.
An application normally supplies shell-tokenized user arguments (commonly
`hideBin(process.argv)`) to `Yargs(...)` and finishes with `.parse()` or the
legacy `.argv` getter.

`yargs/build/` is generated and ignored by Git. A fresh clone needs `npm ci`
(which runs the package `prepare` script) or `npm run compile` before those
public entry points can run. Reading `yargs/lib/` is sufficient for the source
architecture described here.

The factory creates one mutable `YargsInstance`, installs `--help` and
`--version` by default, and returns the fluent configuration API.

## Overall architecture

```text
application tokens
        |
        v
YargsInstance (.option/.command/.middleware/.parse)
        | owns mutable configuration and collaborators
        +--> CommandInstance       command registry and recursive dispatch
        +--> UsageInstance         help, version, errors, stdout/stderr capture
        +--> ValidationInstance    required, strict, choices, implies, conflicts
        +--> GlobalMiddleware      transforms/coercions before and after validation
        +--> Completion            scripts and candidate suggestions
        |
        v
shim.Parser.detailed(...)  [the external yargs-parser package]
        |
        v
DetailedArguments { argv, aliases, newAliases, defaulted, error, configuration }
        |
        +-- a matching command? --> reset local command state, run its builder,
        |                         recursively parse deeper commands, bind
        |                         positionals, validate, run handlers
        |
        +-- no command ----------> middleware, validation, post-processing
        |
        v
Arguments / argv object (or Promise<Arguments> when any stage is async)
```

The critical boundary is `shim.Parser.detailed`. Yargs itself does **not**
manually scan `-abc`, `--name=value`, `--no-name`, aliases, dotted keys, or
config/environment values. It builds parser hints and delegates that syntax to
the external **`yargs-parser`** dependency. It then interprets its `argv._`
non-option array as possible command names and command positionals. For the
engine's token scanner, option hints, type conversions, aliases, dot notation,
and source-precedence algorithm, see
[`docs/yargs-parser-internals.md`](yargs-parser-internals.md).

## What is stored while an application is configured?

### Flags and options: parser hints, not option objects

Calls such as `.option('port', { type: 'number', alias: 'p', demandOption:
true })` are compiled immediately into the private `YargsInstance.#options`
object. `.option()` is mostly an orchestrator: it calls fluent helpers such as
`.alias()`, `.number()`, `.demandOption()`, `.choices()`, `.default()`,
`.implies()`, `.conflicts()`, `.coerce()`, `.group()`, and `.describe()`.

`#options` extends `yargs-parser`'s `Options` and holds parallel, keyed parser
hints rather than a single `Option` record per flag:

| Data | Examples | Used by |
| --- | --- | --- |
| Type/name hints | `boolean`, `string`, `number`, `array`, `count`, `normalize`, `key` | `yargs-parser` token conversion and known-key handling |
| Value/config hints | `alias`, `default`, `narg`, `config`, `configObjects`, `envPrefix` | parser aliasing, defaults, arity, config files/objects, environment |
| Validation hints | `choices`, `demandedOptions`, `demandedCommands`, `skipValidation` | `ValidationInstance` after parsing |
| Presentation hints | `defaultDescription`, `hiddenOptions`, `local`, option groups | `UsageInstance` and command resets |
| Parser behavior | `configuration` | `yargs-parser` features, such as camel-case expansion or `populate--` |

For example, `option('color', {boolean: true, alias: 'c'})` appends `color`
to `options.boolean`, records `options.alias.color = ['c']`, marks both as
known keys, and records a description if present. Parser aliases are expanded
by `yargs-parser`, which returns a normalized bidirectional `aliases` map and
identifies generated camel-case aliases in `newAliases`.

The built-in help and version calls follow exactly the same path: the factory
adds Boolean options named `help` and `version`, with descriptions. Their
special treatment happens *after* the ordinary parse.

### Commands: executable handler records

`.command(...)` delegates to `CommandInstance.addHandler()`. A registered
command lives in `CommandInstance.handlers` under its canonical first word:

```ts
handlers[name] = {
  original,       // e.g. "deploy <file> [targets..]"
  description,
  builder,        // option object or (yargs, helpOrVersionSet) => yargs
  handler,        // (argv) => value | Promise<value>
  middlewares,
  demanded,       // parsed required positional declarations
  optional,       // parsed optional positional declarations
  deprecated,
};
```

`CommandInstance.aliasMap` maps each command alias to the canonical key, and
`defaultCommand` stores the one command marked with `*` or `$0`. The same
command is also recorded in `UsageInstance.commands`, but only as display data
(command text, description, aliases, default/deprecation status). Thus there
are separate execution and help registries.

Registration accepts several forms:

```ts
y.command('deploy <file> [targets..]', 'Deploy files', builder, handler)
y.command(['deploy <file>', 'push <file>'], '...') // command + aliases
y.command({ command: 'deploy <file>', builder, handler, aliases: ['push'] })
y.commandDir('commands') // load command-definition modules from a directory
```

A `builder` may be an object of option definitions or a function that receives
a Yargs instance. A function can be asynchronous. Command modules loaded by
`.commandDir()` are converted into the same command-handler records.

### Positionals: first parsed from command text, then turned into options

The command DSL is parsed by `parse-command.ts`. Given:

```text
deploy <file|source> [region] [targets..]
```

it produces:

```text
cmd: "deploy"
demanded: [{ cmd: ["file", "source"], variadic: false }]
optional: [
  { cmd: ["region"], variadic: false },
  { cmd: ["targets"], variadic: true },
]
```

The bracket form determines required versus optional; `..` on the final
positional makes it variadic; `a|b` supplies aliases. Initially all non-option
tokens remain in `argv._`; they are **not** named values yet.

After the command has been selected, `populatePositionals()` removes already
selected command names from `argv._`, checks that enough required values exist,
and assigns values to a temporary `positionalMap`. It then synthesizes tokens
like `--file README --region us-east` and calls `yargs-parser` again. This gives
positionals the same type coercion, aliases, defaults, choices, normalization,
and custom `.positional(name, definition)` behavior as options. The final
`argv` has named positional properties and restores the command words in `_`.

`.positional()` is therefore a command-builder-time refinement of a positional
already declared in the command string. It filters its definition to supported
option settings, puts it in the `Positionals:` help group, and delegates to
`.option()`.

## What happens when a user runs the CLI?

For an application configured like this:

```ts
const cli = Yargs(['deploy', 'README.md', '--region', 'eu', '--verbose'])
  .option('verbose', { type: 'boolean', global: true })
  .command(
    'deploy <file> [region]',
    'Deploy a file',
    y => y.option('dry-run', { type: 'boolean' }),
    argv => console.log(argv.file, argv.region, argv.verbose)
  );

const argv = await cli.parseAsync();
```

the flow is:

1. **Initial parse.** `runYargsParserAndExecuteCommands()` calls
   `Parser.detailed()` with global hints. It receives an `argv` approximately
   like `{ _: ['deploy', 'README.md'], region: 'eu', verbose: true }`, plus
   alias/error metadata, and adds `$0` (the script name).
2. **Locate command.** It scans `argv._` from the current `commandIndex` for a
   name in `CommandInstance.getCommands()`. `deploy` matches.
3. **Build command scope.** `runCommand()` pushes command context, freezes
   usage state, and calls the command builder. It calls Yargs `reset()` before
   the builder so options marked local do not leak, while global options and
   preserved help groups remain. The builder adds `dry-run` and can add nested
   commands or positionals.
4. **Recursive parse.** The inner Yargs instance re-runs the parser using the
   original token list at the next command index. A nested command repeats
   this process. This is why options can be configured lazily per command.
5. **Bind positionals.** On the selected command, required/optional command
   DSL positionals are named, parsed with parser hints, and merged into `argv`.
6. **Run middleware and validation.** Global middleware with
   `applyBeforeValidation: true` runs first; then Yargs checks required
   options/positionals, strict modes, choices, implications, and conflicts;
   then remaining middleware runs.
7. **Call the selected command function.** The deepest matching command reaches
   this stage first, so its command middleware and handler receive the final
   `argv`. That stage sets Yargs' `hasOutput` guard, preventing outer command
   handlers from running during recursive unwind; parent builders had already
   run while descending. Handler return values do not become CLI output or
   replace `argv`; Yargs waits for them only to support async execution.
8. **Return post-processed arguments.** `.parse()` returns the final `argv`
   synchronously unless a builder, middleware, handler, or check is async; in
   that case it returns `Promise<argv>`. `.parseAsync()` always resolves one.

### The object the application and handler receive

On ordinary success, the observable result is a dynamic JavaScript argument
object, not a typed result wrapper:

```ts
{
  $0: 'my-cli',
  _: ['deploy'],          // selected command words and unclaimed non-options
  file: 'README.md',      // named positional
  region: 'eu',           // named positional or option, depending on schema
  verbose: true,
  'dry-run': false,       // when configured/defaulted
  dryRun: false,          // typical parser-generated camel-case alias
}
```

Exact properties depend on parser configuration. By default, `yargs-parser`
may add camel-case aliases for dashed names; aliases generally appear as
properties too unless configured to strip them. With `populate--`, tokens after
`--` are kept in `argv['--']`; otherwise Yargs copies them into `argv._` during
post-processing. Config files, environment prefixes, aliases, defaults, and
coercions can also add values.

**Yes, functions are registered with commands.** The `handler` is stored in the
command record and invoked with this same `argv`. A handler must explicitly
print, return a rejected promise/throw, or otherwise perform its application
work. A successful parse with no handler does not automatically print data.

### Help, version, failure, and completion outputs

Yargs itself produces framework output in these cases:

- `--help` (and configured multi-character help aliases) formats usage,
  commands, option groups, types, defaults, choices, examples, and epilog.
  Handlers are not invoked; command builders receive a help/version hint so
  they can defer expensive work. It writes to stdout and exits 0 when process
  exit is enabled.
- `--version` writes the configured or discovered package version and exits 0.
- Parser errors, missing requirements, strict/choice/conflict failures, and
  handler-related failures use `UsageInstance.fail()`. The default behavior
  prints help and the error to stderr, then exits 1. `.fail()` and
  `.showHelpOnFail()` customize that behavior.
- `.completion()` registers a `completion` command that emits a shell script.
  Its hidden `--get-yargs-completions` option instead emits candidate command,
  option, and choice values for the active shell completion request.

With `.parse(args, callback)`, Yargs disables process exit and supplies the
captured error, final `argv`, and framework output string to the callback.
`.exitProcess(false)` similarly avoids terminating the host, though ordinary
failures without a callback can then throw.

## Important source files

### Core orchestration

| File | Responsibility |
| --- | --- |
| [`yargs/lib/yargs-factory.ts`](../yargs/lib/yargs-factory.ts) | The central factory and mutable `YargsInstance`. Fluent API methods populate parser hints; private symbol methods freeze/reset command state, call `Parser.detailed`, find commands, run validation/middleware, and post-process `argv`. |
| [`yargs/lib/command.ts`](../yargs/lib/command.ts) | `CommandInstance`: command/module registration, canonical and alias lookup, command builders, recursive dispatch, positional binding/reparse, command middleware, handler invocation, and frozen command state. |
| [`yargs/lib/parse-command.ts`](../yargs/lib/parse-command.ts) | Parses the command-string DSL into a command name plus required/optional/variadic positional metadata. Shared by registration, `argsert`, completion, and positional parser hints. |
| [`yargs/lib/usage.ts`](../yargs/lib/usage.ts) | Stores usage/descriptions/examples/commands/groups, renders terminal help with `cliui`, localizes labels, handles version output, caches help for async handlers, and provides the default failure/exit policy. |
| [`yargs/lib/validation.ts`](../yargs/lib/validation.ts) | Checks non-option and positional counts, required options, strict unknown commands/options, choices, implications, and conflicts. It also suggests near-miss commands. |
| [`yargs/lib/middleware.ts`](../yargs/lib/middleware.ts) | Stores global middleware, command middleware, and special one-per-option coercion middleware; sequences sync and async middleware before or after validation. |

### Completion and API validation

| File | Responsibility |
| --- | --- |
| [`yargs/lib/completion.ts`](../yargs/lib/completion.ts) | Creates default candidates from visible commands/options/choices/positionals, supports custom synchronous/callback/async providers, and emits the completion command output. |
| [`yargs/lib/completion-templates.ts`](../yargs/lib/completion-templates.ts) | Bash, Zsh, and Fish templates. They ask the CLI for hidden completion candidates. |
| [`yargs/lib/argsert.ts`](../yargs/lib/argsert.ts) | Runtime checks Yargs API method arguments using a small positional DSL. It catches errors and warns rather than enforcing hard throws. |
| [`yargs/lib/yerror.ts`](../yargs/lib/yerror.ts) | The framework-specific `YError` used to distinguish expected usage failures from unrelated exceptions. |

### Platform and parser contracts

| File | Responsibility |
| --- | --- |
| [`yargs/lib/typings/yargs-parser-types.ts`](../yargs/lib/typings/yargs-parser-types.ts) | Local TypeScript contract for the external parser: its parser options, detailed result (`argv`, aliases, errors), configurations, and parser helpers. This makes the delegated parsing boundary explicit. |
| [`yargs/lib/typings/common-types.ts`](../yargs/lib/typings/common-types.ts) | Shared dictionaries, type utilities, directory-command options, and the `PlatformShim` contract. |
| [`yargs/lib/platform-shims/esm.mjs`](../yargs/lib/platform-shims/esm.mjs) | Node ESM implementation of the platform contract. Wires Node APIs and npm dependencies, including `yargs-parser`, `cliui`, and `y18n`. |
| [`yargs/lib/platform-shims/browser.mjs`](../yargs/lib/platform-shims/browser.mjs) | Browser shim: uses browser CDN dependencies and makes filesystem/`require` features unavailable. |
| [`yargs/lib/platform-shims/deno.ts`](../yargs/lib/platform-shims/deno.ts) | Deno shim: maps Deno APIs and permissions to the same framework contract; directory command loading is unavailable. |
| [`yargs/index.mjs`](../yargs/index.mjs), [`yargs/browser.mjs`](../yargs/browser.mjs), [`yargs/deno.ts`](../yargs/deno.ts) | Small public bootstraps that choose the appropriate shim and factory. |

### Supporting utilities

| File | Responsibility |
| --- | --- |
| [`yargs/lib/utils/apply-extends.ts`](../yargs/lib/utils/apply-extends.ts) | Resolves a config object's `extends`, detects cycles, and shallow- or deep-merges inherited configuration. |
| [`yargs/lib/utils/is-promise.ts`](../yargs/lib/utils/is-promise.ts) | Minimal thenable check used to preserve synchronous parsing unless async work is present. |
| [`yargs/lib/utils/maybe-async-result.ts`](../yargs/lib/utils/maybe-async-result.ts) | Applies continuation/error logic uniformly to synchronous values and promises. |
| [`yargs/lib/utils/obj-filter.ts`](../yargs/lib/utils/obj-filter.ts) | Copies only matching object keys; used when local command options are reset. |
| [`yargs/lib/utils/process-argv.ts`](../yargs/lib/utils/process-argv.ts) | Implements `hideBin()` and finds the executable argument across Node/Electron layouts. |
| [`yargs/lib/utils/set-blocking.ts`](../yargs/lib/utils/set-blocking.ts) | Requests blocking terminal writes before help/version/error/completion exit so output is not lost. |
| [`yargs/lib/utils/levenshtein.ts`](../yargs/lib/utils/levenshtein.ts) | Damerau-Levenshtein distance used by command recommendations. |
| [`yargs/lib/utils/which-module.ts`](../yargs/lib/utils/which-module.ts) | Legacy CommonJS `require.cache` helper that finds the module exporting an object; it is currently not imported by this source tree. |

The clone's [`yargs/test/`](../yargs/test) directory is also important as the
behavioral specification: parser, command, validation, usage, middleware, and
completion tests exercise the interactions above.

## Relationship to this Dart project

The local Dart parser intentionally adopts only part of the Yargs model:
command-branch activation, inherited active options, named positionals, and a
single merged result object. It deliberately does **not** copy Yargs'
mutable fluent builder, JavaScript handler dispatch, parser-dependency hints,
configuration/env files, help formatting, or completion framework. In
particular, this project returns `ArgParseSuccess`/`ArgParseFailure` and lets
the caller dispatch from `commandPath`; Yargs executes registered handlers as
part of `.parse()`.

The package now additionally provides `YargsCommandRuntime`, a separate,
dependency-free Dart layer over the YargsParser port. It uses typed command and
positional declarations rather than Yargs's command-string DSL, and ports
nested command selection, validation, handlers, basic help, and completion
candidates. See [`yargs-command-runtime.md`](yargs-command-runtime.md).
