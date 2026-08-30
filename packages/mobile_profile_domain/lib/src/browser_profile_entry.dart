/// MobileProfile ↔ 浏览器侧 Profile 的持久化绑定。
///
/// 一个 MobileProfile 恰好绑定一个浏览器 Profile；browserProfileId 全局
/// 唯一、不允许两个 MobileProfile 共享同一浏览器 Profile——这是存储
/// 隔离在数据层的最低保证。storageNamespace 记录浏览器数据目录的
/// 相对路径（不含设备相关的绝对前缀）。
final class BrowserProfileEntry {
  const BrowserProfileEntry({
    required this.mobileProfileId,
    required this.browserProfileId,
    required this.storageNamespace,
    required this.createdAt,
    this.lastOpenedAt,
  });

  final String mobileProfileId;
  final String browserProfileId;
  final String storageNamespace;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;

  BrowserProfileEntry copyWith({DateTime? lastOpenedAt}) => BrowserProfileEntry(
        mobileProfileId: mobileProfileId,
        browserProfileId: browserProfileId,
        storageNamespace: storageNamespace,
        createdAt: createdAt,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      );
}

/// 浏览器 Profile 绑定的持久化契约。
///
/// 具体实现在存储层（SQLite）或测试内存实现；Domain 不依赖具体存储。
abstract interface class BrowserProfileRepository {
  Future<BrowserProfileEntry?> findByMobileProfileId(String mobileProfileId);

  Future<BrowserProfileEntry?> findByBrowserProfileId(String browserProfileId);

  Future<void> save(BrowserProfileEntry entry);

  Future<void> delete(String mobileProfileId);
}
