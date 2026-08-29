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
| **统一基线（2026-08-30 起）** | `dc74be456efab51823bfc913114abb77af5c231c` | git 索引、`tools/prepare-weblibre-worktree.sh`、`tools/import-weblibre.sh`、`tools/apply-weblibre-patches.sh`、全部 CI 工作流 |

历史说明：M1 期间曾出现双基线并存——索引/CI 用 `b4721ae6...`（较旧，
仅差 1 个上游提交 "update flutter deps"），文档/补丁脚本用
`dc74be45...`。2026-08-30 统一到审计基线 `dc74be45`，子模块指针前进
一个提交，android-m1 工作流在统一基线上重新验证了 APK Gate。

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
