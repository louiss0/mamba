---
title: Create a custom help formatter
description: Replace or extend Mamba's help formatter for your CLI.
---

Mamba renders help from the selected `CommandRegistry` using a `HelpFormatter`.
An application installs a formatter through `Executor`'s `helpFormatter`
parameter; the executor calls `format()` for root help, nested command help,
and the help output returned when no command is selected.

```dart
abstract interface class HelpFormatter {
  String format(CommandRegistry registry);
}
```

`HelpFormatter` receives the selected registry, whose inputs already include
any inherited declarations. It returns the complete help text. The default
implementation is `MambaHelpFormatter`, which is the formatter used when no
custom formatter is supplied.

## Install a custom formatter

Pass an instance to the executor:

```dart
final executor = Executor(
  'mamba-example',
  'An example command-line application.',
  '1.0.0',
  [DeployCommand(), ConfigureCommand()],
  helpFormatter: CompactHelpFormatter(),
);
```

## Implement `HelpFormatter`

An implementation provides `format()` only. The method receives the selected
`CommandRegistry` and returns the full help string. The executor writes the
result to stdout when the user requests help or when no subcommand is selected.

A custom formatter owns the complete help output; Mamba does not append
declarations that `format()` leaves out. Keep the following in mind when
writing a formatter:

- Required values are distinguished from optional values, repeatable values
  from single values, and paired alternatives from exclusive alternatives.
- Theme colors identify your product and work well for headings or borders.
- Semantic colors identify a role — required, optional, alternative, or paired
  — and must retain that meaning throughout the output.
- Hidden declarations remain part of parsing but must be omitted from help.
- Inherited declarations must appear on nested commands.
- Every declaration family used by your application must be represented.
- The displayed path must match the selected command.
- The output must remain readable when ANSI color is unavailable.
- Commands with no options or children must not produce empty headings.

```dart
import 'package:mamba/mamba.dart';

final class CompactHelpFormatter implements HelpFormatter {
  @override
  String format(CommandRegistry registry) {
    final buffer = StringBuffer()
      ..writeln(registry.fullPath.join(' '))
      ..writeln('  ${registry.shortDescription}');

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      buffer.writeln();
      buffer.writeln(longDescription);
    }

    _writeFlags(buffer, registry);
    _writeOptions(buffer, registry);
    _writePositionals(buffer, registry);
    _writeCommands(buffer, registry);

    return buffer.toString();
  }

  void _writeFlags(StringBuffer buffer, CommandRegistry registry) {
    final flags = registry.applicableFlags.where((flag) => !flag.hidden);
    if (flags.isEmpty) return;
    buffer
      ..writeln()
      ..writeln('Flags:');
    for (final flag in flags) {
      buffer.writeln('  ${_spell(flag)}\t${flag.description ?? ''}');
    }
  }

  void _writeOptions(StringBuffer buffer, CommandRegistry registry) {
    final options = registry.applicableOptions.where(
      (option) => !option.hidden,
    );
    if (options.isEmpty) return;
    buffer
      ..writeln()
      ..writeln('Options:');
    for (final option in options) {
      buffer.writeln(
        '  ${_spell(option)} ${_optionPlaceholder(option)}\t${option.description ?? ''}',
      );
    }
  }

  String _optionPlaceholder(Option option) {
    if (option is ChoiceValidated) {
      return '(${option.choices.map((c) => c.name).join('|')})';
    }
    if (option is NumericRangeValidated) return 'VALUE';
    return 'VALUE';
  }

  void _writePositionals(StringBuffer buffer, CommandRegistry registry) {
    if (registry.mandatoryPositionals.isEmpty &&
        registry.discretionaryPositionals.isEmpty) {
      return;
    }
    buffer
      ..writeln()
      ..writeln('Arguments:');
    for (final positional in registry.mandatoryPositionals) {
      buffer.writeln('  <${positional.name}>\t${positional.description ?? ''}');
    }
    for (final positional in registry.discretionaryPositionals) {
      buffer.writeln('  [${positional.name}]\t${positional.description ?? ''}');
    }
  }

  void _writeCommands(StringBuffer buffer, CommandRegistry registry) {
    final commands = registry.commandRegistries;
    if (commands.isEmpty) return;
    buffer
      ..writeln()
      ..writeln('Commands:');
    for (final command in commands) {
      buffer.writeln(
        '  ${command.name}\t${command.shortDescription}',
      );
    }
  }

  String _spell(InputDefinition input) => switch (input) {
    Flag(:final short) ||
    Option(:final short) ||
    PairOption(:final short) =>
      short == null ? '--${input.name}' : '-$short, --${input.name}',
    _ => '--${input.name}',
  };
}
```

## Extend `MambaHelpFormatter`

`MambaHelpFormatter` is the final default implementation. You can extend it to
reuse its rendering logic and override individual behavior:

```dart
import 'package:mamba/mamba.dart';

final class BrandedHelpFormatter extends MambaHelpFormatter {
  @override
  String format(CommandRegistry registry) {
    // Delegate to the default implementation, then post-process.
    final defaultOutput = super.format(registry);
    return 'My CLI\n$defaultOutput';
  }
}
```

Check the result at both the root and a nested command:

```sh
$ dart run bin/mamba_example.dart --help
$ dart run bin/mamba_example.dart deploy --help
```
