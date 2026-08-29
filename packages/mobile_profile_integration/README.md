# 集成适配层

本包连接 Mobile Profile Browser 自有领域模型与具体浏览器/网络运行时。

## 原则

- Domain 不依赖 Flutter、GeckoView、Android `VpnService`、SSH client 或 sing-box。
- 上游 WebLibre 通过 Adapter 接入。
- Provider Runtime 使用统一接口，具体实现可以由 WebLibre、sing-box 或 Android 原生层提供。
- Adapter 不拥有 Profile 的业务状态；业务状态由 Domain Repository 与 Runtime 生命周期管理器负责。

## 当前目标

```text
MobileProfile
      ↓
BrowserProfileAdapter ─────→ WebLibre Profile
      ↓
BrowserRuntimeAdapter ─────→ Gecko/浏览器运行时

NetworkRoute
      ↓
NetworkRuntimeFactory ─────→ Direct / Proxy / sing-box / SSH / VPN-TUN / Tor
```

当前仅建立契约，尚未宣称 WebLibre Runtime 已接通。实际实现必须通过 Android 构建和真机测试验证。
