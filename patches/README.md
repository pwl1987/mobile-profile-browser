# WebLibre 补丁管理

## 目录规则

补丁按**目标基线 commit** 分目录存放，文件名用三位序号 + 语义名
（M3.4 约定，便于未来扩展排序）：

```text
patches/
├── b4721ae6/                          当前锁定基线（可构建，M1 已验证）
│   ├── 001-add-mobile-profile-dependencies.patch
│   ├── 002-add-profile-runtime-bridge.patch
│   └── 003-profile-runtime-check-page.patch
└── dc74be45/                          历史基线（上游损坏，仅存档）
    └── 0002-material-ui-compatibility.patch
```

规则：

1. 每个补丁必须只针对一个基线目录编写，目录名即目标 commit。
2. 升级基线时：新基线目录下的补丁全部通过 `git apply --check` 与
   android-m1 工作流验证后，才能合入；旧目录保留存档。
3. 不为"补丁存在"去适配错误基线（ADR-001）。
4. 补丁进入 CI（android-m1 应用补丁后构建）之前，`patches/b4721ae6/`
   允许为空——当前 APK Gate 验证的是纯上游可重复构建。

## 当前状态

- `b4721ae6/001-add-mobile-profile-dependencies.patch`：✅ 已落地——
  把 `mobile_profile_domain` / `mobile_profile_storage` /
  `mobile_profile_weblibre` 以 path 依赖接入 vendor 应用 pubspec。
- `b4721ae6/002-add-profile-runtime-bridge.patch`：✅ 已落地——
  Kotlin `RuntimeBridgePlugin`（bind/unbind/health/attachSessionIdentity，
  薄转发上游 GeckoProfileApi + StartupArbiter；B.3 诊断通道
  selfCheck/readLogTail/clearLog + 应用私有文件日志 `b3-bridge.log`，
  5MB 超限轮转，供 adb 导出取证）、Dart glue
  `MethodChannelRuntimeBridge`、MainActivity 注册。
- `b4721ae6/003-profile-runtime-check-page.patch`：✅ 已落地——
  设置 → 高级 → 开发者工具新增「Profile Runtime 检查」入口，
  全屏检查页（`Dialog.fullscreen`，不新增路由、不触碰上游路由代码生成）：
  创建/启动/停止 B3-A/B3-B、运行时会话与 selfCheck/health 快照、
  恢复与裁决操作、`b3-bridge.log` 路径/尾部读取/清空 + adb 导出提示、
  操作记录（最近 80 条）。驱动栈：`ProfileStore`（SQLite 会话持久化）
  + `DirectoryWebLibreProfileStorage` + `WebLibreRuntimeManager` +
  `MethodChannelRuntimeBridge`，全部走真实契约。
  CI：`android-bridge.yml`（上游 + 001/002/003 打补丁构建；android-m1
  保持纯上游基线，二者不互相迁就）。
- 补丁修改/新增文件一律先本地 `git -C vendor/weblibre apply --check`
  验证，CI 再跑 --check + apply 双保险。
- `dc74be45/0002-material-ui-compatibility.patch`：针对已损坏基线编写，
  存档不使用；上游修复 material_ui 1.1.0 类型冲突后重新评估。

## 与工具脚本的关系

`tools/apply-weblibre-patches.sh` 目前在运行时向 vendor pubspec 注入
path 依赖（幂等、不修改子模块 Git 历史）；补丁文件化（本目录）是它的
可审计替代形态，两者不并存使用。
