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
| M3.4.2 Runtime Hardening | ✅（PR #9） | fail-closed 解绑 / 操作互斥 / generation / 会话持久化 v3 / 删除残留防护（ADR-006） |
| M3.4 Real Runtime Integration | 🔨 进行中 | Binder/补丁/真机验收；runbook 见 tools/device/README.md |

## Next

1. M3.4.3（PR #10）：`RealWebLibreGeckoBinder` + MethodChannel 桥（落在
   vendor 应用内的 Android 侧，不进纯 Dart 包；Binder 只做 Gecko 操作，
   不得知道 SQLite/Repository/NetworkRoute）+
   `patches/b4721ae6/001-add-mobile-profile-dependencies.patch`。
2. M3.4.4（PR #11）：中文产品 UI（首页/Profile 列表/创建编辑/启停/
   设置）+ app_zh.arb，i18n CI 升级为 ARB 完整性 + 硬编码扫描。
3. M3.4.5（PR #12）：Find N3 真机验收——创建/启动/停止/删除/重建全
   生命周期 + Cookie 隔离 + 折叠矩阵 + am kill/低内存回收。

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

七个 CI 工作流全绿是合入 develop 的硬条件；本地预检五包 103 测试
（Dart 3.13.1，`.tools/dart-sdk`）。
