# Carapace completions for Mace

This document describes how Mace can turn Mamba command definitions into
Carapace completion specs. It focuses on completion values and macros rather
than the flag and command structure already emitted by
`CarapaceSpecConverter`.

The research was reviewed on August 25, 2026 against the official Carapace
documentation and the locally installed `carapace-bin 1.6.4`.

## Scope

Mace should generate declarative completion data. It should not accept shell
commands as completion providers. In particular, Mace should not emit the
generic execution macro, `$(command)`, or a shell-specific execution macro such
as `$bash(command)` or `$pwsh(command)`.

This restriction still leaves three useful completion sources:

* Static values derived from a Mamba choice input.
* Portable macros built into `carapace-spec`.
* Named macros registered by `carapace-bin`, when the user explicitly opts in
  to the additional dependency.

A named `carapace-bin` macro is not an arbitrary command string supplied to
Mace. Its implementation may still inspect the machine, access a network, or
invoke another installed tool. Consumers that require completion with no
runtime side effects should use only static values and portable filesystem
macros.

## The Carapace completion model

A Carapace completion entry is an array containing static values, macros, and
optional modifiers. The entry belongs to one of these locations:

| YAML field | Completes |
| --- | --- |
| `completion.flag.<name>` | The value consumed by a named option. The key is the long option name without leading dashes. |
| `completion.positional` | One array per ordinary positional slot. |
| `completion.positionalany` | Every positional slot after the explicitly listed slots. |
| `completion.dash` | One array per value parsed after `--`. |
| `completion.dashany` | Every remaining value parsed after `--`. |

Carapace defines a completion position as an array of static values and macros.
Static values can also carry a description and style in a tab-separated string.
Macro arguments use YAML syntax, and empty parentheses are optional. For
example, `$files` and `$files()` are equivalent, while
`$files([.dart, pubspec.yaml])` limits the results.

```yaml
name: example
flags:
  --format=: Output format
  --output=: Output file
completion:
  flag:
    format: [json, yaml]
    output: ["$files([.json, .yaml])"]
  positional:
    - ["$directories"]
```

The [completion documentation][completion] defines the arrays, and the
[Carapace spec example][spec] shows flag and positional macros together.

## What Mamba and Mace support today

Mamba models commands, aliases, descriptions, flags, options, positionals,
variadics, paired options, and inherited inputs. The current
`CarapaceSpecConverter` emits the following Carapace structure:

* Command names, aliases, descriptions, and nested commands.
* Local `flags` and inherited `persistentflags`.
* Repeatable, optional-value, required, hidden, and value-taking flag
  modifiers.
* Default values for options and non-default boolean flags.
* `exclusiveflags` for variant paired options.
* Static choice completion for choice positionals and choice variadics.

Its current completion coverage is narrower than Mamba's input model:

| Mamba input | Completion emitted today | Best completion source |
| --- | --- | --- |
| `ChoicePositional` | Static enum names in `positional` | Keep static values; no macro is needed. |
| `RepeatedChoicePositional` | One bounded `positional` slot per accepted value (`times` repetitions plus the original) | Keep static values in every slot. |
| `ChoiceVariadic` | Static enum names in `dash` for values after `--` | Keep static values. |
| `RepeatedChoiceVariadic` | Static enum names in `dashany` for values after `--` | Keep static values. |
| `ChoiceOption`, `PairedChoiceOption`, and `PairChoiceOption` | No `completion.flag` entry | Emit their enum names as static flag-value completions. |
| Accessor choice options | No completion entry | Requires an accessor-to-Carapace design before completion can be emitted safely. |
| String options | `$files` in `completion.flag` | Prefer explicit completion metadata because a regular expression does not reveal user intent. |
| Integer and double options | `$carapace.number.Range` over 0–1000 in `completion.flag`; doubles format with two decimals | Keep the generated bounded fallback; narrow the range when the domain has real limits. |
| Boolean and count flags | No value completion is needed | Their names are completed by Carapace itself. |

Mace should not infer a macro from an input name. A value named `path` could be
a local file, a remote object path, or an application-specific identifier.
Likewise, Mamba's regular expressions validate tokens but do not provide a
finite set of useful suggestions.

## Portable macros Mace can support

The portable set is supplied by `carapace-spec`, so it does not depend on the
larger `carapace-bin` macro catalog. The upstream
[core macro registration][core-macros] is the authoritative list.

### Completion producers

