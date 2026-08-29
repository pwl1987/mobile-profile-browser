# 网络架构

## 目标

允许每个 Profile 使用独立的逻辑网络路径，同时让浏览器状态与具体隧道实现解耦。

## 网络路由模型

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

Profile 只引用逻辑 `route_id`，不得把本地 SOCKS 端口、SSH 进程 PID 等运行时细节写死在 Profile 数据中。

## SSH 设计

规划中的 SSH 模式采用 **SSH 本地动态转发（`-D`）建立本地 SOCKS5 端点**，由 Android 原生网络服务管理。不得自行实现 SSH 协议，应采用维护中的 SSH 库。

```text
Profile
  ↓
NetworkRoute(SSH_TUNNEL)
  ↓
SSH Tunnel Service
  ↓
本地 SOCKS5 Endpoint
  ↓
Proxy / TUN Adapter
  ↓
浏览器流量
```

浏览器运行时不得接收或持久化 SSH 私钥。隧道服务只持有受 Android Keystore 保护的凭据引用及运行时句柄。

## 网络隔离边界

浏览器层设置代理，并不能自动证明所有请求都经过代理。正式实现前必须逐项验证：

- DNS 解析；
- HTTP/HTTPS 请求；
- IPv4 / IPv6；
- WebRTC Candidate；
- 重定向和下载；
- 扩展产生的网络请求（在引擎支持范围内）；
- 浏览器后台服务；
- 代理断开后的行为。

## TUN / VPN

如果 Gecko/浏览器层代理不能保证完整的 Profile 网络路由，可以后续采用 Android `VpnService` 配合维护中的 TUN-to-proxy 组件。

TUN/VPN 属于系统级流量能力，必须经过明确的用户授权。不得在用户不知情的情况下启用，也不得把 VPN 权限当成普通浏览器权限处理。

## 故障策略

当用户明确开启“防泄漏”模式后，配置了非直连网络的 Profile 必须：

**故障时 Fail Closed（失败即阻断）。**

SSH/代理不可用时，不允许静默回退到设备直连网络。普通隐私使用场景可以单独提供 Fail Open，但必须明确告知用户。

## 可观测性

仅允许暴露非敏感的健康信息：

- 路由状态；
- 隧道连接 / 断开状态；
- 最近一次成功连接时间；
- 延迟等级；
- 可用时的字节计数。

严禁记录：私钥、密码、代理认证信息、Cookie、Authorization Header，以及包含敏感查询参数的完整 URL。

## 后续实现原则

SSH、SOCKS5、TUN/VPN、DNS、WebRTC 等属于不同网络层，不得因为“能连通”就认定 Profile 已实现完整网络隔离。每层都必须有独立测试和失败证据。
