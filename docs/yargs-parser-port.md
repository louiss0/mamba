# `yargs-parser` port

`lib/src/yargs_parser.dart` is a Dart port of the installed
[`yargs-parser` 22.0.0](../yargs/node_modules/yargs-parser) scanner. It is a
separate API from the schema-driven `ArgParser`: the latter selects commands
and validates a declared command schema; this port only turns tokens plus
parsing hints into an object-shaped argument map, exactly as the JavaScript
package does for Yargs.

## API

Use the stateless convenience function for the equivalent of the package's
default export, or use `YargsParser` when an explicit object reads better:

```dart
import 'package:arg_parser/arg_parser.dart';

final argv = yargsParser(
  '--output-file=report.txt -vv --tag one two',
  const YargsParserOptions(
    alias: {'verbose': ['v']},
    count: ['verbose'],
    string: ['output-file'],
    array: [YargsParserArrayOption('tag')],
  ),
);

// {
//   _: [],
//   output-file: report.txt, outputFile: report.txt,
//   v: 2, verbose: 2, tag: [one, two],
// }
```

`yargsParserDetailed()` and `YargsParser.detailed()` return
`YargsParserDetailedResult`, whose `argv`, `aliases`, `newAliases`,
`defaulted`, `configuration`, and `error` correspond to
`yargs-parser.detailed()`.

`arguments` can be a command string or any iterable. Iterable entries are
stringified, matching the JavaScript package. String input uses the same small
quote-aware convenience tokenizer; a normal Dart CLI should pass its already
shell-tokenized `main` argument list.

## Hints and configuration

`YargsParserOptions` maps every parser hint to a sound Dart type:

| JavaScript option | Dart field |
| --- | --- |
| `alias`, `boolean`, `string`, `number`, `count`, `narg`, `normalize`, `key` | Same name |
| `array` | `List<YargsParserArrayOption>` |
| `default` | `defaultValues` (`default` is a Dart keyword) |
| `coerce` | `Map<String, YargsParserCoercion>` |
| `config` | `Map<String, YargsParserConfigLoader?>` |
| `configObjects`, `envPrefix` | Same name |
| `configuration` | `YargsParserConfiguration` |

The configuration class gives every upstream hyphenated switch an idiomatic
Dart field, for example `populateDoubleDash`, `unknownOptionsAsArgs`, and
`camelCaseExpansion`. `toMap()` exposes the original property spellings for
interoperability and diagnostic output.

All scanner behavior is ported: long and short options, clusters, negation,
negative-number protection, arrays, `narg`, count flags, defaults, alias
closure and camel/dashed expansion, repeated-value rules, dot notation,
terminator handling, unknown-option-as-positional mode, coercions, and output
stripping. The source-precedence order is unchanged: command line, environment,
config file, config objects, then defaults.

## Dart-specific boundary decisions

The JavaScript package receives Node APIs through a platform mixin. This port
makes the equivalent VM operations explicit and keeps the public parser hints
typed:

- `environment` optionally injects a map; otherwise `Platform.environment` is
  used. This retains `envPrefix` semantics while allowing deterministic hosts
  and embedders.
- A `null` config loader reads a JSON object from disk. Supply a
  `YargsParserConfigLoader` for another format or a custom path policy. Node's
  `require()` can load JavaScript modules, but Dart has no equivalent module
  format, so JSON is the safe built-in behavior.
- Normalization and JSON configuration use `dart:io`, consistent with this
  package's CLI focus. No external package is needed.
- JavaScript `undefined` is represented by `null`. In particular,
  `setPlaceholderKey` installs a `null` map entry for an unset known key.

These adaptations preserve the parser's observable token and precedence rules
without exposing untyped JavaScript unions or adopting Node module loading in a
Dart package.
