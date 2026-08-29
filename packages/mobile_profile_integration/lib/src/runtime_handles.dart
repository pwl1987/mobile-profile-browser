/// 浏览器底座创建后的稳定句柄。
///
/// Domain 只关心标识，不持有 Gecko/Flutter 运行时对象。
final class BrowserProfileHandle {
  const BrowserProfileHandle({
    required this.id,
    required this.storageNamespace,
  });

  final String id;
  final String storageNamespace;
}

/// 实际浏览器运行实例句柄。
final class BrowserRuntimeHandle {
  const BrowserRuntimeHandle({
    required this.id,
    required this.profileId,
  });

  final String id;
  final String profileId;
}
