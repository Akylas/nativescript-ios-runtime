#import <Foundation/Foundation.h>
#import <NativeScript/NativeScript.h>

/// Example demonstrating the async script execution API in Objective-C
@interface AsyncScriptExampleObjC : NSObject

@property (nonatomic, strong) NativeScript* runtime;

- (void)executeCalculation;
- (void)executeObjectScript;
- (void)executeArrayScript;
- (void)executeConcurrentScripts;
- (void)executeWithErrorHandling;

@end

@implementation AsyncScriptExampleObjC

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize the NativeScript runtime
        Config* config = [[Config alloc] init];
        config.BaseDir = [[NSBundle mainBundle] resourcePath];
        config.IsDebug = YES;
        config.LogToSystemConsole = YES;
        
        self.runtime = [[NativeScript alloc] initWithConfig:config];
    }
    return self;
}

/// Example 1: Execute a simple calculation script
- (void)executeCalculation {
    NSString* scriptPath = [self createTempScriptWithContent:@"2 + 2"];
    
    [self.runtime runScriptFileAsync:scriptPath completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSNumber class]]) {
            NSLog(@"Calculation result: %@", result);
            // Output: Calculation result: 4
        }
    }];
}

/// Example 2: Execute a script that returns an object
- (void)executeObjectScript {
    NSString* script = @"({\n"
                        "    timestamp: Date.now(),\n"
                        "    message: 'Hello from JavaScript',\n"
                        "    version: '1.0.0'\n"
                        "})";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    [self.runtime runScriptFileAsync:scriptPath completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary* dict = (NSDictionary*)result;
            NSLog(@"Timestamp: %@", dict[@"timestamp"]);
            NSLog(@"Message: %@", dict[@"message"]);
            NSLog(@"Version: %@", dict[@"version"]);
        }
    }];
}

/// Example 3: Execute a script that returns an array
- (void)executeArrayScript {
    NSString* script = @"[1, 2, 3, 4, 5].map(x => x * 2)";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    [self.runtime runScriptFileAsync:scriptPath completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSArray class]]) {
            NSLog(@"Array result: %@", result);
            // Output: Array result: (2, 4, 6, 8, 10)
        }
    }];
}

/// Example 4: Execute multiple scripts concurrently
- (void)executeConcurrentScripts {
    NSArray* scripts = @[
        @"Math.sqrt(16)",
        @"'Concurrent execution'",
        @"[1, 2, 3].length"
    ];
    
    NSMutableDictionary* results = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    
    [scripts enumerateObjectsUsingBlock:^(NSString* scriptContent, NSUInteger idx, BOOL* stop) {
        dispatch_group_enter(group);
        NSString* scriptPath = [self createTempScriptWithContent:scriptContent];
        
        [self.runtime runScriptFileAsync:scriptPath completion:^(id result, NSError* error) {
            if (error) {
                NSLog(@"Script %lu error: %@", (unsigned long)idx, error.localizedDescription);
            } else {
                @synchronized(results) {
                    results[[NSString stringWithFormat:@"script_%lu", (unsigned long)idx]] = result;
                }
            }
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"All scripts completed. Results: %@", results);
    });
}

/// Example 5: Execute a complex data processing script
- (void)executeDataProcessing {
    NSString* script = @"(function() {\n"
                        "    const data = [\n"
                        "        { name: 'Alice', age: 30 },\n"
                        "        { name: 'Bob', age: 25 },\n"
                        "        { name: 'Charlie', age: 35 }\n"
                        "    ];\n"
                        "    \n"
                        "    const result = {\n"
                        "        total: data.length,\n"
                        "        averageAge: data.reduce((sum, person) => sum + person.age, 0) / data.length,\n"
                        "        names: data.map(person => person.name)\n"
                        "    };\n"
                        "    \n"
                        "    return result;\n"
                        "})()";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    [self.runtime runScriptFileAsync:scriptPath completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary* dict = (NSDictionary*)result;
            NSLog(@"Total people: %@", dict[@"total"]);
            NSLog(@"Average age: %@", dict[@"averageAge"]);
            NSLog(@"Names: %@", dict[@"names"]);
        }
    }];
}

/// Example 6: Handle errors gracefully
- (void)executeWithErrorHandling {
    // Try to execute a non-existent file
    [self.runtime runScriptFileAsync:@"/nonexistent/file.js" completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Expected error occurred:");
            NSLog(@"  Domain: %@", error.domain);
            NSLog(@"  Code: %ld", (long)error.code);
            NSLog(@"  Description: %@", error.localizedDescription);
        }
    }];
    
    // Try with empty path
    [self.runtime runScriptFileAsync:@"" completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error for empty path: %@", error.localizedDescription);
        }
    }];
}

