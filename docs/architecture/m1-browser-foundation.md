# M1 浏览器底座实施基线

## 目标

将经过审计的 WebLibre 固定版本接入本项目，并建立第一个可重复构建、可安装、可启动的 Android 浏览器基线。

## 当前上游

- WebLibre：`FaFre/WebLibre`
- 锁定 Commit：`dc74be456efab51823bfc913114abb77af5c231c`
- GeckoView / Mozilla Components：以上游锁定版本为准

WebLibre 当前采用 Flutter + Gecko/GeckoView，并已经包含 Profile、Container、Cookie Isolation、Proxy、Tor 和 sing-box 等基础能力。正式集成前仍然需要在本项目中重新验证这些能力的实际边界。

## 集成原则

1. 上游通过 Git Submodule 固定，不直接复制并失去来源追踪。
2. 本项目自有 Domain、Adapter、UI 与安全策略不得放入上游源码目录。
3. 首次集成只追求“能构建、能启动、能浏览”，不在同一阶段引入复杂指纹修改。
4. Android 真机验收优先于模拟器验收。
5. 任何 Profile 隔离能力在发布前必须有独立测试证据。

## M1 Gate

### Gate M1-01：源码基线

- 子模块能够初始化；
- 子模块 commit 与 `upstream-lock.md` 一致；
- 许可证文件完整。

### Gate M1-02：Flutter/Android 构建

- `flutter pub get` 成功；
- `flutter analyze` 无阻断级错误；
- Android Debug APK 可以生成。

### Gate M1-03：真机启动

- Android 8+ 环境可启动；
- OPPO Find N3 能安装；
- 浏览器可正常打开 HTTPS 页面；
- 应用退出后可以再次启动。

### Gate M1-04：Profile 最小验证

至少建立两个 Profile，并验证：

- Cookie 不串；
- LocalStorage 不串；
- IndexedDB 不串；
- 关闭并重新打开后状态仍归属于原 Profile。

## 当前状态

本文件只定义 Gate，不代表 Gate 已经通过。Android APK 和 Find N3 真机测试必须在实际运行环境中执行并记录证据。
