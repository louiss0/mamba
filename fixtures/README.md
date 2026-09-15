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
Zsh, Fish, PowerShell, and Carapace artifacts. After changing `rig`, refresh
those files from the corresponding converters and verify them with:

```sh
dart test test/integrations_test.dart --name "checked-in rig completions"
```
