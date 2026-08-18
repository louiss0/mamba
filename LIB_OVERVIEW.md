# Project overview

> This overview is based only on the contents of `lib/`.

This is a Dart framework named **Mamba** for defining and executing hierarchical command-line interfaces.

It provides:

- Commands and nested subcommands
- Positional arguments
- Boolean and counting flags
- Typed string, integer, double, and enum options
- Repeatable and paired options
- Nested “accessor” options such as `--database.host`
- Validation and parsing
- Generated ANSI-styled help output
- Shared execution context
- Pre/post execution hooks
- Standard-input processing

`lib/mamba.dart` is the public library barrel that exports the framework.

## High-level architecture

```mermaid
classDiagram
    class Executor {
        -CommandRegistry registry
        -MambaContext context
        -HelpFormatter helpFormatter
        +execute(args)
    }

    class CommandRegistry {
        +create(...)
        +commandRegistries
        +boolFlags
        +singleOptions
        +accessors
    }

    class Parser {
        -CommandRegistry registry
        +parse(args)
    }

    class HelpFormatter {
        <<abstract>>
        +format(registry)
    }

    class MambaHelpFormatter {
        +format(registry)
    }

    class Command {
        <<abstract>>
        +name
        +shortDescription
        +run(positionals, inputs, trailingArguments)
    }

    class MambaContext
    class MambaReadContext
    class HookRunner {
        <<mixin>>
        +prePersistentRun(...)
        +preRun(...)
        +postRun(...)
        +postPersistentRun(...)
    }

    Executor *-- CommandRegistry : constructs
    Executor *-- MambaContext : owns
    Executor --> Parser : creates
    Executor --> HelpFormatter : uses
    Executor o-- Command : executes
    MambaHelpFormatter --|> HelpFormatter
    Parser --> CommandRegistry : parses against
    CommandRegistry --> Command : built from definitions
    MambaReadContext --> MambaContext : read-only facade
    HookRunner ..> Command : applies to
    Executor --> HookRunner : invokes hooks
```

## Execution flow

`Executor` acts as the central coordinator.

```mermaid
sequenceDiagram
    actor User
    participant Executor
    participant Help as HelpFormatter
    participant Parser
    participant Registry as CommandRegistry
    participant Hooks as HookRunner
    participant Command

    User->>Executor: execute(args)

    alt Help requested or no command
        Executor->>Help: format(registry)
        Help-->>Executor: ANSI help text
        Executor-->>User: stdout
    else Execute command
        Executor->>Parser: parse(args)
        Parser->>Registry: inspect definitions
        Parser-->>Executor: command path and parsed inputs

        opt Command uses HookRunner
            Executor->>Hooks: prePersistentRun()
            Executor->>Hooks: preRun(stdin, context, inputs)
        end

        Executor->>Command: run(positionals, inputs, trailing)
        Command-->>Executor: output
        Executor-->>User: stdout

        opt Command uses HookRunner
            Executor->>Hooks: postRun()
            Executor->>Hooks: postPersistentRun()
        end
    end
```

Errors are caught by `Executor` and written to `stderr`.

## Command model

Applications extend `Command` to define executable behavior. A command can contain child commands, producing a command tree.

`GroupCommand` adds the ability to select and run a descendant command itself, including a default child path.

```mermaid
classDiagram
    class Command {
        <<abstract>>
        +String name
        +String shortDescription
        +List~Command~ commands
        +List~Flag~ flags
        +List~Option~ options
        +run(...)
    }

    class GroupCommand {
        <<abstract>>
        +List~String~ defaultSubCommandPath
        +runChildCommand(path, ...)
        +run(...)
    }

    class HookRunner {
        <<mixin>>
        +prePersistentRun(...)
        +preRun(...)
        +postRun(...)
        +postPersistentRun(...)
    }

    class ProcessedStandardInput {
        +List~int~ bytes
        +String text
        +String utf8Text
        +dynamic json
    }

    GroupCommand --|> Command
    HookRunner ..> Command : mixed onto
    HookRunner --> ProcessedStandardInput : receives
    Command o-- Command : nested subcommands
```

`ProcessedStandardInput` exposes piped standard input as:

- Raw bytes
- Character text
- UTF-8 text
- Decoded JSON

## Input type hierarchy

Most CLI definitions inherit from `NamedInput`, which supplies a name and optional description.

```mermaid
classDiagram
    class NamedInput {
        <<sealed>>
        +String name
        +String description
    }

    class Positional {
        +RegExp regex
    }

    class Flag {
        <<sealed>>
        +String short
    }

    class BooleanFlag {
        +bool defaultValue
        +bool negatable
    }

    class CountFlag

    class Option {
        <<sealed>>
        +String short
        +bool required
    }

    class SingleOption {
        <<sealed>>
    }

    class RepeatableOption {
        <<sealed>>
    }

    class PairedOption {
        <<sealed>>
        +List~PairOption~ options
        +bool variant
    }

    class PairOption {
        <<sealed>>
        +String short
    }

    class AccessorOption {
        <<sealed>>
    }

    NamedInput <|-- Positional
    NamedInput <|-- Flag
    Flag <|-- BooleanFlag
    Flag <|-- CountFlag

    NamedInput <|-- Option
    Option <|-- SingleOption
    Option <|-- RepeatableOption
    Option <|-- PairedOption

    NamedInput <|-- PairOption
    NamedInput <|-- AccessorOption

    PairedOption *-- PairOption : contains
```

