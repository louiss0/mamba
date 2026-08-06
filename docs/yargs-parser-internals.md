# `yargs-parser` internals: the engine beneath Yargs

Yargs delegates flag decoding to the installed
[`yargs-parser` 22.0.0](../yargs/node_modules/yargs-parser) package. This guide
explains that implementation as installed by `npm ci` in `yargs/`.

`yargs-parser` is deliberately narrower than Yargs:

- It has **no commands**, handlers, help renderer, validation policy, or exit
  behavior.
- It transforms a token sequence and parsing hints into a JavaScript object.
- It returns rich metadata through `.detailed()` so Yargs can add the framework
  features above it.

The installed package contains compiled JavaScript in `build/lib/`; its
TypeScript authoring source and test suite are not included in the npm package.
The important implementation is still readable and maps directly to the
algorithm described here.

## The public API and object model

```ts
import parser from 'yargs-parser';

const argv = parser(args, options);          // returns argv only
const detail = parser.detailed(args, options); // returns parser metadata
```

The Node entry point creates one `YargsParser` with a small Node mixin:

```text
index.js
  -> YargsParser({ cwd, env, format, normalize, resolve, require })
  -> parser.parse(args, options)
```

The mixin keeps the core parser portable. Browser and Deno builds can replace
filesystem, environment, path, formatting, and config-loading operations.

`.detailed()` returns:

```ts
{
  argv: { _: [] /* parsed values */ },
  aliases: { /* normalized, bidirectional alias graph */ },
  newAliases: { /* aliases inferred from dashed/camel keys */ },
  defaulted: { /* keys populated by opts.default */ },
  configuration: { /* effective configuration */ },
  error: Error | null,
}
```

`argv._` is the ordered collection of positional/non-option tokens. With
`populate--: true`, tokens after `--` go to `argv['--']`; otherwise they are
appended to `_`.

## One complete parse in six phases

```text
input string or token array
       |
       +--> tokenize (only for string input)
       +--> normalize aliases, configuration, defaults, and type flags
       |
       +--> one left-to-right scan of every token
       |       `--long=value`, `--long value`, `--no-long`, `-abc`, etc.
       |
       +--> setArg -> process type -> set nested key -> mirror aliases
       |
       +--> fill missing values by precedence: env, config, config objects,
       |    defaults; then coerce, initialize counts, and place `--` values
       |
       +--> strip requested alias/dashed properties and return detailed result
```

### 1. Tokenize input

If the input is an array, `tokenizeArgString()` returns a stringified copy. If
it is a string, it splits on spaces except inside matching single or double
quotes. It retains quote characters initially; `processValue()` later removes
matching outer quotes.

This is a convenience tokenizer, **not a shell parser**. It does not implement
shell escaping, expansion, or every shell quoting rule. Production CLIs should
usually pass the already split `process.argv.slice(2)`/`hideBin(process.argv)`
array.

### 2. Normalize configuration and parsing hints

`parse()` creates defaults for all parser configuration switches, then overlays
`opts.configuration`. Important defaults include:

```text
boolean-negation: true             camel-case-expansion: true
dot-notation: true                 parse-numbers: true
duplicate-arguments-array: true    flatten-duplicate-arrays: true
greedy-arrays: true                short-option-groups: true
populate--: false                  unknown-options-as-args: false
```

It builds an internal `flags` record with lookup maps:

```ts
{
  aliases, arrays, bools, strings, numbers, counts,
  normalize, configs, nargs, coercions, keys
}
```

The `array`, `boolean`, `string`, `number`, `count`, `normalize`, `narg`,
`coerce`, and `config` option hints populate their corresponding maps. These
are parser instructions, not output declarations.

#### Alias closure

`combineAliases()` turns overlapping alias declarations into equivalence
classes. For example, these overlapping declarations mean all three names are
one group:

```ts
{ alias: { color: ['c'], c: ['colour'] } }
// normalized relationship: color <-> c <-> colour
```

`extendAliases()` then constructs a bidirectional lookup for configured keys,
explicit aliases, default keys, and array keys. It additionally creates
camel-case/dashed aliases when that configuration is enabled:

```text
--output-file  -> output-file and outputFile
--outputFile   -> outputFile and output-file
```

In Yargs, `YargsInstance.#options.key` is important: Yargs fills it whenever
an option is declared, then passes it to the parser. That lets the parser build
complete alias/type knowledge even when a property was not present in the
actual tokens.

### 3. Scan tokens from left to right

The central `for` loop in `build/lib/yargs-parser.js` classifies each token in
this order:

