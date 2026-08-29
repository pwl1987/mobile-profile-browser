# M1 构建环境基线

## 目的

固定 Android 浏览器底座的工具链，避免 WebLibre 上游元数据与实际依赖版本不一致导致不可重复构建。

## 工具链

| 组件 | M1 基线 |
|---|---|
| Flutter | 3.32.8 stable |
| Dart | 3.8.1 |
| Android | GitHub Actions Ubuntu runner 上的 Android 工具链；真机版本另行验收 |
| WebLibre | `dc74be456efab51823bfc913114abb77af5c231c` |

Flutter 3.32 系列对应 Dart 3.8 系列；Dart 3.8.1 对应 Flutter 3.32.8。M1 以实际依赖约束为准，不以 WebLibre 仓库中可能滞后的 `.metadata` 版本声明作为构建依据。

## 为什么不使用上游 `.metadata`

当前锁定的 WebLibre commit 中，`.metadata` 记录的 Flutter revision 对应 Flutter 3.22.2，但同一 commit 的应用 `pubspec.yaml` 要求 Dart `>=3.8.0 <4.0.0`。直接使用 `.metadata` 的 Flutter 版本会导致依赖解析无法满足。

因此本项目把 Flutter/Dart 作为自己的可重复构建输入单独锁定，并在 CI 中校验 Dart 版本。

## M1 构建流程

```text
检出 mobile-profile-browser
        ↓
初始化 vendor/weblibre 子模块
        ↓
校验 WebLibre commit
        ↓
安装 Flutter 3.32.8 / Dart 3.8.1
        ↓
flutter pub get
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
