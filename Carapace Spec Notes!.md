# Carapace Spec Notes!

A carapace spec is a YAML file the first thing that must be placed in it is the name of the CLI! Then you provide the list of commands! 

```yaml
name: command
```

```yaml
name: command
commands:
 - name: subcommand
```

This is how usage must be written! It must be done as one line next to the name of a command:

`[ ]` is a list of optional flags and options. 
`...` belongs after delimiters it means the options can be repeated
`|` indicates options that are for mutually exclusive
`{ }` is a set of mutually exclusive arguments when only one is required

Aliases are an array literal of aliases with the command. 

```yaml
commands:
 - name: sub
   aliases: [s, b]
```

Description use the description field 

```yaml
commands:
 - name: sub 
   description: "I'm a sub"
```

In Carapace a command group is an association of one or more commands with a specific group! Used for sorting! **Mamba doesn't support this**

In Carapace a command can be declared hidden from completion! 
Mamba supports hidden flags and options! 

```yaml
commands:
 - name: sub
   hidden: true
```


Flags in Carapace are written using the flags prop! 
This prop takes in the name of flags and Their descriptions! 

The way the names are written to indicate hints! 

`--ok` flag prefixed with two dashes: indicates long hand bool  
`-b` flag with no name: indicates a short bool flag
`-v=` flag suffixed with equal sign prefixed with a dash: short option
`--repeat*` flag prefixed with two dashes suffixed with asterisk: indicate a longhand repeated flag 
`--opt?` flag with prefixed with two dashes, suffixed with question mark: indicates an optional argument 
`--hidden&` flag prefixed with two dashes suffixed with ampersand 
`--required!` flag prefixed with two dashes suffixed with exclamation 

These options can be mixed! I'd like to take a ordered approach! 
`<key><repeatability><optionality><appearance><arity>`

`<key>` is the name of the flag
`<repeatability>` is whether the `*` can appear. 
`<optionality>` is whether the `!` or `?` appears 
`<arity>` is whether the `=` can appear 

In Mamba there's always the short and long flag! The short one should be before the long one! The long flag should always appear! It's the key that should have all the modifier mentioned above with the exact structure. 
It should look like this! 

```yaml
commands:
 - name: sub
   flags: 
	-m, --message: The commit message  
```

Carapace supports limits on repeatable arguments by passing in an object with a `nargs` argument. 


```yaml
commands:
 - name: sub
   flags:
    --nargs-two=: { description: consumes two, nargs: 2 }
```

Carapace supports default values using a similar syntax! 

```yaml
commands:
 - name: sub
   flags:
    --default-value=: { description: default, default: '/' }
```

Carapace supports global flags and options through the `persistentflags`
field! 

```yaml
name: command 
commands: 
 - name: persistentflags 
   persistentflags:
    -p, --persistent: persistent flag
```

Carapace supports mutually exclusive flags through the `exclusiveflags` field.
It's a prop that accepts a list of arrays of exclusive flags

```yaml
name: command
commands:
 - name: sub
   flags: 
    --add: add a pacakage
    --delete: delete a pacakge 
   exclusiveflags:
   - [add, delete]
```

That area should be filled with paired options

Positional arguments are supported through `completion.positional` prop! 
It's an array of values that can be selected per positional 

```yaml
name: command
commands:
  - name: positional
	completion:
	  positional:
		- [pos1, positional1]
		- [pos2, positional2]

```

Carapace supports many positionals that all take the same amount of values with `completion.positionalany`. Mamba doesn't support this! 
Each list value takes an array of limited values

```yaml
name: command
commands:
  - name: completion
    commands:
      - name: positionalany
        completion:
          positionalany: [posany, positionalany]

```

Carapace supports unparsed variadic arguments that must take a set of values by using `completion.dash`

```yaml
name: command
commands:
  - name: completion
    commands:
      - name: dash
        completion:
          dash:
            - [d1, dash1]
            - [d2, dash2]

```

A series of any amount of unparsed variadic values with strict choices are supported!

```yaml
name: command
commands:
  - name: completion
    commands:
      - name: dashany
        completion:
          dashany: [dany, dashany]

```
