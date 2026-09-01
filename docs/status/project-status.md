# 项目状态

> 每轮 Gate 推进后更新本文件。进度口径：不以功能数量衡量，
> 以经过真实测试的能力衡量（见 AGENTS.md 进度原则）。

## 当前 Gate：M3 Browser Profile（收口阶段）

| Gate | 状态 | 证据 |
|---|---|---|
| M1 Android Build Baseline | ✅ 2026-08-29 | Run 33259412696 全绿，APK Artifact 产出 |
| M2 Profile Core（CRUD+SQLite+迁移+恢复） | ✅ 2026-08-30 | PR #3，全工作流绿 |
| M3.1 Browser Profile Contract | ✅ 2026-08-30 | PR #4，映射/绑定/隔离契约 CI 化 |
| M3.2 Isolation Contract Test | ✅ 2026-08-30 | browser_profile_isolation_test 常驻 CI |
| M3.3 Real WebLibre Runtime | ✅ 编排层（PR #5） | 目录布局/状态机/进程绑定管理 + ADR-004 unknown 恢复语义 |
| M3.4.2 Runtime Hardening | ✅（PR #9/#10） | fail-closed 解绑 / 操作互斥 / generation / 会话持久化 v3 / 删除残留防护（ADR-006） |
| M3.4.2.5 Integration Readiness | ✅ | 状态所有权三层 / generation 原子分配 / 恢复语义三分 / Binder health 契约（ADR-007） |
| M3.4.2.6 Rehydration 补丁 | ✅ | Dart 重启 unknown 重建槽位 + health 可信判定 fail-closed + freshness（ADR-007 补遗） |
| M3.4-B.1 Real Binder 契约 | ✅（PR #13） | 通道契约 + RealWebLibreGeckoBinder + 对接点调研（m3-runtime-bridge.md） |
| M3.4-B.2-a 切换事务模型 | 🔨 本轮 | bind 返回 bound/restart_required；restartPending 终态 + 会话 restart_pending；上游 Pigeon 通道（GeckoProfileApi）复用确认 |
| M3.4-B.2-b Kotlin Bridge + 补丁 + CI | ✅（PR #15） | RuntimeBridgePlugin + Dart glue + 001/002 + android-bridge（九工作流） |
| M3.4-B.3 真机验收 | 🔨 准备就绪 | 真实 Gecko 探测已实现（probeKind=gecko_runtime，EngineProvider 第二事实源）；二十项矩阵 runbook（tools/device/README.md）；**Blocker=真机不在开发端** |
| M3.4 Real Runtime Integration | 🔨 进行中 | Binder/补丁/真机验收；runbook 见 tools/device/README.md |

## Next（按里程碑命名追踪，不绑定仓库 PR 号）

**PR-B 前置已冻结（ADR-007 补遗）**：Rehydration ✅ → Health Trust ✅ →
Real Binder → MethodChannel → v4 migration。

1. **PR-B RealWebLibreGeckoBinder**：Binder health/runtimeInfo 的 Android
   实现 + MethodChannel（落在 vendor 应用内的 Android 侧，不进纯 Dart 包；
   Binder 只做 Gecko 操作，不得知道 SQLite/Repository/NetworkRoute）+
   `patches/b4721ae6/001-add-mobile-profile-dependencies.patch`；随接线
   落 runtime_sessions v4（last_known_pid / runtime_owner）。
2. **PR-C 中文产品 UI**：首页/Profile 列表/创建编辑/启停/设置 +
   app_zh.arb，i18n CI 升级为 ARB 完整性 + 硬编码扫描。
3. **PR-D 真实 Profile 生命周期**：创建/启动/停止/删除/重建全链路。
4. **PR-E Find N3 真机验收**：Cookie 隔离 + 折叠矩阵 + am kill/低内存回收。

备注（工程规则 vs 平台强制）：8/8 全绿是团队硬规则；GitHub 侧 develop
尚未配置 Branch Protection/required status checks，二者不混为一谈，
是否启用由技术负责人裁定。

## 中文优先（一级要求，2026-08-31 起）

ADR-005 + `docs/standards/i18n.md`：产品名**「独立浏览器」**（副标题：
多 Profile 隔离浏览环境）；UI/文档/Release 中文，代码标识符与 APK 文件名
英文；内部 enum 不直接出 UI（`profileStatusZhLabel` /
`webLibreRuntimeStateZhLabel` 已落地）；`i18n-quality.yml` 常驻 CI。
自 M3 起开发版 Release 使用 `docs/release/release-notes-template.md`。

## 产品定位说明（ADR-004）

Gecko 单绑定约束 ⇒ 产品是**多 Profile 管理浏览环境**，不是多开浏览器：
同一时刻至多一个 Profile 浏览；切换走 STOP→UNBIND→CREATE→BIND→START。
多 Profile 并发浏览需要未来的进程隔离方案，当前明确不做。

## Blocker

- **真机不在开发端**：Find N3 真机验证需持机执行（tools/device/README.md
  的 runbook）；CI 侧无 Android 模拟器（当前决策不引入，见风险）。

## Risks

- Gecko 进程一次性绑定（ADR-002）：切换 Profile 必须 stop→launch，
  多 Profile 并发浏览需未来进程隔离方案。
- sqlite3 同步绑定：Android 集成时必须移入后台 isolate，否则主线程
  卡顿/ANR（M4 前处理）。
- 上游 material_ui 1.1.0 类型冲突未修（ADR-001），基线推进被阻塞。

## 质量基线

**八个 CI 工作流全绿是合入 develop 的硬条件**（android-m1 / domain-test /
domain-quality / integration-test / storage-test / browser-adapter-test /
weblibre-runtime-test / i18n-quality）。本地预检五包测试
（Dart 3.13.1，`.tools/dart-sdk`）。
