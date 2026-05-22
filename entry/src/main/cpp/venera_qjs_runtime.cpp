#include "venera_qjs_runtime.h"

#include "venera_http.h"

#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#if !defined(_WIN32)
#include <unistd.h>
#endif

extern "C" {
#include "third_party/quickjs-ng-temp/quickjs.h"
}

#include "napi/native_api.h"

struct VeneraQjsRuntime {
    JSRuntime *jsRuntime = nullptr;
    JSContext *jsContext = nullptr;
    bool inited = false;
    napi_env env = nullptr;
    napi_ref handlerRef = nullptr;
    napi_threadsafe_function tsfn = nullptr;
};

namespace {

struct BridgeCall {
    std::string requestJson;
    std::string responseJson;
    std::mutex mu;
    std::condition_variable cv;
    bool done = false;
    bool ok = false;
};

static VeneraQjsRuntime *g_active = nullptr;

static std::string js_value_to_string(JSContext *ctx, JSValue val)
{
    if (JS_IsUndefined(val) || JS_IsNull(val)) {
        return "null";
    }
    JSValue json = JS_JSONStringify(ctx, val, JS_UNDEFINED, JS_UNDEFINED);
    if (JS_IsException(json)) {
        JSValue err = JS_GetException(ctx);
        const char *msg = JS_ToCString(ctx, err);
        std::string out = msg != nullptr ? std::string("{\"error\":\"") + msg + "\"}" : "{\"error\":\"stringify failed\"}";
        if (msg != nullptr) {
            JS_FreeCString(ctx, msg);
        }
        JS_FreeValue(ctx, err);
        return out;
    }
    const char *str = JS_ToCString(ctx, json);
    std::string out = str != nullptr ? str : "null";
    if (str != nullptr) {
        JS_FreeCString(ctx, str);
    }
    JS_FreeValue(ctx, json);
    return out;
}

static JSValue string_to_js_value(JSContext *ctx, const std::string &json)
{
    if (json.empty()) {
        return JS_NULL;
    }
    JSValue val = JS_ParseJSON(ctx, json.c_str(), json.size(), "<bridge>");
    if (JS_IsException(val)) {
        JSValue err = JS_GetException(ctx);
        JS_FreeValue(ctx, err);
        return JS_NULL;
    }
    return val;
}

static std::string extract_method(const std::string &json)
{
    const char *key = "\"method\"";
    size_t pos = json.find(key);
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

static std::string extract_field_string(const std::string &json, const char *field)
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

static void tsfn_callback(napi_env env, napi_value js_callback, void * /*context*/, void *data)
{
    BridgeCall *call = static_cast<BridgeCall *>(data);
    napi_value arg;
    napi_create_string_utf8(env, call->requestJson.c_str(), call->requestJson.size(), &arg);
    napi_value global;
    napi_get_global(env, &global);
    napi_value result;
    napi_status status = napi_call_function(env, global, js_callback, 1, &arg, &result);
    if (status != napi_ok) {
        call->responseJson = "null";
        call->ok = false;
    } else {
        napi_valuetype type;
        napi_typeof(env, result, &type);
        if (type == napi_string) {
            size_t len = 0;
            napi_get_value_string_utf8(env, result, nullptr, 0, &len);
            call->responseJson.resize(len);
            napi_get_value_string_utf8(env, result, &call->responseJson[0], len + 1, &len);
            call->ok = true;
        } else {
            call->responseJson = "null";
            call->ok = true;
        }
    }
    {
        std::lock_guard<std::mutex> lock(call->mu);
        call->done = true;
    }
    call->cv.notify_one();
}

static std::string call_arkts_handler(VeneraQjsRuntime *runtime, const std::string &requestJson)
{
    if (runtime->tsfn == nullptr) {
        return "null";
    }
    BridgeCall call;
    call.requestJson = requestJson;
    napi_call_threadsafe_function(runtime->tsfn, &call, napi_tsfn_blocking);
    std::unique_lock<std::mutex> lock(call.mu);
    call.cv.wait(lock, [&call]() { return call.done; });
    return call.responseJson;
}

static JSValue js_send_message(JSContext *ctx, JSValueConst /*this_val*/, int argc, JSValueConst *argv)
{
    if (argc < 1) {
        return JS_UNDEFINED;
    }
    std::string requestJson = js_value_to_string(ctx, argv[0]);
    std::string method = extract_method(requestJson);
    std::string responseJson;
    if (method == "http") {
        responseJson = venera_http_message_json(requestJson);
    } else if (method == "convert") {
        responseJson = call_arkts_handler(g_active, requestJson);
    } else if (method == "delay") {
        int ms = 0;
        size_t pos = requestJson.find("\"time\"");
        if (pos != std::string::npos) {
            pos = requestJson.find(':', pos);
            if (pos != std::string::npos) {
                ms = std::atoi(requestJson.c_str() + pos + 1);
            }
        }
        if (ms > 0) {
#if !defined(_WIN32)
            usleep(static_cast<useconds_t>(ms) * 1000);
#endif
        }
        return JS_NULL;
    } else {
        responseJson = call_arkts_handler(g_active, requestJson);
    }
    return string_to_js_value(ctx, responseJson);
}

static void install_globals(JSContext *ctx, const std::string &appVersion)
{
    JSValue global = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global, "sendMessage",
        JS_NewCFunction(ctx, js_send_message, "sendMessage", 1));
    JS_SetPropertyStr(ctx, global, "appVersion", JS_NewString(ctx, appVersion.c_str()));
    JS_FreeValue(ctx, global);
}

static bool run_script(JSContext *ctx, const std::string &script, const char *filename)
{
    JSValue val = JS_Eval(ctx, script.c_str(), script.size(), filename, JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(val)) {
        JSValue err = JS_GetException(ctx);
        const char *msg = JS_ToCString(ctx, err);
        if (msg != nullptr) {
            JS_FreeCString(ctx, msg);
        }
        JS_FreeValue(ctx, err);
        JS_FreeValue(ctx, val);
        return false;
    }
    JS_FreeValue(ctx, val);
    return true;
}

static JSValue eval_expression(JSContext *ctx, const std::string &script, const char *filename)
{
    return JS_Eval(ctx, script.c_str(), script.size(), filename, JS_EVAL_TYPE_GLOBAL);
}

} // namespace

