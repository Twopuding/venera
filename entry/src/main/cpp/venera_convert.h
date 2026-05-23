#pragma once

#include <string>

/** 将 init.js convert 消息 JSON 转为响应 JSON（同步，供 QuickJS sendMessage） */
std::string venera_convert_message_json(const std::string &requestJson);
