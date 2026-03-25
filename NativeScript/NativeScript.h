#import <Foundation/Foundation.h>

@interface Config : NSObject

@property (nonatomic, retain) NSString* BaseDir;
@property (nonatomic, retain) NSString* ApplicationPath;
@property (nonatomic) void* MetadataPtr;
@property BOOL IsDebug;
@property BOOL LogToSystemConsole;
@property int ArgumentsCount;
@property (nonatomic) char** Arguments;

@end

@interface NativeScript : NSObject

- (instancetype)initWithConfig:(Config*)config;
- (void)runScriptString: (NSString*) script runLoop: (BOOL) runLoop;
- (void)restartWithConfig:(Config*)config;
- (void)shutdownRuntime;

/**
 WARNING: this method does not return in most applications. (UIApplicationMain)
 */
- (void)runMainApplication;
- (bool)liveSync;

/**
 Run a JavaScript script file asynchronously from a file path.
 The script will be executed on a background thread and the result will be returned via the completion handler on the main thread.
 
 @param filePath The absolute file path to the JavaScript file to execute
 @param completion A completion handler that receives the result (id) and any error (NSError*). 
                   The result can be NSString, NSNumber, NSArray, NSDictionary, or NSNull for JavaScript primitives, arrays, objects, and null/undefined.
 */
- (void)runScriptFileAsync:(NSString*)filePath
                completion:(void(^)(id result, NSError* error))completion;

/**
 Run a JavaScript script file asynchronously from a file path with optional main thread execution.
 The script will be executed on a background thread and the result will be returned via the completion handler.
 
 @param filePath The absolute file path to the JavaScript file to execute
 @param runOnMainThread Whether to call the completion handler on the main thread (YES) or on the background thread (NO)
 @param completion A completion handler that receives the result (id) and any error (NSError*). 
                   The result can be NSString, NSNumber, NSArray, NSDictionary, or NSNull for JavaScript primitives, arrays, objects, and null/undefined.
 */
- (void)runScriptFileAsync:(NSString*)filePath
          runOnMainThread:(BOOL)runOnMainThread
                completion:(void(^)(id result, NSError* error))completion;

/**
 Run a JavaScript script file asynchronously from a file path with an optional string argument and optional main thread execution.
 The script will be executed on a background thread and the result will be returned via the completion handler.
 The argument will be available in JavaScript as a global variable `__scriptArgument`.
 
 @param filePath The absolute file path to the JavaScript file to execute
 @param argument An optional string argument that will be accessible in JavaScript as `__scriptArgument` (can be nil)
 @param runOnMainThread Whether to call the completion handler on the main thread (YES) or on the background thread (NO)
 @param completion A completion handler that receives the result (id) and any error (NSError*). 
                   The result can be NSString, NSNumber, NSArray, NSDictionary, or NSNull for JavaScript primitives, arrays, objects, and null/undefined.
 */
- (void)runScriptFileAsync:(NSString*)filePath
                  argument:(NSString*)argument
          runOnMainThread:(BOOL)runOnMainThread
                completion:(void(^)(id result, NSError* error))completion;

@end
