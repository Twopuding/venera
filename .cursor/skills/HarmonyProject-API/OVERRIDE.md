# Venera 项目 — HarmonyProject-API 覆盖说明

供 **HarmonyProject-API** skill 在 Venera 仓库内开发时优先遵循。

## API 上限（固定）

| 项 | 值 |
|----|-----|
| **API N** | **23** |
| SDK 字符串 | **6.1.0(23)** |
| 运行时 | HarmonyOS Stage 模型 |
| 配置来源 | `AppScope/app.json5`：`minAPIVersion` / `targetAPIVersion` = 23；`build-profile.json5`：`compatibleSdkVersion` / `targetSdkVersion` = `6.1.0(23)` |

**禁止**引入 API 24+ 的 Kit、装饰器或权限，除非用户明确要求并同步修改上述配置文件。

## 本项目已验证的 Kit（API 23）

开发时优先复用仓库内已有 import 模式：

| Kit | 典型用途 |
|-----|----------|
| `@kit.AbilityKit` | `common.UIAbilityContext`、Ability 生命周期 |
| `@kit.ArkUI` | `router`、`promptAction`、ArkUI 组件 |
| `@kit.ArkData` | `preferences` |
| `@kit.CoreFileKit` | `fileIo`、`picker`、`BackupExtensionAbility` |
| `@kit.ArkTS` | `util`（Base64 等） |
| `@kit.NetworkKit` | `http`（`HttpService`） |
| `@kit.PerformanceAnalysisKit` | `hilog` |
| `@kit.BasicServicesKit` | `deviceInfo` |
| `@kit.UIDesignKit` | `hdsMaterial`（HDS 沉浸光感） |
| `@kit.PDFKit` | PDF 阅读（`PdfReaderPage`） |

新增能力前先 `grep` 仓库是否已有同类 Kit 用法。

## 项目特有 API 陷阱

- **AppStorage**：全局单例，勿 `import { AppStorage } from '@kit.ArkUI'`；见 `GlobalLoadingOverlay.ets`。
- **ArkWeb EPUB**：`EpubReaderPage` 使用 API 23 ArkWeb 加载 XHTML，勿改用未在 API 23 文档中的 Web 组件 API。
- **QuickJS NAPI**：仅通过 `libvenera_qjs.so` 暴露的桥接；不引入依赖更高 API 的第三方 NDK 库。
- **7z 解压**：`extract7z` NAPI + 可选 LZMA；构建依赖见 `HarmonyProject-build` OVERRIDE。
- **漫画源 JS**：引擎接口以 `source.js` / QuickJS 桥为准，ArkTS 侧不引入高版本 `@kit` 仅用于“方便”的捷径。

## 官方文档（编写前必查）

实现新功能或引入新 Kit 前，按 skill 正文查阅（并过滤 **API 23**）：

- [API 参考总览](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/development-intro-api)
- [最佳实践概览](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-best-practices-overview)
- [应用开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-dev-guide)
- [示例代码](https://developer.huawei.com/consumer/cn/samples/)

## 文案一致性

README、代码注释、会话回复中的版本须写：**HarmonyOS 6.1.0 (API 23)**，与 `README.md` 表头一致。
