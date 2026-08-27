---
name: mamba-release
description: Prepare and publish stable Mamba releases through the repository's tag-triggered pub.dev workflow.
---

# Mamba Release

Mamba publishes through `.github/workflows/publish.yml` when `main` receives a
pushed tag matching `vMAJOR.MINOR.PATCH`.

For a release, require a stable semantic version with no `v` prefix. Ensure
`pubspec.yaml` has that exact version and `CHANGELOG.md` includes a
`## <version>` section.

Run the repository preflight before any release mutation:

```sh
dart run tool/release.dart --version <version>
```

The script requires a clean `main` worktree, checks the version and changelog,
formats the project, runs analysis and tests, and runs `dart pub publish
--dry-run`.

Report the preflight result and obtain explicit confirmation before pushing a
release tag. After confirmation, run:

```sh
dart run tool/release.dart --version <version> --push
```

This creates and pushes the annotated `v<version>` tag to `origin`, triggering
the pub.dev publishing workflow. Do not invoke `dart pub publish` directly,
force-push a tag, or move an existing release tag.
