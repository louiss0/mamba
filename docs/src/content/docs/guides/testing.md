---
title: testing
description: Test your Commands by using a different version of the Executor.
---

When it comes to testing your commands you need to use a different version of the `Executor`. 
When you use `create` The executor that get's returned is what is called the real version. 
When you use the `fake` method you get a test version of the executor.

The `Executor` that's returned by `fake` is one that returns a `MambaExecutionResult`.
The result could either be a `MambaSuccessResult` when the command returns the string.
It could also be a `MambaFailureResult` when the command raises an exception.

As a developer you don't worry about buffers or standard logic! 
That's handled by the `Executor.create`.

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

As you can see this executor **passes the value of the returned string to a sucess result**! 

What happens when the command raises an exception?

Well we'll find out! 

Change the add Command like this! 

```dart del={6} ins={7-15}
class Add extends Command {
  @override
  String get name => "add";

  @override
  String get description => "Add something";


  FuttureOr<String> run() => "Added something";
  FuttureOr<String> run(positionals) { 

    if (positionals.isEmpty) {
      throw Exception("No positionals provided");
    }
    
    return "Added ";
  };
  
}
```

Then run the test again! This time it should fail!

When it does you'll get error! 

When it does you then change the test to accept an argument!

```dart del={3} ins={4} 
test("it adds", (){
  
    final result = executor.run('add');
    final result = executor.run('add', "Make lunch");


    expect(result, isA<MambaSuccessResult>().having((result)=> result.value), "value", "Added something");
    
});
```

Then run the test again! This time it should fail again!

But this time
