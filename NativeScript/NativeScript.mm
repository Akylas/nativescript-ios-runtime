#include <Foundation/Foundation.h>
#include "NativeScript.h"
#include "inspector/JsV8InspectorClient.h"
#include "runtime/Console.h"
#include "runtime/RuntimeConfig.h"
#include "runtime/Helpers.h"
#include "runtime/Runtime.h"
#include "runtime/Tasks.h"
#include "runtime/Caches.h"

using namespace v8;
using namespace tns;

@implementation Config

@synthesize BaseDir;
@synthesize ApplicationPath;
@synthesize MetadataPtr;
@synthesize IsDebug;

@end

@implementation NativeScript

extern char defaultStartOfMetadataSection __asm("section$start$__DATA$__TNSMetadata");

- (void)runScriptString: (NSString*) script runLoop: (BOOL) runLoop {

    std::string cppString = std::string([script UTF8String]);
    runtime_->RunScript(cppString);
    
    if (runLoop) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    }


    tns::Tasks::Drain();

}

std::unique_ptr<Runtime> runtime_;

- (void)runMainApplication {
    runtime_->RunMainScript();

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    tns::Tasks::Drain();
}

- (bool)liveSync {
    if (runtime_ == nullptr) {
        return false;
    }

    Isolate* isolate = runtime_->GetIsolate();
    return tns::LiveSync(isolate);
}

- (void)shutdownRuntime {
    if (RuntimeConfig.IsDebug) {
        Console::DetachInspectorClient();
    }
    tns::Tasks::ClearTasks();
    if (runtime_ != nullptr) {
        runtime_ = nullptr;
    }
}

- (instancetype)initializeWithConfig:(Config*)config {
    if (self = [super init]) {
        RuntimeConfig.BaseDir = [config.BaseDir UTF8String];
        if (config.ApplicationPath != nil) {
            RuntimeConfig.ApplicationPath = [[config.BaseDir stringByAppendingPathComponent:config.ApplicationPath] UTF8String];
        } else {
            RuntimeConfig.ApplicationPath = [[config.BaseDir stringByAppendingPathComponent:@"app"] UTF8String];
        }
        if (config.MetadataPtr != nil) {
            RuntimeConfig.MetadataPtr = [config MetadataPtr];
        } else {
            RuntimeConfig.MetadataPtr = &defaultStartOfMetadataSection;
        }
        RuntimeConfig.IsDebug = [config IsDebug];
        RuntimeConfig.LogToSystemConsole = [config LogToSystemConsole];

        Runtime::Initialize();
        runtime_ = nullptr;
        runtime_ = std::make_unique<Runtime>();

        std::chrono::high_resolution_clock::time_point t1 = std::chrono::high_resolution_clock::now();
        Isolate* isolate = runtime_->CreateIsolate();
        v8::Locker l(isolate);
        runtime_->Init(isolate);
        std::chrono::high_resolution_clock::time_point t2 = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(t2 - t1).count();
        printf("Runtime initialization took %llims (version %s, V8 version %s)\n", duration,  NATIVESCRIPT_VERSION, V8::GetVersion());

        if (config.IsDebug) {
            Isolate::Scope isolate_scope(isolate);
            HandleScope handle_scope(isolate);
            v8_inspector::JsV8InspectorClient* inspectorClient = new v8_inspector::JsV8InspectorClient(runtime_.get());
            inspectorClient->init();
            inspectorClient->registerModules();
            inspectorClient->connect([config ArgumentsCount], [config Arguments]);
            Console::AttachInspectorClient(inspectorClient);
        }
    }
    return self;
    
}

- (instancetype)initWithConfig:(Config*)config {
    return [self initializeWithConfig:config];
}

- (void)restartWithConfig:(Config*)config {
    [self shutdownRuntime];
    [self initializeWithConfig:config];
}

