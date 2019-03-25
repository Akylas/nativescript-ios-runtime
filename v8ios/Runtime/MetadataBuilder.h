#ifndef MetadataBuilder_h
#define MetadataBuilder_h

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#include "v8.h"
#pragma clang diagnostic pop

#include <map>
#include "Metadata.h"
#include "ObjectManager.h"
#include "ArgConverter.h"
#include "ClassBuilder.h"

namespace tns {

class MetadataBuilder {
public:
    MetadataBuilder();
    void Init(v8::Isolate* isolate);
    static MetadataBuilder* Load(const std::string& baseDir) {
        static MetadataBuilder *b = new MetadataBuilder(baseDir);
        return b;
    }

private:
    v8::Isolate* isolate_;
    ObjectManager objectManager_;
    ArgConverter argConverter_;
    ClassBuilder classBuilder_;

    static void ClassConstructorCallback(const v8::FunctionCallbackInfo<v8::Value>& info);
    static void AllocCallback(const v8::FunctionCallbackInfo<v8::Value>& info);
    static void MethodCallback(const v8::FunctionCallbackInfo<v8::Value>& info);
    static void CFunctionCallback(const v8::FunctionCallbackInfo<v8::Value>& info);
    static void PropertyGetterCallback(v8::Local<v8::String> name, const v8::PropertyCallbackInfo<v8::Value>& info);
    static void PropertySetterCallback(v8::Local<v8::String> name, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void>& info);
    static void PropertyNameGetterCallback(v8::Local<v8::Name> name, const v8::PropertyCallbackInfo<v8::Value> &info);
    static void PropertyNameSetterCallback(v8::Local<v8::Name> name, v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<void> &info);
    v8::Local<v8::Value> InvokeMethod(v8::Isolate* isolate, const MethodMeta* meta, v8::Local<v8::Object> receiver, const std::vector<v8::Local<v8::Value>> args, std::string containingClass);

    v8::Local<v8::FunctionTemplate> GetOrCreateConstructorFunctionTemplate(const InterfaceMeta* interfaceMeta);
    v8::Local<v8::Function> CreateEmptyObjectFunction(v8::Isolate* isolate);
    void RegisterCFunction(const FunctionMeta* funcMeta);
    void RegisterAllocMethod(v8::Local<v8::Function> ctorFunc, const InterfaceMeta* interfaceMeta);
    void RegisterInstanceMethods(v8::Local<v8::FunctionTemplate> ctorFuncTemplate, const BaseClassMeta* meta);
    void RegisterInstanceProperties(v8::Local<v8::FunctionTemplate> ctorFuncTemplate, const BaseClassMeta* meta);
    void RegisterInstanceProtocols(v8::Local<v8::FunctionTemplate> ctorFuncTemplate, const BaseClassMeta* meta);
    void RegisterStaticMethods(v8::Local<v8::Function> ctorFunc, const BaseClassMeta* meta);
    void RegisterStaticProperties(v8::Local<v8::Function> ctorFunc, const BaseClassMeta* meta);
    void RegisterStaticProtocols(v8::Local<v8::Function> ctorFunc, const BaseClassMeta* meta);

    MetadataBuilder(const std::string& baseDir) {
        std::string fileName = baseDir + "/metadata-x86_64.bin";
        std::string mode = "rb";
        auto file = fopen(fileName.c_str(), mode.c_str());
        if (!file) {
            assert(false);
        }

        fseek(file, 0, SEEK_END);
        long length = ftell(file);
        rewind(file);

        uint8_t* data = new uint8_t[length];
        fread(data, sizeof(uint8_t), length, file);
        fclose(file);

        MetaFile::setInstance(data);
    }

    template<class T>
    struct CacheItem {
        CacheItem(const T* meta, const BaseClassMeta* classMeta, MetadataBuilder* builder)
        : meta_(meta), classMeta_(classMeta), builder_(builder) {
            static_assert(std::is_base_of<Meta, T>::value, "Derived not derived from Meta");
        }
        const T* meta_;
        const BaseClassMeta* classMeta_;
        MetadataBuilder* builder_;
    };
};

}

#endif /* MetadataBuilder_h */
