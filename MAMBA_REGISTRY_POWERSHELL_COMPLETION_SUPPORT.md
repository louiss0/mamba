---
title: PowerShell completion support for the Mamba registry map
description: How Mamba can compile its registry map into native PowerShell completion and which registry features can be represented faithfully.
---

# PowerShell completion support for the Mamba registry map

## Purpose

This document explains how PowerShell completion can be generated from the
map returned by `CommandRegistry.toMap()`. It is based on the registry shape in
`registry-maps.md`, including commands, aliases, flags, options, option groups,
positionals, variadics, recursive accessors, and persistent inputs.

The registry is a read-only, machine-readable description of the CLI surface.
It describes what Mamba accepts; it does not contain the values from a
particular invocation. A PowerShell converter can compile that description into
a `.ps1` completion script without loading the original Dart command objects.

The main conclusion is:

> PowerShell can faithfully complete nearly every finite or structural feature
> in the current registry. It cannot derive useful candidates from validation
> metadata alone when the possible value set is infinite or environmental.

Commands, aliases, flags, options, choices, safe finite integer ranges,
repeated choice positionals, choice variadics, accessor paths, descriptions,
and persistent inputs can all be supported. Arbitrary regex values, unbounded
numbers, doubles without a step, files, directories, URLs, and application
runtime values require either additional completion metadata or a dynamic
completion provider.

## 1. The PowerShell completion API

Mamba is a native executable, so its generated script should use
`Register-ArgumentCompleter -Native`:

```powershell
Register-ArgumentCompleter -Native -CommandName mamba -ScriptBlock {
    param(
        $wordToComplete,
        $commandAst,
        $cursorPosition
    )

    Invoke-MambaCompletion `
        -WordToComplete $wordToComplete `
        -CommandAst $commandAst `
        -CursorPosition $cursorPosition
}
```

PowerShell supplies three values to a native completer:

| Value | Meaning for Mamba |
|---|---|
| `$wordToComplete` | The token fragment currently being completed. |
| `$commandAst` | PowerShell's parsed representation of the current command. |
| `$cursorPosition` | The cursor offset within the current input line. |

The parameter order matters because PowerShell passes these values by
position. The parameter names themselves are not significant.

The official API also permits the completer to emit
`System.Management.Automation.CompletionResult` objects. Those objects let
Mamba provide separate insertion text, list text, result classification, and a
tooltip. This is a strong match for the registry because its descriptions can
appear directly in PowerShell's completion UI.

PowerShell's documentation warns that a completer should emit its values one at
a time through the pipeline. Returning an array as a single object can cause
the whole array to be treated as one completion. Generated handlers should
therefore enumerate candidates instead of returning a nested array.

Sources:

- [Register-ArgumentCompleter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/register-argumentcompleter?view=powershell-7.6)
- [CompletionResult](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.completionresult?view=powershellsdk-7.4.0)
- [CompletionResultType](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.completionresulttype?view=powershellsdk-7.4.0)

## 2. Recommended architecture

The generated script should have one registered PowerShell entry point and a
small internal completion engine:

```text
Register-ArgumentCompleter -Native
              |
              v
      Resolve-MambaState
              |
              |-- active canonical command path
              |-- effective local and persistent inputs
              |-- pending option or accessor value
              |-- positional slot
              |-- before or after Mamba's `--`
              `-- current prefix
              |
              v
      Invoke-MambaHandler
              |
       +------+------+----------+
       |             |          |
       v             v          v
    command        input     positional or
    handler       handler    variadic handler
              |
              v
       CompletionResult
```

The responsibilities should be separated as follows:

1. The Dart converter validates and freezes the registry map.
2. The converter emits ordered PowerShell data and reusable helper functions.
3. `Resolve-MambaState` interprets the incomplete command line tolerantly.
4. A mapped handler chooses the candidates for that state.
5. A single result helper filters, quotes, and emits `CompletionResult`
   objects.

Completion must be tolerant. It runs while the command line is incomplete and
often temporarily invalid. It should not call the strict invocation parser and
should not produce diagnostics merely because the user has not finished
typing.

## 3. Support matrix

