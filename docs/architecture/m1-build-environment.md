# M1 构建环境基线

## 目的

固定 Android 浏览器底座的工具链，避免 WebLibre 上游元数据与实际依赖版本不一致导致不可重复构建。

## 工具链

| 组件 | M1 基线 |
|---|---|
| Flutter | 3.44.4 stable |
| Dart | 3.12.2 |
| Android | GitHub Actions Ubuntu runner 上的 Android 工具链；真机版本另行验收 |
| WebLibre | `dc74be456efab51823bfc913114abb77af5c231c` |

Flutter 官方归档显示，Flutter 3.44.4 对应 Dart 3.12.2。选择该组合是因为当前锁定的 WebLibre 工作区依赖 `hooks_riverpod ^3.4.2`，而该版本要求 Dart `^3.12.0`；Flutter 3.38.5 / Dart 3.10.4 已经无法满足依赖解析。citeturn492152search3turn596708search3

## 版本选择原则

M1 不盲目追随当前最新 Flutter，而优先选择满足上游依赖、同时尽量减少与锁定 WebLibre commit 之间版本跨度的稳定版本。当前选定 3.44.4，避免过早引入 Flutter 3.47 的额外迁移变化。

## 为什么不使用上游 `.metadata`

当前锁定的 WebLibre commit 中，`.metadata` 不能作为唯一构建依据。M1 根据实际工作区 `pubspec.yaml` 和依赖求解结果确定 Flutter/Dart 版本，并在 CI 中显式校验。

## M1 构建流程

```text
检出 mobile-profile-browser
        ↓
初始化 vendor/weblibre 子模块
        ↓
校验 WebLibre commit
        ↓
安装 Flutter 3.44.4 / Dart 3.12.2
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
