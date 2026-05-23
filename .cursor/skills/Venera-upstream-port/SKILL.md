---
name: Venera-upstream-port
description: >-
  Project-only skill for the venera HarmonyOS port repo (d:/Project/venera).
  Do not apply in any other workspace. Ports venera-app/venera (Flutter) via local
  clone d:/Project/venera-upstream with 1:1 parity. Use only here when porting,
  移植, 对齐上游, parity, or syncing upstream.
---

# Venera 上游 1:1 移植

## 适用范围（必读）

- **仅在本仓库使用**：路径为 `d:/Project/venera` 的鸿蒙移植工程（含 `entry/src/main/ets/`、`AppScope/app.json5`）。
- **禁止**在其它项目、其它工作区、或个人 skill 目录中套用本 skill 的路径与流程。
- 打开非 venera 工作区时：**不要**加载或执行本 skill；即使用户提到「venera 移植」，也应提示切换到本仓库。
- 启用前自检：工作区根目录存在 `oh-package.json5` 且 `entry/src/main/ets/common/constants/AppConstants.ets` 含 `UPSTREAM_VERSION`；否则停止并说明当前不是 venera 鸿蒙工程。

本 skill 文件位于 **`.cursor/skills/Venera-upstream-port/`**（项目级），勿复制到 `~/.cursor/skills/`。

本仓库是 [venera-app/venera](https://github.com/venera-app/venera) 的鸿蒙移植。**一切功能移植必须以本地上游克隆为唯一事实来源**，禁止仅凭记忆、网页摘要或未同步的 GitHub 内容实现。

## 上游本地路径（固定）

| 项 | 值 |
|----|-----|
| 本地克隆根目录 | `d:/Project/venera-upstream` |
| 远程仓库 | `https://github.com/venera-app/venera.git` |
| 默认分支 | `master` |
| 上游 Dart 源码 | `d:/Project/venera-upstream/lib/` |
| 上游资源 | `d:/Project/venera-upstream/assets/` |
| 上游文档 | `d:/Project/venera-upstream/doc/` |

若目录不存在或 `remote` 不是上述地址，先按 [OVERRIDE.md](OVERRIDE.md) 克隆/校验，再继续移植。

## 何时必须先同步上游

在以下情况**开始前**执行「同步上游」：

- 用户提到上游有新版本、changelog、tag、或要对齐某次上游提交
- 需要对比/移植尚未在本仓库实现的上游文件
- 上游行为与当前鸿蒙实现不一致，需以最新上游为准排查
- 长期未 `pull`，不确定本地 `venera-upstream` 是否落后

日常小改且仅改已读过的上游文件、且确认无上游更新时，可跳过 `pull`，但仍须从 `venera-upstream` **读取**对应源文件。

## 同步上游（标准流程）

在 PowerShell 中（路径可按本机调整，逻辑不变）：

```powershell
$upstream = "d:\Project\venera-upstream"
if (-not (Test-Path "$upstream\.git")) {
  git clone https://github.com/venera-app/venera.git $upstream
} else {
  git -C $upstream fetch origin
  git -C $upstream pull --ff-only origin master
}
git -C $upstream log -1 --oneline
git -C $upstream status -sb
```

同步后记录最新 commit（写入移植说明或 README「最近更新」时可引用）。

若 `pull` 失败（本地有改动）：**不要**强行覆盖；向用户说明冲突，待清理后再移植。

## 1:1 移植工作流

1. **定位上游文件**  
   - 先查本仓库 `README.md` → `### 上游模块映射`  
   - 若无映射：在 `venera-upstream/lib/` 按页面/服务名搜索（如 `comic_source_page.dart`）

2. **通读上游实现**  
   用 Read/Grep 阅读完整 Dart 文件及直接依赖（models、foundation、network、utils）。记录：状态字段、用户可见流程、边界条件、持久化键名、与 JS 引擎的交互。

3. **确定鸿蒙落点**  
   遵循 [OVERRIDE.md](OVERRIDE.md) 目录约定；UI → `entry/src/main/ets/pages/`，逻辑 → `common/services/` 或 `common/utils/`。

4. **实现 parity（1:1）**  
   - 行为、数据结构、默认值、错误提示语义与上游一致  
   - 平台差异（Flutter Widget → ArkUI、Dio → `HttpService`、QJS NAPI）仅替换实现手段，**不改变产品行为**  
   - 文件头注释标明上游路径，例如：`对齐 upstream lib/pages/comic_source_page.dart`

5. **关联资产与脚本**  
   - 图标等：`venera-upstream/assets/`  
   - 漫画源脚本：仍用 `scripts/fetch-comic-sources.ps1`（来源 [venera-configs](https://github.com/venera-app/venera-configs)，非本 clone 主仓）  
   - `init.js` / JS 契约：对照 `venera-upstream` 内嵌或文档，与 `entry/src/main/resources/rawfile/` 保持一致

6. **更新移植文档**  
   - `README.md`：`功能对照`、`上游模块映射`、必要时 `AppConstants.UPSTREAM_VERSION`（与上游 `pubspec.yaml` version 一致）  
   - 由 **HarmonyProject-build** 在构建成功后合并「最近更新」

7. **构建验证**  
   执行 **HarmonyProject-build**；API 边界遵守 **HarmonyProject-API**。

## 禁止事项

- ❌ 不读 `venera-upstream` 就「按 Flutter 习惯」重写功能  
- ❌ 用 GitHub 网页/API 替代本地 clone 做实现依据（仅用于确认仓库 URL / tag 名）  
- ❌ 在 `venera-upstream` 内修改代码（只读参考；改动只在 `d:/Project/venera`）  
- ❌ 缩小 scope 时静默丢掉上游已有能力（若鸿蒙暂不可实现，在 README 标 ⏳ 并注释原因）

## 与其它 skill 的分工

| Skill | 职责 |
|-------|------|
| **Venera-upstream-port**（本 skill） | 上游同步、1:1 对照、模块映射、parity 范围 |
| **HarmonyProject-API** | API 23 / Kit 上限与官方文档 |
| **HarmonyProject-build** | hvigor 构建、修编译错误、README 进度同步 |

移植任务默认：**先本 skill → 再 HarmonyProject-API（写 ArkTS/Native 时）→ 最后 HarmonyProject-build**。

## 完成标准（向用户汇报）

- 已说明是否执行了上游 `pull` 及当前 commit  
- 列出对照的上游文件路径与鸿蒙文件路径  
- 行为差异（若有）明确标注为平台限制或未实现项  
- 构建通过或列出阻塞项

## 项目级约定

路径映射、Native/JS 对照、版本号更新见 [OVERRIDE.md](OVERRIDE.md)。
