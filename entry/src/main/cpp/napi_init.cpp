#include "venera_qjs_runtime.h"
#include "venera_archive.h"

#include <string>
#include <thread>

#include "napi/native_api.h"

namespace {

VeneraQjsRuntime *g_runtime = nullptr;
napi_threadsafe_function g_load_resolve_tsfn = nullptr;
napi_threadsafe_function g_eval_resolve_tsfn = nullptr;
struct LoadSourceWork {
    napi_deferred deferred = nullptr;
    std::string key;
    std::string script;
    bool ok = false;
};

void load_resolve_tsfn_callback(napi_env env, napi_value /*js_callback*/, void * /*context*/, void *data)
{
    LoadSourceWork *work = static_cast<LoadSourceWork *>(data);
    if (work == nullptr || work->deferred == nullptr) {
        delete work;
        return;
    }
    napi_value result;
    napi_get_boolean(env, work->ok, &result);
    napi_resolve_deferred(env, work->deferred, result);
    delete work;
}

struct EvalWork {
    napi_deferred deferred = nullptr;
    std::string script;
    std::string resultJson;
};

void eval_resolve_tsfn_callback(napi_env env, napi_value /*js_callback*/, void * /*context*/, void *data)
{
    EvalWork *work = static_cast<EvalWork *>(data);
    if (work == nullptr || work->deferred == nullptr) {
        delete work;
        return;
    }
    napi_value result;
    napi_create_string_utf8(env, work->resultJson.c_str(), work->resultJson.size(), &result);
    napi_resolve_deferred(env, work->deferred, result);
    delete work;
}

void ensure_load_resolve_tsfn(napi_env env)
{
    if (g_load_resolve_tsfn != nullptr) {
        return;
    }
    napi_value resourceName;
    napi_create_string_utf8(env, "VeneraLoadResolve", NAPI_AUTO_LENGTH, &resourceName);
    napi_create_threadsafe_function(env, nullptr, nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr,
        load_resolve_tsfn_callback, &g_load_resolve_tsfn);
}

void ensure_eval_resolve_tsfn(napi_env env)
{
    if (g_eval_resolve_tsfn != nullptr) {
        return;
    }
    napi_value resourceName;
    napi_create_string_utf8(env, "VeneraEvalResolve", NAPI_AUTO_LENGTH, &resourceName);
    napi_create_threadsafe_function(env, nullptr, nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr,
        eval_resolve_tsfn_callback, &g_eval_resolve_tsfn);
}

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

/** 创建 QuickJS 运行时与 global（不含 init.js），须在 registerMessageHandler 之前调用 */
napi_value NapiPrepareRuntime(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    ensure_runtime();
    std::string appVersion = argc > 0 ? napi_get_string(env, args[0]) : "1.0.0";
    bool ok = venera_qjs_prepare(g_runtime, appVersion);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

/**
 * 在主线程执行 init.js（须已 prepareRuntime + registerMessageHandler）。
 * init.js 内 sendMessage 依赖 ArkTS 回调，不可在 worker 中先于 handler 注册执行。
 */
napi_value NapiRunInitScript(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::string initJs = argc > 0 ? napi_get_string(env, args[0]) : "";
    bool ok = false;
    if (g_runtime != nullptr && venera_qjs_is_handler_ready(g_runtime)) {
        ok = venera_qjs_run_init_script(g_runtime, initJs);
    }
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
    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);
    if (g_runtime == nullptr) {
        napi_value f;
        napi_get_boolean(env, false, &f);
        napi_resolve_deferred(env, deferred, f);
        return promise;
    }
    ensure_load_resolve_tsfn(env);
    if (g_load_resolve_tsfn == nullptr) {
        napi_value f;
        napi_get_boolean(env, false, &f);
        napi_resolve_deferred(env, deferred, f);
        return promise;
    }
    LoadSourceWork *work = new LoadSourceWork();
    work->deferred = deferred;
    work->key = napi_get_string(env, args[0]);
    work->script = napi_get_string(env, args[1]);
    std::thread([work]() {
        work->ok = venera_qjs_load_source(g_runtime, work->key, work->script);
        napi_call_threadsafe_function(g_load_resolve_tsfn, work, napi_tsfn_blocking);
    }).detach();
    return promise;
}

napi_value NapiEvaluate(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);
    if (g_runtime == nullptr) {
        napi_value s;
        napi_create_string_utf8(env, "null", NAPI_AUTO_LENGTH, &s);
        napi_resolve_deferred(env, deferred, s);
        return promise;
    }
    ensure_eval_resolve_tsfn(env);
    if (g_eval_resolve_tsfn == nullptr) {
        napi_value s;
        napi_create_string_utf8(env, "null", NAPI_AUTO_LENGTH, &s);
        napi_resolve_deferred(env, deferred, s);
        return promise;
    }
    EvalWork *work = new EvalWork();
    work->deferred = deferred;
    work->script = napi_get_string(env, args[0]);
    std::thread([work]() {
        work->resultJson = venera_qjs_eval_json(g_runtime, work->script, "<eval>");
        napi_call_threadsafe_function(g_eval_resolve_tsfn, work, napi_tsfn_blocking);
    }).detach();
    return promise;
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

napi_value NapiExtract7z(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::string archivePath = argc > 0 ? napi_get_string(env, args[0]) : "";
    std::string outDir = argc > 1 ? napi_get_string(env, args[1]) : "";
    std::string err;
    bool ok = venera_extract_7z(archivePath, outDir, err);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"prepareRuntime", nullptr, NapiPrepareRuntime, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"runInitScript", nullptr, NapiRunInitScript, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"registerMessageHandler", nullptr, NapiRegisterHandler, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"loadSource", nullptr, NapiLoadSource, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"evaluate", nullptr, NapiEvaluate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resetSources", nullptr, NapiResetSources, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"isAvailable", nullptr, NapiIsAvailable, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"extract7z", nullptr, NapiExtract7z, nullptr, nullptr, nullptr, napi_default, nullptr},
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
