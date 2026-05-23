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
| 主界面四栏导航 | `main_page.dart` / NaviPane | ✅ 已完成 | `MainShell.ets` + `HdsTabs`（首页/收藏/发现/分类；非首页标题栏搜索） |
| 首页仪表盘 | `home_page.dart` | ✅ 已完成 | `HomePage.ets`：搜索/同步/历史/本地/关注更新/漫画源/图片收藏 |
| 沉浸光感底栏/标题栏 | — (Material 3) | ✅ 已完成 | `MaterialEffectHelper` + `HdsNavigation` / `HdsTabs` |
| 本地漫画书架 | `local_comics_page.dart` | ✅ 已完成 | `LocalLibraryPage.ets` + `LocalComicService` |
| 阅读器 | `pages/reader/*` | ✅ 已完成 | `ReaderPage`（横竖屏/滑条/章节）+ `PdfReaderPage` / `EpubReaderPage` + 拼图解码 |
| 收藏 | `favorites/*` | 🟡 进行中 | `FavoritesPage` + `FavoritesService`（待本地文件夹/网络收藏双轨） |
| 关注更新 | `follow_updates_page.dart` | 🟡 进行中 | `FollowUpdatesPage.ets`（占位，待 LocalFavorites） |
| 图片收藏 | `image_favorites_page/*` | 🟡 进行中 | `ImageFavoritesPage.ets`（占位，待 ImageFavoriteManager） |
| 发现 / 探索 Tab | `explore_page.dart` | 🟡 进行中 | `explore_pages` 多 Tab + `SingleExplorePanel` |
| 漫画源管理 | `comic_source_page.dart` | ✅ 已完成 | `ComicSourcePage`（添加/删除/更新/官方列表/编辑/设置/登录）+ 31 个 venera-configs |
| 分类浏览 | `categories_page.dart` | 🟡 进行中 | `CategoriesPage` + `CategoryComicsPage` + 排行榜入口 |
| 搜索 | `search_page.dart` | 🟡 进行中 | `SearchPage` + `AggregatedSearchPage` + `SearchSourcesSettingsPage` |
| 排行榜 | `ranking_page.dart` | ✅ 基础完成 | `RankingPage` + `categoryComics.ranking.load` |
| 漫画详情 | `comic_details_page/*` | 🟡 进行中 | `ComicDetailPage` 章节/标签/评论/推荐/下载本章 |
| 下载队列 | `download.dart` | 🟡 进行中 | `DownloadService` 重试/删除/清除已完成 |
| 漫画源 (JS) | `flutter_qjs` + `source.js` | ✅ 基础完成 | QuickJS NAPI + `JsEngineBridge` + `JsMessageHost` |
| 网络 HTTP | `rhttp` / Dio | 🟡 进行中 | `@kit.NetworkKit` `HttpService` |
| 设置 | `settings/*` | 🟡 进行中 | 阅读模式/代理/WebDAV/聚合搜索源/探索页/清缓存/Cookie |
| WebView 登录 | `webview.dart` | 🟡 进行中 | `SourceLoginWebPage` + `WebCookieBridge` |
| CBZ/ZIP/7z/PDF/EPUB | `utils/cbz.dart` 等 | 🟡 进行中 | ZIP/CBZ + NAPI `extract7z` + PDFKit + ArkWeb EPUB |
| WebDAV 同步 | `data_sync.dart` | 🟡 进行中 | `WebDavSyncService` JSON 上传/拉取 |
| EhTag 标签翻译 | `translation` | ✅ 基础完成 | `TagTranslationService` + `tags_tw.json` |
| 无头模式 | `headless.dart` | ⏳ 不计划首期 | — |
| 应用锁 | `auth_page.dart` | ⏳ 待开发 | 生物识别 API |

图例：**✅ 已完成** · **🟡 进行中** · **⏳ 待开发**

---

## 移植进度总览

```
整体进度 ██████████████████░░ 约 85%

阶段 0  工程脚手架 / API 23 配置     [████████████████████] 100%
阶段 1  HDS 沉浸光感主壳 UI          [████████████████████] 100%
阶段 2  数据层 (Preferences/模型)    [███████████████████░]  95%
阶段 3  本地书架与阅读器              [████████████████████]  95%
阶段 4  JS 漫画源引擎 (QuickJS)      [████████████████████] 100%
阶段 5  下载 / 归档 / 多格式          [██████████████░░░░░░]  70%
阶段 6  WebView / 同步 / 高级设置     [████████████░░░░░░░░]  60%
```

