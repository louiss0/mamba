---
title: Create a custom help formatter
description: Replace Mamba's default help output with a formatter designed for your CLI.
---

This guide shows you how to replace Mamba's default help output with your own layout and visual style. It assumes that you already have an `Executor` and at least one command.

## Understand the help DSL

Before choosing colors or arranging sections, decide how your formatter will communicate Mamba's command grammar.

Mamba writes a required value as `< VALUE >` and an optional value as `[ VALUE ]`. A short and long name share the form `-v|--verbose`. A finite choice is written as `(json|yaml)`, while alternatives use `--json|--yaml`. Values that must be supplied together are joined as `--user USER & --password PASSWORD`.

A repeatable option uses `(--tag TAG)+`. A repeated positional includes its accepted count, such as `FILE{1,3}`. A regular trailing value is shown as `-- ...`, a trailing choice as `-- (json|yaml)`, and a repeatable trailing choice as `-- (json|yaml)...`. When an option accepts an unrestricted value, its name becomes an uppercase placeholder, so `--output-path` is presented as `--output-path OUTPUT_PATH`.

The `HelpFormatter` methods preserve these meanings with typed fragments. `formatIntoRequiredString()` creates `< ... >`, `formatIntoOptionalString()` creates `[ ... ]`, `formatIntoOrString()` joins alternatives with `|`, and `formatIntoPairString()` joins dependent values with `&`. The returned fragments expose their rendered text through `.string`.

Keep these forms consistent even when you change the surrounding layout. Users should be able to tell what is required, optional, repeatable, or related without relying on color alone.

## Create the formatter

Extend `HelpFormatter`, not `MambaHelpFormatter`. The default formatter is final, while `HelpFormatter` is the customization boundary.

Create a formatter next to your application's executor. The following formatter produces a compact usage line followed by descriptions, flags, options, and child commands:

```dart
import 'package:mamba/mamba.dart';

final class CompactHelpFormatter extends HelpFormatter {
  @override
  String format(CommandRegistry registry) {
    final buffer = StringBuffer()
      ..writeln(_usageFor(registry))
      ..writeln("  ${registry.shortDescription}");

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      formatLongDescription(buffer, longDescription);
    }

    _writeSection(buffer, 'Flags', [
      _flagEntry(registry.helpFlag),
      ...?registry.boolFlags?.values
          .where((flag) => flag.name != registry.helpFlag.name && !flag.hidden)
          .map(_flagEntry),
      ...?registry.countFlags?.values
          .where((flag) => !flag.hidden)
          .map(_flagEntry),
    ]);

    _writeSection(buffer, 'Options', [
      ...?registry.singleOptions?.values
          .where((option) => !option.hidden)
          .map(_optionEntry),
      ...?registry.repeatedOptions?.values
          .where((option) => !option.hidden)
          .map(_optionEntry),
    ]);

    _writeSection(
      buffer,
      'Commands',
      registry.commandRegistries
              ?.map(
                (command) =>
                    '${command.name} '
                    '${formatIntoEntryDescription(command.shortDescription).string}',
              ) ??
          const [],
    );

    return buffer.toString();
  }

  @override
  void formatLongDescription(
    StringBuffer buffer,
    String longDescription,
  ) {
    buffer
      ..writeln()
      ..writeln(longDescription);
  }

  String _usageFor(CommandRegistry registry) {
    final positionals = [
      ...?registry.mandatoryPositionals?.values.map(
        (positional) =>
            formatIntoRequiredString(_positionalSyntax(positional)).string,
      ),
      ...?registry.discretionaryPositionals?.values.map(
        (positional) =>
            formatIntoOptionalString(_positionalSyntax(positional)).string,
      ),
      if (registry.variadic case final variadic?)
        FormattedString(chalk.gray(_variadicSyntax(variadic))).string,
    ];
    return [
      'Usage:',
      registry.fullPath.join(' '),
      ...positionals,
    ].join(' ');
  }

  String _positionalSyntax(Positional positional) {
    final name = switch (positional) {
      RepeatedChoicePositional(:final choices) =>
        '(${choices.map((choice) => choice.name).join('|')})',
      ChoicePositional(:final choices) =>
        choices.map((choice) => choice.name).join('|'),
      _ => positional.name,
    };
    return positional is RepeatedPositional
        ? '$name{1,${positional.times + 1}}'
        : name;
  }

  String _variadicSyntax(Variadic variadic) => switch (variadic) {
    RepeatedChoiceVariadic(:final choices) =>
      '-- (${choices.map((choice) => choice.name).join('|')})...',
    ChoiceVariadic(:final choices) =>
      '-- (${choices.map((choice) => choice.name).join('|')})',
    NormalVariadic() => '-- ...',
  };

  String _flagEntry(Flag flag) =>
      '${formatIntoOptionalString(_namedInput(flag.name, flag.short)).string} '
      '${formatIntoEntryDescription(flag.description ?? '').string}';

  String _optionEntry(Option option) {
    final namedInput = _namedInput(option.name, option.short);
    final value = switch (option) {
      ChoiceOption(:final choices) ||
      RepeatableChoiceOption(:final choices) =>
        '(${choices.map((choice) => choice.name).join('|')})',
      _ => _valuePlaceholder(option.name),
    };
    final input = '$namedInput $value';
    final expression = option is RepeatableOption ? '($input)+' : input;
    final syntax = option.required
        ? formatIntoRequiredString(expression)
        : formatIntoOptionalString(expression);

    return '${syntax.string} '
        '${formatIntoEntryDescription(option.description ?? '').string}';
  }

  String _namedInput(String name, String? short) =>
      short == null ? '--$name' : '-$short|--$name';

  String _valuePlaceholder(String name) => name
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .replaceAll(RegExp(r'[-.]'), '_')
      .toUpperCase();

  void _writeSection(
    StringBuffer buffer,
    String title,
    Iterable<String> entries,
  ) {
    final values = entries.toList();
    if (values.isEmpty) return;

    buffer
      ..writeln()
      ..writeln(formatIntoSectionTitle(title).string);
    for (final value in values) {
      buffer.writeln('  $value');
    }
  }
}
```

