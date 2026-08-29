# Mobile Profile Browser

> Android 多 Profile 移动浏览器项目。
>
> 目标：在一台真实 Android 设备上，以独立 Profile 管理浏览器状态、设备配置与网络身份，并保证 Profile 之间的数据与网络边界清晰、可验证、可恢复。

## 项目定位

本项目以开源浏览器能力为基础进行二次开发，当前重点研究并实现：

- 多 Profile 管理
- Profile 级浏览数据隔离
- Profile 级网络路由
- SOCKS5 / HTTP 等代理能力
- SSH 动态转发作为 Profile 网络出口
- Android TUN/VPN 网络接管
- 设备配置 Profile
- 后续的浏览器指纹一致性研究
- 安全存储、崩溃恢复、导入导出与自动化测试

项目优先保证**隔离正确性、网络可验证性和运行稳定性**，不会以简单修改 User-Agent 作为所谓“指纹方案”。

## 当前状态

项目处于 V0.1 架构与底座建设阶段。

当前上游基线：

- 上游项目：WebLibre
- 上游仓库：<https://github.com/FaFre/WebLibre>
- 审计基线：`dc74be456efab51823bfc913114abb77af5c231c`

当前已经完成：

- 中文优先项目文档规范
- V0.1 架构基线
- Profile 模型初稿
- 网络与代理边界设计
- 安全威胁模型
- V0.1 验收矩阵
- WebLibre 第一轮代码级底座审计

当前进行中：

1. 固定 WebLibre 上游版本并建立可复现导入流程
2. 验证 WebLibre Profile / Storage 隔离模型
3. 验证 sing-box Profile 级代理能力
4. 设计 `MobileProfile` 领域层
5. 设计 `DeviceProfile` 与 `NetworkRoute`
6. 设计 SSH → SOCKS5 → Profile 网络链路
7. 建立 Android 真机验收环境

## 核心原则

### 1. Profile 是完整运行身份

Profile 不只是 Cookie 容器，而是：

```text
MobileProfile
├── 浏览器状态
├── 存储空间
├── DeviceProfile
├── NetworkRoute
├── 权限策略
└── 生命周期状态
```

### 2. 强隔离优先

不同 Profile 必须能够独立验证：

- Cookie
- LocalStorage
- IndexedDB
- Cache
- History
- 权限状态
- 浏览器会话
- 网络出口
- DNS
- WebRTC

### 3. 网络故障默认安全

代理或 SSH 隧道异常时，不允许静默回落到真实网络。

目标状态：

```text
Profile
  ↓
NetworkRoute
  ↓
Proxy / SSH
  ↓
健康检查
  ↓
允许浏览
```

健康检查失败：

```text
NetworkRoute
  ↓
FAIL CLOSED
  ↓
阻断外网
```

### 4. 指纹必须保持一致性

后续 Device/Fingerprint Engine 不采用简单随机字段拼接。

设备配置、浏览器能力、屏幕参数、触控能力、语言、时区、Client Hints、WebGL 等必须遵循一致性模型，并明确区分：

- `controlled`：应用可控
- `derived`：由运行环境推导
- `observed`：运行时观测
- `unsupported`：当前无法可靠控制

## 文档

- [架构文档](docs/architecture/README.md)
- [V0.1 架构基线](docs/architecture/v0.1-baseline.md)
- [Profile 模型](docs/architecture/profile-model.md)
- [网络架构](docs/architecture/networking.md)
- [安全威胁模型](docs/security/threat-model.md)
- [V0.1 验收矩阵](docs/testing/acceptance-matrix.md)

## 开发语言规范

项目自己的 README、架构设计、技术方案、测试方案、Issue、PR 模板与运行手册默认使用**中文**。

代码中的类名、函数名、变量名、协议名、第三方项目名、Android/GeckoView API 等保留其官方英文名称。

## 上游与许可证

本项目会长期跟踪 WebLibre 上游，但不会把上游代码无审计地整体复制到业务层。

在引入上游代码、修改许可证文件或重新分发构建产物前，必须检查对应文件的版权声明、许可证及第三方依赖义务。WebLibre 当前采用 AGPL-3.0，因此本项目的许可证与分发策略必须在正式发布前单独完成合规审查。

## 免责声明

本项目用于浏览器隔离、隐私保护、网络工程和安全研究。不得用于绕过合法的访问控制、平台规则或从事违法活动。
