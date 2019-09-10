#include <string>
#include <chrono>
#include "Runtime.h"
#include "Caches.h"
#include "Console.h"
#include "SetTimeout.h"
#include "ArgConverter.h"
#include "Interop.h"
#include "InlineFunctions.h"
#include "SimpleAllocator.h"
#include "Helpers.h"
#include "Tasks.h"
#include "WeakRef.h"
#include "Worker.h"

#if defined __arm64 && __arm64__
#include "arm64/natives_blob.h"
#include "arm64/snapshot_blob.h"
#elif defined __x86_64__ && __x86_64__
#include "x86_64/natives_blob.h"
#include "x86_64/snapshot_blob.h"
#else
#error Unknown CPU architecture. Only ARM64 and X86_64 architectures are supported
#endif

#define STRINGIZE(x) #x
#define STRINGIZE_VALUE_OF(x) STRINGIZE(x)

using namespace v8;
using namespace std;

#ifdef DEBUG
#include "v8-inspector-platform.h"
#include "JsV8InspectorClient.h"
#endif

namespace tns {

SimpleAllocator allocator_;

void Runtime::InitializeMetadata(void* metadataPtr) {
    MetaFile::setInstance(metadataPtr);
}

Runtime::Runtime() {
    currentRuntime_ = this;
}

void Runtime::InitAndRunMainScript(const string& baseDir) {
    std::chrono::high_resolution_clock::time_point t1 = std::chrono::high_resolution_clock::now();
    this->Init(baseDir);
    std::chrono::high_resolution_clock::time_point t2 = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(t2 - t1).count();
    printf("Runtime initialization took %llims\n", duration);

#ifdef DEBUG
    v8_inspector::JsV8InspectorClient* inspectorClient = new v8_inspector::JsV8InspectorClient(this->isolate_, baseDir);
    inspectorClient->init();
    inspectorClient->connect();
#endif

    {
        Isolate* isolate = this->GetIsolate();
        HandleScope scope(isolate);
        v8::TryCatch tc(isolate);
        this->moduleInternal_.RunModule(isolate, "./");

        if (tc.HasCaught()) {
            HandleScope scope(this->GetIsolate());
            printf("%s\n", tns::ToString(isolate_, tc.Exception()).c_str());
            assert(false);
        }
    }

    tns::Tasks::Drain();
}

void Runtime::Init(const string& baseDir) {
    if (!mainThreadInitialized_) {
        Runtime::platform_ =
#ifdef DEBUG
            v8_inspector::V8InspectorPlatform::CreateDefaultPlatform();
#else
            platform::NewDefaultPlatform().release();
#endif

        V8::InitializePlatform(Runtime::platform_);
        V8::Initialize();
        std::string flags = "--expose_gc --jitless";
        V8::SetFlagsFromString(flags.c_str(), flags.size());
    }

    auto* nativesBlobStartupData = new StartupData();
    nativesBlobStartupData->data = reinterpret_cast<const char*>(&natives_blob_bin[0]);
    nativesBlobStartupData->raw_size = natives_blob_bin_len;
    V8::SetNativesDataBlob(nativesBlobStartupData);

    auto* snapshotBlobStartupData = new StartupData();
    snapshotBlobStartupData->data = reinterpret_cast<const char*>(&snapshot_blob_bin[0]);
    snapshotBlobStartupData->raw_size = snapshot_blob_bin_len;
    V8::SetSnapshotDataBlob(snapshotBlobStartupData);

    Isolate::CreateParams create_params;
    create_params.array_buffer_allocator = &allocator_;
    Isolate* isolate = Isolate::New(create_params);

    Caches* cache = Caches::Get(isolate);
    cache->ObjectCtorInitializer = MetadataBuilder::GetOrCreateConstructorFunctionTemplate;
    cache->StructCtorInitializer = MetadataBuilder::GetOrCreateStructCtorFunction;

    HandleScope handle_scope(isolate);
    Local<FunctionTemplate> globalTemplateFunction = FunctionTemplate::New(isolate);
    globalTemplateFunction->SetClassName(tns::ToV8String(isolate, "NativeScriptGlobalObject"));
    Local<ObjectTemplate> globalTemplate = ObjectTemplate::New(isolate, globalTemplateFunction);
    DefineNativeScriptVersion(isolate, globalTemplate);

    MetadataBuilder::RegisterConstantsOnGlobalObject(isolate, globalTemplate, mainThreadInitialized_);
    Worker::Init(isolate, globalTemplate, mainThreadInitialized_);
    DefinePerformanceObject(isolate, globalTemplate);
    DefineTimeMethod(isolate, globalTemplate);
    WeakRef::Init(isolate, globalTemplate);
    SetTimeout::Init(isolate, globalTemplate);

    Local<Context> context = Context::New(isolate, nullptr, globalTemplate);
    context->Enter();

    baseDir_ = baseDir;
    DefineGlobalObject(context);
    Console::Init(isolate);
    this->moduleInternal_.Init(isolate, baseDir);

    ArgConverter::Init(isolate, MetadataBuilder::StructPropertyGetterCallback, MetadataBuilder::StructPropertySetterCallback);
    Interop::RegisterInteropTypes(isolate);
    cache->ToStringFunc = MetadataBuilder::CreateToStringFunction(isolate);

    ClassBuilder::RegisterBaseTypeScriptExtendsFunction(isolate); // Register the __extends function to the global object
    ClassBuilder::RegisterNativeTypeScriptExtendsFunction(isolate); // Override the __extends function for native objects

    InlineFunctions::Init(isolate);

    mainThreadInitialized_ = true;

    isolate_ = isolate;
}

void Runtime::RunScript(string file, TryCatch& tc) {
    Isolate* isolate = isolate_;
    Isolate::Scope isolate_scope(isolate);
    HandleScope handle_scope(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    std::string filename = baseDir_ + "/" + file;
    string source = tns::ReadText(filename);
    Local<v8::String> script_source = v8::String::NewFromUtf8(isolate, source.c_str(), NewStringType::kNormal).ToLocalChecked();

    ScriptOrigin origin(tns::ToV8String(isolate, file));

    Local<Script> script;
    if (!Script::Compile(context, script_source, &origin).ToLocal(&script)) {
        return;
    }

    Local<Value> result;
    if (!script->Run(context).ToLocal(&result)) {
        return;
    }
}

Isolate* Runtime::GetIsolate() {
    return this->isolate_;
}

const int Runtime::WorkerId() {
    return this->workerId_;
}

void Runtime::SetWorkerId(int workerId) {
    this->workerId_ = workerId;
}

void Runtime::DefineGlobalObject(Local<Context> context) {
    Local<Object> global = context->Global();
    const PropertyAttribute readOnlyFlags = static_cast<PropertyAttribute>(PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    if (!global->DefineOwnProperty(context, ToV8String(context->GetIsolate(), "global"), global, readOnlyFlags).FromMaybe(false)) {
        assert(false);
    }

    if (mainThreadInitialized_ && !global->DefineOwnProperty(context, ToV8String(context->GetIsolate(), "self"), global, readOnlyFlags).FromMaybe(false)) {
        assert(false);
    }
}

void Runtime::DefinePerformanceObject(Isolate* isolate, Local<ObjectTemplate> globalTemplate) {
    Local<ObjectTemplate> performanceTemplate = ObjectTemplate::New(isolate);

    Local<FunctionTemplate> nowFuncTemplate = FunctionTemplate::New(isolate, PerformanceNowCallback);
    performanceTemplate->Set(tns::ToV8String(isolate, "now"), nowFuncTemplate);

    const PropertyAttribute readOnlyFlags = static_cast<PropertyAttribute>(PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    Local<v8::String> performancePropertyName = ToV8String(isolate, "performance");
    globalTemplate->Set(performancePropertyName, performanceTemplate, readOnlyFlags);
}

void Runtime::PerformanceNowCallback(const FunctionCallbackInfo<Value>& args) {
    std::chrono::system_clock::time_point now = std::chrono::system_clock::now();
    std::chrono::milliseconds timestampMs = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    double result = timestampMs.count();
    args.GetReturnValue().Set(result);
}

void Runtime::DefineNativeScriptVersion(Isolate* isolate, Local<ObjectTemplate> globalTemplate) {
    const PropertyAttribute readOnlyFlags = static_cast<PropertyAttribute>(PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    globalTemplate->Set(ToV8String(isolate, "__runtimeVersion"), ToV8String(isolate, STRINGIZE_VALUE_OF(NATIVESCRIPT_VERSION)), readOnlyFlags);
}

void Runtime::DefineTimeMethod(v8::Isolate* isolate, v8::Local<v8::ObjectTemplate> globalTemplate) {
    Local<FunctionTemplate> timeFunctionTemplate = FunctionTemplate::New(isolate, [](const FunctionCallbackInfo<Value>& info) {
        auto nano = std::chrono::time_point_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now());
        double duration = nano.time_since_epoch().count() / 1000000.0;
        info.GetReturnValue().Set(duration);
    });
    globalTemplate->Set(ToV8String(isolate, "__time"), timeFunctionTemplate);
}

Platform* Runtime::platform_ = nullptr;
bool Runtime::mainThreadInitialized_ = false;
thread_local Runtime* Runtime::currentRuntime_ = nullptr;

}