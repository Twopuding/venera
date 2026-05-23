---
name: HarmonyProject-API
description: >-
  Enforces HarmonyOS project API ceiling on every code change: resolve target API
  from app.json5 and build-profile.json5, consult Huawei official API reference,
  best practices, dev guides, and samples before coding, then use only Kits/APIs
  at that level. Use when editing ArkTS, native, module config, or HarmonyOS
  features in a DevEco / hvigor / Stage-model repository.
---

# HarmonyOS Project API Compliance

鸿蒙工程内**所有**代码与配置改动，必须严格遵循项目声明的**最高可用 API**（以 `targetAPIVersion` / `targetSdkVersion` 为准，不得超出）。

## When to apply

- 仓库根存在 `hvigorfile.ts` 或 `oh-package.json5`（鸿蒙工程）
- 修改 `**/*.ets`、`module.json5`、`app.json5`、`build-profile.json5`、Native 模块
- 新增 Kit 引用、系统能力、权限、UI 组件或 NAPI 接口
- 用户要求按项目 API 标准开发，或提及 HarmonyOS API / SDK 版本

与 **HarmonyProject-build** 并行：本 skill 管 **API 合规**；build skill 管 **编译与 README 同步**。

## Resolve project API ceiling (mandatory first step)

在写或改任何代码前，读取并记录（路径因工程而异）：

| 来源 | 字段 | 含义 |
|------|------|------|
| `AppScope/app.json5` | `minAPIVersion` | 运行时可声明的最低 API |
| `AppScope/app.json5` | `targetAPIVersion` | 应用目标 API（**主要上限**） |
| `build-profile.json5` → `products[]` | `compatibleSdkVersion` | 编译兼容 SDK（如 `6.1.0(23)`） |
| `build-profile.json5` → `products[]` | `targetSdkVersion` | 编译目标 SDK |

**有效上限** = `targetAPIVersion` 与 `targetSdkVersion` 括号内数字的**较小者**（二者应一致；不一致时以较小者为准并提醒用户修正配置）。

将结果记为 **API N**（例如 `23`），后续所有选型不得要求 **API > N**。

### 项目级 override

若存在 `.cursor/skills/HarmonyProject-API/OVERRIDE.md`，**优先**遵循其中的 Kit 列表、已知陷阱与禁用写法。

## Official documentation lookup (before writing code)

在**动手写或改代码之前**（解析完 **API N** 之后），必须通过华为开发者联盟官方文档查证拟用 API、Kit、权限与实现方式。**禁止**仅凭训练记忆或第三方博客直接落笔。

使用 **WebFetch** / **WebSearch** 访问下列入口（按场景选用，可组合）：