VeneraQjsRuntime *venera_qjs_create()
{
    return new VeneraQjsRuntime();
}

void venera_qjs_destroy(VeneraQjsRuntime *rt)
{
    if (rt == nullptr) {
        return;
    }
    if (g_active == rt) {
        g_active = nullptr;
    }
    if (rt->tsfn != nullptr) {
        napi_release_threadsafe_function(rt->tsfn, napi_tsfn_release);
        rt->tsfn = nullptr;
    }
    if (rt->handlerRef != nullptr && rt->env != nullptr) {
        napi_delete_reference(rt->env, rt->handlerRef);
        rt->handlerRef = nullptr;
    }
    if (rt->jsContext != nullptr) {
        JS_FreeContext(rt->jsContext);
        rt->jsContext = nullptr;
    }
    if (rt->jsRuntime != nullptr) {
        JS_FreeRuntime(rt->jsRuntime);
        rt->jsRuntime = nullptr;
    }
    delete rt;
}

bool venera_qjs_init(VeneraQjsRuntime *rt, const std::string &initJs, const std::string &appVersion)
{
    if (rt == nullptr) {
        return false;
    }
    g_active = rt;
    rt->jsRuntime = JS_NewRuntime();
    rt->jsContext = JS_NewContext(rt->jsRuntime);
    install_globals(rt->jsContext, appVersion);
    if (!run_script(rt->jsContext, initJs, "<init.js>")) {
        return false;
    }
    rt->inited = true;
    return true;
}

