# Mobile Profile 浏览器适配包

把 `MobileProfile` 映射到 WebLibre 浏览器 Profile，并编排启动/删除流程。

## 结构

```text
MobileProfileService / MobileProfileRepository   （domain）
        ↓
ProfileLaunchService                              （本包）
        ↓                          ↓
WebLibreProfileMapper      BrowserProfileAdapter（integration 契约）
        ↓                          ↓
browser_profiles 绑定表      真实 WebLibre/GeckoView 实现（M3 真机阶段）
（storage schema v2）        或 FakeWebLibreBrowserProfileAdapter（测试）
```

## 上游对齐事实

WebLibre（b4721ae6）的浏览器 Profile 是
`{filesDir}/weblibre_profiles/profile-<uuid36>/` 目录，Gecko 存储在其中的
`files/mozilla/`；上游 Profile.id 为 UUID。本包的
`WebLibreProfileMapper` 把 `browser-<uuid>` 引用映射为该目录身份，常量
升级上游时需按 `docs/upstream/weblibre.md` 核对。

## 测试

```bash
dart pub get
dart analyze
dart test
```