- (void)runScriptFileAsync:(NSString*)filePath 
                completion:(void(^)(id result, NSError* error))completion {
    if (!filePath || [filePath length] == 0) {
        if (completion) {
            NSError* error = [NSError errorWithDomain:@"NativeScriptRuntime" 
                                               code:1001 
                                           userInfo:@{NSLocalizedDescriptionKey: @"File path is required"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    if (runtime_ == nullptr) {
        if (completion) {
            NSError* error = [NSError errorWithDomain:@"NativeScriptRuntime" 
                                               code:1002 
                                           userInfo:@{NSLocalizedDescriptionKey: @"Runtime not initialized"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
        return;
    }
    
    // Create a strong reference to the completion block to ensure it stays alive
    void(^completionCopy)(id, NSError*) = [completion copy];
    
    // Execute on a background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError* error = nil;
        id resultObj = nil;
        
        @try {
            // Read the file
            NSString* scriptContent = [NSString stringWithContentsOfFile:filePath 
                                                               encoding:NSUTF8StringEncoding 
                                                                  error:&error];
            if (error || !scriptContent) {
                if (!error) {
                    error = [NSError errorWithDomain:@"NativeScriptRuntime" 
                                               code:1003 
                                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to read file: %@", filePath]}];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionCopy(nil, error);
                });
                return;
            }
            
            // Execute the script and get the result
            std::string cppScript = std::string([scriptContent UTF8String]);
            
            // Get the isolate and execute with proper locking
            Isolate* isolate = runtime_->GetIsolate();
            
            // Lock and execute
            v8::Locker locker(isolate);
            v8::Isolate::Scope isolate_scope(isolate);
            v8::HandleScope handle_scope(isolate);
            
            // Execute the script
            v8::Local<v8::Value> result = runtime_->RunScriptWithResult(cppScript);
            
            // Drain any pending tasks
            tns::Tasks::Drain();
            
            // Convert V8 value to Objective-C object
            if (!result.IsEmpty()) {
                resultObj = [self convertV8ValueToObjC:result isolate:isolate];
            }
            
        } @catch (NSException* exception) {
            error = [NSError errorWithDomain:@"NativeScriptRuntime" 
                                       code:1004 
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Script execution failed: %@", exception.reason]}];
        }
        
        // Call completion on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            completionCopy(resultObj, error);
        });
    });
}

// Helper method to convert V8 values to Objective-C objects
- (id)convertV8ValueToObjC:(v8::Local<v8::Value>)value isolate:(v8::Isolate*)isolate {
    v8::HandleScope handle_scope(isolate);
    std::shared_ptr<tns::Caches> cache = tns::Caches::Get(isolate);
    v8::Local<v8::Context> context = cache->GetContext();
    v8::Context::Scope context_scope(context);
    
    if (value->IsNull() || value->IsUndefined()) {
        return [NSNull null];
    }
    
    if (value->IsBoolean()) {
        return [NSNumber numberWithBool:value->BooleanValue(isolate)];
    }
    
    if (value->IsNumber()) {
        return [NSNumber numberWithDouble:value->NumberValue(context).FromMaybe(0.0)];
    }
    
    if (value->IsString()) {
        v8::String::Utf8Value utf8(isolate, value);
        return [NSString stringWithUTF8String:*utf8];
    }
    
    if (value->IsArray()) {
        v8::Local<v8::Array> array = value.As<v8::Array>();
        NSMutableArray* result = [NSMutableArray arrayWithCapacity:array->Length()];
        for (uint32_t i = 0; i < array->Length(); i++) {
            v8::Local<v8::Value> element;
            if (array->Get(context, i).ToLocal(&element)) {
                id objcElement = [self convertV8ValueToObjC:element isolate:isolate];
                if (objcElement) {
                    [result addObject:objcElement];
                } else {
                    [result addObject:[NSNull null]];
                }
            }
        }
        return result;
    }
    
    if (value->IsObject()) {
        v8::Local<v8::Object> obj = value.As<v8::Object>();
        v8::Local<v8::Array> propertyNames;
        if (!obj->GetOwnPropertyNames(context).ToLocal(&propertyNames)) {
            return [NSDictionary dictionary];
        }
        
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:propertyNames->Length()];
        for (uint32_t i = 0; i < propertyNames->Length(); i++) {
            v8::Local<v8::Value> key;
            if (!propertyNames->Get(context, i).ToLocal(&key)) {
                continue;
            }
            
            v8::String::Utf8Value keyStr(isolate, key);
            NSString* objcKey = [NSString stringWithUTF8String:*keyStr];
            
            v8::Local<v8::Value> val;
            if (obj->Get(context, key).ToLocal(&val)) {
                id objcVal = [self convertV8ValueToObjC:val isolate:isolate];
                if (objcVal && objcKey) {
                    [result setObject:objcVal forKey:objcKey];
                }
            }
        }
        return result;
    }
    
    // For other types, return string representation
    v8::String::Utf8Value utf8(isolate, value);
    return [NSString stringWithUTF8String:*utf8];
}


@end
