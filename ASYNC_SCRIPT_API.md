# Async Script Execution API

## Overview

This API allows you to execute JavaScript script files asynchronously from Objective-C or Swift code and receive the results via a completion handler.

## Objective-C API

### Method Signature

```objective-c
- (void)runScriptFileAsync:(NSString*)filePath
                completion:(void(^)(id result, NSError* error))completion;
```

### Parameters

- `filePath`: The absolute file path to the JavaScript file to execute
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

```objective-c
NativeScript* runtime = [[NativeScript alloc] initWithConfig:config];

// Execute a script that returns a number
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

// Execute a script that returns an object
[runtime runScriptFileAsync:@"/path/to/object-script.js"
                  completion:^(id result, NSError* error) {
    if (!error && [result isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)result;
        NSLog(@"Name: %@", dict[@"name"]);
        NSLog(@"Value: %@", dict[@"value"]);
    }
}];
```

### Swift

```swift
let config = Config()
config.baseDir = Bundle.main.resourcePath
let runtime = NativeScript(config: config)

// Execute a script that returns a number
runtime.runScriptFileAsync("/path/to/script.js") { result, error in
    if let error = error {
        print("Error: \(error.localizedDescription)")
        return
    }
    
    if let number = result as? NSNumber {
        print("Result: \(number)")
    }
}

// Execute a script that returns an object
runtime.runScriptFileAsync("/path/to/object-script.js") { result, error in
    guard error == nil else {
        print("Error: \(error!.localizedDescription)")
        return
    }
    
    if let dict = result as? [String: Any] {
        print("Name: \(dict["name"] ?? "N/A")")
        print("Value: \(dict["value"] ?? "N/A")")
    }
}
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
- The completion handler is always called on the main thread
- Multiple scripts can be executed concurrently

## Notes

- The script file must be a valid JavaScript file
- The script is executed in the same runtime context as the main application
- All global variables and functions defined in the main app are accessible
- Be cautious about long-running scripts as they will block the V8 isolate