| Form | Result |
| --- | --- |
| Unknown dash token with `unknown-options-as-args` | Preserved as a positional instead of interpreted as an option. |
| `---`, `---=`, or more dashes with no name | Preserved as a positional. |
| `--key=value` | Sends the inline value to an array/nargs consumer or `setArg(key, value)`. |
| `--no-key` | Sets `key` to `false` when Boolean negation is enabled. |
| `--key value` / `--key` | Consumes one following non-dash value unless the key is Boolean/count; otherwise assigns a type-derived default. Literal next tokens `true`/`false` are consumed even for Boolean keys. |
| `-x.foo=value` / `-x.foo value` | Supports a single-dash dotted key. |
| `-abc`, `-ovalue`, `-o=value` | Processes a short-option group one character at a time. Prefix letters get type-derived defaults; the final/value-taking letter consumes the suffix or a following token. |
| `-0` | A special single-digit Boolean alias form. |
| `--` | Stops scanning and saves all remaining tokens. |
| First non-option with `halt-at-non-option` | Stops scanning and saves this and all following tokens. |
| Any other token | Appends it to `argv._`. |

A string that resembles a negative number is protected from option detection:
`-2`, `-.5`, and `-3.1` can be values/positionals instead of short flags.

### Arrays and `narg`

`eatArray()` consumes values after an array flag. By default it is greedy: it
continues until another option-like token; with `greedy-arrays: false`, it takes
one value. It respects an `narg` limit when both are configured and records an
error if the required number is absent. A Boolean array with no Boolean literal
becomes `[true]`.

`eatNargs()` consumes exactly the configured count. By default it stops before
a dash option; `nargs-eats-options: true` changes that. `narg: NaN`, used by
Yargs for `.requiresArg()`, means at least one value is required.

### 4. Set a value, apply types, and materialize object paths

Every normal branch eventually calls `setArg(key, value)`. This is the most
important mutation point:

1. For a dashed key, it creates a camel-case alias when configured.
2. `processValue()` strips outer input-string quotes and applies type behavior.
3. `setKey()` stores the value at the dot-separated key path.
4. It mirrors that same value to all aliases, including aliases of the first
   segment of a dotted key.
5. For normalized non-array keys, it installs a getter/setter on the returned
   object so later assignments are path-normalized.

#### Type behavior

| Hint | Behavior |
| --- | --- |
| `boolean` | Presence without a value becomes `true`; an explicit string only becomes `true` when it is exactly `"true"`, otherwise `false`. |
| `count` | Each occurrence increments from 1; any absent count is initialized to 0 later. |
| `string` | Prevents automatic numeric conversion. |
| `number` | Forces `Number(value)` when a value is present. |
| `array` | Stores a list; repeated occurrences use duplicate-array rules. |
| none | Number-looking values are converted when `parse-numbers` is enabled. |

`looksLikeNumber()` recognizes decimal/scientific values and hexadecimal values
but deliberately does not coerce a leading-zero string such as `0123`, because
conversion would discard meaning. Positionals use the same conversion unless
`parse-positional-numbers` is false.

#### Dot notation and repeated values

With `dot-notation: true`, `--user.name Ada` becomes:

```js
{ _: [], user: { name: 'Ada' } }
```

`setKey()` handles collisions rather than silently overwriting structure. If a
path segment is already a scalar, it converts the segment to an array ending in
a fresh object so the deeper write can continue. It sanitizes `__proto__` to
`___proto___` before setting path segments.

Repeated values are not simply “last one wins” by default. The default
`duplicate-arguments-array: true` turns repeated scalar options into arrays:

```text
--tag first --tag second  -> { tag: ['first', 'second'] }
```

For repeated array options, `flatten-duplicate-arrays: true` produces one flat
array. Turning off duplicate arrays replaces compatible prior values instead;
turning off flattening preserves nested occurrence arrays.

### 5. Resolve values that did not come from the command line

After the scan, the parser deliberately applies sources from lower to higher
priority using “set only if missing” logic. Its effective precedence is:

```text
1. command-line token
2. environment variable
3. configured config file
4. configured config object
5. opts.default
```

There is a preliminary environment pass only for env values that name config
files, so `MY_APP_CONFIG=path.json` can activate a `config` option. Environment
names use the configured prefix and `__` for nesting; segments are camel-cased.
For example `MY_APP_USER__DISPLAY_NAME=Ada` maps to `user.displayName` with a
`MY_APP_` prefix.

`setConfigObject()` recursively treats nested plain config objects as dotted
paths when dot notation is enabled. Command-line values remain authoritative;
with `combine-arrays: true`, array values from config may be combined instead.

After sources are resolved the parser:

1. applies each configured coercion once per alias group, trapping exceptions
   into `detail.error`;
2. initializes unprovided count flags to `0`;
3. creates missing configured keys with `undefined` if `set-placeholder-key` is
   enabled;
4. places post-terminator tokens in `_` or `--`;
5. removes properties requested by `strip-dashed` or `strip-aliased`.

Errors such as inadequate `narg`, invalid configuration combinations, config
load failures, and coercion failures are usually recorded in `detail.error`.
Yargs later turns that parser error into its usage/failure behavior.

### 6. Return data and metadata

The parser returns `argv` merged into an `argvReturn` object. This separate
object exists to support the special normalize getters. It returns the final
alias graph, generated aliases, defaulted-key flags, effective configuration,
and any single accumulated error alongside it.

