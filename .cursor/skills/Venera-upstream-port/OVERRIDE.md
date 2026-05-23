# Venera — 上游克隆与路径映射（OVERRIDE）

**项目专用**：仅 `d:/Project/venera` 仓库内的 **Venera-upstream-port** skill 引用本文件；其它仓库忽略。

供 **Venera-upstream-port** 使用。路径以 Windows 开发机为准；Agent 在 skill 正文中统一写 `d:/Project/venera-upstream`（正斜杠）。

## 校验克隆

```powershell
git -C "d:\Project\venera-upstream" remote get-url origin
# 期望: https://github.com/venera-app/venera.git
```

## 上游 → 鸿蒙目录（默认规则）

| 上游 | 鸿蒙 (`entry/src/main/ets/`) |
|------|------------------------------|
| `lib/pages/**/*.dart` | `pages/**`（按功能分子目录，文件名 PascalCase + `Page.ets`） |
| `lib/foundation/*.dart` | `common/services/` 或 `common/models/` |
| `lib/network/*.dart` | `common/services/`（如 `HttpService.ets`、`DownloadService.ets`） |
| `lib/utils/*.dart` | `common/utils/` |
| `lib/main.dart`、`lib/init.dart` | `entryability/`、`common/services/AppBootstrap.ets` |
| `assets/*` | `AppScope/resources/` 或 `entry/src/main/resources/` |
| Flutter QuickJS / `patch/` | `entry/src/main/cpp/` + `rawfile/init.js` |

完整映射表以仓库根 `README.md` 的 **`### 上游模块映射`** 为准；新增页面后**必须**补一行映射。

## 上游版本号

移植涉及版本展示或兼容性时，同步：

- 上游：`d:/Project/venera-upstream/pubspec.yaml` → `version`
- 鸿蒙：`entry/src/main/ets/common/constants/AppConstants.ets` → `UPSTREAM_VERSION`

## 常见上游入口文件

| 功能 | 上游路径 |
|------|----------|
| 主壳 | `lib/pages/main_page.dart` |
| 首页 | `lib/pages/home_page.dart` |
| 漫画源 | `lib/pages/comic_source_page.dart` |
| 阅读器 | `lib/pages/reader/reader.dart` |
| JS 引擎 | `lib/foundation/js_engine.dart` |
| 漫画源模型 | `lib/foundation/comic_source/` |
| 下载 | `lib/network/download.dart` |
| 设置 | `lib/pages/settings/settings_page.dart` |

## 上游已归档说明

上游仓库已 archived，通常无新 commit；若社区 fork 有更新，仍应先 `pull` 官方 `master`，再决定是否跟踪 fork——**未经用户明确指示不要切换 remote**。

## 首次克隆（一键）

```powershell
git clone https://github.com/venera-app/venera.git "d:\Project\venera-upstream"
```
