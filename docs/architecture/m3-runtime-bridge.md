# M3 Runtime Bridge：WebLibre 真实对接点（PR-B 设计依据）

> 基于对 vendor/weblibre @ b4721ae6 的源码调研（2026-08-31）。
> 本文是 RealWebLibreGeckoBinder 的实现依据，评审以本文件为准。

## 一、上游运行时模型（决定性事实）

| 组件 | 位置 | 职责 |
| --- | --- | --- |
| `StartupArbiter` | flutter_mozilla_components/android/.../startup/StartupArbiter.kt | **进程级仲裁**：`beginStartup(lease)`→directive、`commitSelection(leaseId, profileId)`、`heartbeatSelection`、`committedProfileId()`、`boundProfileFolder()`、`currentState()`、`onCommitted(cb)` |
| `ActiveProfile` | 同上 `ActiveProfile.kt` | 按 `boundProfileFolder()` 重定向 Context（每 Profile 独立 SharedPreferences/数据）；`persistNextStartProfile` 写入**下一次启动**要绑定的 Profile |
| `RestartCoordinator` | 同上 `RestartCoordinator.kt` | **切换 Profile 的官方途径**：`arm(...)` → `terminate` → trampoline + alarm 重启进程 |
| `filesystem.activate(UuidValue)` | apps/weblibre/lib/core/filesystem.dart | Dart 侧一次性绑定；同 Profile 幂等；跨 Profile 抛错（原话 "switching requires a restart"）；合法时点 = native arbiter 已 commit 同一 Profile 之后（启动 bootstrap 内） |
| `fs.createNewProfile` | apps/weblibre/lib/utils/filesystem.dart | 目录创建（幂等），metadata.json 原子写 |

**结论：上游不存在运行时 rebind。** Profile 切换 = `persistNextStartProfile`
+ `RestartCoordinator` 进程重启 → 新进程 StartupArbiter commit → Dart
`activate`。这印证并强化 ADR-004：单进程单绑定是上游硬约束。

## 二、Binder 语义映射（真实含义）

| 契约方法 | 上游真实语义 |
| --- | --- |
| `bind(id, dir, sessionId, generation)` | 提交并进入该 Profile 的浏览进程（首版 = 当前进程 activate 路径，切换场景 = 持久化 next profile + 重启编排） |
| `unbind(id, sessionId, generation)` | 退出浏览（浏览进程终止/回主进程）；抛错不保证已退出 |
| `health(id)` | 实时查询：StartupArbiter 当前状态 + Gecko runtime 存活 + 绑定身份（sessionId/generation 由 bridge 侧回读）→ `RuntimeHealth` |

`health` **禁止缓存**：observedAt 必须为本次查询完成时刻（ADR-007
freshness，healthMaxAge 默认 30s）。

## 三、通道协议（PR-B.1 冻结，实现在 B.2/B.3 落地）

- MethodChannel：`weblibre/runtime_bridge`，方法 `bind` / `unbind` /
  `health`，参数与返回见 `WebLibreRuntimeBridgeChannel` 的文档注释。
- EventChannel：`weblibre/runtime_bridge/events`，事件负载必须携带
  `{event, browserProfileId, sessionId, generation}`——**双重 fencing**，
  Dart 侧一律经 `manager.isCurrentSession()` 校验，过期回调丢弃。
- pid：Android 侧真实 `android.os.Process.myPid()`/Gecko 进程号；
  v4 迁移（PR-B.4）之前不持久化。

## 四、PR-B 分片（技术负责人裁定顺序）

| 分片 | 内容 | 状态 |
| --- | --- | --- |
| B.1 | 通道契约 + RealWebLibreGeckoBinder（Dart 侧，纯 Dart 可测） | 🔨 本轮 |
| B.2 | Android MethodChannel/EventChannel 实现（vendor 内 Kotlin） | ⏳ |
| B.3 | `patches/b4721ae6/001-add-mobile-profile-dependencies.patch` + `002-add-profile-runtime-bridge.patch`；patched 构建进 CI | ⏳ |
| B.4 | runtime_sessions v4（last_known_pid / runtime_owner）——仅在真实数据来源就绪后 | ⏳ |

## 五、边界（继续有效）

Binder 是 Runtime Adapter：不知道 SQLite / Repository / NetworkRoute /
DeviceProfile（ADR-007）。Profile 目录创建复用上游 `createNewProfile`
语义（`DirectoryWebLibreProfileStorage` 已对齐），不在 Android 侧重造。
