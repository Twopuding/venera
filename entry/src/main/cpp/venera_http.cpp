#include "venera_http.h"

#include <cctype>
#include <cstdlib>
#include <sstream>
#include <string>

#if defined(__OHOS__)
#include "RemoteCommunicationKit/rcp.h"
#endif

namespace {

std::string json_escape(const std::string &s)
{
    std::ostringstream out;
    for (char c : s) {
        if (c == '"') {
            out << "\\\"";
        } else if (c == '\\') {
            out << "\\\\";
        } else if (c == '\n') {
            out << "\\n";
        } else if (c == '\r') {
            out << "\\r";
        } else if (c == '\t') {
            out << "\\t";
        } else if (static_cast<unsigned char>(c) < 0x20) {
            out << ' ';
        } else {
            out << c;
        }
    }
    return out.str();
}

std::string extract_field_string(const std::string &json, const char *field)
{
    std::string token = std::string("\"") + field + "\"";
    size_t pos = json.find(token);
    if (pos == std::string::npos) {
        return "";
    }
    pos = json.find(':', pos);
    if (pos == std::string::npos) {
        return "";
    }
    pos = json.find('"', pos);
    if (pos == std::string::npos) {
        return "";
    }
    size_t end = json.find('"', pos + 1);
    if (end == std::string::npos) {
        return "";
    }
    return json.substr(pos + 1, end - pos - 1);
}

#if defined(__OHOS__)

Rcp_Session *g_rcp_session = nullptr;

Rcp_Session *ensure_rcp_session()
{
    if (g_rcp_session != nullptr) {
        return g_rcp_session;
    }
    uint32_t err = 0;
    g_rcp_session = HMS_Rcp_CreateSession(nullptr, &err);
    return g_rcp_session;
}

#endif

} // namespace

HttpNativeResult venera_http_request(
    const std::string &method,
    const std::string &url,
    const std::string &headersJson,
    const std::string &body,
    bool wantBytes)
{
    HttpNativeResult result;
    (void)headersJson;
    (void)wantBytes;

#if defined(__OHOS__)
    Rcp_Session *session = ensure_rcp_session();
    if (session == nullptr) {
        result.error = "rcp session create failed";
        return result;
    }
    Rcp_Request *request = HMS_Rcp_CreateRequest(url.c_str());
    if (request == nullptr) {
        result.error = "rcp request create failed";
        return result;
    }
    std::string upper = method;
    for (char &c : upper) {
        c = static_cast<char>(toupper(static_cast<unsigned char>(c)));
    }
    if (upper == "POST") {
        request->method = RCP_METHOD_POST;
    } else if (upper == "PUT") {
        request->method = RCP_METHOD_PUT;
    } else if (upper == "DELETE") {
        request->method = RCP_METHOD_DELETE;
    } else if (upper == "HEAD") {
        request->method = RCP_METHOD_HEAD;
    } else {
        request->method = RCP_METHOD_GET;
    }
    if (!body.empty()) {
        auto *content = new Rcp_RequestContent();
        content->type = RCP_CONTENT_TYPE_STRING;
        content->data.contentStr.buffer = body.c_str();
        content->data.contentStr.length = static_cast<uint32_t>(body.size());
        request->content = content;
    }
    request->headers = HMS_Rcp_CreateHeaders();
    if (request->headers != nullptr) {
        HMS_Rcp_SetHeaderValue(request->headers, "User-Agent", "Venera-HarmonyOS/1.0");
        HMS_Rcp_SetHeaderValue(request->headers, "Accept", "*/*");
    }
    uint32_t err = 0;
    Rcp_Response *response = HMS_Rcp_FetchSync(session, request, &err);
    HMS_Rcp_DestroyRequest(request);
    if (response == nullptr || err != 0) {
        result.error = "rcp fetch failed: " + std::to_string(err);
        return result;
    }
    result.status = static_cast<int>(response->statusCode);
    if (response->body.buffer != nullptr && response->body.length > 0) {
        result.body.assign(response->body.buffer, response->body.length);
    }
    if (response->destroyResponse != nullptr) {
        response->destroyResponse(response);
    }
    return result;
#else
    (void)method;
    (void)url;
    result.error = "http only available on OHOS device build";
    return result;
#endif
}

std::string venera_http_message_json(const std::string &requestJson)
{
    std::string method = extract_field_string(requestJson, "http_method");
    if (method.empty()) {
        method = "GET";
    }
    std::string url = extract_field_string(requestJson, "url");
    std::string body = extract_field_string(requestJson, "data_body");
    HttpNativeResult res = venera_http_request(method, url, "{}", body, false);
    if (!res.error.empty()) {
        return std::string("{\"status\":0,\"headers\":{},\"error\":\"") + json_escape(res.error) + "\"}";
    }
    return std::string("{\"status\":") + std::to_string(res.status) + ",\"headers\":{},\"body\":\"" +
        json_escape(res.body) + "\"}";
}
