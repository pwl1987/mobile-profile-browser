# Find N3 真机验收 Runbook（B.3，2026-09-01 冻结版）

> 二十项验收矩阵（B3-01～B3-20）由技术负责人冻结。**完整 PASS 的硬条件**：
> health 返回 `probeKind=gecko_runtime` 且 `runtimeAlive` 来自
> EngineProvider 真实状态——切换全过但探测未升级最多 PARTIAL PASS。
> B3-12 为最关键单项。

## 准备

1. 从 CI Artifact 下载 `mobile-profile-browser-bridge-debug`（上游+001/002
   补丁构建）安装；或本地按 android-bridge 工作流同流程构建。
2. 抓取证据（全程开着）：
   ```bash
   adb logcat -s MobileProfileBridge:I flutter:V -v time | tee b3-bridge.log
   ```
   bridge 每步输出：sessionId/gen/observedAt/probeKind/pid 与退出时间线。
3. 记录设备观测值到"设备观测记录"并回填 `docs/devices/oppo-find-n3.md`。

## 验收矩阵

| # | Gate | 步骤 | 期望 | 证据要点 |
|---|---|---|---|---|
| B3-01 | 首次 Profile 启动 | 创建 Profile A → 启动 | bind 日志 `result=bound`；health `geckoState=live` 且 `geckoProfileId==A`；会话 running | bind 行（session/gen/pid）、health 行 |
| B3-02 | A → B 切换 | A 运行中 → 启动 B | bind `restart_required` + currentProfile=A；UI 呈现切换；进程自动重启；新进程 commit B、activate | restart_required 行、旧进程 terminate 行、新进程 register 行、PID 变化 |
| B3-03 | B → A 切换 | 反向重复 B3-02 | 同上对称 | 同上 |
| B3-04 | 切换中重复 launch | B3-02 的 restart_pending 期间再 launch C | 被拒（事务进行中） | 拒绝日志/异常 |
| B3-05 | restartPending 时 stop | 同上状态调用 stop | 明确拒绝，不产生部分状态 | 异常信息 |
| B3-06 | Cookie 隔离 | A 写 cookie=A→停→切 B→同一测试页 | B 读不到 A；反向同 | 页面观测 + 目录核对 |
| B3-07 | localStorage/IndexedDB 隔离 | 同 B3-06 换存储类型 | 同上 | 页面观测 |
| B3-08 | attachSessionIdentity | 新进程 activate 后注入会话身份 | `adopted=true`；随后 health 携带正确 session/gen | attach 行 + health 行 |
| B3-09 | unbind 应答先于退出 | 停止浏览 | Dart await 不悬挂（先见 `exiting` 应答日志，再见 `terminate` 行） | 两行日志顺序 + 时间差 |
| B3-10 | am kill 应用进程死亡 | `adb shell am kill <pkg>` 后重启 App | 持久化声称存活经 unknown 收敛 stopped；可重新启动 | 重启后 health/会话状态 |
| B3-11 | Dart 重启 Rehydration | 触发 Flutter engine 重建（如热重启） | 声称存活降级 unknown 槽位，不自动判死；经 health 裁决 | unknown→裁决时间线 |
| **B3-12** | **Gecko 死而 Arbiter 仍 COMMITTED** | 人为终止 Gecko runtime（如 `adb shell am force-stop` 后快速重进 / 或上游维护通道 shutdown runtime） | **health 必须 `runtimeAlive=false`、`alive=false`（geckoState=shutdown/never_created）——binding_presence 不得单独放行** | health 行含 geckoState |
| B3-13 | 低内存杀进程 | 后台多应用挤压后返回 | 恢复路径与 B3-10 一致 | 同 B3-10 |
| B3-14 | 折叠→展开 | 运行中折叠再展开 | 布局自适应、状态保持、度量值不缓存 | 屏幕度量即时读取 |
| B3-15 | 折叠态切 Profile | 折叠状态下执行 B3-02 | 与展开态行为一致 | 同 B3-02 |
| B3-16 | 快速 A→B→A | 连续两次切换 | 两次 restart 事务都正确落地，无中间态泄漏 | 两轮 restart/terminate/commit 时间线 |
| B3-17 | stale health | 注入 30s 前的 observedAt（调试通道） | fail-closed 判死（不回 running） | 裁决拒绝记录 |
| B3-18 | 错误 session/generation | 注入不匹配身份 | isCurrentSession=false；健康裁决不可信→stopped | 拒绝记录 |
| B3-19 | 错误 committedProfileId | attachSessionIdentity 带错误目标 | `adopted=false`（拒绝伪造） | attach rejected 行 |
| B3-20 | 新进程重建身份 | B3-02 完成后核对 | 新进程 identity 链成立（B3-08 通过即证） | attach+health 成对 |

## 结果记录

| # | 日期 | 结果 | 证据文件/行 | 备注 |
|---|---|---|---|---|
| B3-01…20 | | | | |

## 原始证据要求（技术负责人裁定）

逐项带回：**原始日志**（b3-bridge.log）、每步实际状态、sessionId/generation、
observedAt、probeKind、进程 PID 与退出时间线。裁决按本矩阵逐项进行，
不接受"测试通过"四字结论。

## 设备观测记录（首次执行时填写）

- Android 版本：
- ColorOS 版本：
- build 指纹（`getprop ro.build.fingerprint`）：
- 内/外屏实际 DisplayMetrics（DPR/尺寸）：
- GeckoView 实际版本（about:weblibre 或日志）：

## 结果回填

全部通过 → 在 `docs/status/project-status.md` 标记 M3.4-B.3 ✅ 并附
Run/证据索引；单项失败 → 记录复现步骤与日志，不进入 PR-C。
