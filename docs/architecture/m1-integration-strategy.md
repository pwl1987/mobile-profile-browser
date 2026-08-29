# M1 浏览器底座集成策略

## 目标

在保留 WebLibre 上游可同步能力的前提下，将 Mobile Profile Browser 的领域模型接入真实 Flutter/Gecko Android 应用。

## 结论

V0.1 采用三层结构：

```text
mobile-profile-browser
├── 自有 Domain / Policy / Test
├── Adapter / Integration
└── vendor/weblibre  ← Git Submodule
```

WebLibre 的 `apps/weblibre` 是完整 Flutter 应用，而不是一个可以简单作为普通 Dart package 引入的浏览器库。因此第一阶段不创建一个“套娃式”的第二 Flutter App 再去嵌入 WebLibre。

## 推荐集成方式

### 方案 A：上游 App 作为最终 Flutter App，使用补丁层注入本项目能力

优点：

- 最大程度复用 WebLibre 已完成的 Android、GeckoView、路由、UI、启动和存储基础设施；
- 不需要重新实现浏览器启动链；
- Profile / Container / Proxy 的既有代码可以直接复用。

缺点：

- 上游 `apps/weblibre` 仍然是应用源码边界；
- 需要通过补丁或上游分支承载本项目对 WebLibre App 源码的必要修改。

### 方案 B：复制 WebLibre App 到本项目

暂不采用。虽然源码边界简单，但会失去清晰的上游来源和升级路径，并把大量第三方应用源码与本项目 Domain 混在同一层。

### 方案 C：单独重做浏览器 App，再调用 WebLibre packages

暂不采用。WebLibre 当前应用级功能很多，强行从 package 层重组会重复实现启动、路由、Profile、Gecko 生命周期和 Android glue，收益不足。

## 最终工程策略

1. `vendor/weblibre` 继续以 Git Submodule 固定上游。
2. 本项目所有业务能力放入自己的 `packages/mobile_profile_*` 和 Adapter 层。
3. 对 WebLibre App 必须修改的文件，使用明确的补丁集或维护中的本项目 WebLibre 分支承载。
4. 不把业务逻辑长期直接散落在第三方目录。
5. 每次升级 WebLibre，先应用补丁、再执行构建和 Profile/网络回归测试。

## 第一批接入点

### Profile

```text
MobileProfile
    ↓
BrowserProfileAdapter
    ↓
WebLibre Profile
    ↓
Gecko Profile Directory
```

### Network

```text
NetworkRoute
    ↓
NetworkProviderRegistry
    ↓
WebLibre Proxy / sing-box Adapter
```

### Runtime

```text
RuntimeLifecycleManager
    ↓
BrowserRuntimeAdapter
    ↓
Gecko / Network Runtime
```

## 禁止在 M1 做的事情

- 不修改 Gecko C++ 指纹能力；
- 不加入随机 Canvas/WebGL/Audio 参数；
- 不在网页中注入大规模脚本伪造 navigator；
- 不把 Android 全局 VPN 当作天然的 Profile 级隔离；
- 不允许代理失败自动直连。

## M2 前置验收

M1 只需要证明：

1. 上游工程可重复获取依赖；
2. Flutter/Android Debug APK 可以构建；
3. App 可以在真实 Android 设备启动；
4. 上游 Profile 机制可被本项目 Adapter 调用；
5. Profile A/B 隔离可以开始做真机测试。

完成 M1 后再决定是否需要建立独立的本项目 WebLibre fork。此决定取决于补丁数量和上游修改深度，而不是预先猜测。