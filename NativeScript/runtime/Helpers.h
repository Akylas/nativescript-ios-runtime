#ifndef Helpers_h
#define Helpers_h

#include <functional>
#include <string>
#include "Common.h"
#include "DataWrapper.h"

namespace tns {

v8::Local<v8::String> ToV8String(v8::Isolate* isolate, std::string value);
std::string ToString(v8::Isolate* isolate, const v8::Local<v8::Value>& value);
double ToNumber(v8::Isolate* isolate, const v8::Local<v8::Value>& value);
bool ToBool(const v8::Local<v8::Value>& value);
std::vector<uint16_t> ToVector(const std::string& value);

std::string ReadText(const std::string& file);
uint8_t* ReadBinary(const std::string path, long& length);
bool WriteBinary(const std::string& path, const void* data, long length);

void SetPrivateValue(const v8::Local<v8::Object>& obj, const v8::Local<v8::String>& propName, const v8::Local<v8::Value>& value);
v8::Local<v8::Value> GetPrivateValue(const v8::Local<v8::Object>& obj, const v8::Local<v8::String>& propName);

void SetValue(v8::Isolate* isolate, const v8::Local<v8::Object>& obj, BaseDataWrapper* value);
BaseDataWrapper* GetValue(v8::Isolate* isolate, const v8::Local<v8::Value>& val);
std::vector<v8::Local<v8::Value>> ArgsToVector(const v8::FunctionCallbackInfo<v8::Value>& info);
void ThrowError(v8::Isolate* isolate, std::string message);

bool IsString(v8::Local<v8::Value> value);
bool IsNumber(v8::Local<v8::Value> value);
bool IsBool(v8::Local<v8::Value> value);

void ExecuteOnMainThread(std::function<void ()> func, bool async = true);

void LogError(v8::Isolate* isolate, v8::TryCatch& tc);
void LogBacktrace(int skip = 1);
void Log(const char* format, ...);

v8::Local<v8::String> JsonStringifyObject(v8::Isolate* isolate, v8::Local<v8::Value> value, bool handleCircularReferences = false);
v8::Local<v8::Function> GetSmartJSONStringifyFunction(v8::Isolate* isolate);

std::string ReplaceAll(const std::string source, std::string find, std::string replacement);

}

#endif /* Helpers_h */