bool venera_qjs_register_handler(VeneraQjsRuntime *rt, void *envPtr, void *handlerRefPtr)
{
    if (rt == nullptr || envPtr == nullptr) {
        return false;
    }
    napi_env env = static_cast<napi_env>(envPtr);
    rt->env = env;
    if (rt->handlerRef != nullptr) {
        napi_delete_reference(env, rt->handlerRef);
    }
    rt->handlerRef = static_cast<napi_ref>(handlerRefPtr);
    napi_value handler;
    napi_get_reference_value(env, rt->handlerRef, &handler);
    napi_value resourceName;
    napi_create_string_utf8(env, "VeneraQjsBridge", NAPI_AUTO_LENGTH, &resourceName);
    napi_create_threadsafe_function(env, handler, nullptr, resourceName, 0, 1, nullptr, nullptr, nullptr,
        tsfn_callback, &rt->tsfn);
    return rt->tsfn != nullptr;
}

bool venera_qjs_load_source(VeneraQjsRuntime *rt, const std::string &sourceKey, const std::string &script)
{
    if (rt == nullptr || !rt->inited) {
        return false;
    }
    std::string normalized = script;
    size_t pos = 0;
    while ((pos = normalized.find("\r\n", pos)) != std::string::npos) {
        normalized.replace(pos, 2, "\n");
        pos += 1;
    }
    size_t classPos = normalized.find("class ");
    if (classPos == std::string::npos) {
        return false;
    }
    size_t extendsPos = normalized.find("extends ComicSource", classPos);
    if (extendsPos == std::string::npos) {
        return false;
    }
    std::string className = normalized.substr(classPos + 6, extendsPos - (classPos + 6));
    size_t s = 0;
    while (s < className.size() && className[s] == ' ') {
        s++;
    }
    className = className.substr(s);
    size_t e = className.size();
    while (e > s && className[e - 1] == ' ') {
        e--;
    }
    className = className.substr(0, e);
    std::string loader = "(function(){ " + normalized + " this['temp']=new " + className + "();"
        "ComicSource.sources['" + sourceKey + "']=this['temp'];}).call(globalThis);";
    return run_script(rt->jsContext, loader, sourceKey.c_str());
}

static std::string eval_on_context(VeneraQjsRuntime *rt, const std::string &script, const char *filename)
{
    JSContext *ctx = rt->jsContext;
    JSValue val = eval_expression(ctx, script, filename);
    if (JS_IsException(val)) {
        JSValue err = JS_GetException(ctx);
        std::string out = js_value_to_string(ctx, err);
        JS_FreeValue(ctx, err);
        return out;
    }
    JSPromiseStateEnum promiseState = JS_PromiseState(ctx, val);
    if (promiseState != (JSPromiseStateEnum)(-1)) {
        JSRuntime *jsrt = JS_GetRuntime(ctx);
        for (int i = 0; i < 20000; i++) {
            JSPromiseStateEnum state = JS_PromiseState(ctx, val);
            if (state == JS_PROMISE_FULFILLED) {
                JSValue settled = JS_PromiseResult(ctx, val);
                std::string out = js_value_to_string(ctx, settled);
                JS_FreeValue(ctx, settled);
                JS_FreeValue(ctx, val);
                return out;
            }
            if (state == JS_PROMISE_REJECTED) {
                JSValue settled = JS_PromiseResult(ctx, val);
                std::string out = js_value_to_string(ctx, settled);
                JS_FreeValue(ctx, settled);
                JS_FreeValue(ctx, val);
                return out;
            }
            JSContext *pctx = nullptr;
            while (JS_ExecutePendingJob(jsrt, &pctx) > 0) {
            }
        }
        JS_FreeValue(ctx, val);
        return "null";
    }
    std::string out = js_value_to_string(ctx, val);
    JS_FreeValue(ctx, val);
    return out;
}

std::string venera_qjs_eval_json(VeneraQjsRuntime *rt, const std::string &script, const char *filename)
{
    if (rt == nullptr || !rt->inited) {
        return "null";
    }
    g_active = rt;
    std::string result;
    std::thread worker([&]() { result = eval_on_context(rt, script, filename); });
    worker.join();
    return result;
}

void venera_qjs_reset_sources(VeneraQjsRuntime *rt)
{
    if (rt == nullptr || !rt->inited) {
        return;
    }
    run_script(rt->jsContext, "ComicSource.sources = {};", "<reset>");
}
