# WebLibre 补丁管理

## 目录规则

补丁按**目标基线 commit** 分目录存放，文件名用三位序号 + 语义名
（M3.4 约定，便于未来扩展排序）：

```text
patches/
├── b4721ae6/                          当前锁定基线（可构建，M1 已验证）
│   ├── 001-add-mobile-profile-dependencies.patch   （规划中）
│   └── 002-add-profile-runtime-bridge.patch        （规划中）
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

- `b4721ae6/`：空。M3.4 需要的前两枚补丁（命名见上）：
  `001-add-mobile-profile-dependencies.patch`（把 mobile_profile_* 包以
  path 依赖接入 vendor/weblibre/apps/weblibre/pubspec.yaml，即
  apply-weblibre-patches.sh 当前在运行时做的那份注入）与
  `002-add-profile-runtime-bridge.patch`（RealWebLibreGeckoBinder 的
  Android 侧桥接，落在 vendor 应用内，不污染纯 Dart 包）。
- `dc74be45/0002-material-ui-compatibility.patch`：针对已损坏基线编写，
  存档不使用；上游修复 material_ui 1.1.0 类型冲突后重新评估。

## 与工具脚本的关系

`tools/apply-weblibre-patches.sh` 目前在运行时向 vendor pubspec 注入
path 依赖（幂等、不修改子模块 Git 历史）；补丁文件化（本目录）是它的
可审计替代形态，两者不并存使用。
