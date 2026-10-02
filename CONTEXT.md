# Mamba

Mamba describes command-line interfaces as commands and typed input declarations.

## Language

**Command path**:
The sequence of commands selected by an invocation, whether named explicitly or selected by defaults.

**Default command**:
A command selected when an invocation does not name a child command at a scope that has a configured default. It is selected implicitly rather than by a command token.

**Typed input declaration**:
A retained handle describing a command-line input and the type of value a command may read from it.

**Repeated positional**:
A positional input that accepts up to a declared maximum number of values. Its `times` count is the maximum number of values, not a number of additional repetitions.
