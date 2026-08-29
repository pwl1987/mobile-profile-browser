# M1 构建环境基线

## 目的

固定 Android 浏览器底座的工具链，避免 WebLibre 上游元数据与实际依赖版本不一致导致不可重复构建。

## 工具链

| 组件 | M1 基线 |
|---|---|
| Flutter | 3.38.5 stable |
| Dart | 3.10.4 |
| Android | GitHub Actions Ubuntu runner 上的 Android 工具链；真机版本另行验收 |
| WebLibre | `dc74be456efab51823bfc913114abb77af5c231c` |

Flutter 3.38.5 官方对应 Dart 3.10.4。选择该版本是因为锁定的 WebLibre 工作区包含示例包，其 SDK 约束要求 Dart `^3.10.4`；更早的 3.38.x 版本不能满足该约束。citeturn814351search0

## 为什么不使用上游 `.metadata`

当前锁定的 WebLibre commit 中，`.metadata` 记录的 Flutter revision 与实际工作区依赖约束不一致。M1 不把 `.metadata` 当作唯一构建依据，而是根据工作区 `pubspec.yaml` 的实际 SDK 下限选择可重复构建版本。

## M1 构建流程

```text
检出 mobile-profile-browser
        ↓
初始化 vendor/weblibre 子模块
        ↓
校验 WebLibre commit
        ↓
安装 Flutter 3.38.5 / Dart 3.10.4
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
