# Command-Line Domain-Specific Language

This page records the research used to decide how Mamba describes command-line
syntax in generated help. It focuses on synopsis notation: the compact language
that tells a user which tokens are required, optional, mutually exclusive,
repeatable, or variadic.

The research was reviewed on August 24, 2026. The sources are primary
documentation for POSIX, Linux manual pages, Click, Python `argparse`, and Rust
`clap`.

## Terminology

The sources use overlapping terms, but the following vocabulary is consistent
enough for this document:

* A **command** selects an operation or a nested command group.
* An **option** is a named input such as `--config` or `-c`.
* An **option argument** is the value consumed by an option.
* An **operand** is a non-option token interpreted by its position. Mamba calls
  this a **positional**.
* A **repeated positional** accepts a bounded series of positional values.
* A **variadic positional** accepts every positional value left after the
  bounded positionals have been filled.
* A **value placeholder**, formally called a **metavariable**, stands for a
  value the user supplies. In `--config FILE`, `--config` is literal but `FILE`
  stands for a path such as `settings.json`. It is a help label, not a token the
  user types. Mamba derives it from the input name, so `config-file` becomes
  `CONFIG_FILE`.

## Shared Synopsis Conventions

### Optional input uses square brackets

POSIX utility syntax encloses optional options and operands in square brackets.
The Linux manual-page conventions and Click use the same rule. For example,
`[FILE]` means that `FILE` may be omitted.

This convention is the strongest point of agreement across the researched
systems and is worth preserving because experienced CLI users already read
square brackets as optional syntax.

Sources: [POSIX Utility Argument Syntax][posix],
[Linux man-pages synopsis conventions][linux-man-pages], and
[Click help pages][click-help].

### Alternatives use a vertical bar

POSIX and Linux manual pages use `|` between alternatives. An expression such
as `json | yaml` means that one member can be selected, not that both members
can be supplied.

Python `argparse` renders a restricted choice set with braces and commas, such
as `{rock,paper,scissors}`. The notation differs, but the important behavior is
the same: help should expose the accepted values rather than only showing a
generic field name.

Sources: [Linux man-pages synopsis conventions][linux-man-pages] and
[Python argparse choices][argparse-choices].

### Ellipses communicate repetition

POSIX places `...` after an option or operand to show that it can occur more
than once. A bracketed expression followed by an ellipsis permits zero or more
occurrences. An unbracketed first occurrence followed by a bracketed repeated
occurrence permits one or more.

Click follows this convention by rendering an optional variadic argument as
`[FOO]...`. Rust `clap` similarly renders a multiple positional as `[name]...`.
The marker is effective because it says both that the input repeats and that
the repeated values occupy the same conceptual slot.

Mamba follows the required, optional, and alternative conventions directly.
It uses regex quantifiers instead of ellipses for repetition, as described
below.

Sources: [POSIX Utility Argument Syntax][posix], [Click help pages][click-help],
and [clap positional arguments][clap-positionals].

## Arity Models

The researched frameworks distinguish fixed, optional, repeated, and variadic
arity even when their display syntax differs.

Python `argparse` exposes the most explicit arity model:

* An integer `N` consumes exactly `N` values.
* `?` consumes zero or one value.
* `*` consumes zero or more values.
* `+` consumes one or more values.

For an integer arity, `argparse` repeats the metavariable in help, such as
`--foo FOO FOO`. For one-or-more positionals, its error output uses a form such
as `foo [foo ...]`.

Click uses a positive `nargs` for fixed arity and `nargs=-1` for an arbitrary
number of values. It permits only one variadic positional because that input
consumes all remaining positional tokens.

Rust `clap` separates collection behavior from value count. Its generated help
still uses familiar positional delimiters and ellipses rather than exposing
the builder API directly.

Mamba maps its arity model to regex syntax:

* `{1,N}` means between one and `N` values.
* `+` means one or more occurrences.
* `*` means zero or more values.
* Parentheses group a choice or complete option occurrence before it is
  quantified.

Sources: [Python argparse nargs][argparse-nargs],
[Click arguments][click-arguments], and [clap argument syntax][clap-syntax].

## Positionals And Variadics

A variadic belongs to the positional grammar, not the option grammar. It is
selected by position, has no `--name` token on the command line, and collects
the remaining operands. Click explicitly describes variadics as arguments with
arbitrary arity, while `argparse` models the same behavior with positional
`nargs='*'` or `nargs='+'`.

That leads to the following design rules for Mamba:

* Render a variadic after mandatory and discretionary positionals.
* Render it in the usage line rather than the Options section.
* Permit only one variadic per command registry.
* Treat it as optional while the parser permits an empty collected list.
* Show its accepted choice names when it is a `ChoiceVariadic`.

