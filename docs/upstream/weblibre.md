# WebLibre 上游锁定记录

本文件记录 `vendor/weblibre` 子模块的锁定基线、构建工具链与升级规则。
每次升级上游前必须先更新本文件草稿，全部验证通过后才允许合入。

## 上游信息

- 上游仓库：`FaFre/WebLibre`（https://github.com/FaFre/WebLibre）
- 许可证：AGPL-3.0（本项目分发策略在正式发布前需单独合规审查）
- 集成方式：`vendor/weblibre` Git Submodule，永远锁定 commit
- 禁止 `git submodule update --remote` 跟随上游分支

## 当前锁定基线

| 用途 | commit | 使用者 |
|---|---|---|
| **统一基线（2026-08-30 起）** | `b4721ae6b34aea65e589417b3a64244cc14dbb91` | git 索引、三个 tools 脚本、全部 CI 工作流、README |

统一过程与依据：

1. M1 期间出现双基线并存：索引/CI 用 `b4721ae6`，文档/补丁脚本用
   `dc74be45`（两者仅差 1 个上游提交），导致 domain-quality 工作流自
   d7cd51a 起持续失败。
2. 2026-08-30 曾尝试统一到审计基线 `dc74be45`（"update flutter deps"），
   android-m1 工作流实测：**纯上游在 Flutter 3.47.1 下 `flutter analyze`
   报 6 个 error**——material_ui 1.1.0 的 `ColorScheme` 与
   flutter/material 的类型冲突（main.dart:470-486）。上游自身在该提交
   不可分析通过。
3. 因此统一回退到可构建的父提交 `b4721ae6`（M1 APK Gate 已在该基线
   验证通过）。`dc74be45` 保留为审计范围上限。

待办（M3 处理）：`patches/weblibre/0002-material-ui-compatibility.patch`
针对 `dc74be45` 编写，在 `b4721ae6` 上无法应用；补丁流进入 CI 时需要
基于 `b4721ae6` 重做或跟随上游修复 material_ui 冲突后重新评估基线。

## 构建工具链（M1 Gate 已验证）

- Flutter 3.47.1 stable（Dart 3.13.1，CI 强制核验）
- Java 17（Temurin）
- Go 1.25
- Android NDK 29.0.14206865（版本号读自上游 `apps/weblibre/android/gradle.properties`）
- mozilla-components 154.0（`packages/flutter_mozilla_components` 引入，内含 GeckoView，随 Mozilla Maven 解析）
- gomobile Runtime 源码锁定（`native/go_mobile_runtime/pins.env`）：
  - sing-box v1.13.12（`1086ab2563320e0da0c23b3a491d8dfa0939dff4`）
  - IPtProxy 5.4.2（`3b99b6b1f4d5b51aea97d7213bc36e74ec77c84d`，含 dnstt `f1b9b97...`）
  - gomobile v0.1.12

验证记录：develop @ 73cd054，CI Run 33259412696 全步骤通过，
Debug APK Artifact `mobile-profile-browser-m1-debug` 已产出（2026-08-30）。

## 升级流程（每次上游变更必须完整执行）

```text
1. 新旧 commit 差异审计（安全与行为变化）
2. Profile / Storage 隔离审计
3. Proxy / sing-box / DNS 审计
4. 第三方许可证审计
5. 更新本文件与 tools/ 脚本中的 commit 常量
6. Android Debug APK 构建验证（android-m1 工作流全绿）
7. Profile / 网络相关真机回归
```

任何一步失败即中止升级并保持原基线不变。

## 上游安全待办（升级时反馈上游）

Mimosa 扫描在 2026-08-31 标记（处置依据已核）：

- `scripts/build_quotes_db.py:79`、`scripts/build_sites_db.py:250`：
  f-string 拼接 SQL（`DROP TABLE IF EXISTS {table}`）。核实为**上游离线
  构建脚本**中的内部常量（表名），非外部输入，不进 APK、不在产品
  运行路径——对本项目不构成可利用注入面；按上游锁定规则不修改
  子模块，升级时反馈上游改参数化。
- `packages/.../pigeons/Gecko.g.kt:12146`：Pigeon 生成代码疑似跨文件
  污点（medium）——生成物，不在本项目修改范围。
