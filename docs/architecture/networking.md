# 网络架构 V2

## 1. 总体原则

网络层采用 Provider 架构。SSH 只是其中一种出口方式，不作为整个代理系统的中心设计。

```text
MobileProfile
    ↓
NetworkRoute
    ↓
RouteResolver
    ↓
NetworkProvider
    ↓
ProviderRuntime
    ↓
实际网络出口
```

## 2. Provider 类型

第一阶段统一预留以下 Provider：

```text
DIRECT
HTTP
SOCKS5
SING_BOX
SSH
WIREGUARD
VPN_TUN
TOR
```

其中 `SING_BOX` 承载具体协议配置，例如：

```text
Shadowsocks
VMess
VLESS
Trojan
Naive
Hysteria
Hysteria2
TUIC
WireGuard
ShadowTLS
AnyTLS
Custom Outbound
```

这种设计避免每新增一种 sing-box 协议就修改 MobileProfile 核心模型。

## 3. NetworkRoute

```text
NetworkRoute
├── id
├── name
├── provider
├── protocol
├── providerConfigRef
├── credentialRef
├── trustRef
├── NetworkPolicy
├── FailurePolicy
├── ProviderCapabilities
└── schemaVersion
```

Profile 只引用 NetworkRoute，不保存具体本地端口或运行时对象。

## 4. RoutePolicy

V0.1 先使用单一路由，模型预留未来按域名、地址、协议和端口进行分流：

```text
RouteGraph
Profile
 ↓
RoutePolicy
 ↓
Route A / Route B / Route C
```

同时预留链式线路：

```text
SOCKS5 → SSH → VLESS → Internet
```

V0.1 不实施多跳，但不得因为当前未实施而破坏领域模型。

## 5. DNS

DNS 必须与“浏览器代理是否正常”分开验收。至少区分：

```text
系统 DNS
浏览器 DNS
Provider DNS
Bootstrap DNS
```

NetworkPolicy 必须能够表达：

- DNS 走代理；
- 指定 DoH / DoT / DoQ；
- 指定 bootstrap resolver；
- DNS 失败时是否阻断流量。

对于要求身份保护的线路，不能静默使用系统 DNS。

## 6. IPv4 / IPv6

IPv6 策略至少支持：

```text
PREFER
DISABLE
ONLY
FOLLOW_PROVIDER
FAIL_IF_UNAVAILABLE
```

重点防止：IPv4 经过代理而 IPv6 直接访问互联网的泄漏。

## 7. WebRTC

WebRTC 是独立的网络暴露面。NetworkPolicy 必须明确其处理策略，并通过真实网页进行 Candidate / 地址暴露测试。

## 8. ProviderCapabilities

每个 Provider 必须声明能力：

```text
TCP
UDP
IPv4
IPv6
DNS
TUN
Browser Proxy
```

UI 不允许假定所有 Provider 都支持 UDP、IPv6 或 TUN。

## 9. ProviderRuntime

运行状态必须与网络健康分离：

```text
连接状态：CONNECTED
健康状态：DEGRADED
流量状态：BLOCKED
泄漏状态：SAFE
```

运行实例具有独立的 `runtimeId` 和 `generation`，防止崩溃恢复后旧实例状态覆盖新实例。

## 10. SSH Provider

SSH 是普通 Provider 之一。目标链路：

```text
NetworkRoute(SSH)
      ↓
SSH Provider
      ↓
sing-box SSH outbound / 成熟 SSH 运行时
      ↓
VPS
      ↓
公网出口
```

不得自行实现 SSH 协议。优先复用当前上游已经采用的 sing-box 能力。

SSH 凭据和主机密钥属于安全存储，不进入普通 Profile JSON。

## 11. VPS SSH 出口

VPS 最终建议使用独立 SSH 账号，禁止复用 VPS 管理员账号。生产环境应：

- 使用专用密钥；
- 固定并校验主机密钥；
- 限制账号权限；
- 关闭不需要的交互能力；
- 定期轮换密钥；
- 在健康检查中验证实际公网出口。

## 12. Fail Closed

对于要求身份保护的代理线路：

```text
Provider
  ↓
失联 / DNS 失败 / 健康检查失败
  ↓
阻断非必要外网流量
  ↓
自动重连
  ↓
健康检查
  ↓
恢复浏览
```

禁止：

```text
代理失败 → 自动 DIRECT
```

除非用户明确将该线路配置为允许故障开放。

## 13. 健康检查

HealthCheck 至少检查：

1. Provider 运行状态；
2. TCP/UDP 可达性（按 Provider 能力）；
3. DNS 正常性；
4. 实际公网 IPv4；
5. 实际公网 IPv6（如果启用）；
6. WebRTC 地址暴露；
7. 是否发生异常直连。

## 14. 结论

网络层的核心不是“支持多少代理协议”，而是：

**Profile 能否稳定、可验证地绑定到一个明确网络身份，并在故障时不泄漏真实网络。**