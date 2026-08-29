# WebLibre 上游代码审计

> 本文档记录 Mobile Profile Browser 对 WebLibre 的代码级复用判断。每次上游升级都必须重新验证，不以 README 描述替代代码审计。

## 1. 审计基线

- 项目：WebLibre
- 仓库：<https://github.com/FaFre/WebLibre>
- 当前锁定 commit：`dc74be456efab51823bfc913114abb77af5c231c`
- Flutter 上游 `.metadata` 的 revision 对应 Flutter 3.22.2，但该 commit 的应用 `pubspec.yaml` 已要求 Dart `>=3.8.0 <4.0.0`；本项目因此单独锁定 Flutter 3.32.8 / Dart 3.8.1 作为 M1 构建基线。
- 许可证：上游当前为 AGPL-3.0，正式发布前必须完成许可证及第三方依赖合规审查。

## 2. 浏览器底座结论

### 强复用

- GeckoView / Mozilla Android Components
- Profile 文件系统
- 浏览器存储与会话基础设施
- Secure Storage
- Startup 配置与恢复机制
- sing-box Android runtime
- 现有 Proxy Domain 基础设施

WebLibre 的 Profile 实体使用稳定 UUID，并由文件系统按 `weblibre_profiles/profile-<UUID>/` 建立目录边界。Profile 元数据采用临时文件写入后 rename 的原子方式保存；Mozilla 数据进一步位于 Profile 的 `files/mozilla/` 下。这个实现是我们 Profile Storage 隔离的主要复用基础。

### 需要建立本项目领域层

- `MobileProfile`
- `DeviceProfile`
- `NetworkRoute`
- `SecurityPolicy`
- Profile 生命周期编排
- `RuntimeInstance`

## 3. Profile 隔离审计结论

上游近期有专门的 Profile handling 重构，并在 Android 启动阶段增加了 Profile Arbiter / 启动提交机制，避免 profile-sensitive 状态在未确定 Profile 前进入全局应用存储。

这个方向与本项目的核心安全目标高度一致，但**不能因此直接认定隔离已经通过**。本项目仍必须用至少两个实际 Profile 在真机上验证 Cookie、LocalStorage、IndexedDB、权限、缓存和恢复路径。

### 当前采用的集成原则

```text
MobileProfile
├── browserProfileRef
├── deviceProfileRef
├── networkRouteRef
└── securityPolicyRef
        ↓
WebLibre Profile
        ↓
Gecko Profile Directory
```

不直接修改 WebLibre 的 Profile 领域对象来容纳本项目业务字段。

## 4. 网络能力结论

WebLibre 已存在 Proxy Domain 和 sing-box runtime。当前实现支持多 Profile 的 sing-box outbound，并为活动 Profile 提供本地 SOCKS 接入能力。

因此不重新实现：

- SOCKS 基础设施；
- sing-box 协议栈；
- 基础 TUN runtime。

本项目建立自己的：

```text
NetworkRoute
   ↓
ProviderRegistry
   ↓
ProviderRuntime
```

负责 Profile 与上游网络运行时之间的编排。

## 5. SSH 结论

SSH 只是 Provider，不是网络层总抽象。

首选路径：

```text
Profile
  ↓
NetworkRoute(SSH)
  ↓
sing-box SSH outbound
  ↓
VPS
  ↓
Internet
```

只有在实际能力不足时才考虑独立 Android SSH Runtime。

SSH 私钥、密码和其他秘密只通过安全存储提供给运行时，不进入普通 Profile JSON。

## 6. Find N3 结论

OPPO Find N3 必须作为折叠设备处理：

```text
DeviceProfile
├── mainDisplay
├── coverDisplay
└── posture
```

厂商规格只作为初始参考。网站真正可见的 viewport、DPR、触控、Client Hints、WebGL 等需要在真机运行时观测后建立基线。

## 7. 当前禁止事项

- 不复制上游全部代码后无记录地修改。
- 不把指纹逻辑散落在 UI、网页脚本和代理代码中。
- 不把 SSH 私钥写入普通 Profile JSON。
- 不在代理失败时自动静默回落直连。
- 不以修改 User-Agent 宣称已经完成指纹隔离。
- 不把厂商硬件规格表直接当成浏览器指纹实测结果。

## 8. 下一轮必须验证

1. Profile 创建、删除、切换完整调用链。
2. Gecko Runtime 与 Profile directory 的真实绑定关系。
3. Profile / Container / Cookie isolation 的真实边界。
4. sing-box local SOCKS 与 Gecko 代理配置的绑定方式。
5. Android VPN/TUN 生命周期与系统级流量边界。
6. Provider 断线后的 Fail Closed 行为。
7. Find N3 外屏/内屏切换时 WebView/Gecko runtime 的 Window Metrics 变化。
8. 上游测试覆盖范围及需要补充的本项目回归测试。

## 9. 当前判断

WebLibre 适合作为浏览器核心底座，但不能直接视为最终产品。我们真正新增的价值是：

**Profile 身份编排 + 网络身份隔离 + 设备表现模型 + 安全故障语义 + 可验证的身份暴露控制。**
