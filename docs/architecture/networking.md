# 网络架构

## 1. 总体模型

网络系统采用 Provider 架构。SSH 只是其中一种出口能力，不是整个网络层的中心。

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
  ↓
Internet
```

## 2. 一级 Provider

- `DIRECT`：明确的直连模式。
- `HTTP`：HTTP/HTTPS 代理。
- `SOCKS5`：SOCKS5 代理。
- `SING_BOX`：统一承载多种代理协议。
- `SSH`：SSH 出口，优先复用 sing-box SSH outbound。
- `WIREGUARD`：WireGuard 网络出口。
- `VPN_TUN`：Android `VpnService` / TUN 系统级出口。
- `TOR`：Tor 网络出口。

SING_BOX 内部可以承载 Shadowsocks、VMess、VLESS、Trojan、Naive、Hysteria、Hysteria2、TUIC、ShadowTLS、AnyTLS、WireGuard、SSH 与自定义出站。

## 3. NetworkRoute

NetworkRoute 只保存稳定引用，不保存协议实现细节：

```text
NetworkRoute
├── route_id
├── provider_kind
├── protocol
├── provider_config_ref
├── credential_ref
├── trust_ref
├── policy
├── failure_policy
└── schema_version
```

## 4. Provider 与协议分离

Provider 表示运行机制，Protocol 表示具体协议。例如：

```text
SING_BOX + VLESS
SING_BOX + HYSTERIA2
SING_BOX + TROJAN
SSH + SSH
SOCKS5 + SOCKS5
WIREGUARD + WIREGUARD
```

以后增加 sing-box 新协议，不应该修改整个 NetworkRoute 模型。

## 5. Provider 能力

每个 Provider 必须声明能力集合：

```text
ProviderCapabilities
├── TCP
├── UDP
├── IPv4
├── IPv6
├── DNS
├── TUN
└── Browser Proxy
```

UI 和运行时根据能力决定可用配置，不假设所有代理具有相同能力。

## 6. 路由策略

后续支持 Route Graph 和分流规则：

```text
NetworkPolicy
├── 默认线路
├── 域名规则
├── IP / CIDR 规则
├── Geo 规则
├── 端口规则
├── 协议规则
└── DNS 规则
```

V0.1 可只运行一条线路，但模型必须允许未来组合：

```text
Provider A → Provider B → Provider C → Internet
```

## 7. DNS

必须区分：

1. 浏览器 DNS；
2. Provider DNS；
3. Provider Bootstrap DNS；
4. Android 系统 DNS。

受保护线路不得因为配置缺失而静默回落到系统 DNS。DNS 健康状态属于网络健康的一部分。

## 8. IPv4 / IPv6

IPv6 必须有显式策略，例如：

- `PREFER`
- `DISABLE`
- `ONLY`
- `FOLLOW_PROVIDER`
- `FAIL_IF_UNAVAILABLE`

严禁出现“IPv4 走代理、IPv6 直连”的无提示状态。

## 9. Fail Closed

受保护线路默认：

```text
Provider 断线
   ↓
立即阻断受保护流量
   ↓
进入 RECONNECTING
   ↓
健康检查
   ↓
恢复
```

禁止静默回落到真实网络。

## 10. SSH

SSH 是普通 Provider。对于 VPS SSH 出口，优先使用现有 sing-box SSH outbound；只有当该能力不能满足 Profile 级隔离、凭据保护、健康检查或生命周期需求时，才增加独立 Android SSH Runtime。

SSH 私钥、密码和其他认证数据只能通过安全凭据引用访问，不进入普通 Profile JSON、日志或浏览器运行时。

## 11. Android VPN/TUN

Android `VpnService` 属于系统级网络机制。启用前必须明确用户授权，并且必须处理系统 VPN 与 Profile 级路由之间的边界。

如果系统级 VPN 无法安全表达多个 Profile 的独立出口，则不得伪装成已经实现“每 Profile 独立 TUN”。此能力必须以真机测试结果为准。

## 12. 网络状态

网络运行态必须拆分为：

```text
Connection
Health
Traffic
Leak
```

例如：

```text
Connection = CONNECTED
Health     = DEGRADED
Traffic    = BLOCKED
Leak       = SAFE
```

这样才能准确表达“隧道还活着，但出口不可安全使用”。
