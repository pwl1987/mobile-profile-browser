import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_integration/mobile_profile_integration.dart';

import 'weblibre_profile_mapper.dart';

/// 浏览器 Profile 的隔离存储模拟：Cookie / LocalStorage 按命名空间分桶。
final class FakeBrowserProfileStorage {
  FakeBrowserProfileStorage(this.storageNamespace);

  final String storageNamespace;
  final Map<String, String> cookies = <String, String>{};
  final Map<String, String> localStorage = <String, String>{};
  bool deleted = false;
}

/// `BrowserProfileAdapter` 的确定性 Fake 实现。
///
/// 语义与真实 WebLibre/GeckoView 对齐：
/// - 每个浏览器 Profile 的存储完全按 storageNamespace 隔离；
/// - 相同 namespace 只能属于同一个 MobileProfile（重复 ensure 同一
///   profile 幂等，跨 profile 冲突直接抛错）；
/// - deleteProfile 只清空目标 namespace 的存储桶。
///
/// 用于在无真机条件下验证隔离契约与启动编排；真机 GeckoView 隔离
/// 验收在 M3 真机阶段用同一套测试口径执行。
final class FakeWebLibreBrowserProfileAdapter implements BrowserProfileAdapter {
  final Map<String, FakeBrowserProfileStorage> _storages =
      <String, FakeBrowserProfileStorage>{};
  final Map<String, String> _namespaceOwners = <String, String>{};

  /// 内部存储桶视图（测试断言用）。
  Map<String, FakeBrowserProfileStorage> get storages => _storages;

  @override
  Future<BrowserProfileHandle> ensureProfile(MobileProfile profile) async {
    final handle = WebLibreProfileMapper.handleFor(profile);
    final owner = _namespaceOwners[handle.storageNamespace];
    if (owner != null && owner != profile.id) {
      throw StateError('存储命名空间已被其他 Profile 占用: '
          '${handle.storageNamespace} -> $owner');
    }
    _namespaceOwners[handle.storageNamespace] = profile.id;
    _storages.putIfAbsent(
      handle.storageNamespace,
      () => FakeBrowserProfileStorage(handle.storageNamespace),
    );
    return handle;
  }

  @override
  Future<void> prepareProfile(BrowserProfileHandle handle) async {
    if (!_storages.containsKey(handle.storageNamespace)) {
      throw StateError('浏览器 Profile 尚未创建: ${handle.storageNamespace}');
    }
  }

  @override
  Future<void> deleteProfile(BrowserProfileHandle handle) async {
    final storage = _storages.remove(handle.storageNamespace);
    if (storage == null) return;
    storage.deleted = true;
    storage.cookies.clear();
    storage.localStorage.clear();
    _namespaceOwners.remove(handle.storageNamespace);
  }

  // ---- 测试辅助：模拟浏览器行为读写隔离存储 ----

  Future<void> writeCookie(BrowserProfileHandle handle, String name, String value) async {
    _requireStorage(handle).cookies[name] = value;
  }

  Future<String?> readCookie(BrowserProfileHandle handle, String name) async {
    return _requireStorage(handle).cookies[name];
  }

  Future<void> writeLocalStorage(BrowserProfileHandle handle, String key, String value) async {
    _requireStorage(handle).localStorage[key] = value;
  }

  Future<String?> readLocalStorage(BrowserProfileHandle handle, String key) async {
    return _requireStorage(handle).localStorage[key];
  }

  FakeBrowserProfileStorage _requireStorage(BrowserProfileHandle handle) {
    final storage = _storages[handle.storageNamespace];
    if (storage == null) {
      throw StateError('浏览器 Profile 存储不存在: ${handle.storageNamespace}');
    }
    return storage;
  }
}
