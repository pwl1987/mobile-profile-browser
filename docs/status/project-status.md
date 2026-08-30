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
| M3.3 Real WebLibre Runtime | 🔨 编排层完成 | PR #5：目录布局/状态机/进程绑定管理（Dart 层） |
| M3.4 Find N3 Device Validation | ⏳ 待真机 | 验收脚本见 tools/device/README.md |

## Next

1. 真实 Gecko 绑定实现（Android/Flutter 侧 WebLibreGeckoBinder）+
   `patches/b4721ae6/0001-profile-hooks.patch`。
2. Find N3 真机执行 M3 验收（Cookie 隔离 / 重启恢复 / 折叠矩阵）。

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
