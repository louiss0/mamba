# TODO

I need you to do the following tasks! 

1. Make the registry tests pass 
2. Make sure that commands accept a `List<AccessorListOption>` instead of `List<AccessorOption>`
3. Remove the `pairOption` field from the registry! 
  - When the paired option is chosen the `pairOptions` will be iterated through to validate them

Commit the changes that are related to task 2 and three.
Commit the tests related to task one only If there's a test that doesn't cover something!
If so then make suggestions!

## Follow-up test coverage

4. Add `CommandRegistry.toMap()` tests for `ChoiceOption` and `PairedChoiceOption`, including defaults and variants.
5. Add `CommandRegistry.toMap()` tests for paired integer/double options and repeatable paired options.
6. Decide whether aliases and hidden inputs should be included in exported registry maps, then add coverage for that behavior.
