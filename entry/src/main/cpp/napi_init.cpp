#include "venera_qjs_runtime.h"

#include <string>

#include "napi/native_api.h"

namespace {

VeneraQjsRuntime *g_runtime = nullptr;

napi_value ensure_runtime()
{
    if (g_runtime == nullptr) {
        g_runtime = venera_qjs_create();
    }
    return nullptr;
}

std::string napi_get_string(napi_env env, napi_value value)
{
    size_t len = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::string out(len, '\0');
    if (len > 0) {
        napi_get_value_string_utf8(env, value, &out[0], len + 1, &len);
    }
    return out;
}

napi_value NapiInitRuntime(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    ensure_runtime();
    std::string initJs = napi_get_string(env, args[0]);
    std::string appVersion = argc > 1 ? napi_get_string(env, args[1]) : "1.0.0";
    bool ok = venera_qjs_init(g_runtime, initJs, appVersion);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value NapiRegisterHandler(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (g_runtime == nullptr) {
        napi_value f;
        napi_get_boolean(env, false, &f);
        return f;
    }
    napi_ref ref;
    napi_create_reference(env, args[0], 1, &ref);
    bool ok = venera_qjs_register_handler(g_runtime, env, ref);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value NapiLoadSource(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (g_runtime == nullptr) {
        napi_value f;
        napi_get_boolean(env, false, &f);
        return f;
    }
    std::string key = napi_get_string(env, args[0]);
    std::string script = napi_get_string(env, args[1]);
    bool ok = venera_qjs_load_source(g_runtime, key, script);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value NapiEvaluate(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (g_runtime == nullptr) {
        napi_value s;
        napi_create_string_utf8(env, "null", NAPI_AUTO_LENGTH, &s);
        return s;
    }
    std::string script = napi_get_string(env, args[0]);
    std::string json = venera_qjs_eval_json(g_runtime, script, "<eval>");
    napi_value result;
    napi_create_string_utf8(env, json.c_str(), json.size(), &result);
    return result;
}

napi_value NapiResetSources(napi_env env, napi_callback_info /*info*/)
{
    if (g_runtime != nullptr) {
        venera_qjs_reset_sources(g_runtime);
    }
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

napi_value NapiIsAvailable(napi_env env, napi_callback_info /*info*/)
{
    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"initRuntime", nullptr, NapiInitRuntime, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"registerMessageHandler", nullptr, NapiRegisterHandler, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"loadSource", nullptr, NapiLoadSource, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"evaluate", nullptr, NapiEvaluate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resetSources", nullptr, NapiResetSources, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isAvailable", nullptr, NapiIsAvailable, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

} // namespace

extern "C" __attribute__((constructor)) void RegisterVeneraQjsModule(void)
{
    static napi_module module = {
        .nm_version = 1,
        .nm_flags = 0,
        .nm_filename = nullptr,
        .nm_register_func = Init,
        .nm_modname = "venera_qjs",
        .nm_priv = nullptr,
        .reserved = {0},
    };
    napi_module_register(&module);
}
