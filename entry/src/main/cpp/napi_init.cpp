/**
 * NAPI 桥接层 — 连接 ArkTS DiffSessionViewModel 与 C++ Myers 引擎
 *
 * 接口:
 *   computeDiff(linesA: string[], linesB: string[]): {
 *     matches: Array<{ indexA: number; indexB: number }>;
 *     lengthA: number;
 *     lengthB: number;
 *   }
 */
#include <napi/native_api.h>
#include <vector>
#include <string>
#include "myers_diff.cpp"

// ---------- 工具函数 ----------

static napi_value CreateInt32(napi_env env, int32_t value) {
    napi_value result;
    napi_create_int32(env, value, &result);
    return result;
}

// 读取一个 JS string 元素为 std::string（规范缓冲区写法）
static bool ReadStringElement(napi_env env, napi_value elem, std::string& out) {
    napi_valuetype vt;
    if (napi_typeof(env, elem, &vt) != napi_ok || vt != napi_string) {
        return false;
    }
    size_t strLen = 0;
    if (napi_get_value_string_utf8(env, elem, nullptr, 0, &strLen) != napi_ok) {
        return false;
    }
    std::string str(strLen + 1, '\0');
    size_t written = 0;
    if (napi_get_value_string_utf8(env, elem, &str[0], strLen + 1, &written) != napi_ok) {
        return false;
    }
    str.resize(written);
    out = std::move(str);
    return true;
}

/**
 * 将 C++ edits 转换为 NAPI 结果对象:
 *   { matches: [{indexA, indexB}, ...], lengthA, lengthB }
 */
static napi_value BuildResult(napi_env env,
                               const myers::Edits& edits,
                               int lengthA, int lengthB) {
    napi_value result;
    napi_create_object(env, &result);

    // matches 数组
    napi_value matchesArr;
    napi_create_array(env, &matchesArr);

    int indexA = 0;
    int indexB = 0;
    uint32_t matchIdx = 0;

    for (size_t i = 0; i < edits.size(); i++) {
        switch (edits[i]) {
            case '=': {
                napi_value matchObj;
                napi_create_object(env, &matchObj);
                napi_set_named_property(env, matchObj, "indexA", CreateInt32(env, indexA));
                napi_set_named_property(env, matchObj, "indexB", CreateInt32(env, indexB));
                napi_set_element(env, matchesArr, matchIdx, matchObj);
                matchIdx++;
                indexA++;
                indexB++;
                break;
            }
            case '-':
                indexA++;
                break;
            case '+':
                indexB++;
                break;
        }
    }

    napi_set_named_property(env, result, "matches", matchesArr);
    napi_set_named_property(env, result, "lengthA", CreateInt32(env, lengthA));
    napi_set_named_property(env, result, "lengthB", CreateInt32(env, lengthB));

    return result;
}

// ---------- NAPI 导出函数 ----------

/**
 * computeDiff(linesA: string[], linesB: string[]): Object
 */
static napi_value ComputeDiff(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "computeDiff requires 2 arguments: linesA, linesB");
        return nullptr;
    }

    bool isArrayA = false;
    bool isArrayB = false;
    napi_is_array(env, args[0], &isArrayA);
    napi_is_array(env, args[1], &isArrayB);
    if (!isArrayA || !isArrayB) {
        napi_throw_type_error(env, nullptr, "computeDiff arguments must be string arrays");
        return nullptr;
    }

    // 读取 linesA[]
    uint32_t lenA = 0;
    napi_get_array_length(env, args[0], &lenA);
    myers::Lines linesA;
    for (uint32_t i = 0; i < lenA; i++) {
        napi_value elem;
        napi_get_element(env, args[0], i, &elem);
        std::string str;
        if (!ReadStringElement(env, elem, str)) {
            napi_throw_type_error(env, nullptr, "linesA contains non-string element");
            return nullptr;
        }
        linesA.push_back(std::move(str));
    }

    // 读取 linesB[]
    uint32_t lenB = 0;
    napi_get_array_length(env, args[1], &lenB);
    myers::Lines linesB;
    for (uint32_t i = 0; i < lenB; i++) {
        napi_value elem;
        napi_get_element(env, args[1], i, &elem);
        std::string str;
        if (!ReadStringElement(env, elem, str)) {
            napi_throw_type_error(env, nullptr, "linesB contains non-string element");
            return nullptr;
        }
        linesB.push_back(std::move(str));
    }

    // 执行 Myers diff
    myers::Edits edits = myers::shortestEditScript(linesA, linesB);

    return BuildResult(env, edits, static_cast<int>(lenA), static_cast<int>(lenB));
}

// ---------- 模块注册 ----------

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"computeDiff", nullptr, ComputeDiff, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "myers_diff_napi",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterMyersDiffModule(void) {
    napi_module_register(&demoModule);
}
