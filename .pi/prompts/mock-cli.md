---
description: Build a harmless, realistic mock CLI fixture from any supplied specification
argument-hint: "<cli-name> [requirements...]"
---
Create or update a mock CLI fixture from the complete request below.

The fixture layout is mandatory:
- `fixtures/<cli-name>/<cli-name>.dart` is the unbundled executable CLI.
- `fixtures/<cli-name>/completions/` contains generated completion artifacts only.
- Add an activated top-level `completion` command backed by Mamba's
  `CompletionCommand`; it prints the requested artifact to stdout and never
  writes files.
- Add focused tests under `test/`.

Treat every argument after the prompt name as part of the specification. Preserve the requested command hierarchy, aliases, positionals, flags, options, validation rules, help text, output formats, and examples. Use the repository's Mamba APIs and keep the fixture deterministic and terminal-only.

Mock-only safety is absolute: do not use operating-system APIs, shell commands, files, processes, network connections, devices, displays, power actions, or persistent state in the CLI. Successful commands must describe what they would do and explicitly say that no real changes occurred. Never print secrets supplied as arguments.

Write tests before implementation when adding behavior. Run formatting, static analysis, and the focused fixture tests. Generate supported completion artifacts into the fixture's `completions` directory through the activated `completion` command, and report any limitation of the parser or completion integration.

User specification:
$@
