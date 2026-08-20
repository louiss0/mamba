# Handoff TODO


I want you to write documentation for me! 
I need you to write about the API's in Mamba.

For the things in the command file! 

I want you to look at the registry and the help formatter! 

I expect you to talk about what what each thing registers! 

The order should be! 

1. What it registers
2. What the parser does when what is registered is found in the registry
3. What the help formatter will display

When it comes to the registry be broad about how it works! 
Don't talk about how it works with the parser! 
Talk about why and how it sorts things it the areas that it does. 

When talking about the parser talk about the syntaxes that can be parsed by it.

When talking about the Executor talk about the fact that the create method is meant to be used for production.
While the fake method is for testing! it's suppossed to be called then imported in test files!
It's best to call it in one file call the `create` function it a place where the executable will be built.
Then fake in the place where the CLI will be tested! 

In the Mamba file! You can talk about everything you know about Mamba so far!
Talk about Mamba in terms of it's Architecture! 
In Mamba: 
1. Commands Register data, 
2. that data is read by the parser, 
3. the parser decides whether the command is valid
4. The executor selects the correct command then sends the parsed data to it along with global information
