# Completed

- Migrated registry-definition expectations to `MambaRegistryError` for eager
  command, input, paired-option, and alias invariant failures while retaining
  `MambaException` expectations for recoverable runtime failures.
- Updated Carapace YAML expectations to include built-in help at the root and
  generated command levels, along with the shipped completion metadata.
- Ran `dart format` and `dart test`; the full test suite passes.
