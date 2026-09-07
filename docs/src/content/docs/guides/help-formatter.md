---
title: Create a custom help formatter
description: Extend or implement Mamba's help formatter abstraction for your CLI.
---

This guide shows you how to replace Mamba's default help output by extending or implementing its formatter abstraction.

## Understand the help DSL

Before choosing colors or arranging sections, decide how your formatter will communicate Mamba's command grammar.

Mamba writes a required value as `< VALUE >` and an optional value as `[ VALUE ]`. A short and long name share the form `-v|--verbose`. A finite choice is written as `(json|yaml)`, while alternatives use `--json|--yaml`. Values that must be supplied together are joined as `--user USER & --password PASSWORD`.

A repeatable option uses `(--tag TAG)+`. A repeated positional includes its accepted count, such as `FILE{1,3}`. A regular trailing value is shown as `-- ...`, a trailing choice as `-- (json|yaml)`, and a repeatable trailing choice as `-- (json|yaml)...`. When an option accepts an unrestricted value, its name becomes an uppercase placeholder, so `--output-path` is presented as `--output-path OUTPUT_PATH`.

The formatter interface preserves these meanings with typed fragments. `formatIntoRequiredString()` creates `< ... >`, `formatIntoOptionalString()` creates `[ ... ]`, `formatIntoOrString()` joins alternatives with `|`, and `formatIntoPairString()` joins dependent values with `&`. The returned fragments expose their rendered text through `.string`.

Keep these forms consistent even when you change the surrounding layout. Users should be able to tell what is required, optional, repeatable, or related without relying on color alone.

## Choose between extending and implementing

`HelpFormatter` is an abstract class and the formatter type accepted by `Executor`. It supports two customization approaches:

- Extend `HelpFormatter` to inherit Mamba's concrete DSL fragment methods and provide only the layout operations your class still requires.
- Implement `HelpFormatter` to replace every member of the contract, including the styling of each DSL fragment.

`MambaHelpFormatter` is the final default implementation. Use it directly when you want Mamba's built-in help; application formatters extend or implement `HelpFormatter` instead.

Choose based on how much policy you want to own. Extending is useful when Mamba's DSL styling already communicates the right meaning. Implementing is useful when layout, branding, and semantic colors must all belong to your application.

## Style output with ChalkDart