The resulting position communicates ownership. In a usage expression such as
`copy source [destination] [extra*]`, `extra` is visibly the final positional
slot rather than a named option.

## Choice Display

Showing only a positional name hides an important constraint. Both `argparse`
and typed CLI frameworks expose possible values in generated help, although
they use different punctuation.

Mamba uses its existing `OrString` vocabulary and joins enum member names with
`|`. A quantified choice is grouped so the quantifier applies to the complete
choice expression:

```text
auto|always
[(json|yaml)*]
[-f|--format (json|yaml)]
```

This keeps the synopsis compact and makes the valid command-line spellings
visible. The enum type name and Dart enum qualification are intentionally not
shown because users enter member names, not Dart expressions.

## Bounded Repetition

There is no single dominant synopsis notation for a bounded range. `argparse`
repeats the metavariable for exact arity, while POSIX concentrates on one-or-
more and zero-or-more expressions. Mamba already has a bounded
`RepeatedPositional` model, so generated help needs to expose that limit.

Mamba uses a regex interval whose upper bound is the maximum accepted arity:

```text
files{1,3}
[(auto|always){1,2}]
```

`N` is the maximum number of accepted values, not the raw `times` constructor
value. `RepeatedPositional.times` counts repetitions after the original value,
so `times: 2` accepts at most three values and renders `{1,3}`. A discretionary
repeated positional wraps that expression in square brackets, allowing the
entire series to be omitted.

## Mamba Help Grammar

The current formatter produces these positional forms:

| Input definition | Mamba help expression |
| --- | --- |
| Mandatory positional | `source` |
| Discretionary positional | `[target]` |
| Mandatory choice positional | `auto|always` |
| Repeated positional with `times: 2` | `files{1,3}` |
| Repeated choice with `times: 1` | `[(auto|always){1,2}]` |
| Normal variadic | `[extra*]` |
| Choice variadic | `[(json|yaml)*]` |
| Optional string option | `[--config CONFIG]` |
| Optional choice option | `[--format (json|yaml)]` |
| Repeatable option occurrence | `[(--tag TAG)+]` |
| Dependent paired options | `[--user USER & --password PASSWORD]` |
| Mutually exclusive paired options | `[--token TOKEN|--api-key API_KEY]` |

The formatter also uses ANSI color as a second communication channel: required
expressions are red, optional expressions are dim, section titles are green,
and entry descriptions are yellow. Delimiters remain meaningful when color is
disabled or stripped.

[posix]: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html
[linux-man-pages]: https://man7.org/linux/man-pages/man7/man-pages.7.html
[click-help]: https://click.palletsprojects.com/en/stable/documentation/
[argparse-choices]: https://docs.python.org/3/library/argparse.html#choices
[clap-positionals]: https://docs.rs/clap/latest/clap/_tutorial/#positionals
[argparse-nargs]: https://docs.python.org/3/library/argparse.html#nargs
[click-arguments]: https://click.palletsprojects.com/en/stable/arguments/
[clap-syntax]: https://docs.rs/clap/latest/clap/macro.arg.html

## How Mamba Differs From The Researched Conventions

Mamba deliberately does not reproduce any one external grammar exactly.

| Concern | Common researched form | Current Mamba form |
| --- | --- | --- |
| Required positional | Bare `FILE` or italic `file` | Bare `file` |
| Optional positional | `[FILE]` | `[file]` |
| Choice set | `{json,yaml}` or a value listing | `(json|yaml)` when grouping is needed |
| Variadic positional | `FILE...` or `[FILE]...` | `[file*]` |
| Exact fixed arity | Repeated metavariables such as `FILE FILE` | No dedicated positional type |
| Bounded repeated arity | Tool-specific | Regex interval such as `file{1,3}` |
| Repeatable named option | `[--tag TAG]...` | Regex group such as `[(--tag TAG)+]` |
| Required dependency | Usually explained in prose or validation errors | Members joined with `&` |
| Mutual exclusion | `A | B` or prose | Members joined with `|` |
| Value placeholder | Custom or derived name | Uppercase name derived by Mamba |
| Styling | Typography, capitalization, or plain text | ANSI color plus delimiters |

Mamba now aligns with POSIX and Linux conventions for bare required operands,
compact optional brackets, literal option tokens, placeholders, and `|`
alternatives. Its remaining project-specific syntax is the use of regex
quantifiers for repetition and `&` for required dependencies. Those extensions
are explicit in generated help and should not be assumed to be universal CLI
notation.
