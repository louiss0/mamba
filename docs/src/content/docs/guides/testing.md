---
title: testing
description: Test your Commands by using a different version of the Executor.
---

When it comes to testing your commands you need to use a different version of the `Executor`. 
When you use `create` The executor that get's returned is what is called the real version. 
When you use the `fake` method you get a test version of the executor.

The `Executor` that's returned by `fake` is one that returns a `MambaExecutionResult`.
The result could either be a `MambaSuccessResult` when a command returns the string.
It could also be a `MambaFailureResult` when a command raises an exception.


All you need to do is make a file in the test folder. 

Then write something like this! 

```dart
import 'package:mamba/mamba.dart';

class Add extends Command {
  @override
  String get name => "add";

  @override
  String get description => "Add something";


  Add({
    mandatoryPositionals: [
     NormalPositional('word')
  ]
  });


  FutureOr<String> run() => "Added something"
  
}

void main() {


  group("my-app", () {


    group("add", (){
      
    final executor = Executor("my-app", "This is my app", [Add()] ).fake();


    test("it adds", (){
      
        final result = executor.run('add');


        expect(result, isA<MambaSuccessResult>().having((result)=> result.value), "value", "Added something");
        
    });

    
    });

    
  });
  
}
```

So far the test that you have written above has passed! So how do you trigger a failure? 

To get an failure you have to! 

1. Throw one manually two 
2. Attempt to parse a command structure with an invalid argument

To trigger a manual failure you must use an `MambaException`. 

Replace run with an error and a return

```dart  del={1-2} ins={3-8} 
  FutureOr<String> run() => "Added something";
  
  FutureOr<String> run() {

  if(true) throw MambaException();
  
  return "Added something";

  }
```
 

To trigger a failure based on an invalid value you must! 

1. Register a cli argument, flag or, option 
2. Pass an invalid value!

::note[Step 1: You need to now replace the error with a registered positional!]

```dart  del={3}  
  FutureOr<String> run() {

  if(true) throw MambaException();
  
  return "Added something";

  }
```
::note


::note[Step 2: Register a mandatory positional!]

```dart ins={3-10}
@override
String get description => "Add something";

Add({
  mandatoryPositionals: [
   NormalPositional('word')
]
});
```
::note

::note[Step 3: Then run the tests]
This time you should get a failure result and the test should fail!
::note