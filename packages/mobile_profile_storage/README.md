# Mobile Profile 存储包

Mobile Profile Browser 的 SQLite 持久化实现，实现 `mobile_profile_domain` 的四个
Repository 契约，并提供 schema 版本迁移与事务支持。

## 结构

```text
ProfileStore.open(path)
├── 迁移：schema_version + device_profiles / network_routes / profiles / runtime_instances
├── profiles          → MobileProfileRepository
├── deviceProfiles    → DeviceProfileRepository
├── networkRoutes     → NetworkRouteRepository
├── runtimes          → ActiveRuntimeRepository（active = stopped_at IS NULL）
└── runInTransaction  → 多步写入的原子执行
```

## 设计约束

- Domain 契约保持存储无关；本包是唯一引入 sqlite3 的地方。
- 所有 DML 使用参数绑定，禁止把外部输入拼接进 SQL。
- 迁移只向前、版本连续、逐版本事务化；库版本高于代码时拒绝打开。
- 进程崩溃后由 Domain 层 `ProfileRecoveryService` 把声称存活的状态收敛回 ready；
  本包只负责如实持久化。
- `browser_profiles` 表延迟到 M3 BrowserProfileAdapter 落地时引入。

## 测试

```bash
dart pub get
dart analyze
dart test
```
