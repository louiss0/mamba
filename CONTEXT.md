# Mamba

Mamba models command-line interfaces through commands and typed input declarations. Its domain covers administrative command trees, filters, and process wrappers.

## Language

**Command path**:
The sequence of commands selected by an invocation, whether named explicitly or selected by defaults. It never begins with the application name: an invocation that repeats the application name is naming a child command, or is rejected.
_Avoid_: Application prefix, argv path

**Default command**:
A command selected when an invocation does not name a child command at a scope that has a configured default. It is selected implicitly rather than by a command token. Each scope is resolved on its own: the executor's `defaultCommandPath` covers the root, and a group's `defaultSubCommandPath` covers that group once the group itself has been named. A root without a default command renders help rather than reaching into a child group's default.

**Typed input declaration**:
A retained handle describing a command-line input and the type of value a command may read from it.

**Token ownership**:
The command or input an invocation token belongs to, determined by invocation syntax independently of content validation.

**Explicit input occurrence**:
An input supplied in the command-line tokens, distinct from a value supplied only by a declaration default. Syntax conflicts concern explicit occurrences, not resolved values.
_Avoid_: Default presence, effective-value presence

**Input relationship**:
A declaration-level constraint between named inputs: explicit-occurrence conflicts or paired/selected value-option groups. Constraints outside that vocabulary belong to application logic.

**Declaration validity**:
Whether a typed input declaration is well-formed across the whole command tree: legal spellings, no two applicable inputs answering to the same spelling, a positive capacity, and no reserved spelling. Validity is decided once, by the registry, before any invocation runs.
_Avoid_: Input validation, parse-time checking

**Reserved spelling**:
A spelling the framework always interprets itself rather than as a declaration. Help and version spellings are reserved; opt-in built-in declarations such as the dry-run flag are not. A declaration that uses a reserved spelling is invalid.
_Avoid_: Built-in flag, magic spelling

**Local input**:
An input available only when its declaring command is selected, not when a descendant is selected. Token placement before a child command does not make a parent-local input applicable.

**Propagated input**:
A group-declared input available to the declaring group and all descendants. A descendant may replace it with an input of the same kind, output type, and cardinality, while both retained handles read the effective descendant value.
_Avoid_: Inherited flag, published flag, persistent flag

**Effective input**:
The applicable declaration owning a spelling after propagation and compatible local overrides are resolved. Its value is also readable through retained handles of compatible overridden declarations.

**Accessor option**:
A typed input declaration whose values are read through nested leaves addressed by dot-separated path segments. Each leaf is independently optional, required, or defaulted.
_Avoid_: Accessor flag (it takes values)

**Trailing arguments**:
The tokens after the first `--`, kept separate from positional inputs and never used to satisfy their declarations.
_Avoid_: Escaped positionals, positional continuation

**Repeated positional**:
A positional input accepting at most its finite maximum (`times`), with tokens reserved for following required positionals. Content validation checks the assigned values rather than transferring rejected values to another positional.

**Command name**:
The shared spelling of a command, an alias, or a named input. Letter-led words of letters and digits, separated by a single hyphen or underscore, so `max-workers2` is legal and `dry__run`, `2fast`, and `verbose!` are not. `foo-bar` and `foo_bar` are two different names, never one name.

**Command instance ownership**:
A command instance belongs to one configured executor, which may create multiple execution adapters. Different configured executors use different command instances; each command object occupies one canonical path, while aliases and shared immutable input declarations remain valid.

**Fake execution**:
An invocation executed without connecting the executor's process-delivery boundary. It neither replaces nor intercepts command-owned effects, whose services and mocks remain application-owned.

**Choice spelling**:
The declared text representing one enum member in command-line input, help, and completion. It may differ from the member's source-code name without changing the typed value a command reads; offered spellings are exact, case-sensitive strings and must be unique within a declaration's choices.

**Completion candidate**:
A value a shell offers for an input. Every candidate is a value that input's own declaration accepts, and distinct accepted names keep distinct generated artifacts.
_Avoid_: Suggestion, hint, completion token