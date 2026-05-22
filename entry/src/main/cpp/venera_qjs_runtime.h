#pragma once

#include <string>

struct VeneraQjsRuntime;

VeneraQjsRuntime *venera_qjs_create();
void venera_qjs_destroy(VeneraQjsRuntime *rt);

bool venera_qjs_init(VeneraQjsRuntime *rt, const std::string &initJs, const std::string &appVersion);
bool venera_qjs_register_handler(VeneraQjsRuntime *rt, void *env, void *handlerRef);
bool venera_qjs_load_source(VeneraQjsRuntime *rt, const std::string &sourceKey, const std::string &script);
std::string venera_qjs_eval_json(VeneraQjsRuntime *rt, const std::string &script, const char *filename);
void venera_qjs_reset_sources(VeneraQjsRuntime *rt);
