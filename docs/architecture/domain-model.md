# 领域模型

## 目标

Mobile Profile Browser 的核心对象不是“一个浏览器窗口”，而是一个可以长期保存、恢复、迁移和验证的移动浏览身份。

## MobileProfile

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
└── securityPolicyRef
```

### 生命周期

```text
CREATED
   ↓
READY
   ↓
STARTING
   ↓
RUNNING
   ↓
STOPPING
   ↓
READY
```

异常状态：

```text
STARTING → ERROR
RUNNING  → DEGRADED
```

恢复必须经过显式状态转换，不允许通过 UI 状态猜测实际运行状态。

## DeviceProfile

DeviceProfile 描述一个目标 Android 设备能力集合，而不是随机字段集合。

```text
DeviceProfile
├── device identity
├── Android version
├── browser compatibility
├── screen
├── DPR
├── touch
├── locale
├── timezone
├── hardware capability
├── Client Hints capability
└── fingerprint capability state
```

每个字段必须标记为：

- `controlled`：应用可以可靠控制。
- `derived`：由运行环境推导。
- `observed`：运行时读取后记录。
- `unsupported`：当前无法可靠控制。

## NetworkRoute

```text
NetworkRoute
├── id
├── mode
├── proxy reference
├── ssh reference
├── dns policy
├── ipv6 policy
├── webrtc policy
├── failClosed
└── healthCheck
```

Profile 只引用 NetworkRoute，不直接依赖 sing-box 或 SSH 实现。

## 关系

```text
                    MobileProfile
                    /     |      \
                   /      |       \
                  ↓       ↓        ↓
        BrowserProfile DeviceProfile NetworkRoute
                                          ↓
                                  NetworkService
                                          ↓
                                  sing-box / SSH
```

## 隔离要求

不同 MobileProfile 必须使用不同的浏览器数据边界，并且网络出口必须能够独立验证。

验收至少覆盖 Cookie、LocalStorage、IndexedDB、Cache、History、权限、DNS、WebRTC 和公网出口 IP。
