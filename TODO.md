# TODO

You are going to add the Variadic feature to this framework! 
It's an optional field that can be used in all commands.
Please do research on a CLI that uses Variadics a lot! 
The registry will hold it and send it to the parser. 
The parser is suppossed to use it to figure out how to validate passed in arguments. 
It will then pass the arguments as values to the variadic parameter.

Variadics are everything that's suppossed to come after all arguments including repeated ones.

Tests for the parser need to make sure that the optional Variadic is used.
Do this by making a test group called `Parses Variadics correctly`

- When the user picks a variadic the arguments are sent to the Variadic array.
 
- When the `NormalVariadic` is used the Variadic array needs to match it's regex.
  - The test needs to confirm that when there's a falure the exact index where the failure is known is sent to the user.
- When the `ChoiceVariadic` is used the array needs to have one of the values that are in the names of the enums.
  - The test needs to confirm that when there's a falure the exact index where the failure is known is sent to the user.
- Variadics must absorb values only after all mandatory and discretionary positionals have taken their values.
- Write a test with:
  - Variadic vs. mandatory positionals
  - Variadic vs. discretionary positionals.
  - Variadic vs. Mandatory, Repeated, Mandatory.
  - Variadic vs. Mandatory, Repeated, Discretionary
  - Variadic vs. Mandatory, Discretionary, Repeated

Tests for the registry need to make sure that the Variadic field needs to exist as `variadic`.

Tests for the commands need to make sure that the command field exists! 

Before doing this task! You need to fix the errors I made by making a mixin that add's regex.
I need you to make a mixin for choice validation too. Make sure that's used for all validations!
