---
name: HarmonyProject-build
description: >-
  Build any HarmonyOS hvigor project (Stage model, ArkTS, optional native C++),
  parse compile errors, fix them, and on BUILD SUCCESSFUL sync README.md with
  this session's changes. Use after modifying .ets / native / module config, or
  when the user asks to compile, verify the build, or check compile errors in
  a HarmonyOS / DevEco / OpenHarmony repository.
---

# HarmonyOS Project Build & Compile Check

通用鸿蒙工程构建 skill，适用于 **DevEco Studio + hvigor** 的 Stage 模型 HAP/APP 工程（含 ArkTS 与可选 Native 模块）。

## When to run

- 修改了 `**/*.ets`、`entry/` 或任意 HAP 模块下的 ArkTS / 资源 / `module.json5`
- 修改了 `**/cpp/`、`CMakeLists.txt` 等原生构建文件
- 用户要求编译、验包、排查 ArkTS / Native 编译错误

## Discover project layout

从仓库根目录识别（路径因工程而异）：

| 文件 / 目录 | 含义 |
|-------------|------|
| `hvigorfile.ts`、`oh-package.json5` | 鸿蒙工程根 |
| `build-profile.json5` | SDK 版本、`modules` 列表 |
| `AppScope/app.json5` | 应用级 `minAPIVersion` / `targetAPIVersion` |
| `entry/` 或其它 `*/src/main/ets/` | 主模块 ArkTS 源码 |
| `entry/src/main/cpp/` | 可选 Native（CMake + Ninja） |
| `.hvigor/outputs/build-logs/build.log` | 完整构建日志 |
| `local.properties` | SDK 路径（DevEco 生成，通常不入库） |

**目标 API**：以 `AppScope/app.json5` 与 `build-profile.json5` 为准；代码与 Kit 引用不得高于项目声明的 API。

## Prerequisites

- DevEco Studio 已安装，且 SDK 版本 ≥ 工程 `compatibleSdkVersion`
- 仓库根目录存在 `local.properties`（或 DevEco 已配置 SDK）
- 若工程 README / `scripts/` 要求预拉取第三方源码（如 QuickJS），先执行对应脚本再构建

## Build commands

在**仓库根目录**执行（将路径换成本机 DevEco 安装位置）：

### Windows

```powershell
& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --no-daemon
```

### macOS / Linux

```bash
hvigorw assembleHap --no-daemon
```

若 `hvigorw` 已在 PATH 中，可直接：

```bash
hvigorw assembleHap --no-daemon
```

### 其它常见目标

| 命令 | 用途 |
|------|------|
| `assembleHap` | 编译 HAP（默认） |
| `assembleApp` | 编译 APP 包 |
| `clean` | 清理增量产物 |
| `compileArkTS` | 仅 ArkTS（部分工程可用） |

多模块工程以 `build-profile.json5` 中的模块名为准；日志里 `Failed :{module}:...` 即出错模块。

## Interpreting output

| Signal | Meaning |
|--------|---------|
| `BUILD SUCCESSFUL` / exit code 0 | 通过 → **执行 README 同步（见下）** |
| `Failed :...@CompileArkTS` | ArkTS 类型/语法错误 → 修 `.ets` |
| `Failed :...@BuildNativeWithNinja` | C++/CMake 错误 → 修对应 `cpp/` |
| `Failed :...@ProcessLibs` 等 | 链接 / 依赖问题 → 查 CMake、`oh-package` |
| 仅 `WARN:` | 警告；除非用户要求，不视为失败 |

日志被截断时读取：

```
.hvigor/outputs/build-logs/build.log
```

快速提取错误（PowerShell）：

```powershell
Select-String -Path ".hvigor\outputs\build-logs\build.log" -Pattern "ERROR:|Error Message:|At File:"
```

## Fix loop

1. 在仓库根目录执行构建命令。
2. 收集所有 `ERROR:` / `Error Message:` / `At File:` 行，按文件分组。
3. **一次性修复**所有报错文件（不要修一个就停）。
4. 重新构建直至 exit code 0。
5. **仅成功时**：同步 `README.md`（见下节）。
6. 向用户报告：失败原因、修复内容、最终构建状态、README 更新了哪些段落。

## README sync (required after BUILD SUCCESSFUL)

当 `hvigorw` 构建 **exit code 0**，且**本会话有实质性代码/配置改动**时，更新仓库根目录 `README.md`。纯验证构建、零改动时可跳过。

### 通用原则

- **跟随现有 README 结构**，不要强行改成某一项目的模板。
- 只写绿构建后真实存在的功能；不写计划或猜测。
- API 版本表述与 `app.json5` / README 既有说法一致。
- 不新建独立 changelog 文件（除非项目已有约定）；优先更新 README。
- 不改许可证、致谢、环境表等与本次改动无关的大段内容。

### 常见段落（按 README 中实际标题匹配）

| 若 README 含有… | 则更新… |
|-----------------|--------|
| 进度 / Progress / 完成度 | 百分比或阶段条 |
| 功能列表 / Feature / 对照表 | 状态列（✅🟡⏳）与实现说明 |
| `最近更新` / `Changelog` / `What's New` | 日期改为**当天**，**顶部插入**本会话要点（≤18 条，去重） |
| Roadmap / 路线图 / TODO | 已完成项改为 `[x]` |
| 工程结构 / Project structure | 新增目录或模块时补一行 |
| 构建说明 / Build | 新增强制预构建步骤时补充 |

### 条目格式示例

```markdown
- **功能名**：`ComponentOrService` 一句话说明（HarmonyOS API N / 所用 Kit）
```

### 项目级 override

若仓库存在 `.cursor/skills/HarmonyProject-build/OVERRIDE.md` 或 README 内「Agent / 构建约定」小节，**优先遵循**其中的段落名、进度表格式与专有术语（例如移植类 README 的「功能对照」「上游模块映射」）。

## HarmonyOS / ArkTS pitfalls (API 12+)

### AppStorage（API 23 常见）

`AppStorage` 为 ArkUI **全局**单例。API 23 下 `@kit.ArkUI` 可能只导出 `AppStorageV2`，勿错误 import：

```typescript
// Wrong
import { AppStorage } from '@kit.ArkUI';

// Correct — global AppStorage, no import
AppStorage.setOrCreate('key', value);
```

### ArkTS 严格类型

规则 `arkts-no-any-unknown`：避免 `any` / `unknown`。`AppStorage.get` 推断失败时用显式联合类型：

```typescript
const raw: string | undefined = AppStorage.get('key') as string | undefined;
```

### Native 模块

CMake 报缺少源码时，查阅工程 `scripts/` 或 README 的预拉取步骤，**不要**假设固定脚本名。

### 多模块

错误任务名含模块前缀（如 `entry:`、`feature:`），只在对应模块目录下改代码。

## Optional: clean rebuild

增量构建异常时：

```powershell
hvigorw clean --no-daemon
hvigorw assembleHap --no-daemon
```

## Success criteria

- `hvigorw assembleHap`（或用户指定的 hvigor 任务）exit code 0
- 最终 `build.log` 中无 `CompileArkTS` / Native 相关 `ERROR:`
- 本会话有代码改动且构建通过时，已按上文同步 `README.md`（用户明确说 skip docs 除外）
