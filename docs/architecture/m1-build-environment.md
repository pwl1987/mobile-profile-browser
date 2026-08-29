# M1 构建环境基线

## 目的

固定 Android 浏览器底座的工具链，避免 WebLibre 上游元数据与实际依赖版本不一致导致不可重复构建。

## 工具链

| 组件 | M1 基线 |
|---|---|
| Flutter | 3.47.1 stable |
| Dart | 3.13.1 |
| Android | GitHub Actions Ubuntu runner 上的 Android 工具链；真机版本另行验收 |
| WebLibre | `dc74be456efab51823bfc913114abb77af5c231c` |

当前 M1 使用 Flutter 3.47.1 / Dart 3.13.1。该组合能够满足锁定 WebLibre 工作区的 Dart SDK 约束；具体依赖解析必须以 CI 实际结果为准。

## 版本选择原则

1. 先满足锁定 WebLibre 工作区实际 SDK/依赖约束；
2. 优先选择正式 stable 版本；
3. 固定到明确版本，不使用浮动版本；
4. 每次升级 Flutter 都必须重新执行依赖解析、静态分析和 Android 构建；
5. 不通过修改上游源码掩盖 SDK/依赖冲突，必要补丁必须进入本项目补丁层并可审计。

## 上游补丁层

本项目不直接提交修改后的 WebLibre 子模块内容，而是在：

```text
patches/weblibre/
```

维护针对固定上游 commit 的最小补丁。

CI 顺序：

```text
检出子模块
   ↓
校验上游 commit
   ↓
应用本项目补丁
   ↓
依赖解析
   ↓
静态分析
   ↓
APK 构建
```

如果补丁无法正向或反向匹配，构建立即失败，避免上游升级后悄悄继续构建。

## 当前已知兼容性补丁

### material_ui / ColorScheme

当前 WebLibre 锁定版本使用 `dynamic_color 2.x`，而其新版本已经迁移到独立的 `material_ui` 包。Flutter 3.47 环境下，`DynamicColorBuilder` 提供的 `ColorScheme` 与旧的 `package:flutter/material.dart` 类型可能出现不兼容。

本项目维护单独补丁，使 `main.dart` 使用与 `dynamic_color` 当前 API 一致的 Material UI 类型，而不修改上游其他模块。

## M1 构建流程

```text
检出 mobile-profile-browser
        ↓
初始化 vendor/weblibre 子模块
        ↓
校验 WebLibre commit
        ↓
应用 WebLibre 补丁层
        ↓
生成上游要求但源码树缺失的资源目录
        ↓
安装 Flutter 3.47.1 / Dart 3.13.1
        ↓
在 WebLibre 工作区执行 dart pub get
        ↓
flutter analyze
        ↓
flutter build apk --debug
        ↓
上传 APK 工件
```

## 当前边界

M1 构建通过不等于 Profile 隔离通过，也不等于 Find N3 真机通过。

下一道验收仍然是：

1. APK 可安装；
2. OPPO Find N3 可以启动；
3. HTTPS 基础浏览正常；
4. Profile A/B 的 Cookie、LocalStorage、IndexedDB 等状态不能串联。
