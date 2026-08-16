# TODO

I want to now remove the schemas from this repo and change the code to just use Lists
as replacements! The registry will no longer accept them instead it will accept the schema lists.


The parser is now supposed to return bool flags and count flags separately.
The bool flags will be a map of bool! The count flags will be a Map of string int.
The options will return single and repeated options separately.

The single options will be a record that returns a record with
- stringOptions
- intOptions
- doubleOptions

The repeated options will return a record with all `Map<String, List<>>`
- stringOptions
- intOptions
- doubleOptions

The list is based on the type the Repeated Option is based on!
The accessor list is suppossed to accept list options at the root!

The tests will need to be adjusted for this after!
Please focus on changing the expectations to `Map` for the related tests.
The `Inputs` type needs to change to just return Maps based on the content!
The type of it is suppossed to now look like this

```dart
typedef Inputs = ({
   Map<String, bool>? boolFlags,
   Map<String, int>? countFlags,
   Map<String, String>? stringOptions,
   Map<String, int>? intOptions,
   Map<String, double>? doubleOptions,
   Map<String, List<String>>? repeatedStringOptions,
   Map<String, List<int>>? repeatedIntOptions,
   Map<String, List<double>>? repeatedDoubleOptions,
   Map<String, dynamic>? accessors,
   Map<String, String>? positionalOptions,
});
```
