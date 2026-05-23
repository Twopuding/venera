# Venera 项目 — HarmonyProject-build 覆盖说明

本文件供 **HarmonyProject-build** skill 在 Venera 仓库内同步 README 时使用。其它鸿蒙项目可自建同名 `OVERRIDE.md` 或省略。

## 目标 SDK

**HarmonyOS 6.1.0 (API 23)** — 文案与 Kit 引用保持一致。

## README 必更新段落（Venera 专用标题）

1. **`## 移植进度总览`** — `整体进度` 与 **阶段 0–6** 进度条
2. **`## 功能对照（上游 → 鸿蒙）`** — 状态列与 **主要实现** 列
3. **`**最近更新（YYYY-MM-DD）**`** — 日期 + 顶部插入 ≤18 条
4. **`## 后续开发路线图`** — P0 / P1 / P2 勾选
5. **`### 上游模块映射`**（有新增页面/服务映射时）

## 构建前可选步骤（Venera）

```powershell
.\scripts\fetch-quickjs.ps1
.\scripts\fetch-comic-sources.ps1
# 7z/cb7 原生解压：
.\scripts\fetch-lzma.ps1
```

QuickJS 缺失时：`entry/src/main/cpp/third_party/quickjs-ng-temp` 不存在则先执行 `fetch-quickjs.ps1`。

## 项目特有编译陷阱

- **AppStorage**：见 skill 正文；`GlobalLoadingOverlay.ets` 使用全局 `AppStorage`
- **Native QuickJS**：CMake 失败时运行 `fetch-quickjs.ps1`