| Registry feature | Support | PowerShell strategy | Important limitation |
|---|---:|---|---|
| Canonical commands | Full | Emit child command candidates. | Resolver must know the active parent. |
| Command aliases | Full | Map alias to canonical command and reuse its handler. | Aliases are in each child's `aliases` list, not `commands` keys. |
| Nested commands | Full | Walk the recursive `commands` maps. | Stop command lookup when Mamba's grammar moves to values. |
| Descriptions | Full | Use `listItemText` and `toolTip`. | Use a nonempty fallback tooltip. |
| Boolean flags | Full | Emit long and short spellings. | Defaults do not create candidates. |
| Negatable flags | Full | Also emit `--no-<name>`. | Only when `negatable: true`. |
| Count flags | Full | Emit their names like flags. | They may remain useful after prior occurrences. |
| Hidden flags/options/groups | Full | Exclude them from suggestions. | They remain parseable by Mamba. |
| Option names | Full | Emit long and short spellings. | Value completion requires separate metadata. |
| Choice option values | Full | Emit every `choices` value. | Pending-option detection must run before `-` filtering. |
| Repeatable choice options | Full | Reuse the choice handler after every occurrence. | Do not treat a prior occurrence as exhausting the option. |
| String options | Names only | Complete the option name. | `pattern` validates; it does not enumerate strings. |
| Integer options | Conditional | Generate a bounded range when both bounds are present and safely small. | One-sided or large ranges should not be expanded. |
| Double options | Names only | No static values from the current map. | The registry has no step, so the interval is not enumerable. |
| Regex patterns | Advisory only | Optionally filter candidates from another source. | A regex is not a candidate generator. |
| Defaults | Advisory only | May enrich a tooltip. | A default should not be inserted as though it were the only value. |
| Required options | Advisory | Prioritize missing required options if desired. | Completion cannot enforce requiredness. |
| `all` option groups | Guided | Prioritize remaining members after one is used. | Completion still does not validate the final invocation. |
| `oneOf` option groups | Guided | Suppress or demote siblings after one is used. | Exact duplicate/error policy must match Mamba's parser. |
| Choice positionals | Full | Choose a handler by logical positional index. | Optional and empty slots must be counted correctly. |
| Repeated choice positionals | Full | Repeat the same handler for `1 + times` slots. | `times` is additional repetitions, not total slots. |
| Normal positionals | Names/descriptions only | Track the slot. | A pattern alone supplies no candidate values. |
| Choice variadic | Full | Complete one choice after Mamba's literal `--`. | It ends after one value unless repeatable. |
| Repeated choice variadic | Full | Continue returning choices indefinitely after `--`. | It is intentionally unbounded. |
| Normal variadic | Structural only | Recognize that it owns values after `--`. | Its regex does not enumerate values. |
| Recursive accessors | Full for paths | Flatten value leaves to dotted option names. | Group nodes are structural unless Mamba accepts them as arguments. |
| Choice accessor values | Full | Route a dotted leaf to its `choices` handler. | Non-choice leaves still need another source. |
| Persistent flags/options | Full | Accumulate definitions while walking the command path. | Nearer definitions must shadow exactly as Mamba does. |
| Files/directories/paths | Not in current map | Add a future semantic completion kind. | A regex must not be guessed to mean a path. |
| URLs | Not in current map | Add known schemes/hosts or a dynamic provider. | A URL type cannot discover arbitrary URLs. |
| Runtime values | Not in current map | Add an explicit dynamic provider contract. | Static registry compilation cannot query application state. |

“Full” means the existing registry contains enough information to produce the
candidate set. It does not mean completion replaces parsing or validation.

## 4. Build a completion state from the AST

PowerShell's `CommandAst` exposes a non-null `CommandElements` collection. The
generated script should inspect those elements instead of splitting
`$commandAst.ToString()` on spaces. String splitting breaks quoted values:

```powershell
mamba commit "a message with spaces"
```

It also loses empty quoted arguments:

```powershell
mamba convert '' json
```

That empty string can matter to Mamba's positional indexing. The completion
resolver must preserve it as one supplied positional slot rather than deleting
it.

A useful shell-independent state shape is:

```text
CompletionState {
  commandPath: List<String>
  canonicalCommandPath: List<String>
  completedArguments: List<String>
  wordToComplete: String
  cursorPosition: int
  afterVariadicSeparator: bool
  pendingValueOwner: String?
  positionalIndex: int
  effectiveFlags: Map
  effectiveOptions: Map
}
```

The PowerShell adapter should convert literal AST nodes into their literal
values without evaluating arbitrary PowerShell expressions. For unknown or
incomplete elements, it can fall back to the element's source extent. The goal
is token recovery, not execution.

