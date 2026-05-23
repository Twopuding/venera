#pragma once

#include <string>

/** 解压 7z/cb7 到 outDir（需 third_party/lzma SDK）。成功返回 true。 */
bool venera_extract_7z(const std::string &archivePath, const std::string &outDir, std::string &errorOut);
