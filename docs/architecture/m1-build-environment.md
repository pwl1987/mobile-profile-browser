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

M1 采用 Flutter 3.47.1 / Dart 3.13.1。原因不是盲目追新，而是锁定的 WebLibre 工作区当前存在 `hooks_riverpod 3.4.2 → Dart ^3.12.0` 以及 `riverpod_generator 4.0.8 → analyzer ^13.0.0` 的依赖链；原先 Flutter 3.44.4 / Dart 3.12.2 在 SDK 自带的 `meta 1.18.0` 与 `analyzer 13.3.0` 所需 `meta ^1.18.3` 之间产生解析冲突。更高的稳定 Dart/Flutter 基线可让 SDK 自带依赖与该工具链正常对齐。Flutter/Dart 的当前版本映射以官方发布信息和实际 CI 解析结果为准。citeturn805746search0turn805746search7

## 版本选择原则

1. 先满足锁定 WebLibre 工作区的实际 SDK/依赖约束；
2. 优先选择正式 stable 版本，不使用测试版；
3. 使用明确版本而不是 `stable` 浮动标签；
4. 每次升级 Flutter 都必须重新执行依赖解析、静态分析和 Android 构建；
5. 不修改上游源码来掩盖 SDK/依赖冲突，除非形成正式的、可审计的补丁。

## 为什么不使用上游 `.metadata`

当前锁定的 WebLibre commit 中，`.metadata` 不能作为唯一构建依据。M1 根据工作区 `pubspec.yaml` 和真实依赖求解结果确定 Flutter/Dart 版本，并在 CI 中显式校验。

## M1 构建流程

```text
检出 mobile-profile-browser
        ↓
初始化 vendor/weblibre 子模块
        ↓
校验 WebLibre commit
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
