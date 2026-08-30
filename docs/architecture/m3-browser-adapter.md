# M3 BrowserProfileAdapter 设计

## 目标

建立 MobileProfile → WebLibre 浏览器 Profile 的映射与启动编排，并把
Profile 隔离作为可执行契约固定下来。

## 上游对齐事实（vendor/weblibre @ b4721ae6）

- 浏览器 Profile 目录：`{filesDir}/weblibre_profiles/profile-<uuid36>/`，
  Gecko 存储在其中的 `files/mozilla/`（`lib/utils/filesystem.dart`：
  `profilesDirName = 'weblibre_profiles'`，`profileDirPrefix = 'profile-'`）。
- 上游 `Profile.id` 是可被 `UuidValue.fromString` 解析的 UUID（上游新建
  用 v7；本项目 browser-<uuid v4> 同样合法）。

## 结构

```text
mobile_profile_domain
├── BrowserProfileEntry      MobileProfile ↔ 浏览器 Profile 一对一绑定
└── BrowserProfileRepository 契约（+内存实现）

mobile_profile_storage（schema v2）
├── browser_profiles 表      主键=mobile_profile_id，UNIQUE=browser_profile_id
└── v1→v2 无损升级路径（有测试）

mobile_profile_browser_adapter（新包，纯 Dart）
├── WebLibreProfileMapper    browser-<uuid> → 上游目录身份（常量与上游镜像）
├── ProfileLaunchService     open/close/delete 编排；绑定漂移即拒绝
└── FakeWebLibreBrowserProfileAdapter  按命名空间分桶的确定性 Fake
```

## 隔离保证（分层实现）

1. 数据层：`browser_profiles.browser_profile_id UNIQUE`——两个
   MobileProfile 不可能绑定同一浏览器 Profile（SQLite 拒绝 + 内存实现
   同语义显式拦截）。
2. 映射层：`WebLibreProfileMapper` 只接受合法 UUID 引用，命名空间与
   上游目录一一对应。
3. 适配器层：Fake 实现拒绝跨 Profile 占用同一命名空间；真实 WebLibre
   适配器（M3 真机阶段）以独立目录实现同一语义。
4. 编排层：`ProfileLaunchService` 发现持久化绑定与 profile 引用漂移时
   直接拒绝打开，不尝试"修复"。

## 验收状态

- ✅ `browser_profile_isolation_test`：A/B Cookie 与 LocalStorage 隔离、
  删除互不影响、复制不继承浏览数据、命名空间抢占被拒（假 runtime +
  真实 SQLite 全链路，CI 常驻）。
- 🔒 待真机验收（M3 Gate 收口条件）：同一断言结构对真实 GeckoView 执行
  ——真机创建 Profile A/B，各自写入 Cookie 后互查，确认物理隔离；
  OPPO Find N3 折叠/展开/Activity 重建后绑定与状态一致。

## 明确的非目标

- 不伪造 Runtime 状态：profile.status 的 starting/running 属于 M4 真实
  Runtime Gate，本层只保证浏览器 Profile 数据就绪。
- 不在本阶段实现真实 GeckoView 适配器（需要 Android/Flutter 环境，
  随 patches 流接入，见 `docs/upstream/weblibre.md` 待办）。
- UI 不在本阶段范围。