| Macro | Use |
| --- | --- |
| `$files` | Complete files and directories. Pass a YAML array to restrict filenames or suffixes, such as `$files([.dart, pubspec.yaml])`. |
| `$directories` | Complete directories only. |
| `$executables` | Complete executable files. |
| `$spec(path)` | Delegate completion to another Carapace spec. This is an advanced escape hatch rather than a normal value type. |
| `$message(text)` | Display a completion-time message. It is useful for diagnostics but does not provide values. |

`$files`, `$directories`, and `$executables` are the strongest initial Mace
features because they are generic, useful across applications, and do not
require Mace to execute a user-provided command.

### Modifiers

Modifiers transform values or another macro. They can be separate array
members or chained with the exact ` ||| ` delimiter.

| Modifier | Use |
| --- | --- |
| `$chdir(directory)` | Resolve another completion from a different directory. |
| `$filter([values])` | Remove specified values. |
| `$filterargs` | Remove values already present in the current argument list. |
| `$list(delimiter)` | Complete one value inside a delimiter-separated list. |
| `$uniquelist(delimiter)` | Complete a delimiter-separated list without duplicate members. |
| `$multiparts([delimiters])` | Complete the separate parts of a structured value. |
| `$nospace(characters)` | Avoid appending a space after matching suffix characters. |
| `$noprefix(characters)` | Disable common-prefix insertion for matching characters. |
| `$prefix(prefix)` | Add text before inserted values. |
| `$suffix(suffix)` | Add text after inserted values. |
| `$retain([values])` | Keep only specified values. |
| `$shift(count)` | Shift the positional-argument context seen by another completion. |
| `$split` | Split the current value and expose its tokens as argument context. |
| `$splitp` | Split like `$split`, including pipeline syntax. |
| `$suppress(pattern)` | Hide matching completion errors. |
| `$style(style)` | Apply a display style to the results. |
| `$tag(tag)` | Apply a display tag to the results. |
| `$usage(text)` | Set the value's usage hint. |

The official [modifier reference][modifiers] documents how these compose. Mace
should expose them as typed configuration rather than asking callers to build
macro strings. That lets Mace validate delimiters, YAML arguments, and modifier
order before writing a spec.

## Optional `carapace-bin` macros

`carapace-bin` exposes hundreds of named macros in addition to the portable
set. Current names use the `$carapace.` prefix. The installed catalog is the
source of truth for a user's version:

```console
carapace --macro
carapace --macro number.Range
```

The first command lists available names and descriptions. The second shows a
macro's full signature, description, and source reference. The upstream
[custom macro documentation][custom-macros] provides the same catalog for the
current release.

These generic groups are useful candidates for an opt-in Mace integration:

| Need | Example macro |
| --- | --- |
| Environment variables | `$carapace.env.Names`, `$carapace.env.NameValues` |
| Colors | `$carapace.color.HexColors`, `$carapace.color.XtermColorNames` |
| Bounded integers | `$carapace.number.Range({start: 1, end: 10})` |
| Semantic versions | `$carapace.number.SemanticVersions([1.2.3, 1.3.0])` |
| Filesystem metadata | `$carapace.fs.FileModes`, `$carapace.fs.FilesystemTypes`, `$carapace.fs.Mounts` |
| Network values | `$carapace.net.Hosts`, `$carapace.net.Ports`, `$carapace.net.Protocols` |
| HTTP values | `$carapace.net.http.RequestMethods`, `$carapace.net.http.StatusCodes`, `$carapace.net.http.MediaTypes` |
| SSH values | `$carapace.net.ssh.Hosts`, `$carapace.net.ssh.PrivateKeys`, `$carapace.net.ssh.PublicKeys` |
| Operating-system values | `$carapace.os.Users`, `$carapace.os.Groups`, `$carapace.os.Locales`, `$carapace.os.Shells` |
| Processes | `$carapace.ps.ProcessIds`, `$carapace.ps.KillSignals` |
| Shell-visible commands | `$carapace.shell.Executables`, `$carapace.shell.Builtins`, `$carapace.shell.Functions` |
| Text encodings | `$carapace.text.Encodings` |
| Dates and times | `$carapace.time.Date`, `$carapace.time.DateTime`, `$carapace.time.Time` |

### Bounded number completion

[`number.Range`][number-range] is inclusive but finite: it materializes every
integer from `start` through `end` for each completion request. Carapace's
[exported action][export] also contains one finite `values` array and has no
continuation token, so it cannot expose an unbounded numeric domain.

