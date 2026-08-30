# Find N3 真机验收 Runbook（M3 Gate 收口）

> 在 OPPO Find N3 上执行 M3 最终验收。全部通过后 M3 才算完成。
> 开发端无真机，本 runbook 供持机会话/人工执行，结果记录回本文件。

## 准备

1. 从 CI Artifact 下载 `mobile-profile-browser-m1-debug` APK 安装
   （或本地 `flutter build apk --debug` 后安装）。
2. 记录设备观测值（填入下方"设备观测记录"，同时更新
   `docs/devices/oppo-find-n3.md`）。

## 验收 1：双 Profile 目录隔离

```bash
adb shell run-as <applicationId> ls files/weblibre_profiles/
# 期望：profile-A 与 profile-B 两个目录（对应两个 MobileProfile），
# 各自包含 metadata.json；绑定后出现 files/mozilla/
```

## 验收 2：Cookie 隔离（核心）

1. 打开 Profile A → 访问测试页（本地 httpd 或 `httpbin.org/cookies/set?profile=A`）
   → 确认写入 cookie profile=A → 退出。
2. 打开 Profile B → 访问同一页面 → **必须读不到 profile=A**。
3. 反向同验（B→A）。
4. 重启 App → 两 Profile 各自 cookie 仍在（持久化恢复）。

## 验收 3：折叠/生命周期矩阵

| 场景 | 操作 | 期望 |
|---|---|---|
| 外屏启动 | 折叠态冷启动 | 正常进入，Profile 状态正确 |
| 内屏启动 | 展开态冷启动 | 同上 |
| 展开 | 运行中展开 | 布局自适应，无崩溃，状态保持 |
| 折叠 | 运行中折叠 | 同上 |
| Activity 重建 | 开发者选项"不保留活动"后切回 | Profile 状态/绑定正确恢复 |
| 后台恢复 | Home → 数分钟 → 回前台 | 同上 |
| 横竖屏 | 旋转 | 同上 |
| 分屏 / 键盘 | 后续阶段 | — |

实现红线：不得缓存 width/height/density——每次经 WindowMetrics
（`MediaQuery.of(context)`）重新读取；折叠切换即尺寸变化。

## 验收 4：崩溃恢复（真机版）

1. Profile 处于运行态 → `adb shell am kill <package>`（模拟进程死亡）。
2. 重新打开 App → Profile 不得仍显示 RUNNING；
   经 unknown → recovering 收敛为 ready（见 M2 恢复语义），
   用户可重新启动。

## 设备观测记录（首次执行时填写）

- Android 版本：
- ColorOS 版本：
- build 指纹（`getprop ro.build.fingerprint`）：
- 内/外屏实际 DisplayMetrics（DPR/尺寸）：
- GeckoView 实际版本（about:weblibre 或日志）：

## 结果记录

| 验收项 | 日期 | 结果 | 备注 |
|---|---|---|---|
| 目录隔离 | | | |
| Cookie 隔离 | | | |
| 重启恢复 | | | |
| 折叠矩阵 | | | |
| 崩溃恢复 | | | |
