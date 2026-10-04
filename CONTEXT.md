# Mamba

Mamba describes command-line interfaces as commands and typed input declarations.

## Language

**Command path**:
The sequence of commands selected by an invocation, whether named explicitly or selected by defaults. It never begins with the application name: an invocation that repeats the application name is naming a child command, or is rejected.
_Avoid_: Application prefix, argv path

**Default command**:
A command selected when an invocation does not name a child command at a scope that has a configured default. It is selected implicitly rather than by a command token. Each scope is resolved on its own: the executor's `defaultCommandPath` covers the root, and a group's `defaultSubCommandPath` covers that group once the group itself has been named. A root without a default command renders help rather than reaching into a child group's default.

**Typed input declaration**:
A retained handle describing a command-line input and the type of value a command may read from it.

**Declaration validity**:
Whether a typed input declaration is well-formed across the whole command tree: legal spellings, no two applicable inputs answering to the same spelling, a positive capacity, and no reserved spelling. Validity is decided once, by the registry, before any invocation runs.
_Avoid_: Input validation, parse-time checking

**Reserved spelling**:
A spelling the framework always interprets itself rather than as a declaration. Help and version spellings are reserved; opt-in built-in declarations such as the dry-run flag are not. A declaration that uses a reserved spelling is invalid.
_Avoid_: Built-in flag, magic spelling

**Propagated input**:
An input declared by a group and made available to that group's descendants, never to the group itself. The group's own local inputs are separate registrations, and a descendant's local declaration deliberately overrides a propagated one.
_Avoid_: Inherited flag, published flag, persistent flag

**Accessor option**:
A typed input declaration whose values are read through nested leaves addressed by dot-separated path segments. Each leaf is independently optional, required, or defaulted.
_Avoid_: Accessor flag (it takes values)

**Repeated positional**:
A positional input that accepts up to a declared maximum number of values. Its `times` count is the maximum number of values, not a number of additional repetitions. It stops collecting at the first word that is not one of its own values, leaving that word to the next positional; a word it turns away is reported as a rejected value rather than as an unknown command.

**Command name**:
The shared spelling of a command, an alias, or a named input. Letter-led words of letters and digits, separated by a single hyphen or underscore, so `max-workers2` is legal and `dry__run`, `2fast`, and `verbose!` are not. `foo-bar` and `foo_bar` are two different names, never one name.

**Completion candidate**:
A value a shell offers for an input. Every candidate is a value that input's own declaration accepts, and distinct accepted names keep distinct generated artifacts.
_Avoid_: Suggestion, hint, completion token