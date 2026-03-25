#import "TNSAsyncScriptTester.h"
#import <NativeScript/NativeScript.h>

// External reference to the global nativescript instance from main.m
extern NativeScript* nativescript;

@implementation TNSAsyncScriptTester

+ (void)runScriptFile:(NSString*)filePath 
           completion:(void(^)(id result, NSError* error))completion {
    [self runScriptFile:filePath argument:nil runOnMainThread:YES completion:completion];
}

+ (void)runScriptFile:(NSString*)filePath
     runOnMainThread:(BOOL)runOnMainThread
           completion:(void(^)(id result, NSError* error))completion {
    [self runScriptFile:filePath argument:nil runOnMainThread:runOnMainThread completion:completion];
}

+ (void)runScriptFile:(NSString*)filePath
             argument:(NSString*)argument
     runOnMainThread:(BOOL)runOnMainThread
           completion:(void(^)(id result, NSError* error))completion {
    if (nativescript) {
        [nativescript runScriptFileAsync:filePath argument:argument runOnMainThread:runOnMainThread completion:completion];
    } else {
        NSError* error = [NSError errorWithDomain:@"TNSAsyncScriptTester" 
                                           code:1000 
                                       userInfo:@{NSLocalizedDescriptionKey: @"NativeScript runtime not initialized"}];
        if (completion) {
            completion(nil, error);
        }
    }
}

+ (id)getRuntimeInstance {
    return nativescript;
}

@end
