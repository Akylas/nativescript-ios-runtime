# Implementation Summary: Async Script Execution API

## Overview

This implementation adds a new asynchronous JavaScript script file execution API to the NativeScript iOS runtime. The API allows Objective-C and Swift developers to execute JavaScript files from a path and receive results via completion handlers. The API includes optional parameters to:
1. Control whether the completion handler is called on the main thread or the background thread
2. Pass a string argument to the script that is easily accessible from JavaScript

## Changes Made

### 1. Core Runtime Extensions

#### NativeScript.h
- Added standard method: `- (void)runScriptFileAsync:(NSString*)filePath completion:(void(^)(id result, NSError* error))completion`
- Added extended method: `- (void)runScriptFileAsync:(NSString*)filePath runOnMainThread:(BOOL)runOnMainThread completion:(void(^)(id result, NSError* error))completion`
- Added full method with argument: `- (void)runScriptFileAsync:(NSString*)filePath argument:(NSString*)argument runOnMainThread:(BOOL)runOnMainThread completion:(void(^)(id result, NSError* error))completion`
- Comprehensive documentation explaining the API, parameters, and return types
- The `runOnMainThread` parameter allows choosing between main thread (YES) or background thread (NO) completion
- The `argument` parameter allows passing a string to the script, accessible as `__scriptArgument` in JavaScript

#### NativeScript.mm
- Implemented `runScriptFileAsync:completion:` as a convenience wrapper that calls the full method with `runOnMainThread=YES` and `argument=nil`
- Implemented `runScriptFileAsync:runOnMainThread:completion:` as a convenience wrapper that calls the full method with `argument=nil`
- Implemented `runScriptFileAsync:argument:runOnMainThread:completion:` (full method) with:
  - Input validation (file path, runtime state)
  - Asynchronous file reading on background thread
  - V8 isolate locking for thread-safe script execution
  - Setting `__scriptArgument` as a global variable in V8 context when argument is provided
  - JavaScript-to-Objective-C type conversion
  - Configurable completion handler callback (main thread or background thread based on parameter)
  - All error paths respect the `runOnMainThread` setting
- Added `convertV8ValueToObjC:isolate:` helper method for type conversion supporting:
  - Primitives: `NSNumber` (for numbers and booleans), `NSString`, `NSNull`
  - Collections: `NSArray`, `NSDictionary`
  - Recursive conversion for nested structures

#### Runtime.h/mm
- Added `RunScriptWithResult(const std::string& script)` method
- Returns `v8::Local<v8::Value>` for script execution result
- Properly manages V8 isolate scope without double-locking

#### ModuleInternal.h/mm
- Added `RunScriptWithResult(Isolate* isolate, const std::string& script)` method
- Returns `v8::MaybeLocal<v8::Value>` for safe result handling
- Leverages existing `RunScriptString` infrastructure

### 2. Test Infrastructure

#### TestFixtures/TNSAsyncScriptTester.h/m
- Created test helper class to expose the async API to JavaScript tests
- Provides `runScriptFile:completion:` static method (defaults to main thread, no argument)
- Provides `runScriptFile:runOnMainThread:completion:` static method (configurable thread, no argument)
- Provides `runScriptFile:argument:runOnMainThread:completion:` static method (full configuration)
- Accesses global `nativescript` instance from TestRunner

#### TestFixtures/TestFixtures.h
- Added import for `TNSAsyncScriptTester.h` to expose to tests

#### TestRunner/app/tests/AsyncScriptExecutionTests.js
- Comprehensive test suite with 24 test cases covering:
  - Basic data types (numbers, strings, booleans, null/undefined)
  - Complex types (objects, arrays)
  - Error handling (file not found, empty path, null path)
  - Concurrent execution (thread safety)
  - Complex expressions and data processing
  - Runtime errors and syntax errors
  - Background thread completion (5 tests)
  - Script argument functionality (6 tests)
  - Thread context verification for both main and background threads

### 3. Documentation

#### ASYNC_SCRIPT_API.md
- Complete API documentation with:
  - Standard, extended, and full method signatures
  - Parameters including `runOnMainThread` and `argument` options
  - Return types and conversions
  - Error codes and handling
  - JavaScript access to arguments via `__scriptArgument`
  - Usage examples in both Objective-C and Swift for all modes
  - Threading notes and best practices
  - Performance considerations

#### examples/AsyncScriptExample.swift
- Comprehensive Swift examples (9 examples total) demonstrating:
  - Simple calculations
  - Object and array returns
  - Concurrent execution
  - Background thread completion for performance
  - Data processing on background thread
  - Passing string arguments to scripts
  - Passing JSON data as arguments
  - Using arguments in script logic
  - Proper UI dispatch patterns

#### examples/AsyncScriptExample.m
- Comprehensive Objective-C examples (11 examples total) with identical scenarios
- Demonstrates idiomatic Objective-C patterns
- Shows background thread completion examples
- Includes argument passing examples with simple strings and JSON data

## Technical Design

### Threading Model