### Typed options

```mermaid
classDiagram
    class SingleOption
    class StringOption
    class IntOption
    class DoubleOption
    class ChoiceOption

    class RepeatableOption
    class RepeatableStringOption
    class RepeatableIntOption
    class RepeatableDoubleOption

    SingleOption <|-- StringOption
    SingleOption <|-- IntOption
    SingleOption <|-- DoubleOption
    SingleOption <|-- ChoiceOption

    RepeatableOption <|-- RepeatableStringOption
    RepeatableOption <|-- RepeatableIntOption
    RepeatableOption <|-- RepeatableDoubleOption
```

A `ChoiceOption` is generic over a Dart `Enum`, but parsed choice values are placed into the string-options result map using the enum member’s name.

### Paired options

Paired options model related values:

- `variant == false`: every member must be supplied together.
- `variant == true`: at most one member may be supplied.
- `required == true`: the group itself must be present.

```mermaid
classDiagram
    class PairedOption
    class PairedStringOption
    class PairedIntOption
    class PairedDoubleOption
    class PairedChoiceOption
    class RepeatablePairedOption

    class PairOption
    class PairStringOption
    class PairIntOption
    class PairDoubleOption
    class PairChoiceOption
    class RepeatablePairOption

    PairedOption <|-- PairedStringOption
    PairedOption <|-- PairedIntOption
    PairedOption <|-- PairedDoubleOption
    PairedOption <|-- PairedChoiceOption
    PairedOption <|-- RepeatablePairedOption

    PairOption <|-- PairStringOption
    PairOption <|-- PairIntOption
    PairOption <|-- PairDoubleOption
    PairOption <|-- PairChoiceOption
    PairOption <|-- RepeatablePairOption

    PairedOption *-- PairOption
```

## Accessor options

Accessors represent nested option paths. For example, a nested definition could be addressed as:

```text
--database.connection.timeout 30
```

```mermaid
classDiagram
    class AccessorOption {
        <<sealed>>
        +String name
    }

    class AccessorListOption {
        +List~AccessorOption~ options
    }

    class AccessorPrimitiveOption {
        <<sealed>>
    }

    class AccessorStringOption
    class AccessorIntOption
    class AccessorDoubleOption
    class AccessorChoiceOption

    AccessorOption <|-- AccessorListOption
    AccessorOption <|-- AccessorPrimitiveOption

    AccessorPrimitiveOption <|-- AccessorStringOption
    AccessorPrimitiveOption <|-- AccessorIntOption
    AccessorPrimitiveOption <|-- AccessorDoubleOption
    AccessorPrimitiveOption <|-- AccessorChoiceOption

    AccessorListOption *-- AccessorOption : nested children
```

The parser returns accessor values as nested maps.

## Registry responsibilities

`CommandRegistry` transforms command definitions into indexed, validated lookup structures.

It:

- Validates command and input names
- Rejects duplicate names
- Reserves `--help` and `-h`
- Separates inputs by concrete type
- Builds registries recursively for child commands
- Optionally propagates flags into descendants

The registry is primarily descriptive—it does not execute commands. `Executor` separately retains the actual `Command` instances so it can call `run()`.

## Context model

```mermaid
classDiagram
    class MambaContextKey {
        <<generic>>
    }

    class MambaContext {
        -Map values
        +set(key, value)
        +get(key)
    }

    class MambaReadContext {
        -MambaContext context
        +get(key)
    }

    MambaContext --> MambaContextKey : keyed by
    MambaReadContext --> MambaContext : delegates reads
```

Hooks receive:

- Mutable `MambaContext` during persistent hooks
- `MambaReadContext` during command-specific pre/post hooks

This allows shared typed state while restricting mutation in some execution stages.

## Help formatting

```mermaid
classDiagram
    class HelpFormatter {
        <<abstract>>
        +format(registry)
        +formatLongDescription(buffer, text)
    }

    class MambaHelpFormatter

    class FormattedString {
        <<abstract>>
        +String string
    }

    class RequiredString
    class OptionalString
    class PairString
    class OrString
    class SectionTitleString
    class EntryDescriptionString

    MambaHelpFormatter --|> HelpFormatter
    FormattedString <|-- RequiredString
    FormattedString <|-- OptionalString
    FormattedString <|-- PairString
    FormattedString <|-- OrString
    FormattedString <|-- SectionTitleString
    FormattedString <|-- EntryDescriptionString

    HelpFormatter --> FormattedString : creates
    MambaHelpFormatter --> CommandRegistry : renders
```

The default formatter uses `chalkdart` to render required values, optional values, section headings, descriptions, paired groups, and mutually exclusive variants.

## Error hierarchy

```mermaid
classDiagram
    class Error
    class Exception

    class MambaRegistryError {
        +String message
    }

    class MambaException {
        +String message
    }

    class MambaParseException
    class MambaCommandNotFoundException

    MambaRegistryError --|> Error
    MambaException ..|> Exception
    MambaParseException --|> MambaException
    MambaCommandNotFoundException --|> MambaException
```

## Current entry point

`lib/main.dart` creates:

```dart
Executor("mamba", "This is the Manba CLI").execute(args);
```

No commands are registered there, so the current executable primarily displays root help. The framework itself is substantially more capable than this minimal entry point demonstrates. There is also a likely typo in the description: **“Manba”** instead of **“Mamba.”**
