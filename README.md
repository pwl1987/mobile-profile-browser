# Mobile Profile Browser（移动多配置浏览器）

> Android 优先、数据本地化、配置隔离的移动浏览器。目标是在一台 Android 设备上管理多个长期运行的独立浏览配置，并为每个配置提供独立的网络路径与一致的设备配置。

**当前状态：V0.1 架构基线阶段。尚未开始导入上游代码。**

本项目作为独立产品开发，以 [WebLibre](https://github.com/FaFre/WebLibre) 作为初始浏览器基础。WebLibre 使用 AGPL-3.0；本项目在导入其衍生代码后，必须遵守适用的许可证及源代码提供义务。

## 产品目标

一台真实 Android 手机应能够创建多个长期存在的浏览 Profile，并对浏览状态、网络路径和设备配置进行明确隔离：

```text
Android APK
  └─ Profile 管理器
      ├─ Profile A
      │   ├─ Gecko / 浏览器状态
      │   ├─ Cookie + 网站存储
      │   ├─ 设备配置
      │   └─ 代理 / 隧道
      ├─ Profile B
      └─ Profile C
```

核心目标不是简单修改 User-Agent，而是建立**可验证、可解释、内部一致**的 Profile 环境。

## V0.1 范围

- 建立可复现的 WebLibre 上游基线。
- 明确 Profile 数据模型、生命周期和所有权。
- 明确浏览器数据隔离边界。
- 建立与具体隧道实现解耦的网络路由抽象。
- 明确 SSH → SOCKS5 的后续集成架构。
- 建立设备配置模型，并保证相关浏览器可见参数具有一致性。
- 在功能开发前建立架构、安全、测试和贡献规范。

## 版本路线

| 版本 | 目标 | 状态 |
|---|---|---|
| V0.1 | 上游基线 + Profile 架构 | 进行中 |
| V0.2 | 每 Profile 独立代理路由 | 规划 |
| V0.3 | SSH 隧道集成 | 规划 |
| V0.4 | 设备配置管理 | 规划 |
| V0.5 | 网络 / 隐私泄漏验证 | 规划 |
| V0.6 | 指纹一致性引擎 | 规划 |
| V0.7+ | 备份、导入导出、自动化 | 规划 |

## 文档

### 架构

- `docs/architecture/README.md` — 架构总览、原则和依赖方向
- `docs/architecture/v0.1-baseline.md` — V0.1 冻结边界
- `docs/architecture/profile-model.md` — Profile 模型、生命周期和隔离契约
- `docs/architecture/networking.md` — 网络路由、代理、SSH、TUN/VPN

### 安全与测试

- `docs/security/threat-model.md` — 威胁模型、安全要求和非目标
- `docs/testing/acceptance-matrix.md` — V0.1 验收矩阵

**后续新增项目文档统一使用中文。**必要的代码符号、协议名称、API 名称、上游项目名保留英文原文。

## 上游项目

主要上游： [FaFre/WebLibre](https://github.com/FaFre/WebLibre)

当前 WebLibre 是基于 Gecko/GeckoView 的 Android 浏览器，已经包含 Profile、隔离浏览、Cookie Isolation 以及多协议代理等能力。它的当前工作区采用 Dart/Flutter。我们会逐项审计这些能力，决定直接复用、适配、替换还是自研；**上游已有能力不等于满足本项目要求**。

## 开发原则

1. **Profile 是第一隔离边界。**
2. 浏览器状态、网络身份、设备身份必须分层管理。
3. 禁止依赖隐式全局可变状态跨 Profile 共享数据。
4. 代理是网络传输能力，不等于指纹能力。
5. 设备配置必须是内部一致的组合，而不是随机拼接参数。
6. 不采用大量临时 JavaScript 覆盖来伪造浏览器指纹；无法由底层引擎可靠控制的字段必须明确标记为“不可控 / 派生 / 观测 / 不支持”。
7. 上游更新必须经过审计、记录和验证后才能合入。
8. 安全敏感能力必须具有明确的验收测试。
9. 任何功能“完成”都必须有测试证据，或者有明确记录的引擎限制。
10. 中文是项目默认文档语言；提交说明、架构决策和开发规范原则上使用中文。

## 许可证

在首次导入 WebLibre 衍生代码前，必须完成许可证边界确认。WebLibre 为 AGPL-3.0 项目，因此不得加入与上游义务冲突的宽松许可证声明。
