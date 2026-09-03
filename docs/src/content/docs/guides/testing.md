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


  FuttureOr<String> run() => "Added something"
  
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
