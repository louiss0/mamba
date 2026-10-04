# Deferred renames and vocabulary analysis

Type: task
Status: resolved
Closes: the vocabulary table in CODEBASE_REVIEW.md.

The analysis is done and recorded here. The renames stay deferred, which is the
decision: `toRecord()` shipped with ticket 01 because the name lied about the
return type and the fix was mechanical, and the rest are not mechanical.

## What each name reaches

| Name | Declared at | Reaches | Meaning |
| --- | --- | --- | --- |
| `propagatedFlags` / `propagatedOptions` | `GroupCommand` constructor (`lib/command.dart:1613`) | the group's **descendants** | what an author writes: this group publishes these |
| `inheritedFlags` / `inheritedOptions` | `GroupCommand` field (`command.dart:1596`) | the same list, from the registry's side | what the registry consumes: these arrived from an ancestor |
| `publishedFlags` / `publishedOptions` / `publishedAccessors` | `CommandRegistry` constructor | a registry's own descendants | the registry's term for the same list, used when walking the tree (`_publishedFlagsToHere`) |
| `persistentFlags` / `persistentOptions` on `RegistryCommand` / `RegistryRecord` | `lib/registry.dart:13-15` | converters only | **a different concept**: inputs a *record* declares that a converter must carry into descendants |

`propagatedFlags`, `inheritedFlags`, and `publishedFlags` are one concept seen
from three points of view — author, child, registry. `persistentFlags` on a
record is not: it is a field of the exported description that a converter reads,
and `RegistryRecord.persistentFlags` is `null` for every record the registry
produces. A converter merging `command.persistentFlags` into a child's inputs is
reading a hand-authored statement, not registry-derived inheritance.

## Why the rename stays deferred

1. Renaming `propagatedFlags` alone breaks the documented API for no defect; the
   glossary now defines *propagated input* so prose uses one term even while the
   three code names remain.
2. `publishedFlags` is a registry-internal constructor parameter and never
   appears in a public signature, so it costs nothing but readability to keep.
3. `persistentFlags` must not be renamed blindly, exactly as the ticket warns:
   it is only a synonym for the others when you are looking at the
   `GroupCommand` parameter, and a different field entirely when you are looking
   at a `RegistryRecord`. Any rename has to state which of the two it means.

## The remaining two renames

- **Help heading `Accessor flags` → `Accessor options`** (`lib/help_formatter.dart`):
  these inputs take values, and `CONTEXT.md` now defines *accessor option* with
  *accessor flag* listed under _Avoid_. Renaming changes user-visible help and
  the checked-in completion goldens, so it wants its own change with regenerated
  artifacts.
- **`propagated`/`inherited`/`published` → one name**: pick `propagated`, which is
  the only one an author writes, and keep the record-level `persistent*` as is.

Neither blocks a correctness fix; both are user-visible or API-visible and belong
to their own change.