# M2 Profile Core 设计

## 目标

证明一个 APK 可以创建多个真正独立、可持久化、可恢复的浏览 Profile 的
**领域与存储底座**：CRUD、SQLite 持久化、schema 迁移、崩溃恢复。
M2 不接入真实浏览器 Runtime 与网络 Provider（分别属于 M3 / M5 Gate）。

## 范围与非目标

- ✅ Profile 创建 / 读取 / 重命名 / 元数据 / 删除 / 复制
- ✅ SQLite 持久化（schema v1 + 迁移框架 + 事务）
- ✅ 崩溃恢复（持久化声称存活状态 → unknown → recovering → ready）
- ❌ 真实 start/stop Runtime（M4，不伪造 starting/running 转换）
- ❌ `browser_profiles` 表（M3 BrowserProfileAdapter 落地时引入；当前
  Profile 的浏览器引用是 `profiles.browser_profile_ref` 列，复制 Profile
  时生成新引用为存储隔离预留边界）
- ❌ 加密存储 / 云同步

## 分层

```text
mobile_profile_domain（纯 Dart，无 sqlite3 依赖）
├── MobileProfileService     CRUD / 复制 / 稳定排序 / 引用完整性
├── ProfileRecoveryService   崩溃恢复状态收敛
└── Repository 契约

mobile_profile_storage（唯一引入 sqlite3 的包）
├── ProfileStore             open / close / runInTransaction / schemaVersion
├── StorageMigrations        版本化迁移（v1 基线）
└── 四个 Sqlite*Repository   实现 Domain 契约
```

## Schema v1

```text
schema_version     (version, applied_at)
device_profiles    (id, name, document JSON)
network_routes     (id, name, provider, document JSON)
profiles           (id, name, created_at, updated_at, browser_profile_ref,
                    device_profile_ref FK, network_route_ref FK,
                    status, metadata JSON)
runtime_instances  (id, profile_id FK ON DELETE CASCADE, route_id,
                    provider_instance_id, generation, started_at,
                    stopped_at, status)
```

- 活动实例定义：`stopped_at IS NULL` 且 generation 最大。
- 排序契约：`ORDER BY created_at, id`——时间相同按 id 兜底，顺序确定。
- 设备配置与网络线路以 JSON 文档列存储（编解码权威在 `ProfileCodec`），
  查询字段（id/name/provider）冗余为列。

## 迁移规则

1. 版本从 1 开始连续递增，只向前，不自动降级。
2. 每个迁移独立事务，全部语句成功才写入 `schema_version`。
3. 数据库版本高于代码已知版本时抛 `StorageVersionError` 拒绝打开。
4. 所有 DML 参数绑定，禁止拼接 SQL。

## 崩溃恢复语义

进程被系统杀死后，持久化的 `starting/running/stopping/degraded` 不可信：

```text
持久化 RUNNING → unknown（承认状态失效）→ recovering（清理）
→ 清理活动 runtime（记录 stopped）→ ready（等待用户重新启动）
```

每一步先落盘再进行下一步；恢复过程本身再次被杀死时，库中只会留下
unknown/recovering，绝不会留下伪装成真实运行的 running。恢复不删除
Profile 本体与用户数据。

## 验收（已由单元/集成测试覆盖）

- CRUD 全字段往返（含 metadata 与恢复状态枚举）
- 重复 id 是更新不是新增；删除不影响其他 Profile 与共享配置
- 排序稳定（createdAt 优先，同刻 id 兜底）
- 外键约束拒绝悬空引用；事务内任一步失败整体回滚
- 文件数据库跨 open 的“进程杀死 → 恢复”场景收敛为 ready 且无活动 runtime
- 旧 generation 不能覆盖新 generation

真机维度的验收（Activity 重建 / 进程死亡恢复）在 M3 接入 Android 后执行。
