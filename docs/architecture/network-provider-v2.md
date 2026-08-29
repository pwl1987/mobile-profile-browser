# 网络 Provider 架构 V2

本文件是网络架构的补充基线，正式重构时以本文件为准。

## 核心原则

SSH 只是 Provider 之一，不得成为网络层的中心抽象。

```text
MobileProfile
  ↓
NetworkRoute
  ↓
RouteResolver
  ↓
NetworkProvider
  ↓
Provider Runtime
```

## Provider

支持的一级 Provider：

- DIRECT
- HTTP
- SOCKS5
- SING_BOX
- SSH
- WIREGUARD
- VPN_TUN
- TOR

SING_BOX 内部可以承载 Shadowsocks、VMess、VLESS、Trojan、Naive、Hysteria、Hysteria2、TUIC、ShadowTLS、AnyTLS、WireGuard、SSH 和 Custom Outbound 等协议。

## NetworkRoute

```text
NetworkRoute
├── route_id
├── provider_id
├── provider_config_ref
├── policy_ref
├── failure_policy_ref
└── health_check_ref
```

## Provider 能力

```text
ProviderCapabilities
├── TCP
├── UDP
├── IPv4
├── IPv6
├── DNS
├── TUN
└── perProfile
```

## 健康状态

运行态与健康态分离：

```text
Runtime = RUNNING
Health  = DEGRADED
Traffic = BLOCKED
Leak    = SAFE
```

## 故障策略

受保护线路默认故障关闭：

```text
断线 → 阻断外网 → 重连 → 健康检查 → 恢复
```

禁止静默回落到真实网络。

## DNS

必须分别建模浏览器 DNS、Provider DNS、Provider Bootstrap DNS 和 Android 系统 DNS。受保护线路不得因配置缺失自动回落系统 DNS。

## 链式网络

V0.1 可以只运行一个 Provider，但领域模型必须为后续 Route Graph 留出空间：

```text
Provider A → Provider B → Provider C → Internet
```

## SSH

SSH 作为普通 Provider。优先复用现有 sing-box SSH outbound；只有在能力不足时才实现独立 Android SSH Runtime。