Cursor position also matters. Completion may be requested in the middle of an
existing line. Elements entirely to the right of the cursor must not be treated
as already consumed when resolving the current state.

Source:

- [CommandAst](https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.commandast?view=powershellsdk-7.4.0)

## 5. State resolution order

The resolver's decision order is critical. A useful order is:

1. Resolve completed canonical commands and aliases.
2. Accumulate persistent inputs for the selected command path.
3. Determine whether a previous option or accessor is waiting for a value.
4. Determine whether Mamba's literal `--` has started its variadic region.
5. If a value is pending, invoke that value handler.
6. If after `--`, invoke the variadic handler.
7. If the current word starts with `--`, offer long names only.
8. Otherwise, if it starts with `-`, offer short names only.
9. Otherwise, offer a child command or the current positional handler.

Pending-value detection must come before hyphen filtering. Consider:

```powershell
mamba build --offset -2
```

The current word `-2` starts with `-`, but it is the value of `--offset`, not a
request for short flags. The same issue occurs with negative double values. The
active registry option gives the resolver the context needed to make the right
choice.

## 6. Commands and aliases

Each `commands` key is canonical. Aliases are stored inside the child command:

```dart
'commands': {
  'checkout': {
    'name': 'checkout',
    'aliases': ['co'],
    // ...
  },
}
```

The converter should generate an identity map for every sibling set:

```powershell
$script:MambaCommandNames = [ordered]@{
    'checkout' = 'checkout'
    'co'       = 'checkout'
    'commit'   = 'commit'
    'ci'       = 'commit'
}
```

Handlers should be keyed only by canonical command path:

```powershell
$script:MambaCommandHandlers = @{
    'root.checkout' = {
        param($state)
        # Complete checkout's children and inputs.
    }

    'root.commit' = {
        param($state)
        # Complete commit's children and inputs.
    }
}
```

Resolution then normalizes before dispatch:

```powershell
$canonical = $script:MambaCommandNames[$typedCommand]

if ($null -ne $canonical) {
    $handler = $script:MambaCommandHandlers["root.$canonical"]
    & $handler $state
}
```

This preserves the important relationship:

```text
co --------+
           +--> checkout --> root.checkout handler
checkout --+
```

An alias should select the same child registry, flags, options, positionals,
accessors, persistent inputs, and descendants as the canonical name. Duplicating
handlers for aliases would make generated scripts larger and creates a risk
that alias behavior drifts from canonical behavior.

Use `CompletionResultType.Command` for command and alias candidates. The
canonical command description can be reused as the alias tooltip. The list
item may optionally make the relationship visible, for example `co (checkout)`,
while the insertion text remains only `co`.

### Command groups

A command with children can offer those children exactly like any other
command. The current registry does not include an explicit `kind: group`
property, so PowerShell should not infer a special visual category. It does not
need that category to complete the command correctly.

## 7. Flags

### 7.1 Long and short filtering

The requested Mamba behavior can be represented exactly:

```text
-   -> short names only
--  -> long names only
```

Always test `--` before `-` because a long option also starts with a single
hyphen:

```powershell
if ($wordToComplete.StartsWith('--', [System.StringComparison]::Ordinal)) {
    $candidates = $effectiveLongInputs
}
elseif ($wordToComplete.StartsWith('-', [System.StringComparison]::Ordinal)) {
    $candidates = $effectiveShortInputs
}
```

The converter should create the leading hyphens. Registry names do not include
them:

```text
flags['help']     -> --help
flags.help.short  -> -h
```

Use ordinal prefix matching unless Mamba explicitly declares command-line names
case-insensitive. PowerShell's `-like` operator is case-insensitive by default,
which can silently change a case-sensitive CLI's semantics.

### 7.2 Boolean flags

For this registry entry:

```dart
'dry-run': {
  'short': 'd',
  'default': false,
  'negatable': true,
  'hidden': false,
  'description': 'Show what would happen.',
}
```

PowerShell can offer:

```text
-d
--dry-run
--no-dry-run
```

`--no-dry-run` should only be generated when `negatable` is `true`. The default
value can appear in documentation or a tooltip, but it does not change the set
of accepted spellings.

### 7.3 Count flags

The absence of `default` and `negatable` distinguishes a count flag. Its long
and optional short names are completed the same way as other flags. Because
each occurrence increments a count, it can remain a useful candidate after it
has already appeared.

