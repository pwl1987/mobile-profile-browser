# ADR-005：产品命名与中文优先定位

日期：2026-08-31 · 状态：已接受

## 决策

1. 产品显示名定为 **「独立浏览器」**，副标题 **「多 Profile 隔离浏览环境」**。
2. 中文优先（Chinese-first）提升为项目一级要求，规范见
   `docs/standards/i18n.md`；此后每个 Gate 的验收包含中文 UI / 中文文档 /
   中文 Release。

## 理由

- 「指纹浏览器」会把产品定位窄化为"改指纹"。本项目的实际架构是
  Profile + Browser Runtime + Storage 隔离 + Network 隔离 + Device
  Profile 的组合，准确的定位是 **Android 多 Profile 隔离浏览器**。
- 「独立浏览器」传达每个 Profile 是独立浏览环境的核心概念，不预设
  指纹/匿名语义（身份最小暴露是目标之一，但不承诺匿名）。

## 边界

- 仓库名 `mobile-profile-browser`、Dart 包名、API/协议名、Git 分支名
  保持英文（面向开发者层，见 i18n 规范）。
- APK 文件名保持英文（CI/脚本/下载环境稳定性）。
- `m1-baseline-20260830` Release 作为历史构建基线保留原样。

## 后果

- M3.4.2 起：中文 UI 基础设施（l10n arb + 状态中文映射）先于 Binder
  落地；README/Release 进入中文产品体系。
- UI 层的双栏/折叠能力（Find N3 内屏）不改变 ADR-004 的 Gecko 单
  运行时约束。