Mace therefore completes numeric options with a pragmatic default range of 0
to 1000. Doubles add a `%.2f` format so money-style values offer at most two
decimal places:

```yaml
completion:
  flag:
    count:
      - "$carapace.number.Range({start: 0, end: 1000})"
    price:
      - "$carapace.number.Range({format: '%.2f', start: 0, end: 1000})"
```

This fallback depends on `carapace-bin` because `number.Range` is a registered
`$carapace.*` macro. Consumers limited to portable `carapace-spec` macros
should omit automatic numeric completion or provide a finite static domain.

Tool-specific groups such as `$carapace.tools.git.Refs`,
`$carapace.tools.docker.Containers`, and `$carapace.tools.npm.Scripts` can be
valuable, but they are deliberately coupled to another program and its local
state. Mace should accept them only through an explicit named-macro facility,
never infer them from a Mamba input.

Named macros are version-dependent. Mace should preserve an unknown named macro
when reading a spec, but validation should report that it could not confirm the
macro against the locally installed catalog. It should not reject a spec merely
because another machine has a different Carapace version.

## Macros Mace should reject

Carapace provides direct execution macros:

```text
$(command)
$bash(command)
$cmd(command)
$elvish(command)
$fish(command)
$nu(command)
$osh(command)
$pwsh(command)
$sh(command)
$xonsh(command)
$zsh(command)
```

These execute a command while the shell asks for completion. They are outside
Mamba's declarative model and create quoting, portability, performance, and
security concerns. The [Carapace 1.5 release notes][exec-macros] document the
execution family and its platform behavior.

Mace should reject these forms in both completion producers and modifiers. A
raw macro-string escape hatch would bypass that guarantee, so the default API
should use an allowlisted macro name plus structured YAML arguments.

## Recommended Mace design

Mace can add completion support without teaching Mamba to execute callbacks or
commands:

* Always derive static completions from every Mamba choice input, including
  ordinary, paired, and accessor options once those inputs have a stable
  Carapace flag representation.
* Add explicit completion metadata for non-choice inputs. Keep it separate
  from token validation because validation and suggestion are different
  concerns.
* Model static values, portable producers, registered named macros, and
  modifiers as distinct types.
* Make portable macros the default compatibility tier. Require an explicit
  `carapace-bin` tier for `$carapace.*` macros.
* Never select completions from an input's name or regular expression.
* Validate macro syntax and arguments, but retain unknown named macros when
  round-tripping specs.
* Allow Carapace variables such as `${C_ARG0}`, `${C_FLAG_FORMAT}`, and
  `${C_VALUE}` only as explicit references. They are context substitution, not
  command execution. The [variable reference][variables] lists the supported
  forms.

A safe conceptual API would distinguish intent like this:

```dart
completion: CarapaceCompletion.files(extensions: ['.dart']),
completion: CarapaceCompletion.directories(),
completion: CarapaceCompletion.values(['json', 'yaml']),
completion: CarapaceCompletion.named(
  'number.Range',
  arguments: {'start': 1, 'end': 10},
),
```

This is a proposed Mace API, not an API currently provided by Mamba. It keeps
state mutation near the input definition, makes generated behavior reviewable,
and prevents command execution from entering the spec accidentally.

## Recommended implementation order

The most useful progression is:

* Fill `completion.flag` for all Mamba choice options.
* Add typed `$files`, `$directories`, and `$executables` providers.
* Add typed list and uniqueness modifiers.
* Add a structured, opt-in `$carapace.*` named-macro provider.
* Add contextual Carapace variables only when a completion needs another flag
  or positional value.

This order closes the existing choice-completion gap first, then adds the most
portable dynamic completions before introducing version-dependent behavior.

[completion]: https://carapace-sh.github.io/carapace-spec/carapace-spec/command/completion.html
[core-macros]: https://github.com/carapace-sh/carapace-spec/blob/master/core.go
[custom-macros]: https://carapace-sh.github.io/carapace-bin/spec/macros.html
[exec-macros]: https://carapace-sh.github.io/carapace-bin/release_notes/v1.5.html#macro
[export]: https://carapace-sh.github.io/carapace/carapace/export.html
[modifiers]: https://carapace-sh.github.io/carapace-spec/carapace-spec/macros/modifier.html
[number-range]: https://github.com/carapace-sh/carapace-bin/blob/master/pkg/actions/number/number.go
[spec]: https://carapace-sh.github.io/carapace-bin/spec.html
[variables]: https://carapace-sh.github.io/carapace-spec/carapace-spec/variables.html