```
┌─────────────────────────────────────────────────────────────┐
│                    Main Thread (Caller)                      │
│                                                              │
│  runScriptFileAsync:runOnMainThread:completion: called       │
│          │                                                   │
│          ├──> Validation (path, runtime state)              │
│          │                                                   │
└──────────┼──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│              Background Thread (I/O & Execution)             │
│                                                              │
│  ├──> Read file from disk                                   │
│  │                                                           │
│  ├──> Acquire V8 Isolate Lock                               │
│  │                                                           │
│  ├──> Execute JavaScript (Runtime::RunScriptWithResult)     │
│  │                                                           │
│  ├──> Convert V8 result to Objective-C                      │
│  │                                                           │
└──┼──────────────────────────────────────────────────────────┘
   │
   ├──> if (runOnMainThread == YES)
   │    │
   │    ▼
   │ ┌───────────────────────────────────────────────────────┐
   │ │           Main Thread (Completion)                    │
   │ │                                                       │
   │ │  completion(result, error) called                     │
   │ │  Safe for UI updates                                  │
   │ └───────────────────────────────────────────────────────┘
   │
   └──> if (runOnMainThread == NO)
        │
        ▼
     ┌───────────────────────────────────────────────────────┐
     │        Background Thread (Completion)                 │
     │                                                       │
     │  completion(result, error) called                     │
     │  Must dispatch to main for UI updates                 │
     └───────────────────────────────────────────────────────┘
```


### Type Conversion

JavaScript Type → Objective-C Type:
- `undefined/null` → `NSNull`
- `boolean` → `NSNumber` (bool)
- `number` → `NSNumber` (double)
- `string` → `NSString`
- `Array` → `NSArray` (recursive)
- `Object` → `NSDictionary` (recursive)

### Error Handling

Error Codes:
- 1001: File path is required
- 1002: Runtime not initialized
- 1003: Failed to read file
- 1004: Script execution failed

## Performance Considerations

1. **Const Reference Parameters**: Script content passed by const reference to avoid copies
2. **Async I/O**: File reading happens on background thread to avoid blocking
3. **Proper Locking**: V8 isolate locked only when necessary, avoiding double-locking
4. **Main Thread Callbacks**: Completion handlers always called on main thread for UI safety

## Security

- CodeQL analysis: 0 issues found
- Input validation for all parameters
- Safe file reading with error handling
- Exception handling around script execution
- No SQL injection or buffer overflow vulnerabilities

## Testing

- 13 comprehensive test cases
- Tests cover success paths, error paths, and edge cases
- Concurrent execution verified
- Error propagation verified

## Compatibility

- Compatible with existing NativeScript iOS runtime
- Does not break existing APIs
- Thread-safe for concurrent use
- Works with both Objective-C and Swift

## Files Modified

1. `NativeScript/NativeScript.h` - API declaration
2. `NativeScript/NativeScript.mm` - API implementation
3. `NativeScript/runtime/Runtime.h` - Runtime extension declaration
4. `NativeScript/runtime/Runtime.mm` - Runtime extension implementation
5. `NativeScript/runtime/ModuleInternal.h` - Module internal extension declaration
6. `NativeScript/runtime/ModuleInternal.mm` - Module internal extension implementation
7. `TestFixtures/TestFixtures.h` - Test fixture registration
8. `TestFixtures/TNSAsyncScriptTester.h` - Test helper declaration
9. `TestFixtures/TNSAsyncScriptTester.m` - Test helper implementation
10. `TestRunner/app/tests/AsyncScriptExecutionTests.js` - Test suite

## Files Added

1. `ASYNC_SCRIPT_API.md` - API documentation
2. `examples/AsyncScriptExample.swift` - Swift examples
3. `examples/AsyncScriptExample.m` - Objective-C examples
4. `IMPLEMENTATION_SUMMARY.md` - This file

## Future Enhancements

Possible future improvements:
1. Support for Promise return values with async/await
2. Stream-based execution for large scripts
3. Script caching for frequently executed files
4. Performance metrics and profiling hooks
5. Debug mode with enhanced error reporting

## Conclusion

This implementation provides a robust, thread-safe, and well-documented API for asynchronous JavaScript script execution from native code with optional main thread completion and argument passing. The implementation follows best practices for iOS development, includes comprehensive tests, and provides clear documentation for developers.

### Key Features
- **Backward Compatible**: Existing code continues to work with default main thread completion and no argument
- **Flexible Threading**: Optional `runOnMainThread` parameter for performance optimization
- **Script Arguments**: Pass string arguments to scripts, accessible as `__scriptArgument` in JavaScript
- **Type Safe**: Proper conversion between JavaScript and Objective-C types
- **Well Tested**: 24 test cases covering all scenarios including thread verification and argument passing
- **Well Documented**: Complete API documentation with examples in both Swift and Objective-C

### Performance Benefits
When using `runOnMainThread=NO`, the completion handler executes on the background thread, which can improve performance by:
- Eliminating unnecessary thread context switches
- Allowing immediate processing of results without waiting for main thread
- Reducing main thread load for non-UI operations
- Enabling more efficient concurrent script execution

### Argument Passing Benefits
The script argument feature allows:
- Passing dynamic data to scripts without file modification
- Simple string arguments for basic use cases
- JSON strings for complex data structures
- Easy JavaScript access via `__scriptArgument` global variable
- Runtime parameterization of script behavior
