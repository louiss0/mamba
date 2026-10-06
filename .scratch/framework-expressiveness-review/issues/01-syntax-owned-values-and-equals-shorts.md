# 01 — Syntax-owned values and equals-attached shorts

Status: ready-for-agent
Type: task
Depends on: none

Planning authorization only; implementation requires separate user authorization. Source: [spec sections 1–2](../spec.md), design Q5–Q6, Q27–Q31, Q48, ADR-0005 and ADR-0014.

## Outcome

Make token ownership independent of content validators; accept already-tokenized unconstrained strings and support exactly the approved equals-attached short syntax. Keep dispatch, parser, control scanning, and supported shell routing consistent.

## Work

Inspect `lib/command.dart` string defaults, `lib/parser.dart` value/short handling, `lib/registry.dart` command resolution/token widths, `lib/executor.dart` control/default resolution, and `lib/integrations.dart` token routing. Share the supported ownership interpretation without a wholesale public declaration rewrite.

`-o=file` and `-vo=file` have a flag-only prefix and one final value-taking short. Split once at `=`; do not split value text into short flags or commands. Empty attached content is supplied content. Reject attached values on flags, unknown shorts, and a value-taking short in the prefix. Do not introduce no-equals attachments or separate-value mixed bundles.

## Acceptance

- Unconstrained scalar/repeated/positional/group/accessor/trailing strings accept supplied empty and whitespace-containing argv values; explicit regexes still validate whole content and defaults.
- `--label --help` fails missing supply; `--label=--help` succeeds as literal content. Signed numeric handling remains declaration-aware. Widening regexes cannot swallow named input syntax.
- `-o file`, `-o=file`, `-vo=file`, `-vo=`, and `-o=a=b` obey the contract; `-ofile`, `-vofile`, `-vo file`, `-v=file`, and malformed prefixes fail as specified.
- Values identical to child/default command names do not select those commands. `-o=h`/`-o=--help` do not request controls.
- A control-bearing bundle validates the entire token, including attached values; errors before controls still fail and later ordinary tokens retain bypass. Test root/group defaults, explicit help scope, `h`/`V`, combined controls, and missing preceding values.
- Parent-local inputs stay invalid with selected children regardless of placement; unknown dash-leading operands do not become positionals.
- Tests cover ownership through direct Parser and fake execution, plus converter routing regressions. Update old whitespace/control-swallowing controls rather than preserving superseded assertions.

## Migration

Document newly accepted strings, explicit validators for nonempty content, inline supply for dash-leading values, the exact new short forms, retained unsupported forms, and order-sensitive control behavior. Keep `--` semantics unchanged.
