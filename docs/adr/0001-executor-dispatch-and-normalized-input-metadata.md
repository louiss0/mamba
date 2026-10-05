# Executor-owned dispatch and normalized input metadata

Default commands are resolved by the executor before parsing, including chained group defaults, so the selected leaf's inputs and all applicable hooks use the same execution pipeline as an explicitly named command. Direct `GroupCommand.run` remains a low-level call, not equivalent to executor dispatch. The registry owns the shared interpretation of input kind and positional cardinality; parsing and completion use that interpretation, while shared validation helpers keep declaration defaults and explicit values in sync. Typed declaration handles remain the way commands read parsed values. We chose this over direct child `run` calls and independent interpretation in each consumer because those approaches let parsing contexts, hooks, and completion behavior diverge.

A group of related options is described rather than flattened. Paired and
selected groups both reach a record's `optionGroups`, the selected group
carrying `single`, so the relationship a command declared survives into the
completion artifacts instead of arriving as members that merely look
independent. Shell-side enforcement is a separate matter: the current converters
do not enforce paired-group relationships either. Preserving both kinds in the
record makes that a uniform, documented gap rather than a lost declaration.
Group kind is inferred from each member's `pairedOptions`: selected members
have an empty list, paired members list their partners. A required selected
group requires a selection, not every member, so Carapace must not mark each
selected member mandatory. Manually built records with null partner metadata
retain the existing paired-group interpretation.

## Amendment

The registry is the single authority on declaration validity, including reserved spellings, effective spellings after inheritance and overrides resolve, and declared counts and capacities, all of which must be positive. A count is refused where it is declared rather than in one registry pass, because that is where a negative count was already refused and one constructor then covers every shape of the declaration; the registry still refuses a default that cannot fit its own capacity, which only it can see. Only help and version spellings are reserved; opt-in built-in declarations are ordinary declarations the registry validates like any other. The parser recognizes those reserved spellings and tells the executor they were used; it does not interpret them independently of a declaration.

A command path never begins with the application name. Resolution no longer treats a leading application-name token as an optional prefix, so an invocation that repeats the application name either names a child command or is rejected with a hint that says so.

Integers are signed decimal in every spelling — long, inline, paired, repeatable, and accessor alike — so one scanner and one value parser decide what is acceptable. Generated shell completions are derived from that same interpretation rather than re-deriving it: every finite candidate satisfies the declaration's own validation, and generated identifiers are encoded independently of user spellings so that `foo-bar` and `foo_bar` never share an identifier or a path boundary. Mamba supports Bash 4 and newer: the Bash completion scopes command names with associative arrays, which need Bash 4, and the artifact says so and stops rather than failing obscurely on an older shell. These changes follow from the original decision that the registry owns shared interpretation; the alternatives we rejected were per-consumer validation (which let propagated inputs and accessor leaves bypass the rules), implicit application-name prefixing (which made a command sharing the application name undispatchable), completion that encoded names literally into generated identifiers, and a Bash completion that avoided associative arrays to keep Bash 3 working.