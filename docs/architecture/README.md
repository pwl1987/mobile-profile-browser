# 架构文档

本目录记录 Mobile Profile Browser 的架构决策、技术边界、上游审计和实施基线。

## 文档索引

| 文档 | 内容 | 状态 |
|---|---|---|
| [V0.1 架构基线](v0.1-baseline.md) | 第一阶段冻结范围与非目标 | 基线 |
| [M1 浏览器底座](m1-browser-foundation.md) | WebLibre 导入与 Android 验收 Gate | 基线（已通过） |
| [M1 构建环境](m1-build-environment.md) | Flutter / Dart / Android 可重复构建环境 | 基线 |
| [M2 Profile Core](m2-profile-core.md) | CRUD / SQLite / 迁移 / 崩溃恢复 | 实施中 |
| [Profile 模型](profile-model.md) | Profile 身份、隔离与生命周期 | 设计中 |
| [领域模型](domain-model.md) | MobileProfile、DeviceProfile、NetworkRoute | 实施中 |
| [网络架构](networking.md) | Provider、DNS、SSH、TUN/VPN 与故障策略 | 实施中 |
| [网络 Provider V2](network-provider-v2.md) | Provider 能力、健康状态和链式网络 | 基线 |
| [身份与隐私架构](identity-privacy.md) | 四层身份暴露面与最小暴露原则 | 基线 |
| [身份暴露矩阵](identity-exposure-matrix.md) | 可控制、可观测和不可控制的身份信息 | 基线 |
| [上游审计](upstream-audit.md) | WebLibre 复用、改造与隔离边界 | 进行中 |
| [上游锁定](upstream-lock.md) | WebLibre commit 与升级规则 | 基线 |
| [上游锁定记录](../upstream/weblibre.md) | 当前锁定 commit / 工具链 / 升级流程 | 基线 |
| [项目治理](../project-governance.md) | 技术决策、验收和变更规则 | 基线 |

## 架构原则

1. **上游能力优先复用**：浏览器内核、成熟存储和代理运行时尽量复用，不重复造轮子。
2. **领域边界独立**：Mobile Profile 是本项目自己的领域模型，不直接把业务字段塞入上游模型。
3. **隔离可验证**：任何声称“独立”的能力都必须有测试证明。
4. **网络默认故障关闭**：代理、SSH 或 TUN 异常不得静默回落到直连网络。
5. **指纹一致性优先于随机性**：设备配置必须形成自洽的能力集合。
6. **身份最小暴露**：不主动增加网站可识别字段；优先关闭、隔离或稳定化真实暴露面。
7. **上游可同步**：尽量通过 Adapter、Facade 和独立 Domain 层降低上游合并冲突。
8. **中文优先**：项目设计与工程文档默认使用中文。

## 当前上游

- WebLibre：<https://github.com/FaFre/WebLibre>
- V0.1 审计基线：`dc74be456efab51823bfc913114abb77af5c231c`

上游版本必须固定到明确 commit 后才能进入可复现构建基线。