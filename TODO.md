# TODO

Using the notes in the `Carapace Spec Notes!.md` file. 
I want you to write tests for carpace integration in the `./lib/integrations_test.dart`.
Don't run them! For each section written here make a group nest them.  
You are testing the `CarapaceSpecConverter` function.
You must transform the `convert` function into one that makes a correct spec for the tests to pass! 
If you do end up making helper 

When writing expectations for Carapace Specs remember that it's YAML.
Always provide the `name` for each expectation! 

## Commands 

For commands they must be rendered under `commands:`.
Under the `name:`.

- rendered with flags
- rendered with aliases
- rendered with options
- rendered with description

## Flags

The following tests are based on the `flags:` field.

### Count vs. Bool flags

A bool flag is just a flag
A count flag is repeatable

Write the following tests based on this:

- count flag rendered
- count flag rendered with short 
- bool flag rendered with words
- bool flag rendered with short
- hidden count flagg rendered
- hidden count flag rendered 
- required bool flag rendered
- required bool flag rendered

### Options

A option must have the `=` at the end of the long flag

Write the following tests based on this:
- option rendered 
- option rendered with short
- repeatable flag rendered 
- repeatable option rendered
- hidden flag rendered
- hidden option rendered 
- required flag rendered
- required option rendered

### Paired Options

- When a paired option is used as a variant `exclusiveflags` is rendered.
- When paired options are all flags are just rendered
- When the paired option is written as required all are written as required

### Modifier Combos

Write a series of parameterized tests that test the order of flag and option modifiers under this order.
`<key><repeatability><optionality><appearance><arity>`
For this series of tests you need to make sure that the long flag is used for these!  

## Positionals

These are based on the `positional:` and `positionalany`fields.

- positionals are rendered when choice positionals are used.
- positionals are rendered based on the repeated choice positionals

## Variadic

These are based on the `dash:` and `dashany` fields.

- variadics are rendered when choice variadics are used.
- variadics are rendered based on the repeated choice variadics

## Inherited flags and options 

When the global options and flags are used they must go to to each child command! 
When inherited options and flags are used they must go to each children's subcommand.

What you need to do is rewrite the tests under the #Flags section based on inherited options.
