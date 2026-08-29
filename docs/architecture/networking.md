# 网络架构

## 1. 目标

允许每个 Profile 引用独立的逻辑网络线路，同时让浏览器状态与具体隧道实现解耦。

## 2. NetworkRoute 模型

```text
NetworkRoute
├── route_id
├── type: DIRECT | HTTP | SOCKS5 | SSH_TUNNEL | VPN_TUNNEL
├── endpoint_ref
├── dns_policy
├── ipv6_policy
├── webrtc_policy
└── health_policy
```

Profile 不保存具体实现细节，只保存 `network_route_id`。

## 3. SSH 方案

计划中的 SSH 模式是 **SSH 本地动态转发（`-D`）→ 本地 SOCKS5 端点**。SSH 生命周期由 Android 原生网络服务管理。

不要自行实现 SSH 协议，应采用维护中的成熟 SSH 库或现有网络运行时能力。

```text
Profile
  ↓
NetworkRoute(SSH_TUNNEL)
  ↓
SSH Tunnel Service
  ↓
本地 SOCKS5
  ↓
Proxy / TUN Adapter
  ↓
浏览器流量
```

浏览器不得接触或持久化 SSH 私钥。隧道服务只持有安全凭据引用和运行所需的最小信息。

## 4. 代理完整性

浏览器设置了代理，并不能自动证明所有网络请求都经过代理。后续验收必须明确覆盖：

- DNS 解析；
- HTTP/HTTPS 请求；
- IPv4/IPv6；
- WebRTC Candidate；
- 重定向和下载；
- 在支持范围内的扩展流量；
- 浏览器后台服务流量。

## 5. TUN/VPN

如果 Gecko/浏览器级代理无法保证完整的 Profile 级网络路由，后续可以采用 Android `VpnService` 与维护中的 TUN-to-Proxy 组件。

TUN 是系统级网络机制，不应在没有明确用户授权的情况下自动启用。

## 6. 故障策略

对于用户明确要求防泄漏的非直连线路，默认：

**Fail Closed（故障关闭）**。

也就是说 SSH/代理线路断开后，不得静默回落到设备真实网络。

普通隐私场景如果确有需要，可以提供用户明确可见的 Fail Open 选项；默认不启用。

## 7. 可观测性

只暴露非敏感的健康信息：

- 线路状态；
- 隧道已连接/已断开；
- 最近一次成功连接时间；
- 延迟等级；
- 可用时的字节计数。

严禁记录：私钥、密码、代理凭据、认证 Header、Cookie，以及包含敏感查询参数的完整 URL。
