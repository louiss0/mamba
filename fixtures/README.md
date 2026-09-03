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

Fixtures only parse arguments and print deterministic descriptions. They must
never affect the workstation. Generated completion files belong in the
fixture's `completions` directory and should be refreshed with that fixture's
completion command when its command surface changes. For `rig`, run:

```text
dart run fixtures/rig/rig.dart completion --shell carapace > fixtures/rig/completions/rig.yaml
dart run fixtures/rig/rig.dart completion --shell bash > fixtures/rig/completions/rig.bash
dart run fixtures/rig/rig.dart completion --shell fish > fixtures/rig/completions/rig.fish
dart run fixtures/rig/rig.dart completion --shell zsh > fixtures/rig/completions/_rig
dart run fixtures/rig/rig.dart completion --shell powershell > fixtures/rig/completions/rig.ps1
```
