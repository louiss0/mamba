# Closed declaration value family with domain built-ins

Mamba adds selected framework-provided domain value types while keeping the declaration value family closed, rather than exposing application-defined converters or retaining primitive outputs alone. This keeps supported value behavior and metadata within the framework's maintained family, at the cost of additional built-in variants and leaving arbitrary domain conversion in application code. The concrete built-in set and each type's syntax and metadata contracts require separate decisions.