## Worked trace

This command was run against the installed exact dependency:

```ts
parser.detailed(
  [
    '-v', '--output-file=report.txt', '--tag', 'a', 'b',
    '--range', '1', '2', '--user.name=Ada', '--', '-x',
  ],
  {
    alias: { verbose: ['v'], 'output-file': ['o'] },
    boolean: ['verbose'],
    string: ['output-file'],
    array: ['tag'],
    narg: { range: 2 },
    default: { color: true },
    configuration: { 'populate--': true },
  }
)
```

Its meaningful result is:

```js
{
  argv: {
    _: [],
    v: true,
    verbose: true,
    'output-file': 'report.txt',
    o: 'report.txt',
    outputFile: 'report.txt',
    tag: ['a', 'b'],
    range: [1, 2],
    user: { name: 'Ada' },
    color: true,
    '--': ['-x'],
  },
  aliases: {
    verbose: ['v'],
    v: ['verbose'],
    'output-file': ['o', 'outputFile'],
    o: ['output-file', 'outputFile'],
    outputFile: ['output-file', 'o'],
    color: [],
    tag: [],
  },
  newAliases: { outputFile: true },
  defaulted: { color: true },
  error: null,
}
```

The key facts are visible in one example: configured aliases are mirrored,
camel-case aliases are generated, arrays greedily consume values, `narg`
collects a fixed number, dot notation constructs an object, defaults apply only
after explicit values, and `--` preserves the remaining dash token.

## How Yargs deliberately wraps this parser

The relationship is not a simple one-call pass-through.

1. `YargsInstance` compiles its fluent calls into parser hints (`#options`).
2. Its `runYargsParserAndExecuteCommands()` calls `Parser.detailed()`.
3. For that first pass, Yargs forces `populate--: true` and
   `parse-positional-numbers: false`, even if the user did not request them.
   It needs command names and post-`--` tokens kept separate, and it postpones
   numeric positional conversion until it knows the active command schema.
4. Yargs scans `argv._` to select commands; the parser itself has no awareness
   of a command name.
5. Once a command is selected, Yargs maps command-DSL positionals to names and
   invokes `Parser.detailed()` a second time on synthesized `--name value`
   tokens. This reuses parser types, aliases, choices, defaults, and coercion
   rules for positionals.
6. Only after those parser passes does Yargs perform framework validation,
   middleware, help/error output, and handler dispatch.

This explains several otherwise surprising Yargs behaviors:

- A parser-only unknown option is usually accepted as a property. Yargs's
  `.strict()` policy is what rejects it later.
- The parser's default repeated-option behavior produces arrays. This Dart
  project intentionally chooses last-value-wins for its current string option.
- Parser dot notation naturally creates nested JavaScript objects. The Dart
  parser instead requires a declared accessor tree before accepting a dotted
  flag.
- A command name is only an ordinary member of `argv._` until Yargs interprets
  it through `CommandInstance`.

The schema-driven `ArgParser` continues to make the deliberate choices noted
above. The package now also includes a separate direct Dart port of this
low-level engine; its API and Dart platform adaptations are documented in
[`yargs-parser-port.md`](yargs-parser-port.md).

## Important installed files

| File | Purpose |
| --- | --- |
| [`yargs/node_modules/yargs-parser/build/lib/index.js`](../yargs/node_modules/yargs-parser/build/lib/index.js) | Node wrapper, platform mixin, Node-version check, default parser function, `.detailed()`, and exported utility functions. |
| [`yargs/node_modules/yargs-parser/build/lib/yargs-parser.js`](../yargs/node_modules/yargs-parser/build/lib/yargs-parser.js) | The 1,046-line core: option normalization, scan loop, `setArg`, array/narg consumption, source precedence, aliases, and result metadata. |
| [`yargs/node_modules/yargs-parser/build/lib/string-utils.js`](../yargs/node_modules/yargs-parser/build/lib/string-utils.js) | `camelCase`, `decamelize`, and conservative numeric recognition. |
| [`yargs/node_modules/yargs-parser/build/lib/tokenize-arg-string.js`](../yargs/node_modules/yargs-parser/build/lib/tokenize-arg-string.js) | Lightweight string-to-token conversion. |
| [`yargs/node_modules/yargs-parser/build/lib/yargs-parser-types.js`](../yargs/node_modules/yargs-parser/build/lib/yargs-parser-types.js) | Runtime output for TypeScript type declarations; the more useful source-facing contract is Yargs' copied [`yargs/lib/typings/yargs-parser-types.ts`](../yargs/lib/typings/yargs-parser-types.ts). |
| [`yargs/node_modules/yargs-parser/README.md`](../yargs/node_modules/yargs-parser/README.md) | Public API and all configuration switches, with behavioral examples. |

For the framework layer that consumes this engine, see
[`docs/yargs-architecture.md`](yargs-architecture.md).
