# Completion fixture review

Reviewed on 2026-09-03 against the `rig` fixture and the generated artifacts in
`fixtures/rig/completions`.

## Conclusion

The completion model is recursive and has no fixed command-depth limit. The
automated suite now executes Bash and PowerShell completion through five command
levels, while the `rig` fixture exercises this three-level route:

```text
rig network wifi connect
```

The Bash, PowerShell, and Carapace blockers found in the original review have
been fixed. Fish and Zsh were not redesigned; their only generated change is
the removal of the built-in `-n` shorthand for `--dry-run`.

| Completion | Nested command verdict |
| --- | --- |
| `rig.bash` | Passes live routing and inherited-input tests through depth 5 |
| `rig.fish` | Recursively emitted; unchanged except for `--dry-run` |
| `_rig` (Zsh) | Recursively emitted; unchanged except for `--dry-run` |
| `rig.ps1` | Passes live routing and inherited-input tests through depth 5 |
| `rig.yaml` (Carapace) | Loads, traverses the deep route, and passes codegen |

The practical limit is generated file size and shell startup cost rather than a
hard-coded depth. Depth 5 is the tested guarantee.

## `rig.bash`

**Verdict: passes the reviewed nested-command cases.**

The registered completion function now scans the completed portion of
`COMP_WORDS`, resolves aliases to canonical handlers, skips values belonging
to options, and dispatches to the deepest completed command path. Exact command
candidates remain candidates until the shell accepts them.

Each path receives its effective input set: root globals, ancestor-persistent
inputs, and local inputs. Positional completion uses a path-relative positional
index rather than raw `COMP_CWORD`.

Live Git Bash probes verified:

```text
rig network <TAB>                    -> wifi, dns, proxy, ping
rig network wifi <TAB>               -> connect, disconnect, scan, status
rig network wifi connect --s<TAB>    -> --ssid
rig network wifi connect --format <TAB> -> text, json, yaml
rig --format json network wifi <TAB> -> connect, disconnect, scan, status
rig net wifi <TAB>                   -> connect, disconnect, scan, status
rig volume <TAB>                     -> output, input
```

Automated runtime tests also cover five nested command levels, nested aliases,
option values that look like command names, inherited choice values, and nested
positional choices.

## `rig.fish`

**Verdict: structurally supports recursive nesting.**

The Fish path-state loop already accepts one path specification per level and
advances until the requested path is selected. No Fish routing logic was
changed in this fix.

Regeneration removed `-n` from the root `--dry-run` declaration. The local
`rig process -n/--name` spelling is now unambiguous.

## `_rig` (Zsh)

**Verdict: structurally supports recursive nesting.**

The Zsh functions continue to shift the local `words` array once per command
level and dispatch through `_rig`, `_rig_network`,
`_rig_network_wifi`, and `_rig_network_wifi_connect`. No Zsh routing logic
was changed.

Regeneration removed the inherited root `-n` spelling, leaving
`rig process -n/--name` as the only use of that shorthand.

## `rig.ps1`

**Verdict: passes deep routing and inherited-input completion.**

Every emitted path table now contains its effective flags, options, and root
accessors. Root and group-persistent inputs propagate to descendants, while
local definitions retain precedence. Value-handler tables are emitted at the
same descendant paths, so inherited choice values complete after deep commands.

Live Windows PowerShell 5.1 probes verified:

```text
rig network <TAB>                    -> globals plus wifi, dns, proxy, ping
rig network wifi <TAB>               -> globals plus connect, disconnect, scan, status
rig net wifi connect --s<TAB>        -> --ssid
rig network wifi connect --format <TAB> -> text, json, yaml
rig network --d<TAB>                 -> --dry-run
rig process --n<TAB>                 -> --name
```

The generated script parses in Windows PowerShell 5.1, and automated runtime
tests cover inherited values and root flags at five nested command levels.

## `rig.yaml` (Carapace)

**Verdict: loads successfully and preserves nested commands.**

The root `--dry-run` flag no longer claims `-n`, so it no longer collides
with `rig process -n/--name`. Carapace 1.6.4 successfully loads the spec,
renders help for `rig network wifi connect`, and generates code for the full
command tree.

The converter remains recursive. Existing tests verify persistent inputs at
depths 2, 3, 4, and 5.

## Verification performed

- `dart run tool/generate_rig_completions.dart` regenerated all five artifacts.
- The complete `dart test` suite passed all 608 tests.
- Bash runtime tests execute generated scripts when Bash is available.
- PowerShell runtime tests execute generated scripts when PowerShell is
  available.
- `bash -n fixtures/rig/completions/rig.bash` passed.
- Windows PowerShell 5.1 parsed `rig.ps1`.
- `carapace --codegen fixtures/rig/completions/rig.yaml` passed.
- Carapace rendered deep-command help without a shorthand collision.
- `dart analyze` reported no errors or warnings.

## Remaining source hygiene note

`dart analyze` still reports 28 informational lints in
`fixtures/rig/rig.dart`, including unbraced conditional bodies, avoidable
null checks, and unnecessary underscore parameter names. These pre-existing
fixture style findings do not affect completion behavior.