This example intentionally focuses on the declarations most applications use. If your command surface includes accessor trees or paired options, add sections for them before adopting the formatter. A custom formatter owns the complete help output; Mamba does not append declarations that your `format()` method leaves out.

## Apply your visual style

The inherited fragment methods already produce ANSI-styled output. Override them when you want to change the emphasis while retaining the DSL delimiters:

```dart
@override
RequiredString formatIntoRequiredString(String syntax) =>
    RequiredString(chalk.cyan(syntax));

@override
OptionalString formatIntoOptionalString(String syntax) =>
    OptionalString(chalk.gray(syntax));
```

Pass styled text to these fragment types. `FormattedString` and its specialized forms validate that the value contains ANSI styling, while `RequiredString` and `OptionalString` add their own `< ... >` and `[ ... ]` delimiters.

You can also override `formatIntoSectionTitle()`, `formatIntoEntryDescription()`, `formatIntoOrString()`, or `formatIntoPairString()` when your layout uses those fragment types. Keep semantic information visible in punctuation and wording instead of communicating it only through a particular color.

## Install the formatter

Pass one formatter instance to the `Executor` that composes your application:

```dart
final executor = Executor(
  'mamba-example',
  'An example command-line application.',
  '1.0.0',
  [
    DeployCommand(),
    ConfigureCommand(),
  ],
  helpFormatter: CompactHelpFormatter(),
);
```

The production executor uses it for root help, nested command help, and help returned when no command is selected. The formatter receives the registry for the selected command path with inherited declarations already resolved.

## Check the result

Run help at both the root and a nested command:

```shell
$ dart run bin/mamba_example.dart --help
$ dart run bin/mamba_example.dart deploy --help
```

Before shipping the formatter, check that:

- required and optional values remain distinguishable without color;
- the displayed path matches the selected command;
- hidden declarations remain hidden;
- inherited declarations appear on nested commands;
- every declaration family used by your application has a section;
- descriptions remain readable when ANSI color is unavailable;
- commands with no options or children do not produce empty headings.

If the output satisfies those checks, the formatter can replace `MambaHelpFormatter` without changing command registration, parsing, or execution.