### 7.4 Hidden flags

`hidden: true` means “accepted but not advertised.” Generated completion should
exclude the candidate, just as generated help excludes it. Completion is a
discovery interface; showing hidden inputs would defeat the registry's intent.

### 7.5 Short-flag clusters

The registry identifies individual short names. It does not state that Mamba
accepts clusters such as `-abc`. The PowerShell generator should therefore emit
`-a`, `-b`, and `-c`, but should not synthesize clustered forms unless the
parser contract explicitly supports them.

## 8. Options and their values

Options have two separate completion stages:

1. Complete the option's name.
2. After that option is selected, complete its value when the registry provides
   a finite value source.

For example:

```powershell
mamba build --format <TAB>
```

The resolver identifies `format` as the pending value owner. The handler then
uses `options.format.choices` rather than offering more option names.

### 8.1 Choice options

Choice options have complete static support:

```dart
'format': {
  'short': 'f',
  'required': false,
  'hidden': false,
  'description': 'Output format.',
  'choices': ['text', 'json', 'yaml'],
  'valueType': 'choice',
}
```

Both spellings route to the same value handler:

```text
--format --+
           +--> format value handler --> text, json, yaml
-f --------+
```

The handler should filter choices against `$wordToComplete` and emit each
value as `ParameterValue`.

### 8.2 Repeatable options

When `repeatable: true`, every occurrence collects another value. A repeatable
choice option should continue to offer its choices after every occurrence:

```powershell
mamba export --format json --format <TAB>
```

Whether already-selected choice values should be offered again is a product
policy. The registry says the option is repeatable, but it does not say the
values must be unique. Suppressing duplicates would add a rule that may not
exist in the parser, so the safe default is to keep every declared choice.

### 8.3 String options and patterns

A regex pattern recognizes a set; it does not enumerate that set. Given:

```dart
'pattern': r'[a-z][a-z0-9-]*'
```

there may be millions or infinitely many valid strings. PowerShell cannot infer
the intended values. The option name can be completed, but its value should
have no static candidates unless another completion source exists.

Patterns can still be useful later as filters. If a future dynamic provider
returns candidate strings, Mamba can discard provider values that fail the
registry pattern. The pattern remains validation metadata, not the source.

### 8.4 `--name=value`

This form should only be completed if Mamba's parser accepts it. If supported,
the resolver can split the current token at the first `=`:

```text
--format=j
|--------| |
 option    value prefix
```

The value handler would filter on `j` and reattach `--format=` to each
completion's insertion text. If the parser accepts only separate tokens, the
generator must not advertise the equals form.

## 9. Numeric ranges

### 9.1 Integer ranges

PowerShell has a native inclusive range operator:

```powershell
1..5
```

It also supports descending integer ranges. Its endpoints must be convertible
to signed 32-bit integers.

This maps well to an integer option only when both `min` and `max` are present:

```powershell
$minimum..$maximum |
    ForEach-Object { $_.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
```

The generator still needs a safety limit. Expanding `0..2147483647` during tab
completion would be disastrous even though it is a formally bounded interval.
A converter policy such as `MaxStaticRangeSize` should decide whether the range
is small enough to enumerate. If it is too large, emit no numeric candidates
and leave validation to Mamba.

If only `min` or only `max` exists, the set is unbounded on one side and cannot
be statically enumerated.

### 9.2 Double ranges

The current registry contains double `min` and `max`, but no `step`. A real
interval contains infinitely many doubles, so there is no honest list of
completion values.

PowerShell's `..` operator does not solve this. It creates integer sequences;
it is not a decimal stepping operator. A helper loop would only become valid if
the registry also declared a step:

```text
min: 0.5
max: 2.0
step: 0.5
```

Because `step` is not part of today's `OptionMap`, double bounds should remain
validation metadata. Completing only the endpoints would incorrectly imply
that intermediate values are unavailable.

Source:

