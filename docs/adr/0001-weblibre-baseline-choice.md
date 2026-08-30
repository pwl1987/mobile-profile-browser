# ADR-001：WebLibre 基线选择 b4721ae6

日期：2026-08-30 · 状态：已接受

## 背景

`vendor/weblibre` 子模块需要锁定单一 commit 作为构建基线。M1 期间曾出现
双基线并存：git 索引与 CI 用 `b4721ae6`，文档/补丁脚本用 `dc74be45`
（两者相差恰好 1 个上游提交 "update flutter deps"），导致 domain-quality
工作流自 d7cd51a 起持续失败。

## 决策

统一锁定 **`b4721ae6`**（git 索引、三个 tools 脚本、README、全部 CI）。

## 依据

2026-08-30 曾实测统一到 `dc74be45`：android-m1 工作流在"静态分析 WebLibre
应用"步骤失败——纯上游 `flutter analyze` 报 6 个 error，根因是
material_ui 1.1.0 的 `ColorScheme` 与 flutter/material 的类型冲突
（main.dart:470-486）。上游自身在该提交不可分析通过。回退到父提交
`b4721ae6` 后 M1 APK Gate 完整复现（Run 33278476189 等）。

## 原则

- 基线选择以"已验证可构建"为准，不以"更新"为准。
- 任何脚本/文档中的子模块 commit 常量必须与 git 索引一致。
- 升级上游必须走 `docs/upstream/weblibre.md` 的完整流程
  （差异审计 → 隔离审计 → 网络审计 → 许可证 → 构建 → 真机回归）。
- 补丁按基线分目录（`patches/<commit>/`），不为补丁适配错误基线。

## 后果

- `patches/dc74be45/0002-material-ui-compatibility.patch` 存档不用；
  M3 真机阶段需基于 b4721ae6 重写 profile hooks 补丁。
- 待上游修复 material_ui 冲突后可重新评估基线推进。
