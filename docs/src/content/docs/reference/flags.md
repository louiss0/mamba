---
title: flags
description: Make flags in Mamba
---


In Mamba a flag is an entity that represents either a boolean or an integer that's based on how many times it's seen.
They can have a long or a short option! But they can't have arguments passed to them!
They can also be negatable! They can't be repeatable at all!

## Bool Flags 

A bool flag is just a boolean flag it's written like this! 

```dart
BooleanFlag("active");
```

To give it a short option you write this. 

```dart
BooleanFlag("active", short: "a");
```

:::warning[Short flag names must be one letter]

To make it negatable to write it like this. 

```dart
BooleanFlag("active", negatable: true);
```

:::note[The negaable flag will allow the user to use `no-` to indicate the opposite value]

To write a description for the flag you write this. 

```dart
BooleanFlag("active", description: "Active flag ");
```

To make it hidden by help you write this. 

```dart
BooleanFlag("active", hidden: true);
```

To give it a default value you write this. 

```dart
BooleanFlag("active", defaultValue: false);
```

## Count Flags

A count flag is a flag that represents an integer! It's a flag that has it's default value as zero.
It's value is 0 by default when it's not used but registered!

To type it out you write this. 

```dart
CountFlag("count");
```

To give it a short option you write this. 

```dart
CountFlag("count", short: "c");
```

To give it a description you write this. 

```dart
CountFlag("count", description: "Count flag");
```
