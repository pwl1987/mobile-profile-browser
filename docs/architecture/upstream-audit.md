# WebLibre 上游代码审计

> 本文档记录 Mobile Profile Browser 对 WebLibre 的代码级复用判断。每次上游升级都必须重新验证，不以 README 描述替代代码审计。

## 1. 审计基线

- 项目：WebLibre
- 仓库：<https://github.com/FaFre/WebLibre>
- 当前审计 commit：`dc74be456efab51823bfc913114abb77af5c231c`
- 许可证：上游当前为 AGPL-3.0，正式发布前必须完成许可证及第三方依赖合规审查。

## 2. 初步结论

### 强复用

- GeckoView / Mozilla Android Components
- Profile 文件系统
- 浏览器存储与会话基础设施
- Secure Storage
- Startup 配置与恢复机制
- sing-box Android runtime
- 现有 Proxy Domain 基础设施

### 需要建立本项目领域层

- `MobileProfile`
- `DeviceProfile`
- `NetworkRoute`
- `SecurityPolicy`
- Profile 生命周期编排

### 后续新增

- SSH Tunnel Adapter
- Device Profile 校验器
- Fingerprint Consistency Engine
- Profile 级网络 Fail Closed 编排

## 3. 为什么不直接修改上游 Profile

WebLibre 的 Profile 更接近浏览器数据与认证上下文。本项目的 Profile 是完整的移动运行身份，因此采用组合关系：

```text
MobileProfile
├── WebLibre Profile Reference
├── DeviceProfile Reference
├── NetworkRoute Reference
└── SecurityPolicy Reference
```

这样可以降低上游同步时的冲突，并防止业务领域模型与浏览器内核模型耦合。

## 4. 代理能力初步结论

WebLibre 当前已经存在 `ProxyConnectionId`，并且能够把 sing-box 连接与 profileId 关联；其 `flutter_singbox_proxy` 设计支持多个 Profile outbound，并为活动 Profile 提供独立本地 SOCKS inbound。

因此 V0.2 不重新实现 SOCKS/TUN 基础设施，而是优先在其上建立本项目的 `NetworkRoute` 与 `NetworkService`。

## 5. SSH 设计方向

SSH 不进入 MobileProfile Domain。采用 Adapter：

```text
MobileProfile
    ↓
NetworkRoute
    ↓
SSH Tunnel Adapter
    ↓
SOCKS / sing-box
    ↓
Gecko
```

SSH 凭据只保存在安全存储中，浏览器运行时只获取必要的连接引用或短生命周期凭据。

## 6. 禁止事项

- 不复制上游全部代码后无记录地修改。
- 不把指纹逻辑散落在 UI、WebView 注入脚本和代理代码中。
- 不把 SSH 私钥写入普通 Profile JSON。
- 不在代理失败时自动回落直连。
- 不以修改 User-Agent 宣称已经完成指纹隔离。

## 7. 下一轮审计

下一轮必须继续定位：

1. WebLibre Profile 创建、删除、切换的完整调用链。
2. Gecko Runtime 与 Profile directory 的绑定方式。
3. Container / Cookie isolation 的实际边界。
4. sing-box local SOCKS endpoint 与 Gecko proxy configuration 的绑定方式。
5. Android VPN/TUN 的生命周期与多 Profile 并发行为。
6. 上游测试是否覆盖 Profile 间数据串扰。

审计完成后才能冻结 V0.1 代码导入清单。