# Mobile Profile Browser

> Android 多 Profile 移动浏览器项目。
>
> 目标：在一台真实 Android 设备上，以独立 Profile 管理浏览器状态、设备配置与网络身份，并保证 Profile 之间的数据与网络边界清晰、可验证、可恢复。

## 项目定位

本项目以开源浏览器能力为基础进行二次开发，当前重点研究并实现：

- 多 Profile 管理
- Profile 级浏览数据隔离
- Profile 级网络路由
- Direct / HTTP / SOCKS5 / sing-box / SSH / WireGuard / VPN-TUN / Tor 等网络 Provider
- VPS SSH 作为一种可选网络出口
- 设备配置 Profile
- 后续的浏览器指纹一致性研究
- 安全存储、崩溃恢复、导入导出与自动化测试

项目优先保证**隔离正确性、网络可验证性和运行稳定性**，不会以简单修改 User-Agent 作为所谓“指纹方案”。

## 当前状态

项目当前处于 **M3 Browser Profile 阶段**：M1 构建底座与 M2 Profile Core 已通过验收，隔离契约与 Runtime 编排层已 CI 化；Gate 状态详见 [docs/status/project-status.md](docs/status/project-status.md)。

## 测试 APK

develop 每次合入后由 CI 自动构建 Debug APK（M1 可重复构建基线，约 383 MiB）：

- **公开下载（无需登录）**：[GitHub Release · m1-baseline-20260830](https://github.com/pwl1987/mobile-profile-browser/releases/tag/m1-baseline-20260830)
- Release 列表（后续构建）：<https://github.com/pwl1987/mobile-profile-browser/releases>
- CI Artifact（需 GitHub 账号登录，保留 90 天）：<https://github.com/pwl1987/mobile-profile-browser/actions/runs/33296076558/artifacts/9727669699>
- gh CLI 方式：`gh run download 33296076558 -n mobile-profile-browser-m1-debug -R pwl1987/mobile-profile-browser`

说明：该 APK 为锁定基线 `b4721ae6` 的纯上游 WebLibre 构建，尚未包含 Mobile Profile 业务层（业务层随补丁流接入，见 [patches/README.md](patches/README.md)）；Debug 签名，仅用于构建基线与真机验收。

当前上游基线：

- 上游项目：WebLibre
- 上游仓库：<https://github.com/FaFre/WebLibre>
- 构建锁定基线：`b4721ae6b34aea65e589417b3a64244cc14dbb91`
  （审计范围覆盖到其子提交 `dc74be45`；`dc74be45` 的 "update flutter deps"
  在 Flutter 3.47.1 下引入 material_ui 1.1.0 类型冲突导致上游自身
  `flutter analyze` 失败，因此构建锁定在其父提交，详见
  `docs/upstream/weblibre.md`）
- 上游集成方式：`vendor/weblibre` Git Submodule

当前已经完成：

- 中文优先项目文档规范
- V0.1 架构与安全基线
- MobileProfile / DeviceProfile / NetworkRoute 领域模型
- Provider Registry / Runtime 生命周期模型
- Repository 契约与测试用内存实现
- OPPO Find N3 双屏设备模型
- WebLibre 第一轮代码级审计
- WebLibre 上游 commit 锁定
- Android M1 可重复构建工作流

当前正在推进：

1. WebLibre 依赖解析与 Android Debug APK 构建
2. BrowserProfileAdapter
3. WebLibre Profile / Gecko Runtime 映射
4. Profile Storage 隔离验证
5. Provider Runtime Adapter
6. sing-box 网络接入
7. OPPO Find N3 真机验收

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

对于用户选择的受保护线路，代理、SSH、VPN-TUN 或其他 Provider 异常时不得静默回落到真实网络。

```text
Profile
  ↓
NetworkRoute
  ↓
Provider Runtime
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
阻断受保护流量
```

### 4. 指纹必须保持一致性

Device/Fingerprint Engine 不采用简单随机字段拼接。

设备配置、浏览器能力、屏幕参数、触控能力、语言、时区、Client Hints、WebGL 等必须遵循一致性模型，并明确区分：

- `controlled`：应用可控
- `derived`：由运行环境推导
- `observed`：运行时观测
- `unsupported`：当前无法可靠控制

### 5. 身份最小暴露

项目核心目标之一是减少不必要的真实身份暴露，但不宣称绝对匿名。

重点关注：

```text
浏览状态身份
设备表现身份
网络身份
应用/系统身份
```

每项能力必须通过真实引擎行为验证，不能因为 UI 配置存在就认定已经完成隔离或身份保护。

## 文档

- [架构文档](docs/architecture/README.md)
- [V0.1 架构基线](docs/architecture/v0.1-baseline.md)
- [M1 浏览器底座](docs/architecture/m1-browser-foundation.md)
- [M1 构建环境](docs/architecture/m1-build-environment.md)
- [M1 集成策略](docs/architecture/m1-integration-strategy.md)
- [领域模型](docs/architecture/domain-model.md)
- [网络架构](docs/architecture/networking.md)
- [网络 Provider V2](docs/architecture/network-provider-v2.md)
- [身份与隐私架构](docs/architecture/identity-privacy.md)
- [OPPO Find N3](docs/devices/oppo-find-n3.md)
- [VPS SSH 出口](docs/network/vps-ssh-exit.md)
- [安全威胁模型](docs/security/threat-model.md)
- [验收矩阵](docs/testing/acceptance-matrix.md)

## 开发语言规范

项目自己的 README、架构设计、技术方案、测试方案、Issue、PR 模板与运行手册默认使用**中文**。

代码中的类名、函数名、变量名、协议名、第三方项目名、Android/GeckoView API 等保留其官方英文名称。

## 上游与许可证

本项目会长期跟踪 WebLibre 上游，但不会把上游代码无审计地整体复制到业务层。

在引入上游代码、修改许可证文件或重新分发构建产物前，必须检查对应文件的版权声明、许可证及第三方依赖义务。WebLibre 当前采用 AGPL-3.0，因此本项目的许可证与分发策略必须在正式发布前单独完成合规审查。

## 免责声明

本项目用于浏览器隔离、隐私保护、网络工程和安全研究。不得用于绕过合法的访问控制、平台规则或从事违法活动。
