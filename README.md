# Venera for HarmonyOS

将开源漫画阅读器 [venera-app/venera](https://github.com/venera-app/venera) 完整移植到 **HarmonyOS 6.1.0 (API 23)**，采用 **HDS 沉浸光感材质**（`systemMaterialEffect`）与 Stage 模型 ArkTS 工程。

> 上游项目已归档且停止维护，本仓库为社区鸿蒙移植版本，遵循 GPL-3.0 许可证。

| 项目 | 说明 |
|------|------|
| 上游仓库 | https://github.com/venera-app/venera |
| 上游版本 | 1.6.3+163 (Flutter) |
| 鸿蒙版本 | 1.0.0 |
| 目标 SDK | **6.1.0(23)** |
| 最低 API | **23** |
| 运行时 | HarmonyOS Stage 模型 |

---

## 功能对照（上游 → 鸿蒙）

| 功能 | 上游 (Flutter) | 鸿蒙移植状态 | 主要实现 |
|------|----------------|-------------|----------|
| 主界面四栏导航 | `main_page.dart` / NaviPane | ✅ 已完成 | `MainShell.ets` + `HdsTabs` |
| 沉浸光感底栏/标题栏 | — (Material 3) | ✅ 已完成 | `MaterialEffectHelper` + `HdsNavigation` / `HdsTabs` |
| 本地漫画书架 | `local_comics_page.dart` | 🟡 进行中 | `LocalComicService` 扫描 + DocumentPicker + CBZ/ZIP 解压 |
| 阅读器 | `pages/reader/*` | 🟡 进行中 | `ReaderPage` 本地/远程 `comic.loadEp` + 磁盘缓存 |
| 收藏 | `favorites/*` | ✅ 基础完成 | `FavoritesService` + Preferences |
| 发现 / 源列表 | `explore_page.dart` | 🟡 进行中 | `ComicSourceService` 索引加载 |
| 分类浏览 | `categories_page.dart` | 🟡 进行中 | `category.parts` 静态标签（待 categoryComics 列表） |
| 搜索 | `search_page.dart` | 🟡 进行中 | UI 完成，结果依赖 JS 引擎 |
| 漫画详情 | `comic_details_page/*` | 🟡 进行中 | `ComicDetailPage` 章节/下载本章 |
| 下载队列 | `download.dart` | 🟡 进行中 | `DownloadService` 队列持久化 + `HttpService` 沙箱写入 |
| 漫画源 (JS) | `flutter_qjs` + `source.js` | 🟡 进行中 | `JsEngineBridge` + `JsMessageHost` + 源脚本 staging |
| 网络 HTTP | `rhttp` / Dio | 🟡 进行中 | `@kit.NetworkKit` `HttpService` |
| 设置 | `settings/*` | 🟡 进行中 | `SettingsPage.ets` 核心项 |
| WebView 登录 | `webview.dart` | ⏳ 待开发 | ArkWeb 组件 |
| CBZ/ZIP/7z/PDF/EPUB | `utils/cbz.dart` 等 | ⏳ 待开发 | 原生解压模块 |
| WebDAV 同步 | `data_sync.dart` | ⏳ 待开发 | — |
| 无头模式 | `headless.dart` | ⏳ 不计划首期 | — |
| 应用锁 | `auth_page.dart` | ⏳ 待开发 | 生物识别 API |

图例：**✅ 已完成** · **🟡 进行中** · **⏳ 待开发**

---

## 移植进度总览

```
整体进度 █████████████░░░░░░░ 约 60%

阶段 0  工程脚手架 / API 23 配置     [████████████████████] 100%
阶段 1  HDS 沉浸光感主壳 UI          [████████████████████] 100%
阶段 2  数据层 (Preferences/模型)    [██████████████████░░]  90%
阶段 3  本地书架与阅读器              [███████████████████░]  90%
阶段 4  JS 漫画源引擎 (QuickJS)      [██████████████████░░]  90%
阶段 5  下载 / 归档 / 多格式          [██████░░░░░░░░░░░░░░]  30%
阶段 6  WebView / 同步 / 高级设置     [░░░░░░░░░░░░░░░░░░░░]   0%
```

**最近更新（2026-05-23）**

- **JS API 对齐上游**：`search.load` → `comics` 数组；章节 `comic.loadInfo`；阅读页 `comic.loadEp` → `images`
- **远程阅读链路**：`ReaderPage` 经 `invokeComicPages` 拉取网络章节并 `ImageCacheUtil` 缓存
- **漫画详情**：章节列表解析分组 chapters；「下载本章」写入 `DownloadService` 队列
- **分类**：从 `category.parts` 静态配置读取标签名
- **JsMessageHost 扩展**：`convert`（MD5/SHA/HMAC/Base64/UTF8，`@kit.CryptoArchitectureKit`）、`cookie`、`load_setting` / `isLogged`、剪贴板（`pasteboard`）
- **JsCookieStore**：沙箱 `cookies.json` 持久化
- **QuickJS NAPI**：`libvenera_qjs.so` + `HMS_Rcp_FetchSync`（API 23）HTTP + `JsMessageHost` 同步桥接
- **JsEngineBridge**：`invokeSearch` / `invokeCategories` / `invokeComicChapters` 经 QuickJS 执行
- **发现 → 搜索**：按漫画源定向搜索（`sourceKey` 路由参数）
- **漫画详情**：章节列表 UI（待 QuickJS 返回数据）
- 初始化 HarmonyOS Stage 工程，`compatibleSdkVersion` / `targetAPIVersion` 设为 **6.1.0(23)**
- 实现 `MaterialEffectHelper`：`getSystemMaterialTypes()` 能力探测 + IMMERSIVE/ADAPTIVE 降级
- 主界面 `HdsTabs` 悬浮底栏 + `HdsNavigation` 标题栏沉浸光感
- 移植核心页面路由与服务层骨架
- Bundled `init.js` / `translation.json` 至 `rawfile/` 供后续 JS 引擎加载
- **本地阅读 P0**：`DocumentImportHelper`（API 23 `DocumentViewPicker`）+ `LocalImageUtil` 图片扫描
- **CBZ/ZIP 解压**：`ArchiveExtractUtil`（API 23 `zlib.decompressFile`）导入时自动解压
- **本地详情**：`LocalComicDetailPage` 多章节选择
- **阅读器**：`ReaderPage` `Swiper(controller)` 同步翻页、阅读进度 `HistoryService`
- **下载**：`HttpService.downloadFile` 写入沙箱 + `DownloadService` 队列处理
- **漫画源缓存**：`ComicSourceService` 预拉取 `source.js` 至沙箱
- **JsEngineBridge**：从 `rawfile/init.js` 预加载 + 沙箱 `source.js` staging（待 NAPI QuickJS 执行）
- **JsMessageHost**：`sendMessage` 宿主（http / delay / convert / load_data 等，API 23）
- **ImageCacheUtil**：阅读器远程图片 `cacheDir` 磁盘缓存
- **ComicSourceDataService**：漫画源 `load_data` / `save_data` 持久化
- **首页**：继续阅读（最近 3 条历史）
- **发现/分类/搜索**：源缓存状态、多源切换、引擎状态提示

---

## API 23 与沉浸光感材质

本工程严格遵守 **HarmonyOS 6.1.0 (API 23)** 开发约定：

1. **`AppScope/app.json5`**：`minAPIVersion` / `targetAPIVersion` = **23**
2. **`build-profile.json5`**：`compatibleSdkVersion` = **6.1.0(23)**
3. **材质 API**：`@kit.UIDesignKit` → `hdsMaterial.getSystemMaterialTypes()` + `systemMaterialEffect`
4. **降级策略**（见 `entry/src/main/ets/common/material/MaterialEffectHelper.ets`）：
   - API &lt; 23 → `SMOOTH`
   - 支持 IMMERSIVE → `IMMERSIVE` + `EXQUISITE`
   - 否则 → `ADAPTIVE`（推荐默认）

参考：[HDS 沉浸光感效果实践](https://harmonyosdev.csdn.net/69e1a1020a2f6a37c5a08772.html)

---

## 工程结构

```
venera/
├── AppScope/                    # 应用级配置与图标
├── entry/                       # 主 HAP 模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/    # EntryAbility（全屏沉浸窗口）
│       │   ├── common/
│       │   │   ├── constants/   # AppConstants
│       │   │   ├── material/    # MaterialEffectHelper
│       │   │   ├── models/      # Comic 领域模型
│       │   │   └── services/    # 业务服务层
│       │   └── pages/           # UI 页面
│       └── resources/
│           └── rawfile/         # init.js, translation.json
├── upstream/                    # 上游 Flutter 源码（参考，已 gitignore）
├── build-profile.json5
├── oh-package.json5
└── README.md
```

### 上游模块映射

| 上游 `lib/` | 鸿蒙 `entry/src/main/ets/` |
|-------------|---------------------------|
| `foundation/appdata.dart` | `common/services/AppDataService.ets` |
| `foundation/local.dart` | `common/services/LocalComicService.ets` |
| `foundation/history.dart` | `common/services/HistoryService.ets` |
| `utils/import_comic.dart` | `common/utils/DocumentImportHelper.ets` |
| `utils/cbz.dart` | `common/utils/ArchiveExtractUtil.ets` |
| `foundation/favorites.dart` | `common/services/FavoritesService.ets` |
| `foundation/comic_source/*` | `common/services/ComicSourceService.ets` |
| `foundation/js_engine.dart` | `common/services/JsEngineBridge.ets` + `JsMessageHost.ets` |
| `network/download.dart` | `common/services/DownloadService.ets` |
| `network/app_dio.dart` | `common/services/HttpService.ets` |
| `pages/main_page.dart` | `pages/main/MainShell.ets` |
| `init.dart` | `common/services/AppBootstrap.ets` |

---

## 环境要求

| 工具 | 版本建议 |
|------|----------|
| DevEco Studio | 6.0+（支持 API 23 SDK） |
| HarmonyOS SDK | **6.1.0(23)** |
| Node.js | 18+（hvigor 构建） |

### 构建步骤

0. 首次构建需拉取 QuickJS 源码（已 gitignore）：

```powershell
.\scripts\fetch-quickjs.ps1
```

1. 使用 DevEco Studio 打开本目录 `venera`
2. 确认 SDK Manager 已安装 **API 23** 工具链
3. 配置签名（调试可使用自动签名）
4. **Build → Build Hap(s)/APP(s)**

命令行（需已配置 `hvigorw`）：

```bash
hvigorw assembleHap
```

### 运行

连接 HarmonyOS 6.1+ 真机或模拟器，安装 `entry-default-signed.hap`。

---

## 后续开发路线图

### P0 — 核心阅读体验

- [x] NAPI 嵌入 QuickJS（`libvenera_qjs.so`），加载 `init.js` 与 `source.js`
- [x] 实现 `JsEngineBridge.invokeSearch` / `invokeCategories` / `invokeComicChapters`
- [x] `invokeComicPages` 远程阅读页完整链路（`comic.loadEp`）
- [ ] convert 哈希类同步原生实现（当前 MD5/SHA 依赖 ArkTS 异步）
- [x] 本地图片页列表与自然排序阅读
- [x] DocumentPicker 导入漫画目录 / 压缩包复制
- [x] CBZ/ZIP 解压阅读（API 23 zlib）
- [x] 阅读器远程图 `cacheDir` 磁盘缓存（`ImageCacheUtil`）
- [ ] 7z/cb7 原生解压

### P1 — 格式与下载

- [x] ZIP/CBZ 解压（API 23 zlib.decompressFile）
- [ ] 7z / PDF / EPUB 模块
- [x] `DownloadService` 写入 `filesDir/downloads`（需任务带 `resourceUrl`）

### P2 — parity 功能

- [ ] ArkWeb 登录与 Cookie 持久化（SQLite）
- [ ] 评论、标签、EhTag 翻译资源
- [ ] WebDAV `data_sync` 等价实现
- [ ] 探索页推荐、聚合搜索、排行榜

---

## 参考与致谢

- 原项目：[venera-app/venera](https://github.com/venera-app/venera) — GPL-3.0
- 漫画源配置：[venera-configs](https://github.com/venera-app/venera-configs)
- 标签翻译：[EhTagTranslation](https://github.com/EhTagTranslation/EhTagTranslation)

---

## 许可证

本项目继承上游 **GPL-3.0** 许可证。详见 [LICENSE](./LICENSE)（自上游同步）。
