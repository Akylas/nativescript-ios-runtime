#import <Foundation/Foundation.h>

@interface TNSAsyncScriptTester : NSObject

// Execute a script file asynchronously and return the result via callback
+ (void)runScriptFile:(NSString*)filePath 
           completion:(void(^)(id result, NSError* error))completion;

// Helper to get the NativeScript runtime instance
+ (id)getRuntimeInstance;

@end