| 入口 | URL | 用途 |
|------|-----|------|
| API 参考总览 | [development-intro-api](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/development-intro-api) | Kit / 模块 / 类 / 方法签名、**起始 API 版本**、是否废弃 |
| 最佳实践 | [bpta-best-practices-overview](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-best-practices-overview) | 架构、界面、功能、多设备、安全、质量、工程工具等场景化推荐 |
| 应用开发指南 | [application-dev-guide](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-guide) | Stage 模型、工程结构、Ability、权限、生命周期、应用配置 |
| 示例代码 | [samples](https://developer.huawei.com/consumer/cn/samples/) | 与当前任务相近的官方 Sample，对照目录结构与调用方式 |

### 查阅流程

1. **明确关键词**：Kit 名（如 `NetworkKit`）、类/方法名、能力名（如 `DocumentPicker`）、场景（如「分段式拍照」「应用间跳转」）。
2. **从总览页进入**：先打开上表对应 URL，再在站内搜索或跟随链接到具体 Kit 参考 / 指南章节 / Sample 详情。
3. **核对 API N**：文档中「起始版本」「Since API version」必须 **≤ API N**；仅高版本可用则换 API N 内等价方案，不得升项目 SDK。
4. **对照 Sample**：功能非 trivial 时，在 [samples](https://developer.huawei.com/consumer/cn/samples/) 搜索同类场景，借鉴模块划分与 `@kit.*` import，仍须满足 API N。
5. **对照仓库**：官方结论与 `grep` 本仓库同类用法一致后再实现；冲突时以 **API N + 项目 OVERRIDE** 为准。

### 页面抓取失败时

华为文档站多为动态渲染，WebFetch 可能只返回壳页面。此时：

```text
WebSearch: site:developer.huawei.com <Kit或API名> API <N> HarmonyOS
```

或直接在 DevEco / 浏览器打开上述链接人工定位；**仍须**在实现前完成版本核对，不得跳过。

### 何时必须查文档

| 场景 | 优先查 |
|------|--------|
| 新 Kit / 新系统能力 / 新权限 | API 参考 + 应用开发指南 |
| 新页面、导航、动效、多设备布局 | 最佳实践（界面/一多）+ samples |
| 网络、媒体、图形、NDK | 最佳实践（功能开发）+ API 参考 |
| 架构拆分、模块化 | 最佳实践（架构设计） |
| 安全、隐私、数据 | 最佳实践（应用安全）+ 指南权限章节 |

仅改错别字、重命名局部变量等**不涉及 API 选型**的微调可跳过文档查阅。

## Hard rules

1. **禁止**使用需要高于 **API N** 的类、装饰器、Kit 模块、系统参数或权限（含仅在高版本文档出现的 API）。
2. **禁止**通过抬高 `targetAPIVersion` / `targetSdkVersion` 来“解决”编译错误；应改用 **API N** 下可用的等价实现。
3. **禁止**从网络示例或旧版 Flutter/安卓代码直接照搬未在 API N 文档中确认的鸿蒙 API。
4. **必须**使用 Stage 模型与当前主流 Kit 导入（API 12+），避免已废弃的 `@ohos.*` 全局模块写法（除非项目仍在 API 9–11 且 README 明确要求）。
5. **必须**满足 ArkTS 严格规则（`arkts-no-any-unknown` 等）：显式类型，避免 `any` / `unknown`。
6. 新增 `requestPermissions`、ExtensionAbility、后台任务等，须确认 **API N** 支持且已在 `module.json5` / `app.json5` 中合法声明。
7. Native（C++/NAPI）仅使用 OpenHarmony/HarmonyOS **API N** 对应 NDK 与头文件中存在的接口。

## Kit and import conventions (API 12+, typical API 23)

```typescript
// Prefer @kit.* (version-specific availability — verify against API N)
import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { fileIo, picker } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
```

选型前对照：

- 已通过 [development-intro-api](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/development-intro-api) 或站内 Kit 页确认 **起始版本 ≤ API N**
- DevEco API 树中该 Kit 是否标记为 Available（与文档结论一致）
- 本仓库已有文件的 import 风格（保持一致）

### AppStorage（API 23 常见）

`AppStorage` 为 ArkUI **全局**单例。API 23 下勿从 `@kit.ArkUI` 错误 import `AppStorage`：

```typescript
// Wrong
import { AppStorage } from '@kit.ArkUI';

// Correct
AppStorage.setOrCreate('key', value);
```

`AppStorage.get` 推断失败时使用显式联合类型，勿用 `any`。

## Decision workflow for new code

```
1. 解析 API N（见上表）
2. 查 OVERRIDE.md（若有）
3. 查阅华为官方文档（API 参考 / 最佳实践 / 开发指南 / samples）并核对起始版本 ≤ API N
4. 在仓库内 grep 同类用法（Kit、组件、权限）
5. 仅采用文档 + 已有代码证明可用的 API 实现
6. 若 API N 无等价能力 → 说明限制，改产品设计或记入 Roadmap，不偷偷升 API
7. 改完后：注释与 README 中的 API 表述须写 HarmonyOS x.y.z (API N)
```

## Anti-patterns

| 做法 | 问题 |
|------|------|
| 未查官方文档直接写 Kit / 权限 | 易用错版本或废弃 API |
| 复制 API 24+ 示例的 `@kit.*` 或装饰器 | 高于项目上限，编译或上架失败 |
| `// @ts-ignore` / `as any` 绕过 ArkTS | 掩盖 API/类型不兼容 |
| 使用已废弃 `router.pushUrl` 旧签名（若 API N 已变更） | 应用项目内已有 router 模式 |
| 为单个功能单独提高 `minAPIVersion` | 须与用户确认；默认保持与 `targetAPIVersion` 一致 |
| 混用 FA 模型 API（`FeatureAbility` 等） | Stage 工程不适用 |

## Verification before finishing

- [ ] 已读取 `app.json5` + `build-profile.json5` 并写明 **API N**
- [ ] 涉及 API 选型的改动已查阅官方文档（API 参考 / 最佳实践 / 指南 / samples 至少其一）且起始版本 ≤ API N
- [ ] 新增 import 均属于 API N 可用 Kit
- [ ] 无 `any` / 无高于 N 的系统 API
- [ ] 权限与 `module.json5` 能力在 API N 合法
- [ ] 用户可见文案（注释、README、提交说明）中的 SDK 版本与 **API N** 一致
- [ ] 若改动涉及构建，继续执行 **HarmonyProject-build** 验证编译

## README / 文档表述

与 **HarmonyProject-build** 一致：功能说明中标注 `HarmonyOS API N` 或 `6.x.x(N)`，与 `AppScope/app.json5` 一致，不写“计划使用 API 24”类未实现表述。

## Optional per-project file

各仓库可添加 `.cursor/skills/HarmonyProject-API/OVERRIDE.md`，写明：

- 固定 **API N** 与 SDK 字符串
- 本项目常用 Kit 清单
- 项目特有陷阱（如 QuickJS NAPI、HDS 材质 API）

通用 skill 不硬编码单一产品名；**OVERRIDE** 承载仓库差异。
