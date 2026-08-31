# ADR-006：Runtime 生命周期 Fail-Closed 与会话持久化

日期：2026-08-31 · 状态：已接受

## 背景

真实 Binder（MethodChannel → Android → Gecko）接入前的架构收口
（M3.4.2 Runtime Hardening）。库级评审发现三个必须在接线前修掉的问题：

1. `unbind()` 失败时错误释放绑定槽位——unbind 失败 ≠ 已解绑，Gecko 可能
   仍占用原 Profile，随后 `launch(B)` 被放行，逻辑层与真实 Runtime 状态分叉；
2. `launch`/`stop` 为 async，槽位检查与赋值之间隔着 `await`，存在
   check-then-act 竞态（并发 launch(A)+launch(B) 可能双双通过检查）；
3. `recoverAfterRestart()` 只作用于内存态 `_bound`——进程死亡后 Dart heap
   消失，不是真正的恢复。

## 决策

### 1. Fail-closed 解绑

```text
unbind 成功 → stopped → 释放槽位
unbind 失败 → unknown → 保留槽位（阻止新 Profile 启动）
                ↓ 健康检查
        确认死亡 → stopped → 释放（confirmUnknownDead）
```

Binder 契约固化：`bind` 抛错 = 保证未绑定（可释放槽位重试）；
`unbind` 抛错 = 不保证已解绑（必须保留槽位）。与网络故障 fail-closed
同一原则：**不知道 Runtime 死没死时，宁可阻止新启动，不冒险放开。**

### 2. 操作互斥

`WebLibreRuntimeManager` 内部串行队列：launch / stop / confirm /
recover 全部排队执行，错误不阻断后续排队。消灭 check-then-act 竞态
（有确定性测试：闸门存储复现挂起窗口，并发第二个 launch 必被拒绝）。

### 3. 会话持久化（schema v3 `runtime_sessions`）

启动意图**先落盘 STARTING 再执行绑定**；每次状态迁移落盘。进程死亡后
数据库中的声称存活状态（starting/running/stopping/unknown）是唯一真相
来源，`recoverAfterProcessRestart()` 逐条 unknown → stopped 收敛
（新进程内旧 Gecko runtime 必死），收敛后即可重新启动。

### 4. generation 与回调守卫

会话携带随 Profile 单调递增的 generation 与唯一 sessionId；
Android 侧回调必须经 `isCurrentSession(sessionId, generation)` 校验，
过期回调一律丢弃——防旧 Runtime 迟到回调误杀新会话。

### 5. Profile 删除的数据残留防护

删除顺序固定：**运行中/unknown → 拒绝**；先删磁盘目录、失败则绑定保留
（可重试）；成功再删 SQLite 绑定。反序会出现"库已删、磁盘 Cookie 残留"。
见 `ProfileTeardownService`。

## 后果

- unknown 槽位期间新 Profile 无法启动——符合 fail-closed，接受。
- 会话历史保留（审计），Profile 删除时级联清理。
- 真机验收必须包含：创建→启动→停止→删除→重建的全生命周期
  （见 tools/device/README.md）。
