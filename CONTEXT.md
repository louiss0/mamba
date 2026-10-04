# Mamba

Mamba describes command-line interfaces as commands and typed input declarations.

## Language

**Command path**:
The sequence of commands selected by an invocation, whether named explicitly or selected by defaults.

**Default command**:
A command selected when an invocation does not name a child command at a scope that has a configured default. It is selected implicitly rather than by a command token. Each scope is resolved on its own: the executor's `defaultCommandPath` covers the root, and a group's `defaultSubCommandPath` covers that group once the group itself has been named. A root without a default command renders help rather than reaching into a child group's default.

**Typed input declaration**:
A retained handle describing a command-line input and the type of value a command may read from it.

**Repeated positional**:
A positional input that accepts up to a declared maximum number of values. Its `times` count is the maximum number of values, not a number of additional repetitions. It stops collecting at the first word that is not one of its own values, leaving that word to the next positional; a word it turns away is reported as a rejected value rather than as an unknown command.

**Command name**:
The shared spelling of a command, an alias, or a named input. Letter-led words of letters and digits, separated by a single hyphen or underscore, so `max-workers2` is legal and `dry__run`, `2fast`, and `verbose!` are not.
