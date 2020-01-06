// This file is generated by TypeBuilder_cpp.template.

// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "src/inspector/protocol/Schema.h"

#include "src/inspector/protocol/Protocol.h"

#include "third_party/inspector_protocol/crdtp/cbor.h"
#include "third_party/inspector_protocol/crdtp/serializer_traits.h"

namespace v8_inspector {
namespace protocol {
namespace Schema {

// ------------- Enum values from types.

const char Metainfo::domainName[] = "Schema";
const char Metainfo::commandPrefix[] = "Schema.";
const char Metainfo::version[] = "1.3";

std::unique_ptr<Domain> Domain::fromValue(protocol::Value* value, ErrorSupport* errors)
{
    if (!value || value->type() != protocol::Value::TypeObject) {
        errors->addError("object expected");
        return nullptr;
    }

    std::unique_ptr<Domain> result(new Domain());
    protocol::DictionaryValue* object = DictionaryValue::cast(value);
    errors->push();
    protocol::Value* nameValue = object->get("name");
    errors->setName("name");
    result->m_name = ValueConversions<String>::fromValue(nameValue, errors);
    protocol::Value* versionValue = object->get("version");
    errors->setName("version");
    result->m_version = ValueConversions<String>::fromValue(versionValue, errors);
    errors->pop();
    if (errors->hasErrors())
        return nullptr;
    return result;
}

std::unique_ptr<protocol::DictionaryValue> Domain::toValue() const
{
    std::unique_ptr<protocol::DictionaryValue> result = DictionaryValue::create();
    result->setValue("name", ValueConversions<String>::toValue(m_name));
    result->setValue("version", ValueConversions<String>::toValue(m_version));
    return result;
}

void Domain::AppendSerialized(std::vector<uint8_t>* out) const {
    v8_crdtp::cbor::EnvelopeEncoder envelope_encoder;
    envelope_encoder.EncodeStart(out);
    out->push_back(v8_crdtp::cbor::EncodeIndefiniteLengthMapStart());
      v8_crdtp::SerializeField(v8_crdtp::SpanFrom("name"), m_name, out);
      v8_crdtp::SerializeField(v8_crdtp::SpanFrom("version"), m_version, out);
    out->push_back(v8_crdtp::cbor::EncodeStop());
    envelope_encoder.EncodeStop(out);
}

std::unique_ptr<Domain> Domain::clone() const
{
    ErrorSupport errors;
    return fromValue(toValue().get(), &errors);
}

std::unique_ptr<StringBuffer> Domain::toJSONString() const
{
    String json = toValue()->toJSONString();
    return StringBufferImpl::adopt(json);
}

void Domain::writeBinary(std::vector<uint8_t>* out) const
{
    AppendSerialized(out);
}

// static
std::unique_ptr<API::Domain> API::Domain::fromJSONString(const StringView& json)
{
    ErrorSupport errors;
    std::unique_ptr<Value> value = StringUtil::parseJSON(json);
    if (!value)
        return nullptr;
    return protocol::Schema::Domain::fromValue(value.get(), &errors);
}

// static
std::unique_ptr<API::Domain> API::Domain::fromBinary(const uint8_t* data, size_t length)
{
    ErrorSupport errors;
    std::unique_ptr<Value> value = Value::parseBinary(data, length);
    if (!value)
        return nullptr;
    return protocol::Schema::Domain::fromValue(value.get(), &errors);
}


// ------------- Enum values from params.


// ------------- Frontend notifications.

void Frontend::flush()
{
    m_frontendChannel->flushProtocolNotifications();
}

void Frontend::sendRawCBORNotification(std::vector<uint8_t> notification)
{
    m_frontendChannel->sendProtocolNotification(InternalRawNotification::fromBinary(std::move(notification)));
}

// --------------------- Dispatcher.

class DispatcherImpl : public protocol::DispatcherBase {
public:
    DispatcherImpl(FrontendChannel* frontendChannel, Backend* backend)
        : DispatcherBase(frontendChannel)
        , m_backend(backend) {
        m_dispatchMap["Schema.getDomains"] = &DispatcherImpl::getDomains;
    }
    ~DispatcherImpl() override { }
    bool canDispatch(const String& method) override;
    void dispatch(int callId, const String& method, v8_crdtp::span<uint8_t> message, std::unique_ptr<protocol::DictionaryValue> messageObject) override;
    std::unordered_map<String, String>& redirects() { return m_redirects; }

protected:
    using CallHandler = void (DispatcherImpl::*)(int callId, const String& method, v8_crdtp::span<uint8_t> message, std::unique_ptr<DictionaryValue> messageObject, ErrorSupport* errors);
    using DispatchMap = std::unordered_map<String, CallHandler>;
    DispatchMap m_dispatchMap;
    std::unordered_map<String, String> m_redirects;

    void getDomains(int callId, const String& method, v8_crdtp::span<uint8_t> message, std::unique_ptr<DictionaryValue> requestMessageObject, ErrorSupport*);

    Backend* m_backend;
};

bool DispatcherImpl::canDispatch(const String& method) {
    return m_dispatchMap.find(method) != m_dispatchMap.end();
}

void DispatcherImpl::dispatch(int callId, const String& method, v8_crdtp::span<uint8_t> message, std::unique_ptr<protocol::DictionaryValue> messageObject)
{
    std::unordered_map<String, CallHandler>::iterator it = m_dispatchMap.find(method);
    DCHECK(it != m_dispatchMap.end());
    protocol::ErrorSupport errors;
    (this->*(it->second))(callId, method, message, std::move(messageObject), &errors);
}


void DispatcherImpl::getDomains(int callId, const String& method, v8_crdtp::span<uint8_t> message, std::unique_ptr<DictionaryValue> requestMessageObject, ErrorSupport* errors)
{
    // Declare output parameters.
    std::unique_ptr<protocol::Array<protocol::Schema::Domain>> out_domains;

    std::unique_ptr<DispatcherBase::WeakPtr> weak = weakPtr();
    DispatchResponse response = m_backend->getDomains(&out_domains);
    if (response.status() == DispatchResponse::kFallThrough) {
        channel()->fallThrough(callId, method, message);
        return;
    }
    std::unique_ptr<protocol::DictionaryValue> result = DictionaryValue::create();
    if (response.status() == DispatchResponse::kSuccess) {
        result->setValue("domains", ValueConversions<protocol::Array<protocol::Schema::Domain>>::toValue(out_domains.get()));
    }
    if (weak->get())
        weak->get()->sendResponse(callId, response, std::move(result));
    return;
}

// static
void Dispatcher::wire(UberDispatcher* uber, Backend* backend)
{
    std::unique_ptr<DispatcherImpl> dispatcher(new DispatcherImpl(uber->channel(), backend));
    uber->setupRedirects(dispatcher->redirects());
    uber->registerBackend("Schema", std::move(dispatcher));
}

} // Schema
} // namespace v8_inspector
} // namespace protocol
