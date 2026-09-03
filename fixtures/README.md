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
fixture's `completions` directory and should be refreshed by that fixture's
generation tool when its command surface changes. For `rig`, run:

```text
dart run tool/generate_rig_completions.dart
```