**最近更新（2026-05-23）**

- **二级页安全区**：全屏窗口下 `SafeAreaInsets`（`getWindowAvoidArea` → AppStorage）为所有 router 二级页根布局增加顶/底内边距；`LocalLibraryPage` 补顶栏返回
- **首次安装启动白屏**：首次冷启动在仍显示 `LaunchPage` 时执行 `AppBootstrap.runFirstLaunchPrep`（QuickJS + 默认图源），完成后再 `loadContent(Index)`，避免首次 AOT 编译主包时长时间纯白；`firstLaunchComplete` 持久化后后续启动仅快速进主界面
- **启动纯白屏修复**：`LaunchPage` 零 Service import；`AppBootstrapLite` 仅 Preferences；系统启动窗与引导页同为浅灰 `card_background`
- **启动白屏（JS 引擎）**：`initRuntime` 在 worker 线程异步执行；`ENGINE_READY_KEY` 控制发现/分类刷新时机
- **启动加载引导**：`StartupSplash` 仅覆盖本地数据快速初始化（图标 + `LoadingProgress`），完成后立即进入主界面
- **首页顶栏空白修复**：`MainShell` 移除无效的 `bindToScrollable`（子页 `Scroller` 未与导航绑定，`MINI` 标题模式下仍预留大标题占位）；搜索条紧贴「首页」标题栏
- **漫画源安装解析**：`addSourceFromScript` 先 `ensureEngineReady`；`SourceScriptUtil.parseMetaFromScript` 静态解析 name/key（支持类前有辅助函数的 jcomic 等）；QuickJS eval 失败时自动回退；`version` 缺省为 `1.0.0`
- **漫画源登录修复**：`ensureSourceReady` 从沙箱/staged 重试 `loadSourceScript` 直至装入 QuickJS；移除 staged 占位导致的假「登录」入口；`openLoginPage` 未装入时 toast 不再误跳登录页；首页漫画源芯片改为 `ComicSource.all()` 等价（仅已装入源）
- **漫画源页 UI/功能对齐截图**：`ComicSourcePage` 可滚动列表、图标化编辑/更新/删除；每源 settings 支持图源 `translation` 中文化（API 地址/分流/签到等）；`input` 经 `JsUiDialogService` 保存；`callback` 显示加载态；已登录时「重新登录」+「注销」对齐上游；检查更新弹出可更新列表对话框；帮助链打开官方文档
- **二级页导航**：新增 `SecondaryPageHeader`（顶栏 `chevron_left` 返回，对齐上游 AppBar）；移除设置/搜索/历史/下载/漫画详情等二级页底部「返回」按钮；表单页（编辑源、探索分区）保留底部取消/保存
- **图源装入卡顿修复**：`JsEngineBridge.init` 不再同步编译全部沙箱图源；启动后后台分批 `loadCachedSourcesFromDiskAsync` → 默认三源 → `registerPendingStagedInBackground`；批量安装仅 stage 脚本、末尾一次性 `registerSourcesToNative`；`getInstalledSources` 仅返回 QuickJS 内 `ComicSource.sources`（`ComicSourcePage` 打开时预装入 staged）
- **漫画源管理 1:1 移植**：`ComicSourcePage` 对齐上游 `comic_source_page.dart`——URL/文件添加、官方 `index.json` 列表（`ComicSourceListPage`）、检查更新与批量更新、单源编辑（`ComicSourceEditPage`）、删除、每源 settings（select/switch/input/callback）、账号密码/WebView 登录；`ComicSourceService` 增删改与 `explore_pages`/`categoryPages`/`searchSources` 同步
- **默认图源精简**：`AppConstants.DEFAULT_SOURCE_KEYS` = `picacg` / `wnacg` / `jm`，`AppBootstrap` 仅默认装入上述三源（不再首启安装全部 31 个）
- **首页布局对齐上游**：`HomePage` 改为仪表盘（搜索条、WebDAV 同步、历史/本地横滑预览、漫画源芯片、关注更新/图片收藏入口）；完整本地书架迁至 `LocalLibraryPage`
- **主导航对齐上游**：Tab0 标题为「首页」；标题栏仅在非首页显示搜索，设置始终可见（对齐 `MainPage` paneActions）
- **新增页面**：`FollowUpdatesPage`、`ImageFavoritesPage`（路由已注册，功能待后续 parity）
- **主线程卡死修复（THREAD_BLOCK_6S）**：`loadSource` / `evaluate` NAPI 均改为 Promise + 后台线程执行 QuickJS，主线程可继续处理 `sendMessage` 的 threadsafe 回调；`g_qjs_mu` 递归锁串行化上下文访问；移除 ArkTS 侧 `handleComputeSync`（`compute` 由原生 `venera_compute_on_context` 处理）；搜索/发现/聚合搜索等页面适配异步 evaluate
- **启动加速与异常修复**：`ComicSourceService.init` 仅加载 index，31 个图源脚本在首帧后后台装入（`AppBootstrap.installSourcesInBackground`）；`isScriptOnDisk` 改用 `fileIo.accessSync`（`FileIoUtil.existsSync`），避免 `statSync` 在 async 中触发 `Pending exception before NotifyNativeReturn`；装入过程每 4 个源让出 UI 线程
- **启动窗口**：系统要求保留 `startWindowIcon` / `startWindowBackground`；已改为应用 `layered_image` + 与主界面一致的 `page_background`
- **应用图标**：`AppScope` / `entry` 资源使用上游 [venera-app/venera `assets/app_icon.png`](https://github.com/venera-app/venera/blob/master/assets/app_icon.png)（1024×1024）；分层图标前景与启动页图标同源
- **启动体验**：`EntryAbility` 先 `loadContent` 再后台 `AppBootstrap`；CDN 同步与图源装入均在后台；HTTP 增加连接/读取超时；浅色模式下状态栏图标改为深色
- **本地书架完善**：首页导入/扫描、标题栏快捷导入、长按删除漫画（`FileIoUtil` 递归删目录）
- **阅读器增强**：`ReaderPage` 跟随设置横/竖向翻页、页码滑条、本地多章节切换；远程图预取缓存
- **统一跳转**：`ReaderLaunchUtil` 本地 PDF/EPUB/图片与历史记录一致路由
- **PDF/EPUB 历史**：`PdfReaderPage` / `EpubReaderPage` 写入 `HistoryService`，继续阅读可恢复
- **官方图源完整内置**：`rawfile/comic_sources/` 打包 [venera-configs](https://github.com/venera-app/venera-configs) 全部 31 个脚本 + `index.json`；`scripts/fetch-comic-sources.ps1` 可同步更新
- **默认三源**：首启后台仅装入 **Picacg**、**绅士漫画**（`wnacg`）、**禁漫天堂**（`jm`）；其余源可在漫画源页或官方列表手动添加
- **离线安装**：`ComicSourceService` 优先 CDN，失败回退内置包；首帧后后台装入 QuickJS；合并 `explore_pages`（对齐上游 `_addAllPagesWithComicSource`）
- **发现 Tab 多 Tab**：`ExplorePage` 按 `explore_pages` 展示探索分区；`ExplorePagesPickerPage` 勾选；`SingleExplorePanel` 单页加载
- **JsEngineBridge**：`invokeListExplorePageTitles` / `invokeExploreByTitle`（multiPart / multiPageComicList / mixed）
- **聚合搜索源设置**：`SearchSourcesSettingsPage` 可视化 `searchSources`；设置页入口
- **漫画源页增强**：`ComicSourcePage` 合并原发现页源列表（搜索/分类/推荐/登录/刷新）
- **聚合搜索**：`AggregatedSearchPage` 多源横向预览；`SearchPage`「聚合搜索」入口；`AppDataService.searchSources` 可配置参与源
- **排行榜**：`RankingPage`（`categoryComics.ranking.load`）；`CategoriesPage` 顶部排行榜芯片（如 Picacg 日/周/月）
- **漫画源索引**：`ComicSourceService` 兼容 `index.json` 顶层数组；CDN 脚本按 `fileName`（如 `baozi.js`）拉取
- **JsEngineBridge**：`invokeListRankingPages` / `invokeRankingComics` / `invokeSearchableSourceKeys`
- **漫画详情增强**：`invokeComicInfo`（标签/评论/相关推荐）；详情页跳转推荐漫画
- **下载队列**：任务重试/删除、清除已完成；主壳与设置页快捷入口
- **探索推荐**：`ExploreRecommendPage` + `invokeExplore`（漫画源 `explore.load` 分区）
- **EPUB 阅读**：`EpubParseUtil`（OPF 书脊）+ `EpubReaderPage`（API 23 ArkWeb XHTML）
- **WebDAV 同步**：`WebDavSyncService`（PUT/GET `venera_sync.json`：收藏/历史/设置）
- **WebView 登录**：`SourceLoginWebPage` + `WebCookieBridge` → `JsCookieStore`；设置页清除 Cookie
- **PDF 阅读**：`PdfReaderPage`（API 23 `@kit.PDFKit`）+ 本地 PDF 导入
- **拼图解码**：`JsImageService` + `ComicImageResolver`（`modifyImage` / `onResponse` 完整链路）
- **7z/cb7**：NAPI `extract7z` + `scripts/fetch-lzma.ps1`（可选 LZMA SDK）
- **EhTag 标签翻译**：`TagTranslationService` + `tags_tw.json`（设置开关）
- **HTML DOM 桥接**：`JsHtmlDomService` 纯 ArkTS `HtmlDocument` / `querySelector`
- **UI 桥接**：`JsUiDialogService`（对话框/输入/Loading）+ `JsUiBridge`（Toast / `openLink`）
- **convert 同步哈希**：`venera_convert.cpp` MD5/SHA/HMAC/Base64（QuickJS 同步路径）
- **远程阅读链路**：`ReaderPage` → `invokeComicPageEntries` → `ImageCacheUtil` 磁盘缓存
- **工程脚手架**：Stage 模型、`compatibleSdkVersion` / `targetAPIVersion` = **6.1.0(23)**、HDS 沉浸光感主壳

> 完整变更历史见 Git 提交记录；**HarmonyProject-build** skill 要求在每次编译通过后同步本节（Venera 细则见 `.cursor/skills/HarmonyProject-build/OVERRIDE.md`）。

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
├── AppScope/                    # 应用级配置与图标（`app_icon.png` 来自上游 venera）
├── entry/                       # 主 HAP 模块
│   └── src/main/
│       ├── cpp/                 # QuickJS NAPI、7z 解压等原生代码
│       ├── ets/
│       │   ├── entryability/    # EntryAbility（全屏沉浸窗口）
│       │   ├── common/
│       │   │   ├── constants/   # AppConstants
│       │   │   ├── material/    # MaterialEffectHelper
│       │   │   ├── models/      # Comic 领域模型
│       │   │   ├── services/    # 业务服务层（JsEngineBridge、Download…）
│       │   │   └── utils/       # 归档/图片/EPUB 等工具
│       │   └── pages/           # UI 页面（main/search/reader/…）
│       └── resources/
│           └── rawfile/         # init.js, comic_sources/*.js, tags_tw.json
├── scripts/                     # fetch-quickjs.ps1, fetch-comic-sources.ps1, fetch-lzma.ps1
├── .cursor/skills/HarmonyProject-build/   # 通用鸿蒙构建 + README 同步
├── .cursor/skills/Venera-upstream-port/   # 仅本仓库：上游 1:1 移植（`d:\Project\venera-upstream`）
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
| `pages/home_page.dart` | `pages/home/HomePage.ets` |
| `pages/local_comics_page.dart` | `pages/local/LocalLibraryPage.ets` + `LocalComicDetailPage.ets` |
| `pages/follow_updates_page.dart` | `pages/follow/FollowUpdatesPage.ets` |
| `pages/image_favorites_page/*` | `pages/image_favorites/ImageFavoritesPage.ets` |
| `pages/reader/*` | `pages/reader/*` + `common/utils/ReaderLaunchUtil.ets` |
| `utils/cbz.dart` | `common/utils/ArchiveExtractUtil.ets` |
| `foundation/favorites.dart` | `common/services/FavoritesService.ets` |
| `foundation/comic_source/*` | `common/services/ComicSourceService.ets` |
| `foundation/js_engine.dart` | `common/services/JsEngineBridge.ets` + `JsMessageHost.ets` |
| `foundation/data_sync.dart` | `common/services/WebDavSyncService.ets` |
| `image.dart` (拼图) | `common/services/JsImageService.ets` + `common/utils/ComicImageResolver.ets` |
| `network/download.dart` | `common/services/DownloadService.ets` |
| `network/app_dio.dart` | `common/services/HttpService.ets` |
| `pages/main_page.dart` | `pages/main/MainShell.ets` |
| `pages/aggregated_search_page.dart` | `pages/search/AggregatedSearchPage.ets` |
| `pages/ranking_page.dart` | `pages/ranking/RankingPage.ets` |
| `pages/explore_page.dart` | `pages/explore/ExplorePage.ets` + `SingleExplorePanel.ets` + `ExplorePagesPickerPage.ets` |
| `pages/comic_source_page.dart` | `pages/sources/ComicSourcePage.ets` |
| `settings searchSources` | `pages/settings/SearchSourcesSettingsPage.ets` |
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
.\scripts\fetch-comic-sources.ps1
# 可选：7z/cb7 解压
.\scripts\fetch-lzma.ps1
```

1. 使用 DevEco Studio 打开本目录 `venera`
2. 确认 SDK Manager 已安装 **API 23** 工具链
3. 配置签名（调试可使用自动签名）
4. **Build → Build Hap(s)/APP(s)**

命令行（需已配置 `hvigorw`）：

```bash
hvigorw assembleHap
```

构建成功后，Agent 使用 **HarmonyProject-build** skill 时会自动将本次代码改动同步到本 README 的「最近更新」与进度表。

### 运行

连接 HarmonyOS 6.1+ 真机或模拟器，安装 `entry-default-signed.hap`。

---

## 后续开发路线图

### P0 — 核心阅读体验

- [x] NAPI 嵌入 QuickJS（`libvenera_qjs.so`），加载 `init.js` 与 `source.js`
- [x] `JsEngineBridge` 搜索/分类/章节/阅读页/详情/探索/排行榜
- [x] convert 哈希类同步原生实现（`venera_convert.cpp`，QuickJS 同步路径）
- [x] 本地图片页列表与自然排序阅读
- [x] DocumentPicker 导入漫画目录 / 压缩包
- [x] CBZ/ZIP 解压阅读（API 23 zlib）
- [x] 阅读器远程图 `cacheDir` 磁盘缓存（`ImageCacheUtil`）
- [x] `JsHtmlDomService` HTML 解析与 CSS 查询
- [x] `JsUiBridge` showMessage / launchUrl（API 23）
- [x] 7z/cb7 NAPI 解压骨架（`extract7z` + `fetch-lzma.ps1`）
- [x] `image` 拼图解码（`JsImageService` + `ComicImageResolver`）

### P1 — 格式与下载

- [x] ZIP/CBZ 解压（API 23 zlib.decompressFile）
- [x] 7z / cb7（NAPI，需 LZMA SDK）
- [x] PDF 本地阅读（`PdfReaderPage` / PDFKit）
- [x] EPUB 导入（ZIP 解压 + 图片扫描）
- [x] EPUB 文本/HTML 渲染阅读器（`EpubReaderPage` / ArkWeb）
- [x] `DownloadService` 队列管理（重试/删除/清除已完成）

### P2 — parity 功能

- [x] ArkWeb 登录与 Cookie 持久化（`WebCookieBridge` + JSON 沙箱）
- [ ] ArkWeb Cookie SQLite（上游 parity）
- [x] EhTag 标签翻译（`TagTranslationService` + `tags_tw.json`）
- [x] WebDAV `data_sync` 基础实现（收藏/历史/设置 JSON）
- [x] 探索页源推荐（`explore.load`）
- [x] 聚合搜索（`AggregatedSearchPage`）
- [x] 排行榜（`RankingPage` / `categoryComics.ranking`）
- [x] 探索页多 Tab（`explore_pages` 配置，对齐上游 ExplorePage）
- [x] 聚合搜索源勾选 UI（`SearchSourcesSettingsPage`）
- [ ] 关注更新完整实现（`FollowUpdatesPage` 占位已对齐入口）
- [ ] 图片收藏完整实现（`ImageFavoritesPage` 占位已对齐入口）
- [ ] 应用锁 / 生物识别

---

## 参考与致谢

- 原项目：[venera-app/venera](https://github.com/venera-app/venera) — GPL-3.0
- 漫画源配置：[venera-configs](https://github.com/venera-app/venera-configs)
- 标签翻译：[EhTagTranslation](https://github.com/EhTagTranslation/EhTagTranslation)

---

## 许可证

本项目继承上游 **GPL-3.0** 许可证。详见 [LICENSE](./LICENSE)（自上游同步）。
