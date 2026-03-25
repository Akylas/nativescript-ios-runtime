# Async Script Execution API

## Overview

This API allows you to execute JavaScript script files asynchronously from Objective-C or Swift code and receive the results via a completion handler. You can optionally pass a string argument to the script.

## Objective-C API

### Method Signatures

#### Standard Method (Main Thread Completion)

```objective-c
- (void)runScriptFileAsync:(NSString*)filePath
                completion:(void(^)(id result, NSError* error))completion;
```

This method executes the script asynchronously and calls the completion handler on the main thread.

#### Extended Method (Configurable Thread)

```objective-c
- (void)runScriptFileAsync:(NSString*)filePath
          runOnMainThread:(BOOL)runOnMainThread
                completion:(void(^)(id result, NSError* error))completion;
```

This method allows you to specify whether the completion handler should be called on the main thread or on the background thread where the script was executed.

#### Full Method (With Argument)

```objective-c
- (void)runScriptFileAsync:(NSString*)filePath
                  argument:(NSString*)argument
          runOnMainThread:(BOOL)runOnMainThread
                completion:(void(^)(id result, NSError* error))completion;
```

This method allows you to pass a string argument to the script, which will be available as a global variable `__scriptArgument` in JavaScript.

### Parameters

- `filePath`: The absolute file path to the JavaScript file to execute
- `argument`: (Optional) A string argument that will be accessible in JavaScript as `__scriptArgument`. Can be nil.
- `runOnMainThread`: (Optional) YES to call completion on main thread, NO to call on background thread. Defaults to YES if using the standard method.
- `completion`: A completion handler block that receives:
  - `result`: The result of the script execution, converted to an Objective-C type
  - `error`: An NSError object if the operation failed, or nil on success

### Result Types

The result parameter can be one of the following Objective-C types, depending on what the JavaScript code returns:

- `NSNull` - for JavaScript `null` or `undefined`
- `NSNumber` - for JavaScript numbers and booleans
- `NSString` - for JavaScript strings
- `NSArray` - for JavaScript arrays
- `NSDictionary` - for JavaScript objects

## Usage Examples

### Objective-C

#### Default (Main Thread Completion)

```objective-c
NativeScript* runtime = [[NativeScript alloc] initWithConfig:config];

// Execute a script that returns a number (completion on main thread)
[runtime runScriptFileAsync:@"/path/to/script.js" 
                  completion:^(id result, NSError* error) {
    if (error) {
        NSLog(@"Error: %@", error.localizedDescription);
        return;
    }
    
    if ([result isKindOfClass:[NSNumber class]]) {
        NSLog(@"Result: %@", result);
    }
}];
```

#### Background Thread Completion

```objective-c
// Execute a script with completion on background thread
[runtime runScriptFileAsync:@"/path/to/script.js"
            runOnMainThread:NO
                  completion:^(id result, NSError* error) {
    if (error) {
        NSLog(@"Error: %@", error.localizedDescription);
        return;
    }
    
    // This code runs on a background thread
    // Perform non-UI work here
    NSLog(@"Result: %@ (on background thread)", result);
    
    // If you need to update UI, dispatch to main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update UI here
    });
}];
```

#### Explicit Main Thread Completion

```objective-c
// Explicitly specify main thread completion
[runtime runScriptFileAsync:@"/path/to/object-script.js"
            runOnMainThread:YES
                  completion:^(id result, NSError* error) {
    if (!error && [result isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)result;
        NSLog(@"Name: %@", dict[@"name"]);
        NSLog(@"Value: %@", dict[@"value"]);
        // Safe to update UI directly here
    }
}];
```

#### Passing Arguments to Scripts

```objective-c
// Pass a string argument to the script
[runtime runScriptFileAsync:@"/path/to/script.js"
                    argument:@"Hello from Objective-C"
            runOnMainThread:YES
                  completion:^(id result, NSError* error) {
    if (!error) {
        NSLog(@"Script result: %@", result);
    }
}];

// The JavaScript can access the argument:
// script.js:
// const message = __scriptArgument;
// return message.toUpperCase();
```

```objective-c
// Pass JSON data as a string argument
NSString* jsonData = @"{\"userId\":123,\"action\":\"process\"}";
[runtime runScriptFileAsync:@"/path/to/processor.js"
                    argument:jsonData
            runOnMainThread:NO
                  completion:^(id result, NSError* error) {
    // Process result on background thread
    if (!error) {
        NSLog(@"Processed: %@", result);
    }
}];

// The JavaScript can parse and use the argument:
// processor.js:
// const data = JSON.parse(__scriptArgument);
// return { userId: data.userId, status: 'completed' };
```

### Swift

#### Default (Main Thread Completion)

```swift
let config = Config()
config.baseDir = Bundle.main.resourcePath
let runtime = NativeScript(config: config)

// Execute a script that returns a number (completion on main thread)
runtime.runScriptFileAsync("/path/to/script.js") { result, error in
    if let error = error {
        print("Error: \(error.localizedDescription)")
        return
    }
    
    if let number = result as? NSNumber {
        print("Result: \(number)")
    }
}
```

