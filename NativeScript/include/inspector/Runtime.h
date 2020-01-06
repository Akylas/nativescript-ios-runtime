// This file is generated by Exported_h.template.

// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef v8_inspector_protocol_Runtime_api_h
#define v8_inspector_protocol_Runtime_api_h

#include "v8-inspector.h"

namespace v8_inspector {
namespace protocol {

#ifndef v8_inspector_protocol_exported_api_h
#define v8_inspector_protocol_exported_api_h
class V8_EXPORT Exported {
public:
    virtual std::unique_ptr<StringBuffer> toJSONString() const = 0;

    V8_DEPRECATE_SOON("Use AppendSerialized instead.")
    virtual void writeBinary(std::vector<uint8_t>* out) const = 0;

    virtual void AppendSerialized(std::vector<uint8_t>* out) const = 0;

    virtual ~Exported() { }
};
#endif // !defined(v8_inspector_protocol_exported_api_h)

namespace Runtime {
namespace API {

// ------------- Enums.

// ------------- Types.

class V8_EXPORT RemoteObject : public Exported {
public:
    static std::unique_ptr<protocol::Runtime::API::RemoteObject> fromJSONString(const StringView& json);
    static std::unique_ptr<protocol::Runtime::API::RemoteObject> fromBinary(const uint8_t* data, size_t length);
};

class V8_EXPORT StackTrace : public Exported {
public:
    static std::unique_ptr<protocol::Runtime::API::StackTrace> fromJSONString(const StringView& json);
    static std::unique_ptr<protocol::Runtime::API::StackTrace> fromBinary(const uint8_t* data, size_t length);
};

class V8_EXPORT StackTraceId : public Exported {
public:
    static std::unique_ptr<protocol::Runtime::API::StackTraceId> fromJSONString(const StringView& json);
    static std::unique_ptr<protocol::Runtime::API::StackTraceId> fromBinary(const uint8_t* data, size_t length);
};

} // namespace API
} // namespace Runtime
} // namespace v8_inspector
} // namespace protocol

#endif // !defined(v8_inspector_protocol_Runtime_api_h)
