#import <Foundation/Foundation.h>

@interface TNSAsyncScriptTester : NSObject

// Execute a script file asynchronously and return the result via callback (defaults to main thread)
+ (void)runScriptFile:(NSString*)filePath 
           completion:(void(^)(id result, NSError* error))completion;

// Execute a script file asynchronously with optional main thread execution
+ (void)runScriptFile:(NSString*)filePath
     runOnMainThread:(BOOL)runOnMainThread
           completion:(void(^)(id result, NSError* error))completion;

// Helper to get the NativeScript runtime instance
+ (id)getRuntimeInstance;

@end
