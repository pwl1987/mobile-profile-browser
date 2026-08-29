# AGENTS.md

Mobile Profile Browser：基于 WebLibre（AGPL-3.0，Git Submodule `vendor/weblibre`）二次开发的 Android 多 Profile 浏览器。当前处于 M1 阶段（上游 Android Debug APK 可重复构建 + 领域模型），业务层尚未接入运行时。

## 目录

- `packages/mobile_profile_domain/` — 纯 Dart 领域模型（MobileProfile / DeviceProfile / NetworkRoute / Repository 契约），刻意不依赖 Flutter。
- `packages/mobile_profile_integration/` — 领域层与浏览器/网络运行时之间的 Adapter 契约，只定义接口，不依赖 Flutter、GeckoView、sing-box 或 Android API。
- `vendor/weblibre/` — 上游 WebLibre 子模块（Flutter/GeckoView 浏览器），**不要手工修改其 Git 历史**。
- `patches/weblibre/` — 本项目对上游工作树的最小补丁。
- `tools/` — 子模块初始化、工作树准备、补丁应用脚本。
- `docs/architecture/` — 架构基线与上游锁定规则。

## 常用命令

本仓库没有根级 workspace 工具，逐包执行（CI 同款，Dart SDK 锁 3.13.1）：

```bash
cd packages/mobile_profile_domain && dart pub get && dart analyze && dart test
cd packages/mobile_profile_integration && dart pub get && dart analyze && dart test
```

Android M1 构建链见 `.github/workflows/android-m1.yml`（Flutter 3.47.1 + Java 17 + Go 1.25 + NDK + sing-box/IPtProxy gomobile Runtime），不要脱离该工作流自行改动构建步骤。

子模块与工作树脚本（各自硬校验不同的基线 commit，见下文"已知坑"）：

- `bash ./tools/import-weblibre.sh` — 初始化子模块到 `dc74be45`（开发环境）。
- `bash ./tools/prepare-weblibre-worktree.sh` — CI（android-m1）用，要求 `b4721ae6`，并补建上游缺失的空 assets 目录。
- `bash ./tools/apply-weblibre-patches.sh` — 幂等地把本项目两个包以 path 依赖写入 `vendor/weblibre/apps/weblibre/pubspec.yaml`，要求 `dc74be45`。

## 架构边界（改动前必守）

- Domain 层不 import Flutter / GeckoView / Android API，不持有 SSH 私钥、代理密码，不创建 socket / VPN / sing-box runtime，不实现指纹随机伪装。
- 上游 WebLibre 只能通过 integration 层 Adapter 接入；不得把上游代码未审计地复制进业务层（AGPL-3.0，分发前需单独合规审查）。
- 网络故障默认 FAIL CLOSED：Provider 异常时不得静默回落直连；指纹一致性优先于随机性。这两条是项目核心原则，测试与实现都不得违反。
- 上游升级必须先走 `tools/README.md` 中的审计清单（差异审计、隔离审计、网络审计、许可证、构建、真机回归）。

## 语言与提交规范

README、架构文档、测试方案、Issue/PR、commit message 默认**中文**；代码中的类名、函数名、API、第三方项目名保留英文。

## 进度原则（最高优先级）

**不以功能数量衡量项目进度，以经过真实测试的能力衡量项目进度。**"SSH Provider 已实现"不算完成；"真机上 Profile A 经 VPS 出口确认公网出口变化、停止后资源正确释放、重启后能重建连接"才算完成。每个 Gate（M1–M9，见 `docs/architecture/implementation-roadmap.md`）未验收不进入下一阶段；禁止在构建底座未稳定时堆 Profile/UI 功能。

## Git 工作流

- 分支模型：`main`（仅 Release/RC）← `develop`（集成分支）← `feature/*`、`fix/*`。
- 开发在 feature 分支进行，以 PR（或快进合并）进入 develop；**禁止修复只存在于 fix 分支而 develop 落后**（M1 期间出现过一次，已杜绝）。
- WebLibre 上游锁定与升级规则见 `docs/upstream/weblibre.md`，升级必须走完整审计流程。

### 每次提交必须能回答

1. 改了什么、为什么改；2. 改了哪些文件；3. 是否影响 Domain；4. 是否影响 Android；5. 是否影响 WebLibre；6. 是否新增依赖；7. 测试是什么；8. CI 是否通过；9. 是否产生技术债。

## 已知坑

1. **双基线并存（有意为之，勿"修复"其一）**：`import-weblibre.sh` 与 `apply-weblibre-patches.sh` 锁 `dc74be45`（文档/补丁基线），而 git 索引与 `prepare-weblibre-worktree.sh`（CI APK Gate）锁 `b4721ae6`。工作树检出 `dc74be45` 时 `git status` 会显示 `M vendor/weblibre`，属预期；改动任一脚本前先确认目标基线。
2. **Flutter 3.47 APK 产物探测误报**：Gradle 已产出 APK 时 flutter CLI 仍可能返回非零。CI 以"存在 >1MB 的 APK"判定成功，不要改回只信任退出码。
3. 上游把 `assets/quotes`、`assets/sites`、`assets/ublock` 声明为 Flutter assets 但空目录不入 Git，构建前需 `prepare-weblibre-worktree.sh` 补建。
4. 分支：`develop` 是实际工作线，`main` 滞后；CI 在 push/PR 到 main 和 develop 时触发。功能分支（如 `fix/ci-apk-build`）完成后合入 develop。

## 敏感变更前必读

- `docs/architecture/upstream-lock.md` — 子模块 commit 锁定与升级规则
- `docs/architecture/upstream-audit.md` — 上游复用/改造/隔离边界
- `docs/architecture/m1-integration-strategy.md` — M1 集成顺序
- `docs/security/threat-model.md`、`docs/testing/acceptance-matrix.md` — 验收口径
