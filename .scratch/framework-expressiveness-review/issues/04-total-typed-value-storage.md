# 04 — Total typed-value storage and stable retained reads

Status: ready-for-agent
Type: task
Depends on: 02, 03

Planning authorization only. Source: [spec sections 3–4](../spec.md), review defect 1, `nested_accessor_reproduction.dart`, design Q12/Q25 and the nested-container probe.

## Outcome

Every successful ordinary parse satisfies the non-null types promised by known retained handles, including compatible ancestor handles.

## Work

Inspect `lib/parser.dart` positional storage, defaults, accessor map construction, known-handle enumeration, and `lib/command.dart` ParsedInputs. Use issue 03's compatible lineage for effective reads. Do not mask omitted storage by weakening types, making known handles unknown, or converting an internal StateError to a normal successful result.

## Acceptance

- Omitting accepted `RepeatedChoicePositional.withDefault(... defaultValue: [])` stores and returns the immutable non-null empty list. `contains` remains true because the value is stored.
- Omitting optional accessor leaves still stores all known non-null root and nested container maps; reading the nested `auth` handle in the focused probe does not throw. Optional leaf absence remains nullable; required leaf omission remains a parse failure.
- Nested containers with empty/populated/defaulted descendants preserve each independently retained handle, recursively, without deleting leaf storage.
- Compatible ancestor and descendant standalone handles read the effective local value, using local defaults/validation, in command and persistent-hook execution.
- Compatible ancestor accessor root, nested container, and leaf handles all read effective local data, including added fields where applicable. No deep merging of undeclared ancestor paths.
- Preserve collection immutability, static output types, known/unknown handle checks, and current nullable absence semantics.
- `ParsedInputs.contains` remains stored-value presence. No public provenance query or paired-member handle redesign.
- Help/control parses do not execute commands and need not fabricate required operands skipped by the selected control contract.

## Tests and migration

Promote the empty-default and nested-container probes into normal tests and include deeper trees and overridden default values. Add static/type-output checks where existing test patterns support them. Explain stable ancestor reads and explicitly declared accessor compatibility; keep Errors as invariant failures rather than claiming the executor catches all Errors.
