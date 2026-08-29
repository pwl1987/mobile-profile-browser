# 架构文档

本目录记录 Mobile Profile Browser 的架构决策与技术边界。

## 文档索引

| 文档 | 内容 | 状态 |
|---|---|---|
| [V0.1 架构基线](v0.1-baseline.md) | 第一阶段冻结范围与非目标 | 基线 |
| [Profile 模型](profile-model.md) | Profile 身份、隔离与生命周期 | 设计中 |
| [网络架构](networking.md) | Proxy、SSH、TUN/VPN 与故障策略 | 设计中 |
| [上游审计](upstream-audit.md) | WebLibre 复用、改造与隔离边界 | 进行中 |
| [领域模型](domain-model.md) | MobileProfile、DeviceProfile、NetworkRoute | 设计中 |

## 架构原则

1. **上游能力优先复用**：浏览器内核、成熟存储和代理运行时尽量复用，不重复造轮子。
2. **领域边界独立**：Mobile Profile 是本项目自己的领域模型，不直接把业务字段塞入上游模型。
3. **隔离可验证**：任何声称“独立”的能力都必须有测试证明。
4. **网络默认 Fail Closed**：代理、SSH 或 TUN 异常不得静默泄漏到直连网络。
5. **指纹一致性优先于随机性**：设备配置必须形成自洽的能力集合。
6. **上游可同步**：尽量通过 Adapter、Facade 和独立 Domain 层降低上游合并冲突。
7. **中文优先**：项目设计与工程文档默认使用中文。

## 当前上游

- WebLibre：<https://github.com/FaFre/WebLibre>
- 审计基线：`dc74be456efab51823bfc913114abb77af5c231c`

上游版本必须固定到明确 commit 后才能进入可复现构建基线。