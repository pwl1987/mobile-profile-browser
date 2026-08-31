# ADR-007：Runtime 状态所有权与接入前边界

日期：2026-08-31 · 状态：已接受（M3.4.2.5 Runtime Integration Readiness；
Rehydration 与 health 可信判定为同日实施补遗，见文末）

## 一、状态所有权：三层真相，不得混同

进入 Android Binder 前钉死的架构定义：

| 层 | 载体 | 回答的问题 | 读写规则 |
| --- | --- | --- | --- |
| **持久化真相** | SQLite `runtime_sessions` | "曾经发生了什么、恢复时从哪起步" | 启动意图先落盘；迁移逐次落盘；进程死亡后是恢复的唯一输入 |
| **编排真相** | `WebLibreRuntimeManager` 内存态（`_bound` + 单绑定槽位） | "本进程此刻的编排决定" | 只由 manager 在互斥队列内写入；**绝不代表 Gecko 实际存活** |
| **实际真相** | Android/Gecko 进程内状态 | "Gecko 现在到底活没活、绑定着谁" | **只能经 Binder `health()` 观测，永远不能被推测** |

推论：

1. 内存态与持久化可能短暂不一致（如 `_bound=running` 而会话行还是
   `stopping` 落盘前的中间态）——不一致时以持久化为恢复基准，以健康
   检查为裁决，不做自动"修复"。
2. 编排真相不得写入"实际存活"断言；`unknown` 就是"编排层不知道实际
   真相"的诚实表达。
3. 跨 Manager 实例（Activity 重建等）的槽位互斥在纯 Dart 层**不成立**
   ——单绑定槽位是进程级事实，属于实际真相，Binder 阶段由 Gecko
   单绑定约束本身兜底（上游行为），manager 槽位只是编排层防线。

## 二、恢复语义三分：Dart 重启 ≠ 应用进程死亡 ≠ Gecko 死亡

三种情形，两种恢复路径：

| 情形 | 事实 | 恢复策略 |
| --- | --- | --- |
| **应用进程死亡** | 当前 WebLibre 架构下 Gecko 运行于应用进程内 ⇒ 进程死 ⇒ Gecko 必死 | `recoverAfterApplicationProcessDeath()`：声称存活 → unknown → **直接 stopped**（假设成立的前提是 Gecko 同进程；若未来 Gecko 迁独立进程，此路径必须改走健康检查） |
| **Dart engine 重启、应用进程未死** | Gecko **可能仍存活**（如 Flutter engine 重建） | `recoverAfterDartRestart()`：声称存活只降级 **unknown 落盘**，不自动判死；裁决交给健康检查 |
| **Gecko 死亡、应用进程未死** | 运行时崩溃 | 经 Binder 回调/健康检查发现，走 confirmUnknownDead / resolveUnknownViaHealth |

禁止再出现"看见持久化 RUNNING 就直接 STOPPED"的一步式恢复
（应用进程死亡路径除外，且其前提已被显式声明）。

## 三、generation 由持久化层原子分配

旧实现 `latestForProfile().generation + 1` 存在读-改-写竞争：两个
Manager（Activity 重建交错）可能同时读到 5 并各自分配 6。

新契约：`BrowserRuntimeSessionRepository.allocateSession(...)` 在
持久化事务内完成 `MAX(generation)+1` 与起始会话落盘——并发分配得到
严格不同且连续的 generation。Manager 一律经 allocateSession 取号，
不得自行计算。

## 四、Binder 契约（升级版，本 ADR 冻结形状、Android 实现属 M3.4.3）

```text
bind(browserProfileId, profileDir, sessionId, generation)
unbind(browserProfileId, sessionId, generation)
health(browserProfileId) -> RuntimeHealth
```

`RuntimeHealth`：`alive / browserProfileId / sessionId / generation /
pid? / observedAt`（health 即 runtimeInfo，一个结构承载观测结果；
pid 在 Binder 接入前可空）。sessionId/generation 随 bind/unbind 传递，
Android 侧回调必须原样携带并经 `isCurrentSession` 校验。

Binder 边界（继续有效）：只做 Gecko 操作，禁止依赖 SQLite /
Repository / NetworkRoute / DeviceProfile。

## 五、RuntimeSession schema 前瞻（避免 Binder 后反复迁移）

现有 v3 列保持不变。Binder 阶段预计 **一次性 v4** 追加：

```text
last_known_pid   真实 Android PID（Binder 前拿不到，不加空列）
runtime_owner    运行时宿主标识（当前恒为应用进程；未来 Gecko 独立进程时区分）
```

在需要真实数据之前不做 v4——不为尚无数据来源的字段提前开列。

## 六、Dart 重启后的 Rehydration（实施补遗，修复闭环漏洞）

初版实现只把持久化降级为 unknown 而 `_bound = null`——导致 launch 仅凭
内存态放行新 Profile（unknown 不设防），且 `resolveUnknownViaHealth`
因槽位为空永远无法执行。修正后的 Rehydration 链：

```text
Dart Restart
   ↓ 从 runtime_sessions 恢复声称存活会话
   ↓ 最新一条 → 重建为 unknown 槽位（继续独占，禁止新 launch）
   ↓ 其余较旧声称存活会话 → 收敛 stopped（单槽位不变量：至多一个真实运行时）
   ↓ Binder health()
   ↓ 可信判定（见七）
alive+可信 → running    不可信/死亡 → stopped → 释放槽位
```

## 七、health 可信判定（fail-closed，缺一不可）

初版允许 `sessionId` 为空的 alive 观测通过、且未校验新鲜度——把
"缺数据"当成了"可信数据"。修正后的规则：

```text
alive == true
AND browserProfileId == 当前槽位
AND sessionId 非空且 == 当前会话
AND generation == 当前代际
AND observedAt <= now（时钟超前不可信）
AND observedAt >= now - healthMaxAge（默认 30s，构造参数可调）
→ 可信 → running；任一不满足 → stopped（fail-closed）
```

## 八、M3 Gate 状态（本 ADR 生效时）

M3 尚未完成：generation 已强化、恢复语义已三分；待办——Real Gecko
Binder / MethodChannel / 中文产品 UI / Find N3 真机。
