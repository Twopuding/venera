#pragma once

#include <string>

struct HttpNativeResult {
    int status = 0;
    std::string body;
    std::string error;
};

HttpNativeResult venera_http_request(
    const std::string &method,
    const std::string &url,
    const std::string &headersJson,
    const std::string &body,
    bool wantBytes);

/** 将 init.js http 消息 JSON 转为响应 JSON */
std::string venera_http_message_json(const std::string &requestJson);
