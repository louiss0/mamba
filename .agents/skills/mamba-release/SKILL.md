---
name: mamba-release
description: Prepare and publish stable or prerelease Mamba releases through the repository's tag-triggered pub.dev workflow.
---

# Mamba Release

Mamba publishes through `.github/workflows/publish.yml` when `main` receives a
pushed `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-PRERELEASE` tag.

For a release, require a stable or prerelease semantic version with no `v`
prefix and no build metadata. Ensure `pubspec.yaml` and the Mamba CLI version
have that exact version and `CHANGELOG.md` includes a `## <version>` section.

Run the repository preflight before any release mutation:

```sh
dart run tool/release.dart --version <version>
```

The script requires a clean `main` worktree, checks the pubspec version, Mamba
CLI version, and changelog, formats the project, runs analysis and tests, and
runs `dart pub publish --dry-run`.

Report the preflight result and obtain explicit confirmation before pushing a
release tag. After confirmation, run:

```sh
dart run tool/release.dart --version <version> --push
```

This creates and pushes the annotated `v<version>` tag to `origin`, triggering
the pub.dev publishing workflow. Do not invoke `dart pub publish` directly,
force-push a tag, or move an existing release tag.
