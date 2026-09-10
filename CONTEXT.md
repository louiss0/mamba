# Mamba Command Inputs

Mamba defines command-line inputs once and uses those declarations for parsing, validation, help, completion, and typed value consumption.

## Language

**Input declaration**:
An identity-bearing description of one command-line input and the value it produces.
_Avoid_: Input value, parsed value

**Required input**:
An input the user must supply and whose output is always available.
_Avoid_: Mandatory output

**Optional input**:
An input the user may omit and whose output may be absent.
_Avoid_: Discretionary input

**Defaulted input**:
An input the user may omit whose configured fallback makes its output always available.
_Avoid_: Optional input, required input

**Mandatory positional**:
An ordered positional input for which the user must supply a token.
_Avoid_: Required positional

**Discretionary positional**:
An ordered positional input for which the user may omit a token.
_Avoid_: Optional positional

**Paired options**:
An all-or-nothing set of options mapped into one cohesive output value.
_Avoid_: Option pair, option bundle

**Selected options**:
A mutually exclusive set of options mapped from the selected member into one output value.
_Avoid_: Variant options, one-of options