- [PowerShell range operator](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7.6#range-operator-)

## 10. Option groups

Option groups are relationships between entries already present in `options`.
PowerShell can use the relationships to improve suggestions without taking over
validation.

### 10.1 `oneOf`

For:

```dart
{
  'mode': 'oneOf',
  'required': false,
  'members': ['json', 'yaml'],
}
```

before either member is used, both may be offered. After `--json` is used, the
completer may suppress `--yaml` because the registry describes them as
alternatives. The same rule must recognize short aliases as the same member.

### 10.2 `all`

For:

```dart
{
  'mode': 'all',
  'required': true,
  'members': ['username', 'password'],
}
```

after `--username` appears, the completer can prioritize `--password`. It should
not insert it automatically, and it should not report an error while the user
is still typing.

### 10.3 Requiredness

Requiredness is useful for ranking or tooltip text, not candidate generation.
PowerShell completion cannot guarantee that the completed command line contains
every required member. Mamba's parser remains authoritative.

## 11. Positionals

Positionals are stored in registry order, even though their exported shape is a
map keyed by name. The converter should preserve that order when emitting its
PowerShell tables.

The resolver must count consumed positional slots while ignoring tokens already
classified as:

- canonical commands or aliases;
- flags;
- option names;
- values consumed by options or accessors; and
- Mamba's literal variadic separator.

### 11.1 Choice positionals

When the current logical index selects a positional containing `choices`, emit
those choices:

```text
position 0 -> source handler
position 1 -> format choices: text, json
```

`required`, `default`, and `description` can enrich behavior or display, but
`choices` is the actual candidate source.

### 11.2 Normal positionals

A normal positional always has a regex `pattern`. As with string options, that
pattern cannot generate values. PowerShell can identify the current positional
and perhaps show its description in diagnostics or debug output, but there is
no finite candidate set.

### 11.3 Repeated positionals

The meaning of `times` is easy to get wrong:

> `times` is the maximum number of additional repetitions.

Therefore:

```text
total occupied slots = 1 + times
```

For a choice positional with `times: 2`:

```text
logical slot 0 -> same choices
logical slot 1 -> same choices
logical slot 2 -> same choices
logical slot 3 -> next positional, if any
```

The generated resolver can either expand these positions at generation time or
store a start index and count. Expansion is simpler; a range descriptor is more
compact.

### 11.4 Empty positional values

PowerShell permits explicit empty strings such as `''`. An empty argument still
occupies a positional slot. Do not discard empty values while translating the
AST, or every later choice positional will be shifted left.

### 11.5 Optional positionals

Completion should follow the same slot-consumption rules as Mamba's parser. It
must not guess that an omitted optional positional disappeared merely because a
later token also matches a later positional. When the grammar permits explicit
empty slots, preserve them. If Mamba has additional disambiguation rules, put
them in the shell-independent completion resolver so every shell behaves the
same way.

## 12. Variadics and Mamba's literal `--`

In the current registry, a variadic owns values after a literal `--` separator:

```powershell
mamba command -- value1 value2
```

This is a Mamba grammar rule. Once the separator is consumed, ordinary command,
flag, option, and positional completion must stop for that command. Later tokens
belong to the variadic.

### 12.1 Normal variadic

A normal variadic provides `description` and `pattern`. PowerShell can recognize
the region but cannot produce values from the regex.

### 12.2 Choice variadic

A non-repeatable choice variadic offers its `choices` for the first value after
`--`. After one variadic value is present, it stops producing candidates.

### 12.3 Repeated choice variadic

When `repeatable: true`, the same choice handler remains active for every value
after `--`:

```text
mamba command -- <TAB>              -> choices
mamba command -- alpha <TAB>        -> choices
mamba command -- alpha beta <TAB>   -> choices
```

This precisely supports the requirement that a repeated choice variadic keep
offering its values indefinitely.

## 13. Recursive accessors

Accessor groups are structural nodes; accessor values are leaves. The
PowerShell converter can recursively flatten every visible leaf:

```text
accessors.database.host -> --database.host
accessors.database.port -> --database.port
```

For deeper nesting:

```text
database.credentials.username -> --database.credentials.username
```

The registry's `kind` property makes traversal unambiguous:

```powershell
function Add-MambaAccessorLeaves {
    param(
        [string] $Prefix,
        $Nodes,
        [System.Collections.Generic.List[object]] $Destination
    )

    foreach ($property in $Nodes.PSObject.Properties) {
        $path = if ($Prefix) {
            "$Prefix.$($property.Name)"
        }
        else {
            $property.Name
        }

        $node = $property.Value

        if ($node.kind -eq 'group') {
            if (-not $node.hidden) {
                Add-MambaAccessorLeaves $path $node.options $Destination
            }
        }
        else {
            $Destination.Add([pscustomobject]@{
                Name        = "--$path"
                Path        = $path
                ValueType   = $node.valueType
                Description = $node.description
                Choices     = $node.choices
            })
        }
    }
}
```

This is illustrative generated-runtime code. A converter may flatten the tree
in Dart instead, producing smaller and faster PowerShell lookup tables.

Choice leaves have full value completion. String, integer, and double leaves
only expose patterns in the current accessor map, so they do not supply finite
values. Unlike ordinary numeric options, accessor numeric leaves currently do
not export `min` and `max`.

Hidden accessor groups should hide their whole subtree. Group descriptions can
be carried into leaf tooltips if desired, but the leaf's own description should
remain primary.

## 14. Persistent flags and options

Persistent definitions are local to the registry level that publishes them;
they are not pre-merged into every descendant. The PowerShell resolver must
accumulate them while walking the active canonical command path.

Conceptually:

```text
root
  effective inputs = root flags/options
    |
    v
group
  + group's persistentFlags/persistentOptions
    |
    v
child
  + child's local flags/options
```

Nearer definitions must shadow according to Mamba's actual inheritance rules.
The completion script should key both long and short spellings back to one
canonical input identity so shadowing and pending-value detection remain
consistent.

The root's global flags live in its ordinary `flags` map. They are not copied
into each child's `persistentFlags`; the resolver must include root globals
explicitly when constructing the effective child state.

Pair groups remain local to their command. They are not part of
`persistentOptions` and should not be invented for descendants.

## 15. Rich completion results

PowerShell distinguishes the text inserted into the command line from the text
shown in a completion menu:

```powershell
[System.Management.Automation.CompletionResult]::new(
    $completionText,
    $listItemText,
    $resultType,
    $toolTip
)
```

A useful registry mapping is:

| Mamba concept | Completion result type |
|---|---|
| Command or command alias | `Command` |
| Flag, option, or accessor name | `ParameterName` |
| Choice, range, positional, or variadic value | `ParameterValue` |
| Future file value | `ProviderItem` |
| Future directory value | `ProviderContainer` |

These result types classify presentation. They do not discover values. Creating
a `ProviderItem` result does not enumerate files; a file completion source must
still do that work.

A reusable emitter can centralize prefix matching and description fallback:

```powershell
function Write-MambaCompletion {
    param(
        [string] $CompletionText,
        [string] $ListItemText,
        [string] $ResultType,
        [AllowNull()] [string] $Description,
        [string] $Prefix
    )

    if (-not $CompletionText.StartsWith(
        $Prefix,
        [System.StringComparison]::Ordinal
    )) {
        return
    }

    $toolTip = if ([string]::IsNullOrEmpty($Description)) {
        $ListItemText
    }
    else {
        $Description
    }

    [System.Management.Automation.CompletionResult]::new(
        $CompletionText,
        $ListItemText,
        $ResultType,
        $toolTip
    )
}
```

PSReadLine completion modes can display these objects differently. Mamba should
provide correct insertion text and metadata without baking one presentation
mode into the registry.

## 16. Files, directories, paths, and URLs

### 16.1 What PowerShell itself can do

PowerShell can enumerate provider items with `Get-ChildItem`. Its filesystem
provider can distinguish files and directories and filter extensions. The
completion result model also has `ProviderItem` and `ProviderContainer`
classifications.

A future Mamba completion vocabulary could map:

| Semantic kind | PowerShell behavior |
|---|---|
| `file` | Enumerate files and directories needed for traversal; only files are final values. |
| `directory` | Enumerate directories only. |
| `path` | Enumerate files and directories. |
| `file` with extensions | Filter final files by declared extensions. |
| `url` with schemes/hosts | Emit the declared URL prefixes or known endpoints. |

Partial paths need to be split into a parent directory and a leaf prefix. Given
`./configs/pro`, the completer should enumerate `./configs/` and filter child
names beginning with `pro`. It must also quote completion text when a path
contains PowerShell-significant characters or spaces.

Source:

- [Get-ChildItem](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-childitem?view=powershell-7.5)

### 16.2 What the current registry can express

The current registry has no `file`, `directory`, `path`, or `url` completion
kind. A string regex is not a safe substitute. For example, `.*\.yaml` may
validate a filename-shaped string, but it does not say whether the value must
exist, whether directories are allowed during traversal, or which working
directory should be searched.

Therefore, current-registry PowerShell generation should not automatically
invoke filesystem completion for string patterns.

URLs are even less enumerable. Knowing that a value is a URL does not reveal
all valid hosts or paths. Useful URL completion requires declared schemes,
known hosts/endpoints, history, or an application-specific provider.

### 16.3 A future metadata extension

One possible shell-independent addition is:

```text
completion?: {
  kind: 'file' | 'directory' | 'path' | 'url' | 'values' | 'dynamic'
  extensions?: List<String>
  schemes?: List<String>
  hosts?: List<String>
  values?: List<String>
  provider?: String
}
```

The exact schema is a Mamba design decision, but the distinction matters:

- validation says whether a supplied value is legal;
- completion says where suggested values come from.

Keeping these concepts separate prevents shell integrations from guessing.

## 17. Static and dynamic completion

The current registry is strong for static completion. The PowerShell script can
embed:

- command and alias names;
- flags and options;
- descriptions;
- choice values;
- safe finite integer ranges;
- positional layout;
- variadic choices;
- accessor leaves; and
- persistent inheritance metadata.

It cannot embed values that only exist while the application is running, such
as current Git branches, remote resources, database names, user accounts, or
files discovered later.

A future hybrid design can use both strategies:

```text
registry metadata
      |
      +--> static source --> generated PowerShell handler --+
      |                                                   |
      `--> dynamic source --> mamba __complete/provider --+
                                                          |
                                                          v
                                                   CompletionResult
```

Static completion avoids starting the Dart executable on every Tab press.
Dynamic completion is necessary when candidates depend on live state. The
current registry has no runtime provider contract, so dynamic behavior should
remain an explicit future feature rather than an undocumented convention.

## 18. Comparison with Cobra

Cobra supports generated PowerShell completion scripts, custom flag completion
functions, and filename completion metadata. Its public guide demonstrates
`RegisterFlagCompletionFunc` for values such as `json`, `yaml`, and `csv`, and
`MarkFlagFilename` for file extensions.

Cobra's architecture normally asks the executable for completion results at
completion time. The generated PowerShell script processes the returned values
and directives, then constructs `CompletionResult` objects. That gives Cobra
runtime flexibility because Go completion functions can inspect application
state.

Mamba's registry-first architecture is different:

| Concern | Cobra | Mamba registry compilation |
|---|---|---|
| Static command grammar | Resolved by the executable's completion engine. | Can be compiled into PowerShell tables. |
| Completion subprocess | Normally used. | Not required for static metadata. |
| Dynamic application values | Supported by Go completion functions. | Requires a future provider contract. |
| Descriptions | Returned by the completion engine and shown by the script. | Already available in the registry. |
| Numeric range abstraction | Custom completion logic. | Mamba can derive safe integer values from `min` and `max`. |
| Recursive accessor paths | Application-specific completion logic. | Directly represented by Mamba's accessor tree. |
| File metadata | Cobra exposes filename APIs/directives. | Not present in the current registry. |

There is also a PowerShell-specific detail worth noticing in Cobra's current
source: its generated PowerShell script identifies file-extension and directory
filter directives as unsupported and returns instead of applying them. Cobra's
cross-shell completion API still exposes those concepts, but its present
PowerShell adapter does not implement those two directives in the same way as
every other shell. Mamba could eventually do better on PowerShell by compiling
an explicit path semantic kind to a native `Get-ChildItem` helper.

Mamba's static approach and Cobra's runtime approach are not mutually exclusive.
The most capable long-term design is static registry completion by default with
an explicit dynamic provider only for values that truly require execution.

Sources:

- [Cobra shell completion guide](https://cobra.dev/docs/how-to-guides/shell-completion/)
- [Cobra's generated PowerShell completion implementation](https://github.com/spf13/cobra/blob/main/powershell_completions.go)

## 19. Suggested generated data model

The converter does not need to reproduce the registry map literally in
PowerShell. It can emit lookup tables optimized for completion:

```powershell
$script:MambaCommands = [ordered]@{
    'root' = [pscustomobject]@{
        Children = @(
            [pscustomobject]@{
                Name        = 'checkout'
                Canonical   = 'checkout'
                Description = 'Switch branches.'
            }
            [pscustomobject]@{
                Name        = 'co'
                Canonical   = 'checkout'
                Description = 'Alias for checkout. Switch branches.'
            }
        )

        LongInputs  = @('--help', '--verbose')
        ShortInputs = @('-h', '-v')
    }
}

$script:MambaValueHandlers = @{
    'root.build.option.format' = {
        param($state)

        foreach ($choice in 'text', 'json', 'yaml') {
            Write-MambaCompletion `
                -CompletionText $choice `
                -ListItemText $choice `
                -ResultType 'ParameterValue' `
                -Description "Value for --format" `
                -Prefix $state.WordToComplete
        }
    }
}
```

Good generated tables should:

- preserve registry declaration order;
- store canonical identity separately from spelling;
- give long and short spellings the same value handler;
- flatten accessor leaves during Dart generation;
- precompute repeated positional spans;
- precompute effective candidate descriptors where safe; and
- keep parser validation metadata separate from candidate sources.

## 20. Generated-script boundaries and safety

Completion code runs interactively and frequently. It should be quiet, fast,
and side-effect free.

The generated completer should:

- write only completion objects to the success pipeline;
- avoid `Write-Host`, progress output, prompts, and ordinary diagnostics;
- catch recoverable resolver errors and return no candidates;
- avoid evaluating AST expressions supplied by the user;
- avoid network access for static completion;
- avoid launching Mamba for static registry values;
- quote generated PowerShell string literals safely;
- use invariant formatting for generated numeric values; and
- prefix helper and variable names to avoid collisions in a user's profile.

A generated module is cleaner than many global functions. Module scope keeps
lookup tables private while the module registers the completer when imported.
A standalone `.ps1` file also works when dot-sourced, but its generated names
should be uniquely prefixed.

## 21. Test matrix

At minimum, the PowerShell converter and resolver should test these cases:

1. Root completion returns canonical child commands.
2. Root completion also returns aliases.
3. Selecting an alias enters the canonical child's handler.
4. Nested commands resolve recursively.
5. `-` returns only short input names.
6. `--` returns only long input names.
7. `--no-` returns only applicable negatable flag forms.
8. Hidden flags and options never appear.
9. The built-in `--help` and `-h` are available at every command.
10. A long choice option routes to its values.
11. The short spelling of that option routes to the same values.
12. A negative integer pending as an option value is not treated as a flag.
13. A safely bounded integer range emits every inclusive value.
14. A one-sided integer range emits no static values.
15. An excessively large integer range is not expanded.
16. A double with only `min` and `max` emits no invented step values.
17. A repeatable choice option continues offering values.
18. A used `oneOf` member suppresses or demotes its siblings according to policy.
19. A partially used `all` group prioritizes remaining members according to policy.
20. A choice positional is selected by logical positional index.
21. A repeated positional occupies exactly `1 + times` slots.
22. An explicit empty argument still consumes one positional slot.
23. Tokens consumed as option values do not increment the positional index.
24. A non-repeatable choice variadic completes only its first value after `--`.
25. A repeated choice variadic continues indefinitely after `--`.
26. Flags and commands are not offered after the variadic separator.
27. Recursive accessor leaves become full dotted candidates.
28. A choice accessor leaf routes to its declared values.
29. Hidden accessor groups hide their entire subtree.
30. Persistent inputs accumulate along the active command path.
31. A nearer persistent or local definition shadows the inherited definition.
32. Command and input descriptions populate completion tooltips.
33. Prefix matching uses Mamba's intended case policy.
34. Quoted arguments containing spaces remain one token.
35. Completion requested in the middle of a line ignores later tokens for state resolution.
36. Handlers emit individual pipeline objects rather than one nested array.
37. A plain string pattern does not accidentally activate filesystem completion.
38. `--name=value` completion is generated only if the parser supports that syntax.
39. Short-flag clusters are not invented without parser support.
40. Resolver failures produce no interactive noise.

## 22. Final recommendation

PowerShell is a strong target for Mamba's registry design. Its hashtables can
store canonical mappings, its script blocks can act as mapped handlers, its AST
preserves more command structure than Bash's word arrays, and its completion
objects can display registry descriptions directly.

The best implementation is a static generated PowerShell resolver for everything
the registry can enumerate today:

- commands and aliases;
- visible long and short flags/options;
- negatable flag names;
- choice values;
- safe finite integer ranges;
- repeated positional spans;
- choice variadics;
- recursive accessor leaves; and
- persistent input inheritance.

Do not stretch validation metadata into fake completion sources. Regexes,
unbounded numbers, doubles without a step, files, URLs, and live application
values need explicit completion metadata or dynamic providers. That boundary
keeps the generated script predictable and lets Mamba remain the authority on
what the command actually accepts.

