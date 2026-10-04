# Registry owns declaration validity

Type: task
Status: resolved
Closes: F5, F6, F7, and the `toRecord()` rename from the vocabulary table.

The registry is the single authority on whether a typed input declaration is legal. Today
validation is thorough for local inputs but bypassed by propagated inputs and accessor leaves,
and it runs before inheritance is resolved, so the effective spelling set is never checked.

## Work

1. Validate the *effective* declaration set for every registry, after inheritance and permitted
   overrides resolve. Cover root, local, propagated, and nested-accessor registrations with the
   same checks.
2. Reject a declaration that uses a reserved spelling. Reserved means help and version only:
   `--help`, `-h`, `--version`, `-V`. Opt-in built-ins such as the dry-run flag are ordinary
   declarations and are not reserved.
3. Reject two applicable inputs answering to the same spelling across inherited and local
   declarations. Preserve intentional overrides: a descendant's local declaration shadowing a
   propagated one is legal and must keep working.
4. Reject zero as a declared count or capacity, everywhere it appears — repeated positional
   `times`, variadic bounds, selected-option cardinality, accessor capacity. A declaration that
   can never be satisfied, and one whose default can never fit, are both errors.
5. Unify integer syntax. Signed decimal in every spelling: long, inline, paired, repeatable, and
   accessor. One scanner, one value parser, one rule. Remove the duplicated numeric patterns and
   the direct `int.tryParse` path so `--number 0x10`, `--number=-0x10`, and `--number -0x10`
   agree.
6. Rename `CommandRegistry.toMap()` to `toRecord()`. It returns a `RegistryRecord`, not a map.
   Update every caller, test, and doc reference. Do not keep an alias.

## Acceptance

- Executing an invocation with a bad propagated flag, an inverted propagated numeric range, an
  accessor leaf named `bad.name`, an inherited/local short-spelling clash, or a `-h` option
  throws at construction with a message naming the offending spelling.
- Registration with a reserved spelling fails at registration, not at invocation.
- A legal descendant override still shadows the propagated declaration.
- Every declared count and capacity of zero is rejected, with a test per declaration kind.
- Each of the three integer spellings produces the same value or the same rejection.
- `dart analyze --fatal-infos` and `dart test` pass.

## Resolution

Shipped in `b405342 fix(registry): validate the effective declaration set`.

- `_validateRepeatedTimes` rejects zero as well as negative counts, and the
  registry rejects a repeated positional whose default is longer than its
  capacity. Counts are checked where they are declared, which is the same place
  a negative count was already refused and means every repeated positional shape
  is covered by one constructor; the registry check catches the default, which
  only the registry can see. `test/registry_test.dart`, group
  `declaration validity`.
- Propagated flags and options go through the same name, short, choice, and
  numeric checks as local ones; accessor node names are checked at every level,
  which is what makes `bad.name` a declaration error instead of an
  unresolvable leaf.
- `CommandRegistry._` validates the effective spellings it will answer for, so
  an inherited and a local input can no longer both claim `x`, while a local
  declaration still deliberately shadows a propagated one by name.
- Reserved spellings are checked in two places on purpose: a declaration and
  what it propagates arrive through `_validate`, while the set that answers for
  a command arrives through `_validateEffectiveSpellings`, and an ancestor can
  publish an input only its descendants ever see. Mamba's own declarations are
  exempt by identity.
- `_integer` accepts only signed decimal in every shape — single, repeatable,
  paired, and accessor — and a dash-led token that starts with a digit is read as
  a value so `--count -0x10` reports the syntax rather than a missing value.
- `CommandRegistry.toMap()` is `toRecord()` everywhere, including
  `tool/regenerate_fixtures.dart` and the reference docs.

## Comments