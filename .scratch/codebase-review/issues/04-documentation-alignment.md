# Correct documentation that contradicts behavior

Type: task
Status: resolved
Closes: D1, D2, D3, D4, D5, D7, D8.

Eight places describe behavior the framework does not have. The glossary is already right in
three of these cases; the prose is what drifted.

## Work

- **D1** — repeated positional cardinality has three descriptions. `arguments.md:94` says "at
  most `times + 1`", `completions.md:190` and `completion-commands.md:112` say exact repetition
  count. The canonical meaning is in `CONTEXT.md`: up to `times` values. Fix the prose and
  exercise the documentation example against that meaning.
- **D2** — default command documentation restricts selection to empty arguments
  (`commands.md:112`, `executor.md:153`). Use the scope-based definition: a default is selected
  when an invocation does not name a child at that scope. Do not describe executor-owned
  dispatch as equivalent to calling `GroupCommand.run` directly.
- **D3** — `skills/mamba-framework/references/completion-commands.md` is wrong three times:
  `CompletionCommand.preset()` without its required `createFile`, a one-argument callback, and the
  claim that the callback replaces generation and receives no content. The writer takes
  `(String path, String contents)`. Fix and compile every example in the file — agents read it.
- **D4** — `overview.md:109` says selected options map one mutually exclusive member.
  `SelectedOptions` allows several members unless `single: true`.
- **D5** — `options.md:187` says accessor leaves remain omittable. Required accessor
  constructors exist and are enforced. Distinguish optional, required, and defaulted leaves, and
  note that nested leaf handles are directly readable.
- **D7** — `flags.md:8` says propagated flags apply to the group and its descendants. The
  declaring group is not covered; its local inputs are separate registrations.
- **D8** — `flags.md:67` says `--no-force` is not shown in help. The formatter includes the
  negated spelling. Generate or test the example against formatter output instead of maintaining
  an approximation.

## Acceptance

- Every example in the changed documentation and skill files compiles and, where it asserts
  behavior, is executed as a documentation test.
- No documentation file states a cardinality, requiredness, or scope rule that `CONTEXT.md`
  contradicts.
- D6's promise is handled in ticket 02, not here.

## Resolution

Shipped in `c5382e0 docs(mamba): state what the framework actually does`.

All seven prose fixes landed. Two deserve a note:

- D3's examples were compiled against the current API before and after the
  change: `CompletionCommand.preset(createFile: null)` is the default writer,
  and the callback takes `(path, contents)` with the content always generated.
- D8's example is the formatter's real output for a negatable flag, and the
  formatter test that pins that rendering is named in the prose so a reader
  knows where the claim is checked.

D6 needed no text: `README.md` and `reference/executor.md` already promised
unchanged output, and ticket 02 made that true.

## Comments