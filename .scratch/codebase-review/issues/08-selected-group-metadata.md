# Preserve selected-option relationships in registry records

Type: task
Status: resolved
Closes: T2's selected-group metadata half.

## Work

The final follow-up request was "Do both please then commit": preserve selected
group metadata and check all documentation examples (ticket 09).

Export both paired and selected groups through `RegistryRecord.optionGroups`,
retaining requiredness, exclusivity and member order. Keep ordinary member
option records, and keep the record immutable. Do not implement shell-side
group enforcement as part of this representational fix.

## Decision

The user chose to infer group kind from member metadata rather than adding a
kind discriminator. Registry-produced selected members have an empty
`pairedOptions` list; paired members list their partners. Null partner metadata
retains the converter's existing paired interpretation for manually built
records.

## Resolution

`RegistryOptionGroup` adds `single`; `CommandRegistry.toRecord()` now exports
both kinds in an unmodifiable group list, with unmodifiable member lists.
Carapace no longer marks every member of a required selected group mandatory:
that group requires a selection, not all members. Paired required groups retain
their mandatory members. The ADR and both completion references state the
representation and the remaining shell-enforcement limitation.

Verification: `dart test test/integrations_test.dart` passes all 19 tests,
including root selected-group metadata, nested fixture metadata, immutability,
required selected versus paired members, legacy manual records, and generated
fixture equality. The new immutability and Carapace assertions were observed
failing before their fixes. All completion fixtures were regenerated; only the
Carapace member order changed.

No version bump, changelog entry or compatibility alias, as agreed.

## Comments
