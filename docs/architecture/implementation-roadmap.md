# 实施路线图 V2

## Gate 验收模型（当前生效）

进度不以功能数量衡量，以**经过真实测试的能力**衡量。每个 Gate 有明确
验收标准，未通过不进入下一阶段：

| Gate | 内容 | 状态 |
|---|---|---|
| M1 | Android / WebLibre 可重复构建底座（APK Artifact） | ✅ 2026-08-30 |
| M2 | Profile Core：CRUD + SQLite + 迁移 + 崩溃恢复 | ✅ 2026-08-30 |
| M3 | Browser Profile 隔离：Adapter + Storage/Cookie/权限隔离验证 | 🔨 第一切片（映射+绑定+隔离契约 CI 化；真机 GeckoView 验收待做） |
| M4 | Runtime 生命周期：统一状态机 + 进程死亡恢复 | |
| M5 | 网络 Provider：DIRECT / SOCKS5 / SSH | |
| M6 | Device Profile：Find N3 一致性（折叠/展开/重建） | |
| M7 | Identity Consistency / Exposure Audit | |
| M8 | Android VPN/TUN（sing-box） | |
| M9 | Release Candidate | |

“完成”的定义示例：SSH Provider 不是“代码已写”，而是“真机上 Profile A 经
VPS 出口访问测试站点确认公网出口变化；停止后 SSH 进程 / Local Proxy /
Runtime 正确释放；重启后能重新建立连接”。

下文的阶段划分是 V2 历史口径，能力维度以本表为准。

## 总体目标

最终交付一个可安装在真实 Android 手机上的多 Profile 浏览器：

```text
一台 Android 手机
       ↓
Mobile Profile Browser
       ↓
Profile A / B / C / ...
       ↓
浏览器状态 + 设备表现 + 网络身份独立管理
```

核心目标不是“支持很多代理协议”，而是让每个 Profile 的运行状态、浏览状态、设备表现和网络身份都可以独立配置、独立验证，并在故障时避免真实身份泄漏。

## 阶段 0：工程基线

- 中文项目自有文档统一；
- WebLibre 上游 commit 固定；
- 许可证与第三方依赖清单建立；
- 纯 Dart 领域包建立；
- Domain 单元测试建立；
- Provider / Runtime / Health 数据模型建立。

## 阶段 1：浏览器底座

- 导入固定 WebLibre 快照；
- Android Debug APK 可重复构建；
- 真机安装；
- 启动、普通浏览、退出与恢复；
- 记录实际 GeckoView / Android / Flutter 版本。

禁止在这一阶段声称已经完成完整指纹伪装。

## 阶段 2：Profile 编排

- MobileProfile 与 WebLibre Profile 建立映射；
- 创建、重命名、启动、停止、切换、删除；
- Storage 生命周期；
- 崩溃恢复；
- Cookie / Storage / 权限 / Service Worker 隔离验收；
- RuntimeInstance 与 generation 机制。

## 阶段 3：Provider 网络层

- NetworkRoute 接入 ProviderRegistry；
- Direct / HTTP / SOCKS5；
- sing-box Provider；
- ProviderCapabilities；
- NetworkHealth；
- FailurePolicy；
- DNS / IPv4 / IPv6 / WebRTC 验证。

## 阶段 4：完整 sing-box 能力

优先复用上游已有 runtime，支持当前版本已经暴露的协议能力：

- Shadowsocks；
- VMess；
- VLESS；
- Trojan；
- Naive；
- Hysteria；
- Hysteria2；
- TUIC；
- WireGuard；
- ShadowTLS；
- AnyTLS；
- Custom Outbound；
- SSH。

新增协议不应导致 MobileProfile 核心领域模型改动。

## 阶段 5：SSH Provider

- VPS SSH 出口；
- 公钥认证；
- Host Key 校验；
- Keepalive；
- 自动重连；
- 健康检查；
- Fail Closed；
- 安全凭据存储。

优先使用 sing-box 原生 SSH outbound 或其他成熟运行时，不自行实现 SSH 协议。

## 阶段 6：系统级网络

- Android VpnService；
- TUN；
- DNS 防泄漏；
- IPv6 策略；
- WebRTC 策略；
- 系统级网络与 Profile 级网络边界验证。

## 阶段 7：Find N3 设备运行时

- OPPO Find N3 设备识别；
- 外屏 / 内屏；
- 折叠 / 展开 / 转换中；
- Window Metrics 观测；
- DPR 观测；
- 触控能力观测；
- Client Hints / WebGL 观测；
- 浏览器运行时能力与设备基线建立映射。

## 阶段 8：身份暴露控制

重点处理：

- Navigator；
- Screen / viewport / DPR；
- Touch；
- Locale / Timezone；
- Client Hints；
- WebGL；
- Canvas；
- Audio；
- Fonts；
- WebRTC；
- DNS；
- IPv4 / IPv6。

原则：先做真实能力观测和最小暴露，再做可靠可控的能力增强；不通过大量临时 JavaScript 注入制造虚假“已完成”假象。

## 阶段 9：产品化

- Profile 搜索、标签、排序；
- 复制 Profile；
- 明确选择的身份数据复制；
- 加密备份与恢复；
- 导入导出；
- 网络配置导入；
- 日志与诊断；
- Crash Recovery；
- 性能优化；
- Release APK。

## Gate 规则

任何阶段必须通过前一阶段验收才能扩大功能范围。

涉及身份隔离、网络泄漏和秘密保护的功能必须有实测证据。

不得因为 UI 已完成、代码已编译或配置看起来正确，就宣称隔离或匿名能力完成。