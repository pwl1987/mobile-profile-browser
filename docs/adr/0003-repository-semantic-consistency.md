# ADR-003：仓储实现语义一致性

日期：2026-08-30 · 状态：已接受

## 背景

M3 开发中发现：`SqliteMobileProfileRepository.save` 的 upsert 在冲突时
只更新部分列（name/updated_at/status/metadata），而内存实现是全量替换。
`browserProfileRef` 的改写被 SQLite 实现**静默丢弃**——两个实现各自通过
测试，但语义不同。此类分叉极隐蔽：上层"保存后读取得到旧引用"的 bug
只有在特定写入序列下才暴露（本次正是隔离测试的篡改场景暴露了它）。

## 决策

1. Repository 契约的 `save` 统一为**全量替换**语义（主键除外）；
   SQLite 的 `ON CONFLICT DO UPDATE` 必须覆盖全部列。
2. 新增 `repository_semantics_test.dart` 常驻 CI：同一组输入序列，
   内存实现与 SQLite 实现的可见结果必须完全一致（含引用字段改写、
   唯一性拒绝、删除隔离、排序契约）。
3. **新增任何 Repository 实现（如未来加密存储）必须跑通该套件**，
   套件按实现参数化扩展。

## 原则

两个实现"都通过各自的测试"不等于语义一致；一致性必须被显式测试。
