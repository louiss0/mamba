# CLI fixtures

Each child directory is a standalone, unbundled mock CLI fixture:

```text
fixtures/
└── <cli-name>/
    ├── <cli-name>.dart
    └── completions/
        ├── <cli-name>.yaml
        ├── <cli-name>.bash
        ├── <cli-name>.fish
        ├── _<cli-name>
        └── <cli-name>.ps1
```

Fixtures only declare deterministic command surfaces. They must never affect
the workstation. Generated completion files belong in each fixture's
`completions` directory.

`test/integrations_test.dart` constructs the fixture's `RegistryRecord`, runs
each completion converter, and compares the result with the checked-in Bash,
Zsh, Fish, PowerShell, and Carapace artifacts. After changing `rig`, regenerate
those files and verify them:

```sh
dart run tool/regenerate_fixtures.dart
dart test test/integrations_test.dart --name "checked-in rig completions"
```

Those artifacts are marked not-text in `.gitattributes`, because the test
compares them byte for byte and `core.autocrlf=true` would otherwise rewrite
them to CRLF on Windows.