/// Example 7: Execute script with background thread completion for performance
- (void)executeWithBackgroundCompletion {
    NSString* script = @"(function() { return 42 * 2; })()";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    // Execute with completion on background thread
    [self.runtime runScriptFileAsync:scriptPath
                    runOnMainThread:NO
                         completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        // This runs on background thread
        NSLog(@"Result on background thread: %@", result);
        
        // If you need to update UI, dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Now on main thread for UI updates");
        });
    }];
}

/// Example 8: Data processing with background completion
- (void)executeDataProcessingOnBackground {
    NSString* script = @"(function() {\n"
                        "    const data = Array.from({length: 1000}, (_, i) => i);\n"
                        "    return data.reduce((sum, val) => sum + val, 0);\n"
                        "})()";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    // Process data on background thread for better performance
    [self.runtime runScriptFileAsync:scriptPath
                    runOnMainThread:NO
                         completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSNumber class]]) {
            NSLog(@"Sum calculated on background: %@", result);
            // Result: 499500
        }
    }];
}

/// Example 9: Pass a string argument to a script
- (void)executeWithArgument {
    NSString* script = @"const message = __scriptArgument;\n"
                        "return message.toUpperCase() + '!';";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    [self.runtime runScriptFileAsync:scriptPath
                            argument:@"Hello from Objective-C"
                    runOnMainThread:YES
                         completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSString class]]) {
            NSLog(@"Result: %@", result);
            // Output: HELLO FROM OBJECTIVE-C!
        }
    }];
}

/// Example 10: Pass JSON data as argument
- (void)executeWithJSONArgument {
    NSString* script = @"const data = JSON.parse(__scriptArgument);\n"
                        "return {\n"
                        "    userId: data.userId,\n"
                        "    userName: data.name.toUpperCase(),\n"
                        "    processed: true\n"
                        "};";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    NSString* jsonData = @"{\"userId\":123,\"name\":\"john\"}";
    
    [self.runtime runScriptFileAsync:scriptPath
                            argument:jsonData
                    runOnMainThread:NO
                         completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary* dict = (NSDictionary*)result;
            NSLog(@"User ID: %@", dict[@"userId"]);
            NSLog(@"User Name: %@", dict[@"userName"]);
            NSLog(@"Processed: %@", dict[@"processed"]);
        }
    }];
}

/// Example 11: Use argument in calculations
- (void)executeCalculationWithArgument {
    NSString* script = @"const input = parseFloat(__scriptArgument);\n"
                        "return {\n"
                        "    original: input,\n"
                        "    squared: input * input,\n"
                        "    cubed: input * input * input\n"
                        "};";
    NSString* scriptPath = [self createTempScriptWithContent:script];
    
    [self.runtime runScriptFileAsync:scriptPath
                            argument:@"5"
                    runOnMainThread:YES
                         completion:^(id result, NSError* error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
            return;
        }
        
        if ([result isKindOfClass:[NSDictionary class]]) {
            NSDictionary* dict = (NSDictionary*)result;
            NSLog(@"Original: %@", dict[@"original"]);
            NSLog(@"Squared: %@", dict[@"squared"]);
            NSLog(@"Cubed: %@", dict[@"cubed"]);
            // Output: Original: 5, Squared: 25, Cubed: 125
        }
    }];
}

// MARK: - Helper Methods

- (NSString*)createTempScriptWithContent:(NSString*)content {
    NSString* tempDir = NSTemporaryDirectory();
    NSString* fileName = [NSString stringWithFormat:@"script_%@.js", [[NSUUID UUID] UUIDString]];
    NSString* filePath = [tempDir stringByAppendingPathComponent:fileName];
    
    NSError* error = nil;
    [content writeToFile:filePath
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:&error];
    
    if (error) {
        NSLog(@"Failed to create temp script: %@", error);
    }
    
    return filePath;
}

@end

// MARK: - Usage Example

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        AsyncScriptExampleObjC* example = [[AsyncScriptExampleObjC alloc] init];
        
        // Run examples
        [example executeCalculation];
        [example executeObjectScript];
        [example executeArrayScript];
        [example executeConcurrentScripts];
        [example executeDataProcessing];
        [example executeWithErrorHandling];
        
        // Keep the run loop alive to see async results
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
