---
title: options
description: This is how options are defined in mamba
---


In mamba Options are words that are paired with string, booleans, and floats!
They can be repeated, hidden, and required. 
Some options are allowed to be grouped where they must be supplied together or picked from one another. 
Options can even be written with dots to represent the dot operator in most programming languages!

## Primitive

A primitive option is an option that represents strings, int's or doubles!
They can be required, and hidden. They can even have a short flag.

You write an option like this! 

```dart
StringOption(
  'name',
);
```

To give it a short flag, you can use the `short` parameter.

```dart
StringOption(
  'name',
  short: 'n',
);
```

To give it a description you can use the `description` parameter.

```dart
StringOption(
  'name',
  description: 'The name of the person',
);
```

To make it hidden you can use the `hidden` parameter.

```dart
StringOption(
  'name',
  hidden: true,
);
```

To make it required you can use the `required` parameter.

```dart
StringOption(
  'name',
  required: true,
);
```

:::note[The examples above apply to the other options]

### String Option

A string option is an option that validates whether a series of charaters is valid! 
When registered it's regex is used to validate the input. By default the `\S+` is used.
This means no white space!

To override the default regex of a string you do it like this!

```dart
StringOption(
  'name',
  regex: RegExp(r'\w+'),
);
```

### Int Option 

An int option is an option that can only accept integers as values! 
It can also have a min or a max! Negative int's are accepted! 

To write an int option you do it like this!

```dart
IntOption(
  'age',
);
```

To configure a min option you write it like this!

```dart
IntOption(
  'age',
  min: 0,
);
```

To configure a max option you write it like this!

```dart
IntOption(
  'age',
  max: 120,
);
```

### Double Option 

A double option is an option that can only accept double as values! 
It can also have a min or a max!

To write a double option you do it like this!

```dart
DoubleOption(
  'height',
);
```

To configure a min option you write it like this!

```dart
DoubleOption(
  'height',
  min: 0.0,
);
```

To configure a max option you write it like this!

```dart
DoubleOption(
  'height',
  max: 5.5,
);
```

## Choice Option 

A choice option is an option that uses enum to valadate a series of choices!


```dart

enum Color {
  red,
  blue,
  green,
}

ChoiceOption(
  'color',
  choices: Color.values,
);
```

To add a default value to a choice option you write it like this!

```dart
ChoiceOption(
  'color',
  choices: Color.values,
  defaultValue: Color.red,
);
```

## Repeatable

A repeatable option is just an array of string, int or double.
They accept the same options as their primitive forms.
They just ensure that arrays are produced from them instead of single values.

To write a repeatable string option you do it like this!

```dart
RepeatableStringOption(
  'tags',
);
```

To write a repeatable int option you do it like this!

```dart
RepeatableIntOption(
  'ports',
);
```

To write a repeatable double option you do it like this!

```dart
RepeatableDoubleOption(
  'scores',
);
```

## Paired Options

Paired Options represent options that are connected together.
The user must either choose from them or bring them all!
The  `PairedOptions` class is used to bring together a series of `PairOption`'s together.
A pair option is what decides name and type of each option. 
Paired options decide the relationship between the options.

To write a paired options you do it like this!

```dart
PairedOptions(
  [
    PairStringOption(
      'username',
    ),
    PairIntOption(
      'age',
    ),
    PairDoubleOption('height'),
  ],
);
```

To make paired options required you write this!

```dart
PairedOptions(
  [
    PairStringOption(
      'username',
    ),
    PairStringOption(
      'password',
    ),
  ],
  required: true,
);
```



To give them a description you write it like this!

```dart
PairedOptions(
  [
    PairStringOption(
      'username',
    ),
    PairStringOption(
      'password',
    ),
  ],
  description: 'The are the credentials',
);
```

## Accessor

In mamba we call options that allow you to use multiple dot in between each word _accessor options_ or _accessors_ for short.
These options are a series of options that are written in a way that represents a schema! but using lists.
They can't be required or repeatable! They can't have short options either! 

To write an accessor option you write this! 

```dart
AccessorListOption('core', [
  AccessorStringOption('ssh-comand'),
  AccessorStringOption('editor'),
  AccessorStringOption('pager'),
]);
```
:::note[The name of the top level is the name that must be written before the `.` and the name of what needs to be accessed]

Accessor Options can nest them selves or children! The primitives are `AccessorStringOption`, `AccessorIntOption`, `AccessorDoubleOption` and `AccessorChoiceOption`.

:::warning[These kinds of options can't decide anything about themseleves the can only do what the primitive version of themselves can do.]


```dart
AccessorListOption('user', [
  AccessorStringOption('name'),
]);
```

```dart
AccessorListOption('core', [
  AccessorIntOption(
    'gitProxyPort',
  ),
]);
```

```dart
AccessorListOption('pack', [
  AccessorDoubleOption(
    'compressionLimit',
  ),
]);
```

```dart
AccessorListOption('core', [
  AccessorChoiceOption(
    'autocrlf',
    choices: ['true', 'false', 'input'],
  ),
]);
```
