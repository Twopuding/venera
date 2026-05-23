cmake_minimum_required(VERSION 3.5.0)
project(venera_qjs)

set(QJS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/quickjs-ng-temp)
file(READ "${QJS_DIR}/VERSION" QUICKJS_VERSION)

add_library(quickjs STATIC
    ${QJS_DIR}/cutils.c
    ${QJS_DIR}/dtoa.c
    ${QJS_DIR}/libregexp.c
    ${QJS_DIR}/libunicode.c
    ${QJS_DIR}/quickjs.c
)
target_compile_definitions(quickjs PRIVATE CONFIG_VERSION="${QUICKJS_VERSION}")
# PRIVATE: avoid shadowing C++ <version> via quickjs-ng-temp/VERSION on case-insensitive FS
target_include_directories(quickjs PRIVATE ${QJS_DIR})

add_library(venera_qjs SHARED
    napi_init.cpp
    venera_qjs_runtime.cpp
    venera_http.cpp
    venera_convert.cpp
    venera_archive.cpp
)

set(LZMA_C_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third_party/lzma/C)
if(EXISTS ${LZMA_C_DIR}/7zDec.c)
    message(STATUS "LZMA SDK found, enabling VENERA_HAS_LZMA_SDK")
    target_compile_definitions(venera_qjs PRIVATE VENERA_HAS_LZMA_SDK)
    target_include_directories(venera_qjs PRIVATE ${LZMA_C_DIR})
    target_sources(venera_qjs PRIVATE
        ${LZMA_C_DIR}/7zAlloc.c
        ${LZMA_C_DIR}/7zArcIn.c
        ${LZMA_C_DIR}/7zBuf.c
        ${LZMA_C_DIR}/7zBuf2.c
        ${LZMA_C_DIR}/7zCrc.c
        ${LZMA_C_DIR}/7zCrcOpt.c
        ${LZMA_C_DIR}/7zDec.c
        ${LZMA_C_DIR}/7zFile.c
        ${LZMA_C_DIR}/7zStream.c
        ${LZMA_C_DIR}/Alloc.c
        ${LZMA_C_DIR}/Bcj2.c
        ${LZMA_C_DIR}/Bra.c
        ${LZMA_C_DIR}/Bra86.c
        ${LZMA_C_DIR}/BraIA64.c
        ${LZMA_C_DIR}/CpuArch.c
        ${LZMA_C_DIR}/Delta.c
        ${LZMA_C_DIR}/Lzma2Dec.c
        ${LZMA_C_DIR}/LzmaDec.c
        ${LZMA_C_DIR}/Ppmd7.c
        ${LZMA_C_DIR}/Ppmd7Dec.c
    )
endif()

# librcp_c.so ships in HMS sysroot, not openharmony sysroot
if(DEFINED HMOS_SDK_NATIVE)
    if(OHOS_ARCH STREQUAL "arm64-v8a")
        set(HMOS_LIB_ARCH aarch64-linux-ohos)
    elseif(OHOS_ARCH STREQUAL "x86_64")
        set(HMOS_LIB_ARCH x86_64-linux-ohos)
    elseif(OHOS_ARCH STREQUAL "armeabi-v7a")
        set(HMOS_LIB_ARCH arm-linux-ohos)
    endif()
    if(DEFINED HMOS_LIB_ARCH)
        set(HMOS_LIB_DIR ${HMOS_SDK_NATIVE}/sysroot/usr/lib/${HMOS_LIB_ARCH})
        target_include_directories(venera_qjs PRIVATE ${HMOS_SDK_NATIVE}/sysroot/usr/include)
        target_link_directories(venera_qjs PRIVATE ${HMOS_LIB_DIR})
    endif()
endif()

target_link_libraries(venera_qjs PUBLIC libace_napi.z.so librcp_c.so quickjs)
target_compile_definitions(venera_qjs PRIVATE __OHOS__)
