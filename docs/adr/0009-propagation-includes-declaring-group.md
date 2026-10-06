# Propagated inputs include the declaring group

A propagated input applies to the group that declares it and all descendants, while a local input remains local. We chose to change propagation rather than introduce a third whole-subtree scope so one group setting can serve the whole subtree through the existing conceptual mechanism. This intentionally replaces the former descendant-only glossary contract and changes which invocations of the group itself accept the declaration; compatible overrides retain the handle semantics in ADR-0008.
