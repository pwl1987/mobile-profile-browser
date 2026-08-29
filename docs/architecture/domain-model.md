# 领域模型 V2

## 1. 核心目标

Mobile Profile Browser 的核心对象不是浏览器窗口，而是一个可以长期保存、恢复、迁移和验证的移动运行身份。

```text
MobileProfile
├── BrowserProfile
├── DeviceProfile
├── NetworkRoute
└── SecurityPolicy
```

这四个领域对象必须解耦，任何一个实现发生变化都不能迫使其他对象直接依赖具体运行库。

## 2. MobileProfile

```text
MobileProfile
├── id
├── name
├── createdAt
├── updatedAt
├── status
├── browserProfileRef
├── deviceProfileRef
├── networkRouteRef
└── schemaVersion
```

显示名称只是 UI 元数据，不能作为数据目录、Cookie 存储或运行实例的唯一标识。

## 3. BrowserProfile

BrowserProfile 表示 WebLibre/Gecko 的浏览器数据边界：

```text
BrowserProfile
├── upstreamProfileRef
├── storageNamespace
├── cookieNamespace
├── permissionNamespace
├── sessionNamespace
└── lifecycleState
```

上游 Profile 不直接等于 MobileProfile。MobileProfile 只保存对上游 Profile 的引用。

## 4. DeviceProfile

DeviceProfile 表示一组相互一致的设备与浏览器能力：

```text
DeviceProfile
├── 设备系列/型号
├── 区域型号
├── Android 版本
├── 浏览器兼容版本
├── 主屏 DisplayProfile
├── 外屏 DisplayProfile
├── 折叠姿态
├── 语言/地区
├── 时区
├── 硬件能力
├── Client Hints 状态
└── WebGL 状态
```

字段必须标记为：

- `controlled`：应用可以可靠控制；
- `derived`：由实际设备运行环境推导；
- `observed`：运行时观测得到；
- `unsupported`：当前不能可靠控制。

不能把硬件宣传参数直接宣称成浏览器可见值。

## 5. NetworkRoute

NetworkRoute 是逻辑线路，不直接等于某一种协议。

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

### Provider

当前预留：

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

### Protocol

协议属于 Provider 的实现配置。例如 `SING_BOX + VLESS`、`SING_BOX + Hysteria2`、`SING_BOX + SSH`。

这样新增 sing-box 协议不会污染整个 Profile Domain。

## 6. NetworkPolicy

```text
NetworkPolicy
├── DNS 模式
├── IPv6 模式
├── WebRTC 模式
├── Fail Closed
└── 后台流量策略
```

网络安全策略与 Provider 类型解耦。

## 7. FailurePolicy

```text
FailurePolicy
├── CLOSED / OPEN
├── 启动失败处理
├── 运行失败处理
├── DNS 失败处理
├── 健康检查失败处理
├── 凭据失败处理
└── 最大重连次数
```

对于明确要求隐私/出口保护的线路，默认 Fail Closed。

## 8. ProviderCapabilities

Provider 必须声明能力，而不是假定所有线路都支持相同能力：

```text
TCP
UDP
IPv4
IPv6
DNS
TUN
Browser Proxy
```

UI 与 RouteResolver 根据 capability 决定可配置功能。

## 9. RuntimeInstance

Profile 与实际运行实例必须分离：

```text
RuntimeInstance
├── id
├── profileId
├── routeId
├── providerInstanceId
├── generation
├── startedAt
├── stoppedAt
└── status
```

这样 Android 进程崩溃后，新 runtime 不会错误继承旧 runtime 的状态。

## 10. NetworkHealth

运行状态和健康状态分离：

```text
connection = CONNECTED
health     = DEGRADED
traffic    = BLOCKED
leak       = SAFE
```

这种状态组合才能真实描述代理进程存在但实际出口不可用的情况。

## 11. Route Chain / Route Graph

V0.1 不实施多跳链路，但模型必须允许未来扩展：

```text
RouteGraph
Profile
 ↓
Provider A
 ↓
Provider B
 ↓
Provider C
 ↓
Internet
```

这样未来可以表达 `SOCKS5 → SSH → VLESS` 等链路，而无需重做 Profile 模型。

## 12. 隔离目标

至少必须能够分别验证：

- Cookie；
- LocalStorage；
- IndexedDB；
- Cache；
- History；
- 权限；
- Service Worker / 站点会话；
- DNS；
- IPv4/IPv6；
- WebRTC；
- 公网出口 IP。

“独立”只能通过实际测试证明，不能仅依据对象模型推断。