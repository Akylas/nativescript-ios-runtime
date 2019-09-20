#include <Foundation/Foundation.h>
#include <string>
#include <sys/stat.h>
#include "ModuleInternal.h"
#include "RuntimeConfig.h"
#include "Helpers.h"

using namespace v8;

namespace tns {

static constexpr bool USE_CODE_CACHE = true;

template <mode_t mode>
static mode_t stat(NSString* path) {
    struct stat statbuf;
    if (stat(path.fileSystemRepresentation, &statbuf) == 0) {
        return (statbuf.st_mode & S_IFMT) & mode;
    }

    return 0;
}

ModuleInternal::ModuleInternal()
    : requireFunction_(nullptr), requireFactoryFunction_(nullptr) {
}

void ModuleInternal::Init(Isolate* isolate) {
    std::string requireFactoryScript =
        "(function() { "
        "    function require_factory(requireInternal, dirName) { "
        "        return function require(modulePath) { "
        "            return requireInternal(modulePath, dirName); "
        "        } "
        "    } "
        "    return require_factory; "
        "})()";

    Local<Context> context = isolate->GetCurrentContext();
    Local<Object> global = context->Global();
    Local<Script> script;
    TryCatch tc(isolate);
    if (!Script::Compile(context, tns::ToV8String(isolate, requireFactoryScript.c_str())).ToLocal(&script) && tc.HasCaught()) {
        tns::LogError(isolate, tc);
        assert(false);
    }
    assert(!script.IsEmpty());

    Local<Value> result;
    if (!script->Run(context).ToLocal(&result) && tc.HasCaught()) {
        tns::LogError(isolate, tc);
        assert(false);
    }
    assert(!result.IsEmpty() && result->IsFunction());

    requireFactoryFunction_ = new Persistent<v8::Function>(isolate, result.As<v8::Function>());

    Local<FunctionTemplate> requireFuncTemplate = FunctionTemplate::New(isolate, RequireCallback, External::New(isolate, this));
    requireFunction_ = new Persistent<v8::Function>(isolate, requireFuncTemplate->GetFunction(context).ToLocalChecked());

    Local<v8::Function> globalRequire = GetRequireFunction(isolate, RuntimeConfig.ApplicationPath);
    bool success = global->Set(context, tns::ToV8String(isolate, "require"), globalRequire).FromMaybe(false);
    assert(success);
}

void ModuleInternal::RunModule(Isolate* isolate, std::string path) {
    Local<Context> context = isolate->GetCurrentContext();
    Local<Object> globalObject = context->Global();
    Local<Value> requireObj;
    bool success = globalObject->Get(context, ToV8String(isolate, "require")).ToLocal(&requireObj);
    assert(success && requireObj->IsFunction());
    Local<v8::Function> requireFunc = requireObj.As<v8::Function>();
    Local<Value> args[] = { ToV8String(isolate, path) };
    Local<Value> result;
    success = requireFunc->Call(context, globalObject, 1, args).ToLocal(&result);
    assert(success);
}

Local<v8::Function> ModuleInternal::GetRequireFunction(Isolate* isolate, const std::string& dirName) {
    Local<v8::Function> requireFuncFactory = requireFactoryFunction_->Get(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    Local<v8::Function> requireInternalFunc = requireFunction_->Get(isolate);
    Local<Value> args[2] {
        requireInternalFunc, tns::ToV8String(isolate, dirName.c_str())
    };

    Local<Value> result;
    Local<Object> thiz = Object::New(isolate);
    bool success = requireFuncFactory->Call(context, thiz, 2, args).ToLocal(&result);
    assert(success && !result.IsEmpty() && result->IsFunction());

    return result.As<v8::Function>();
}

void ModuleInternal::RequireCallback(const FunctionCallbackInfo<Value>& info) {
    ModuleInternal* moduleInternal = static_cast<ModuleInternal*>(info.Data().As<External>()->Value());
    Isolate* isolate = info.GetIsolate();

    std::string moduleName = tns::ToString(isolate, info[0].As<v8::String>());
    std::string callingModuleDirName = tns::ToString(isolate, info[1].As<v8::String>());

    NSString* fullPath;
    if (moduleName.length() > 0 && moduleName[0] != '/') {
        if (moduleName[0] == '.') {
            fullPath = [[NSString stringWithUTF8String:callingModuleDirName.c_str()] stringByAppendingPathComponent:[NSString stringWithUTF8String:moduleName.c_str()]];
        } else if (moduleName[0] == '~') {
            moduleName = moduleName.substr(2);
            fullPath = [[NSString stringWithUTF8String:RuntimeConfig.ApplicationPath.c_str()] stringByAppendingPathComponent:[NSString stringWithUTF8String:moduleName.c_str()]];
        } else {
            NSString* tnsModulesPath = [[NSString stringWithUTF8String:RuntimeConfig.ApplicationPath.c_str()] stringByAppendingPathComponent:@"tns_modules"];
            fullPath = [tnsModulesPath stringByAppendingPathComponent:[NSString stringWithUTF8String:moduleName.c_str()]];
            if (!stat<S_IFDIR | S_IFREG>(fullPath) && !stat<S_IFDIR | S_IFREG>([fullPath stringByAppendingPathExtension:@"js"])) {
                fullPath = [tnsModulesPath stringByAppendingPathComponent:@"tns-core-modules"];
                fullPath = [fullPath stringByAppendingPathComponent:[NSString stringWithUTF8String:moduleName.c_str()]];
            }
        }
    } else {
        fullPath = [NSString stringWithUTF8String:moduleName.c_str()];
    }

    NSString* fileNameOnly = [fullPath lastPathComponent];
    NSString* pathOnly = [fullPath stringByDeletingLastPathComponent];

    bool isData = false;
    Local<Object> moduleObj = moduleInternal->LoadImpl(isolate, [fileNameOnly UTF8String], [pathOnly UTF8String], isData);
    if (moduleObj.IsEmpty()) {
        return;
    }

    if (isData) {
        assert(!moduleObj.IsEmpty());
        info.GetReturnValue().Set(moduleObj);
    } else {
        Local<Context> context = isolate->GetCurrentContext();
        Local<Value> exportsObj;
        bool success = moduleObj->Get(context, tns::ToV8String(isolate, "exports")).ToLocal(&exportsObj);
        assert(success);
        info.GetReturnValue().Set(exportsObj);
    }
}

Local<Object> ModuleInternal::LoadImpl(Isolate* isolate, const std::string& moduleName, const std::string& baseDir, bool& isData) {
    size_t lastIndex = moduleName.find_last_of(".");
    std::string moduleNameWithoutExtension = (lastIndex == std::string::npos) ? moduleName : moduleName.substr(0, lastIndex);
    std::string cacheKey = baseDir + "*" + moduleNameWithoutExtension;
    auto it = this->loadedModules_.find(cacheKey);

    if (it != this->loadedModules_.end()) {
        return it->second->Get(isolate);
    }

    Local<Object> moduleObj;
    Local<Value> exportsObj;
    std::string path = this->ResolvePath(isolate, baseDir, moduleName);
    if (path.empty()) {
        return Local<Object>();
    }

    NSString* pathStr = [NSString stringWithUTF8String:path.c_str()];
    NSString* extension = [pathStr pathExtension];
    if ([extension isEqualToString:@"json"]) {
        isData = true;
    }

    auto it2 = this->loadedModules_.find(path);
    if (it2 != this->loadedModules_.end()) {
        return it2->second->Get(isolate);
    }

    if ([extension isEqualToString:@"js"]) {
        moduleObj = this->LoadModule(isolate, path, cacheKey);
    } else if ([extension isEqualToString:@"json"]) {
        moduleObj = this->LoadData(isolate, path);
    } else {
        // TODO: throw an error for unsupported file extension
        assert(false);
    }

    return moduleObj;
}

Local<Object> ModuleInternal::LoadModule(Isolate* isolate, const std::string& modulePath, const std::string& cacheKey) {
    Local<Object> moduleObj = Object::New(isolate);
    Local<Object> exportsObj = Object::New(isolate);
    Local<Context> context = isolate->GetCurrentContext();
    bool success = moduleObj->Set(context, tns::ToV8String(isolate, "exports"), exportsObj).FromMaybe(false);
    assert(success);

    const PropertyAttribute readOnlyFlags = static_cast<PropertyAttribute>(PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);

    Local<v8::String> fileName = tns::ToV8String(isolate, modulePath);
    success = moduleObj->DefineOwnProperty(context, tns::ToV8String(isolate, "id"), fileName, readOnlyFlags).FromMaybe(false);
    assert(success);

    Persistent<Object>* poModuleObj = new Persistent<Object>(isolate, moduleObj);
    TempModule tempModule(this, modulePath, cacheKey, poModuleObj);

    Local<Script> script = LoadScript(isolate, modulePath);

    TryCatch tc(isolate);
    Local<v8::Function> moduleFunc = script->Run(context).ToLocalChecked().As<v8::Function>();
    if (tc.HasCaught()) {
        tns::LogError(isolate, tc);
        assert(false);
    }

    std::string parentDir = [[[NSString stringWithUTF8String:modulePath.c_str()] stringByDeletingLastPathComponent] UTF8String];
    Local<v8::Function> require = GetRequireFunction(isolate, parentDir);
    Local<Value> requireArgs[5] {
        moduleObj, exportsObj, require, tns::ToV8String(isolate, modulePath.c_str()), tns::ToV8String(isolate, parentDir.c_str())
    };

    success = moduleObj->Set(context, tns::ToV8String(isolate, "require"), require).FromMaybe(false);
    assert(success);

    Local<Object> thiz = Object::New(isolate);
    Local<Value> result;
    if (!moduleFunc->Call(context, thiz, sizeof(requireArgs) / sizeof(Local<Value>), requireArgs).ToLocal(&result)) {
        if (tc.HasCaught()) {
            tns::LogError(isolate, tc);
        }
        assert(false);
    }

    tempModule.SaveToCache();
    return moduleObj;
}

Local<Object> ModuleInternal::LoadData(Isolate* isolate, const std::string& modulePath) {
    Local<Object> json;

    std::string jsonData = tns::ReadText(modulePath);

    TryCatch tc(isolate);

    Local<v8::String> jsonStr = tns::ToV8String(isolate, jsonData);

    Local<Context> context = isolate->GetCurrentContext();
    MaybeLocal<Value> maybeValue = JSON::Parse(context, jsonStr);

    if (maybeValue.IsEmpty() || tc.HasCaught()) {
        std::string errMsg = "Cannot parse JSON file " + modulePath;
        // TODO: throw exception
        assert(false);
    }

    Local<Value> value = maybeValue.ToLocalChecked();

    if (!value->IsObject()) {
        std::string errMsg = "JSON is not valid, file=" + modulePath;
        // TODO: throw exception
        assert(false);
    }

    json = value.As<Object>();

    Persistent<Object>* poJson = new Persistent<Object>(isolate, json);
    this->loadedModules_.insert(std::make_pair(modulePath, poJson));

    return json;
}

Local<Script> ModuleInternal::LoadScript(Isolate* isolate, const std::string& path) {
    Local<Context> context = isolate->GetCurrentContext();
    std::string fullRequiredModulePathWithSchema = "file://" + path;
    ScriptOrigin origin(tns::ToV8String(isolate, fullRequiredModulePathWithSchema));
    Local<v8::String> scriptText = WrapModuleContent(isolate, path);
    ScriptCompiler::CachedData* cacheData = LoadScriptCache(path);
    ScriptCompiler::Source source(scriptText, origin, cacheData);

    ScriptCompiler::CompileOptions options = ScriptCompiler::kNoCompileOptions;

    TryCatch tc(isolate);
    Local<Script> script;

    if (cacheData != nullptr) {
        options = ScriptCompiler::kConsumeCodeCache;
    }

    bool success = ScriptCompiler::Compile(context, &source, options).ToLocal(&script);
    if (!success || tc.HasCaught()) {
        if (tc.HasCaught()) {
            tns::LogError(isolate, tc);
        }
        assert(false);
    }

    if (cacheData == nullptr) {
        SaveScriptCache(script, path);
    }

    return script;
}

Local<v8::String> ModuleInternal::WrapModuleContent(Isolate* isolate, const std::string& path) {
    std::string content = tns::ReadText(path);
    std::string result("(function(module, exports, require, __filename, __dirname) { ");
    result.reserve(content.length() + 1024);
    result += content;
    result += "\n})";
    return tns::ToV8String(isolate, result);
}

std::string ModuleInternal::ResolvePath(Isolate* isolate, const std::string& baseDir, const std::string& moduleName) {
    NSString* baseDirStr = [NSString stringWithUTF8String:baseDir.c_str()];
    NSString* moduleNameStr = [NSString stringWithUTF8String:moduleName.c_str()];
    NSString* fullPath = [[baseDirStr stringByAppendingPathComponent:moduleNameStr] stringByStandardizingPath];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    BOOL exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];

    if (exists == YES && isDirectory == YES) {
        NSString* jsFile = [fullPath stringByAppendingPathExtension:@"js"];
        BOOL isDir;
        if ([fileManager fileExistsAtPath:jsFile isDirectory:&isDir] && isDir == NO) {
            return [jsFile UTF8String];
        }
    }

    if (exists == NO) {
        fullPath = [fullPath stringByAppendingPathExtension:@"js"];
        exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    }

    if (exists == NO) {
        tns::ThrowError(isolate, "The specified module does not exist: " + moduleName);
        return std::string();
    }

    if (isDirectory == NO) {
        return [fullPath UTF8String];
    }

    // Try to resolve module from main entry in package.json
    NSString* packageJson = [fullPath stringByAppendingPathComponent:@"package.json"];
    bool error = false;
    std::string entry = this->ResolvePathFromPackageJson([packageJson UTF8String], error);
    if (error) {
        tns::ThrowError(isolate, "Unable to locate main entry in " + std::string([packageJson UTF8String]));
        return std::string();
    }

    if (!entry.empty()) {
        fullPath = [NSString stringWithUTF8String:entry.c_str()];
    }

    exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    if (exists == YES && isDirectory == NO) {
        return [fullPath UTF8String];
    }

    if (exists == NO) {
        fullPath = [fullPath stringByAppendingPathExtension:@"js"];
    } else {
        fullPath = [fullPath stringByAppendingPathComponent:@"index.js"];
    }

    exists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
    if (exists == NO) {
        tns::ThrowError(isolate, "The specified module does not exist: " + moduleName);
        return std::string();
    }


    return [fullPath UTF8String];
}

std::string ModuleInternal::ResolvePathFromPackageJson(const std::string& packageJson, bool& error) {
    NSString* packageJsonStr = [NSString stringWithUTF8String:packageJson.c_str()];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    BOOL exists = [fileManager fileExistsAtPath:packageJsonStr isDirectory:&isDirectory];
    if (exists == NO || isDirectory == YES) {
        return std::string();
    }

    NSData *data = [NSData dataWithContentsOfFile:packageJsonStr];
    if (data == nil) {
        return std::string();
    }

    NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    if (dic == nil) {
        error = true;
        return std::string();
    }

    NSString *main = [dic objectForKey:@"main"];
    if (main == nil) {
        return std::string();
    }

    NSString* path = [[[packageJsonStr stringByDeletingLastPathComponent] stringByAppendingPathComponent:main] stringByStandardizingPath];
    exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];

