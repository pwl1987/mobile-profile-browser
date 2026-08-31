import 'package:mobile_profile_domain/mobile_profile_domain.dart';

import 'weblibre_profile_storage.dart';
import 'weblibre_runtime_manager.dart';

final class ProfileTeardownError implements Exception {
  const ProfileTeardownError(this.message);

  final String message;

  @override
  String toString() => 'ProfileTeardownError: $message';
}

/// Profile 删除清理（ADR-006：数据残留防护）。
///
/// 删除绝不能只是 `DELETE FROM profiles`，顺序固定：
///
/// ```text
/// 运行中/解绑未知？ → 拒绝（先 stop 并 confirmUnknownDead）
///   ↓
/// 删除浏览器数据目录（磁盘）
///   ↓ 失败 → 抛错，绑定保留，可重试
/// 删除 SQLite 绑定
///   ↓
/// 删除 MobileProfile（调用方负责，会话随 FK 级联）
/// ```
///
/// 关键约束：**先删磁盘再删数据库**。反序会出现"库已删、磁盘 Cookie
/// 残留"的数据泄漏；本顺序下磁盘删除失败时绑定仍在，指向仍存在的
/// 目录，可安全重试。
final class ProfileTeardownService {
  ProfileTeardownService({
    required WebLibreRuntimeManager runtime,
    required BrowserProfileRepository bindings,
    required WebLibreProfileStorage browserStorage,
  })  : _runtime = runtime,
        _bindings = bindings,
        _browserStorage = browserStorage;

  final WebLibreRuntimeManager _runtime;
  final BrowserProfileRepository _bindings;
  final WebLibreProfileStorage _browserStorage;

  /// 清理指定 MobileProfile 的浏览器侧资源（幂等：无绑定为空操作）。
  ///
  /// 不删除 MobileProfile 本体——那是上层 ProfileService 的职责；
  /// 本服务只保证浏览器数据目录与绑定一起消失，或一起保留。
  Future<void> teardown(String mobileProfileId) async {
    final bound = _runtime.bound;
    if (bound != null && bound.profileId == mobileProfileId) {
      throw const ProfileTeardownError(
          'Profile 的浏览器 Runtime 占用中（运行/解绑未知），'
          '先 stop 并在需要时 confirmUnknownDead 后再删除');
    }

    final binding = await _bindings.findByMobileProfileId(mobileProfileId);
    if (binding == null) return;

    // 先磁盘后数据库：磁盘删除失败 ⇒ 绑定保留（fail-closed，可重试）。
    await _browserStorage.delete(binding.browserProfileId);
    await _bindings.delete(mobileProfileId);
  }
}
