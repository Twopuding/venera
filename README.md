# Venera for HarmonyOS

将开源漫画阅读器 [venera-app/venera](https://github.com/venera-app/venera) 完整移植到 **HarmonyOS 6.1.0 (API 23)**，采用 **HDS 沉浸光感材质**（`systemMaterialEffect`）与 Stage 模型 ArkTS 工程。

纯AI编写移植

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
| 收藏 | `favorites/*` | 🟡 进行中 | `FavoritesPage` 本地多选/复制移动/删除、关联网络夹同步；`NetworkFavoritesPanel` 转本地 + 分页列表 |
| 关注更新 | `follow_updates_page.dart` | ✅ 基础完成 | `FollowUpdatesPage` + `FollowUpdatesService` + `followUpdatesFolder` |
| 图片收藏 | `image_favorites_page/*` | 🟡 进行中 | `ImageFavoritesPage` 横向缩略图/多选删除；`ImageFavoritesPhotoViewPage` 大图 Swiper；`ImageFavoriteImageUtil` |
| 发现 / 探索 Tab | `explore_page.dart` | 🟡 进行中 | `ExplorePage` 可滚动 Tab+添加、`SingleExplorePanel` 网格/multiPart/mixed/viewMore/loadNext、FAB 刷新、Tab 重按回顶；`ComicGridTile`/`ComicListRow` 收藏·历史角标 |
| 漫画源管理 | `comic_source_page.dart` | ✅ 已完成 | `ComicSourcePage`（添加/删除/更新/官方列表/编辑/设置/登录）+ 31 个 venera-configs |
| 分类浏览 | `categories_page.dart` | 🟡 进行中 | `CategoriesPage` + `CategoryComicsPage` + 排行榜入口 |
| 搜索 | `search_page.dart` / `search_result_page.dart` | 🟡 进行中 | `SearchPage`（linkHandler 打开漫画/idMatcher/标签建议/onTagSuggestionSelected/选项 chips）+ `SearchResultPage`（顶栏 EhTag 建议/validateOptions/设置 sheet）+ 聚合搜索 |
| 排行榜 | `ranking_page.dart` | ✅ 基础完成 | `RankingPage` + `categoryComics.ranking.load` |
| 漫画详情 | `comic_details_page/*` | 🟡 进行中 | `ComicDetailPage`（继续阅读/操作栏/分组标签/收藏面板/评论页/分享/点赞）+ `ComicFavoritePanelPage` + `ComicCommentsPage` |
| 下载队列 | `download.dart` | 🟡 进行中 | `DownloadService` 重试/删除/清除已完成 |
| 漫画源 (JS) | `flutter_qjs` + `source.js` | ✅ 基础完成 | QuickJS NAPI + `JsEngineBridge` + `JsMessageHost` |
| 网络 HTTP | `rhttp` / Dio | 🟡 进行中 | `@kit.NetworkKit` `HttpService` |
| 设置 | `settings/*` | 🟡 进行中 | `ExploreSettingsPage` 对齐 `explore_settings.dart`；阅读模式/代理/WebDAV/清缓存/Cookie |
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
整体进度 ███████████████████░ 约 88%

阶段 0  工程脚手架 / API 23 配置     [████████████████████] 100%
阶段 1  HDS 沉浸光感主壳 UI          [████████████████████] 100%
阶段 2  数据层 (Preferences/RDB)      [████████████████████]  98%
阶段 3  本地书架与阅读器              [████████████████████]  95%
阶段 4  JS 漫画源引擎 (QuickJS)      [████████████████████] 100%
阶段 5  下载 / 归档 / 多格式          [██████████████░░░░░░]  70%
阶段 6  WebView / 同步 / 高级设置     [████████████░░░░░░░░]  60%
```

**最近更新（2026-05-23）**

- **发现 Tab**：`ExplorePage` 多 Tab / mixed·multiPart·loadNext / 「查看更多」；FAB 刷新与重按回顶
- **探索设置**：`ExploreSettingsPage`——漫画块模式·缩放、各页图源、角标开关、屏蔽词、搜索默认项等
- **漫画块角标**：`ComicGridTile` / `ComicListRow` 收藏书签与阅读进度（受设置开关控制）
- **搜索**：`SearchPage` + `SearchResultPage`——EhTag 建议、链接/ID 解析、选项 chips、改词重搜、自动语言过滤
- **漫画详情**：`ComicDetailPage` 操作栏·标签·收藏面板·评论/推荐；`ComicFavoritePanelPage`
- **收藏**：本地多选复制/移动；`NetworkFavoritesPanel` 网络列表与「转本地」；阅读器页图片收藏
- **图片收藏**：横向缩略图、多选删除、大图 `ImageFavoritesPhotoViewPage`
- **关注更新**：`FollowUpdatesPage` + `FollowUpdatesService` 基础检测流程
- **漫画源**：`ComicSourcePage` 管理 1:1（添加/更新/设置/登录）；首启默认三源；更新后 `reloadManager` 全量重载
- **启动与引擎**：`initRuntime` 初始化顺序与首启 index 死锁修复；`StartupSplash`；二级页 `SafeAreaInsets`
- **性能**：`loadSource` / `evaluate` 后台线程；图源分批装入，避免主线程卡死
- **主壳与首页**：`MainShell` 四栏导航；`HomePage` 仪表盘；`SecondaryPageHeader` 顶栏返回
- **阅读与格式**：`ReaderPage` 横竖翻页·滑条；PDF/EPUB；远程图缓存；拼图解码（`JsImageService`）
- **基础设施**：QuickJS NAPI + `JsEngineBridge`；内置 31 图源；WebDAV 同步；EhTag 翻译

> 更早条目见 Git 提交记录；编译通过后由 **HarmonyProject-build** 同步本节（≤18 条，见 `OVERRIDE.md`）。

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
| `foundation/favorites.dart` | `common/services/LocalFavoritesService.ets` + `FavoritesService.ets`（WebDAV 扁平列表） |
| `foundation/follow_updates.dart` | `common/services/FollowUpdatesService.ets` |
| `foundation/image_favorites.dart` | `common/services/ImageFavoriteService.ets` |
| `pages/follow_updates_page.dart` | `pages/follow/FollowUpdatesPage.ets` |
| `foundation/comic_source/*` | `common/services/ComicSourceService.ets` |
| `foundation/js_engine.dart` | `common/services/JsEngineBridge.ets` + `JsMessageHost.ets` |
| `foundation/data_sync.dart` | `common/services/WebDavSyncService.ets` |
| `image.dart` (拼图) | `common/services/JsImageService.ets` + `common/utils/ComicImageResolver.ets` |
| `network/download.dart` | `common/services/DownloadService.ets` |
| `network/app_dio.dart` | `common/services/HttpService.ets` |
| `pages/main_page.dart` | `pages/main/MainShell.ets` |
| `pages/comic_details_page/comic_page.dart` | `pages/comic/ComicDetailPage.ets` + `ComicFavoritePanelPage` + `ComicCommentsPage` |
| `pages/search_page.dart` | `pages/search/SearchPage.ets` |
| `pages/search_result_page.dart` | `pages/search/SearchResultPage.ets` |
| `pages/aggregated_search_page.dart` | `pages/search/AggregatedSearchPage.ets` |
| `pages/ranking_page.dart` | `pages/ranking/RankingPage.ets` |
| `pages/explore_page.dart` | `pages/explore/ExplorePage.ets` + `SingleExplorePanel.ets` + `ExplorePagesPickerPage.ets` |
| `pages/comic_source_page.dart` | `pages/sources/ComicSourcePage.ets` |
| `pages/settings/explore_settings.dart` | `pages/settings/ExploreSettingsPage.ets` + `CategoryPagesPickerPage.ets` + `BlockingWordsPage.ets` |
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
- [x] 关注更新基础实现（`FollowUpdatesPage` + `LocalFavoritesService` + `FollowUpdatesService`）
- [x] 图片收藏阅读器写入（`ReaderPage` + `ImageFavoriteService`；大图浏览/多选待补）
- [x] 收藏 Tab 网络收藏基础（`NetworkFavoritesPanel` + 侧栏/设置页；多选/转本地待补）
- [ ] 应用锁 / 生物识别

---

## 参考与致谢

- 原项目：[venera-app/venera](https://github.com/venera-app/venera) — GPL-3.0
- 漫画源配置：[venera-configs](https://github.com/venera-app/venera-configs)
- 标签翻译：[EhTagTranslation](https://github.com/EhTagTranslation/EhTagTranslation)

---

## 许可证

本项目继承上游 **GPL-3.0** 许可证。详见 [LICENSE](./LICENSE)（自上游同步）。
