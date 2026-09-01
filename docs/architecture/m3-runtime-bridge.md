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

## 三、通道协议（PR-B.2 修订：bind 返回切换事务结果）

上游**已有官方 Pigeon 通道**（B.2 调研确认）：
`flutter_mozilla_components` 的 `GeckoProfileApi`（Kotlin
`GeckoProfileApiImpl` ↔ Dart `GeckoProfileService`），暴露
beginStartup / commitSelection / heartbeat / release /
armProfileRestart / completeProfileRestart。**bind/unbind 的原生执行
路径直接复用它**；我们自己的 `weblibre/runtime_bridge` MethodChannel
只补上游缺失的 health/runtimeInfo 探测。

- MethodChannel `weblibre/runtime_bridge`：
  - `bind`：committed==target → `{result:'bound'}`；否则
    `armProfileRestart(target)` 成功 →
    `{result:'restart_required', currentProfile, targetProfile}`；
    arm 失败 → error（Dart 侧 failed）。
  - `unbind`：先回 `{result:'exiting'}` 再 `RestartCoordinator.terminate`
    （原方法即 `exitProcess(0)`，必须先应答否则 Dart await 悬挂）。
  - `health`：`{alive, browserProfileId, sessionId, generation, pid?,
    observedAt}`——sessionId/generation 来自 bridge 内存中记录的最近
    bind 身份（执行层单值状态，非数据库）；进程重启后丢失 → 空身份 →
    Dart 可信判定 fail-closed 判死（正确：旧会话本就该判死）。
- 事件（EventChannel `weblibre/runtime_bridge/events`）：
  `{event, browserProfileId, sessionId, generation}`——双重 fencing。

### 切换事务（硬规则：禁止运行时 rebind）

```text
stop(A) → launch(B)
  ↓ allocateSession(B, restart_pending 先落盘)
  ↓ armProfileRestart(B)（persistNextStartProfile + trampoline + alarm）
  ↓ 本进程：restartPending 终态（不许转出，不谎称 running）
  ↓ 进程死亡 → 新进程 StartupArbiter commit B → activate(B)
  ↓ Rehydration(restart_pending) → unknown → health 四元组+freshness 裁决
  → 可信 → running；不可信/死亡 → stopped（无状态漂移）
```

中途任何失败都不会把 A 标 stopped、B 标 running：A 的会话由 stop 正常
收敛；B 的会话停在 restart_pending（声称存活集合成员），由下一进程裁决。
旧会话收敛为 stopped 的前提限定于当前单 Runtime（runtime_owner=应用
进程）架构假设；Gecko 进程独立化后此规则必须重新评估。

### health 的 bindingPresent 与 runtimeAlive（B.3 落地：真实 Gecko 探测）

**B.3 起为真实现**（002 补丁已升级，待真机验证）：

```text
bindingPresent : StartupArbiter 提交 + 绑定目录（"系统认为已绑定"，独立诊断字段）
runtimeAlive   : EngineProvider.runtimeState() —— Live/NeverCreated/Shutdown
                 （与 Arbiter 独立的第二事实源；Live.profileId 交叉核验目标）
probeKind      : "gecko_runtime"
geckoState     : live | never_created | shutdown（证据字段）
alive          : bindingPresent && runtimeAlive —— 缺一不可
```

B3-12 判别器：`Arbiter COMMITTED ∧ Gecko 已 shutdown/未创建` 时，
runtimeAlive=false ⇒ alive=false——binding_presence 不得单独放行。
B.2-b 期间的 binding_presence 过渡模式已被替换；真机验证见
tools/device/README.md 的 B3-12。

### 会话身份重建链（B.3 真机验收前置，B.2-b 已落 Kotlin）

```text
进程重启（切换事务后）
  ↓ bridge 内存身份丢失 → health 返回空身份 → Dart fail-closed 判死（旧会话，正确）
  ↓ 新进程 bootstrap：StartupArbiter commit B → activate(B)
  ↓ Dart 层读取 SQLite restart_pending 会话（持久化意图）
  ↓ attachSessionIdentity(browserProfileId=B, sessionId, generation)
  ↓ Kotlin 核验：StartupArbiter.committedProfileId == B 才接受（拒绝伪造）
  ↓ health 携带身份 → Dart 可信判定（四元组+freshness）→ running
```

不重建该链会出现"Gecko 启动成功但 Dart 判死"。桥的内存身份是执行层
单值状态，不是数据库。

### unbind 应答顺序（P0 集成测试点）

`RuntimeBridgePlugin.handleUnbind`：**先 `result.success({result: exiting})`
（主线程同步写出应答字节），再把 `completeProfileRestart()`（内部
exitProcess(0)）投递到主线程队列末尾**——保证应答先于进程退出送达，
Dart 的 await 不得悬挂。该顺序是 B.3 真机集成测试必测点。

## 四、PR-B 分片（技术负责人裁定顺序）

| 分片 | 内容 | 状态 |
| --- | --- | --- |
| B.1 | 通道契约 + RealWebLibreGeckoBinder（Dart 侧） | ✅ PR #13 |
| B.2-a | bind 契约返回 BindOutcome + restartPending 事务模型 + 测试 | ✅ PR #14 |
| B.2-b | Kotlin RuntimeBridgePlugin（bind/unbind/health/attachSessionIdentity）+ Dart glue + 001/002 补丁 + android-bridge CI | 🔨 本轮 |
| B.3 | patched APK 真机验收：切换重启事务 + Cookie 隔离 + 身份重建链 + unbind 顺序 | ⏳ |
| B.4 | runtime_sessions v4（last_known_pid / runtime_owner）——仅在真实数据来源就绪后 | ⏳ |

android-m1 保持**纯上游基线**验证；android-bridge = 上游 + 001/002 +
bridge。不为 CI 绿修改 android-m1。

## 五、边界（继续有效）

Binder 是 Runtime Adapter：不知道 SQLite / Repository / NetworkRoute /
DeviceProfile（ADR-007）。Profile 目录创建复用上游 `createNewProfile`
语义（`DirectoryWebLibreProfileStorage` 已对齐），不在 Android 侧重造。