#### Background Thread Completion

```swift
// Execute a script with completion on background thread
runtime.runScriptFileAsync("/path/to/script.js", runOnMainThread: false) { result, error in
    guard error == nil else {
        print("Error: \(error!.localizedDescription)")
        return
    }
    
    // This code runs on a background thread
    // Perform non-UI work here
    print("Result: \(result ?? "nil") (on background thread)")
    
    // If you need to update UI, dispatch to main thread
    DispatchQueue.main.async {
        // Update UI here
    }
}
```

#### Explicit Main Thread Completion

```swift
// Explicitly specify main thread completion
runtime.runScriptFileAsync("/path/to/object-script.js", runOnMainThread: true) { result, error in
    guard error == nil else {
        print("Error: \(error!.localizedDescription)")
        return
    }
    
    if let dict = result as? [String: Any] {
        print("Name: \(dict["name"] ?? "N/A")")
        print("Value: \(dict["value"] ?? "N/A")")
        // Safe to update UI directly here
    }
}
```

#### Passing Arguments to Scripts

```swift
// Pass a string argument to the script
runtime.runScriptFileAsync("/path/to/script.js", 
                          argument: "Hello from Swift",
                          runOnMainThread: true) { result, error in
    guard error == nil else {
        print("Error: \(error!.localizedDescription)")
        return
    }
    
    print("Script result: \(result ?? "nil")")
}

// The JavaScript can access the argument:
// script.js:
// const message = __scriptArgument;
// return message.toUpperCase();
```

```swift
// Pass JSON data as a string argument
let jsonData = "{\"userId\":123,\"action\":\"process\"}"
runtime.runScriptFileAsync("/path/to/processor.js",
                          argument: jsonData,
                          runOnMainThread: false) { result, error in
    // Process result on background thread
    guard error == nil else {
        print("Error: \(error!.localizedDescription)")
        return
    }
    
    print("Processed: \(result ?? "nil")")
}

// The JavaScript can parse and use the argument:
// processor.js:
// const data = JSON.parse(__scriptArgument);
// return { userId: data.userId, status: 'completed' };
```

## JavaScript Access to Arguments

When a script is executed with an argument, it's available as a global variable in JavaScript:

```javascript
// Direct access
const arg = __scriptArgument;

// Via global object
const arg = global.__scriptArgument;

// Check if argument was provided
if (typeof __scriptArgument !== 'undefined') {
    // Use the argument
    console.log('Received:', __scriptArgument);
}

// Parse JSON argument
const data = JSON.parse(__scriptArgument);

// Use argument in computation
const result = __scriptArgument.toUpperCase();
return result;
```

## Error Handling

The API returns errors in the following situations:

1. **File path is required** (code: 1001) - The provided file path is nil or empty
2. **Runtime not initialized** (code: 1002) - The NativeScript runtime has not been initialized
3. **File read error** (code: 1003) - Failed to read the specified file
4. **Script execution failed** (code: 1004) - The JavaScript code threw an exception

## JavaScript Examples

### Simple Value Return

```javascript
// script.js
42
```

Result: `NSNumber` with value 42

### String Return

```javascript
// script.js
'Hello from JavaScript'
```

Result: `NSString` with value "Hello from JavaScript"

### Object Return

```javascript
// script.js
({
  name: 'John',
  age: 30,
  active: true
})
```

Result: `NSDictionary` with keys "name", "age", and "active"

### Array Return

```javascript
// script.js
[1, 2, 3, 'four', true]
```

Result: `NSArray` with 5 elements

### Complex Expression

```javascript
// script.js
(function() {
  const data = {
    timestamp: Date.now(),
    message: 'Processing complete'
  };
  return data;
})()
```

Result: `NSDictionary` with "timestamp" and "message" keys

## Threading

- The file is read on a background thread to avoid blocking
- The JavaScript execution uses proper V8 isolate locking for thread safety
- The completion handler can be called on the main thread (default) or the background thread (if `runOnMainThread=NO`)
- Multiple scripts can be executed concurrently
- When using `runOnMainThread=YES` (default), it's safe to update UI directly in the completion handler
- When using `runOnMainThread=NO`, you must dispatch to the main queue if you need to update UI

## Notes

- The script file must be a valid JavaScript file
- The script is executed in the same runtime context as the main application
- All global variables and functions defined in the main app are accessible
- Be cautious about long-running scripts as they will block the V8 isolate
- Use `runOnMainThread=NO` when you need maximum performance and don't need to update UI immediately
- The `__scriptArgument` global variable is only set when an argument is provided (not nil)
- If no argument is provided, `__scriptArgument` will be undefined in JavaScript
- You can pass any string as an argument, including JSON strings for complex data
- The argument is available throughout the entire script execution
