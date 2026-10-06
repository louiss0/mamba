# Keep exception-driven nonzero exit statuses

Mamba retains success with exit code 0 and uses exceptions for nonzero statuses rather than add distinct normal-completion status results or a unified status/diagnostic result shape. Expected outcomes such as a grep-like no-match status of 1 still require a failure exception, accepting that adaptation in exchange for retaining the existing error-based status mechanism. This narrows the normal-nonzero-status capability proposed when choosing the general-purpose core in ADR-0002; documentation must not claim that this limitation was removed.
