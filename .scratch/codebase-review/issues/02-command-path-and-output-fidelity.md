# Command paths exclude the application name; output is byte-exact

Type: task
Status: resolved
Closes: F1, D6.

Two corrections on the executor side. Resolution currently treats a token matching the
application name as an optional prefix, and the executor then skips *every* path segment
matching that name instead of only the first. Separately, the process writes through
`writeln` while the documented contract promises stdout identical to the fake result's output.

## Work

1. Remove implicit application-name prefixing from both `resolveCommandPath` and
   `_commandsForPath`. A command path never begins with the application name.
2. When a leading token equals the application name and does not name a child, reject the
   invocation with a failure whose message states the rule: a command path never begins with the
   application name. The hint is an error message, not a resolution special case — resolution
   itself must stay free of application-name knowledge.
3. Stop hardcoding control-flag spellings outside the registry. `_requestsControlFlag` and the
   parser both recognize help and version spellings independently of any declaration; that
   duplication is why a declared `-h` could be shadowed. One source of truth, consumed by the
   parser to tell the executor that a control flag was used.
4. Write output and errors with exact bytes: `write`, not `writeln`, on both stdout and stderr.
   Update the process tests to assert the fake's bytes, which is now the contract.

## Acceptance

- Executing `['tool']`, `['tool', 'tool']`, and `['tool', 'tool', 'tool']` against application
  `tool` with a child `tool` runs the child, and the regression test names the command that
  actually ran. Covers root-name reuse, ancestor-name reuse, aliases, and explicit versus
  default selection.
- An invocation beginning with an unmatched application name fails with the hint, not help.
- The generated starter-test template no longer emits `execute(['$name', '--help'])`, since that
  spelling now means "unknown command" (see ticket 05).
- Process tests assert byte-identical stdout and stderr, including the UTF-8 and multi-error
  cases the review lists as missing.
- `README.md` and `docs/src/content/docs/reference/executor.md` state the exact-byte contract.

## Resolution

Shipped in `d766249 fix(executor): keep the application name out of command paths`.

- `resolveCommandPath` no longer swallows a leading application-name token, and
  a resolved path no longer carries the application name; `descendant()` walks a
  path the way an invocation names it and `registryForPath()` keeps its
  full-path form for callers that have one.
- A leading name that matches no child raises `MambaApplicationNameException`,
  which the executor turns into a failure carrying the rule.
- `MambaBuiltInFlags.isHelp`, `isVersion`, and `isControl` are the only places
  the spellings are written down; the parser and the executor both read them.
- `SystemMambaProcess` writes and reports with `write`, and the process tests
  assert the exact bytes the fake returns, including multi-line output and an
  error carrying only a message.

Two existing tests encoded the old convention — a resolved path of
`['tool', 'config']` and an invocation that repeated the application name — and
now assert the path without the application name.

The generated starter template needed no change: it invokes a real child command
by its own name under a differently named executor, which is exactly what the
new rule says.

## Comments