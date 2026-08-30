# ADR-004：Gecko Runtime 单绑定约束

日期：2026-08-30 · 状态：已接受

## 事实

上游 WebLibre（b4721ae6，core/filesystem.dart）明确：**Gecko runtime
与 Android 进程一次性绑定**。绑定后不能重定向——第二次激活会让 Dart
与 Gecko 读取不同 Profile 且无法调和。

即每个进程的结构是：

```text
Process
  └── Gecko Runtime（至多一个）
        └── 当前绑定的 Profile（至多一个）
```

**不是**每个 Profile 一个 Gecko Runtime。

## 决策

1. 产品定位为**多 Profile 管理浏览环境**，不是"多开浏览器"：同一时刻
   至多一个 Profile 处于浏览状态。
2. `WebLibreRuntimeManager` 强制独占所有权（单绑定槽位）：绑定期间
   `launch` 其他 Profile 直接拒绝。
3. Profile 切换必须走完整序列，不得走捷径：

```text
STOP → UNBIND → CREATE(如需) → BIND → START
```

4. 进程死亡后的恢复不得直接 `RUNNING → STOPPED`：持久化声称
   starting/running/stopping 的句柄先降级为 `unknown`（承认知识失效），
   经健康检查收敛到 `running`/`stopped`。新进程内不存在旧 runtime，
   结论恒为 `stopped`（`recoverAfterRestart`）。

## 后果

优点：
- 符合 Gecko 生命周期，避免数据污染；
- 恢复语义简单（进程重启 ⇒ runtime 必死）；
- 与上游升级兼容（约束来自上游本身）。

代价：
- 第一版不能多窗口同时浏览多个 Profile；
- "多 Profile 并发浏览"需要未来的进程隔离方案（单独 ADR 评估，
  参考 GeckoView 多进程能力），当前明确不做。

## 关联

- ADR-002 Profile 隔离架构（本约束是其运行时层的基础）
- `packages/mobile_profile_weblibre`（约束的代码实现）