Mamba uses [ChalkDart](https://pub.dev/packages/chalkdart) for terminal styling and re-exports its `chalk` API. An import of `package:mamba/mamba.dart` is enough to use it in a formatter:

```dart
import 'package:mamba/mamba.dart';

final heading = chalk.bold.blue('Commands');
final warning = chalk.yellow('A value is required.');
final branded = chalk.hex('#7C3AED').bold('Deploy');
final precise = chalk.rgb(125, 211, 252)('SOURCE');
```

Call a named style such as `chalk.cyan()`, chain styles such as `chalk.bold.yellow()`, or create a palette with `chalk.hex()` and `chalk.rgb()`. ChalkDart composes the ANSI Select Graphic Rendition sequences expected by Mamba's formatted fragment types.

Distinguish a theme color from a semantic color. A theme color identifies your product and works well for headings or borders. A semantic color identifies a role, such as required values, optional values, alternatives, or paired values, and must retain that meaning throughout the output.

Use both kinds of color as reinforcement rather than as the only source of meaning. The DSL punctuation still needs to explain the command when output is copied into a log, read without color, or interpreted by someone who cannot distinguish parts of your palette.

## Design the formatter around user needs

Use `HelpFormatter` when the user needs a different route through the information. Before writing code, decide what question the help output should answer first. A command-discovery tool might lead with child commands; an automation tool might lead with exact usage; a safety-critical command might place required values and consequences before optional controls.

Treat help as a user interface, not as a dump of the registry. Establish an information hierarchy, keep related declarations together, and make the most likely next action easy to find. At the same time, keep the registry as the source of truth: honor hidden declarations, render inherited inputs, and avoid hand-written command names that can drift away from registration.

Keep `format()` deterministic and side-effect free. Its job is to transform the selected `CommandRegistry` into a string. It should not parse arguments, execute commands, or write directly to the terminal.

## Extend `HelpFormatter`

Extend `HelpFormatter` when you want to reuse its DSL fragment methods. Your subclass must implement `format()` and `formatLongDescription()`, while methods such as `formatIntoRequiredString()` and `formatIntoSectionTitle()` remain available to compose the output.

This command-first formatter is suitable for a CLI whose root help primarily directs users toward a subcommand:

```dart
import 'package:mamba/mamba.dart';

final class CommandFirstHelpFormatter extends HelpFormatter {
  @override
  String format(CommandRegistry registry) {
    final buffer = StringBuffer()
      ..writeln(chalk.bold(registry.fullPath.join(' ')))
      ..writeln(registry.shortDescription);

    final longDescription = registry.longDescription;
    if (longDescription != null) {
      formatLongDescription(buffer, longDescription);
    }

    final commands = registry.commandRegistries ?? const [];
    if (commands.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(formatIntoSectionTitle('Commands').string);
      for (final command in commands) {
        buffer.writeln(
          '  ${command.name} '
          '${formatIntoEntryDescription(command.shortDescription).string}',
        );
      }
    }

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
}
```

Inherited methods can still be overridden individually. For example, override only `formatIntoSectionTitle()` to apply a brand theme while preserving the default semantic treatment of required, optional, paired, and alternative values.

This focused example does not render inputs. Add every declaration family used by your application, or use the more complete layout below as a starting point.

## Implement `HelpFormatter`

Implement `HelpFormatter` when you do not want to inherit any formatter behavior. An implementation must provide `format()`, `formatLongDescription()`, and every DSL fragment method.

The following formatter produces a compact usage line followed by descriptions, flags, options, and child commands. It uses a brand color for navigation and consistent semantic colors for the DSL:

```dart
import 'package:mamba/mamba.dart';

final class CompactHelpFormatter implements HelpFormatter {
  @override
  RequiredString formatIntoRequiredString(String syntax) =>
      RequiredString(chalk.yellow.bold(syntax));

  @override
  OptionalString formatIntoOptionalString(String syntax) =>
      OptionalString(chalk.gray(syntax));

  @override
  SectionTitleString formatIntoSectionTitle(String title) =>
      SectionTitleString(chalk.hex('#7C3AED').bold(title));

  @override
  EntryDescriptionString formatIntoEntryDescription(String description) =>
      EntryDescriptionString(chalk.white(description));

  @override
  OrString formatIntoOrString(
    String primaryMember,
    Iterable<String> alternativeMembers,
  ) => OrString(
    chalk.magenta(primaryMember),
    alternativeMembers.map((member) => chalk.magenta(member)),
  );

  @override
  PairString formatIntoPairString(
    String primaryMember,
    Iterable<String> pairMembers,
  ) => PairString(
    chalk.cyan(primaryMember),
    pairMembers.map((member) => chalk.cyan(member)),
  );

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

This example intentionally focuses on the declarations most applications use. If your command surface includes accessor trees or paired options, add sections for them before adopting the formatter. A custom formatter owns the complete help output; Mamba does not append declarations that `format()` leaves out.

## Install the formatter

Pass either formatter to the executor. This example installs the complete interface implementation:

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

The production executor uses the instance for root help, nested command help, and help returned when no command is selected. It supplies the registry for the selected command path with inherited declarations already resolved.

## Check the result

Run help at both the root and a nested command:

```shell
$ dart run bin/mamba_example.dart --help
$ dart run bin/mamba_example.dart deploy --help
```

Before shipping the formatter, check that:

- required and optional values remain distinguishable without color;
- theme colors are limited to branding and navigation;
- semantic colors keep the same meaning throughout the output;
- the displayed path matches the selected command;
- hidden declarations remain hidden;
- inherited declarations appear on nested commands;
- every declaration family used by your application has a section;
- descriptions remain readable when ANSI color is unavailable;
- commands with no options or children do not produce empty headings.

If the output satisfies those checks, your formatter can change Mamba's presentation without changing command registration, parsing, or execution.