    if (exists == YES && isDirectory == YES) {
        packageJsonStr = [path stringByAppendingPathComponent:@"package.json"];
        exists = [fileManager fileExistsAtPath:packageJsonStr isDirectory:&isDirectory];
        if (exists == YES && isDirectory == NO) {
            return this->ResolvePathFromPackageJson([packageJsonStr UTF8String], error);
        }
    }

    return [path UTF8String];
}

ScriptCompiler::CachedData* ModuleInternal::LoadScriptCache(const std::string& path) {
    if (!USE_CODE_CACHE) {
        return nullptr;
    }

    long length = 0;
    std::string cachePath = GetCacheFileName(path + ".cache");

    struct stat result;
    if (stat(cachePath.c_str(), &result) == 0) {
        auto cacheLastModifiedTime = result.st_mtime;
        if (stat(path.c_str(), &result) == 0) {
            auto jsLastModifiedTime = result.st_mtime;
            if (jsLastModifiedTime > 0 && cacheLastModifiedTime > 0 && jsLastModifiedTime > cacheLastModifiedTime) {
                // The javascript file is more recent than the cache file => ignore the cache
                return nullptr;
            }
        }
    }

    uint8_t* data = tns::ReadBinary(cachePath, length);
    if (!data) {
        return nullptr;
    }

    return new ScriptCompiler::CachedData(data, (int)length, ScriptCompiler::CachedData::BufferOwned);
}

void ModuleInternal::SaveScriptCache(const Local<Script> script, const std::string& path) {
    if (!USE_CODE_CACHE) {
        return;
    }

    Local<UnboundScript> unboundScript = script->GetUnboundScript();
    ScriptCompiler::CachedData* cachedData = ScriptCompiler::CreateCodeCache(unboundScript);

    int length = cachedData->length;
    std::string cachePath = GetCacheFileName(path + ".cache");
    tns::WriteBinary(cachePath, cachedData->data, length);
}

std::string ModuleInternal::GetCacheFileName(const std::string& path) {
    std::string key = path.substr(RuntimeConfig.ApplicationPath.size() + 1);
    std::replace(key.begin(), key.end(), '/', '-');

    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachesPath = [paths objectAtIndex:0];
    NSString* result = [cachesPath stringByAppendingPathComponent:[NSString stringWithUTF8String:key.c_str()]];

    return [result UTF8String];
}

}
