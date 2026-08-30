import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_integration/mobile_profile_integration.dart';

import 'weblibre_profile_mapper.dart';

final class ProfileLaunchError implements Exception {
  const ProfileLaunchError(this.message);

  final String message;

  @override
  String toString() => 'ProfileLaunchError: $message';
}

/// Profile 启动编排：MobileProfile → 浏览器 Profile 绑定 → 适配器。
///
/// 职责与边界：
/// - 建立/复用 MobileProfile 与浏览器 Profile 的持久化绑定（一对一）；
/// - 通过 `BrowserProfileAdapter` 契约驱动真实实现（当前为测试用
///   FakeWebLibreBrowserProfileAdapter；真机 GeckoView 实现在 M3 真机
///   阶段接入 Android 侧）；
/// - 不伪造 Runtime 状态：profile.status 的 starting/running 转换属于
///   M4 真实 Runtime Gate，本服务只保证浏览器 Profile 数据就绪。
///
/// 失败语义：ensure/prepare 任一步失败时不落盘绑定，保持数据一致。
final class ProfileLaunchService {
  ProfileLaunchService({
    required MobileProfileRepository profileRepository,
    required BrowserProfileRepository browserProfileRepository,
    required BrowserProfileAdapter adapter,
    DateTime Function()? clock,
  })  : _profiles = profileRepository,
        _bindings = browserProfileRepository,
        _adapter = adapter,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final MobileProfileRepository _profiles;
  final BrowserProfileRepository _bindings;
  final BrowserProfileAdapter _adapter;
  final DateTime Function() _clock;

  /// 打开（或创建）MobileProfile 对应的浏览器 Profile，返回绑定记录。
  ///
  /// 幂等：重复调用复用既有绑定与浏览器 Profile，只更新 lastOpenedAt。
  Future<BrowserProfileEntry> openBrowserProfile(String mobileProfileId) async {
    final profile = await _profiles.findById(mobileProfileId);
    if (profile == null) {
      throw ProfileLaunchError('Profile 不存在: $mobileProfileId');
    }

    final existing = await _bindings.findByMobileProfileId(mobileProfileId);
    final browserProfileId = WebLibreProfileMapper.browserProfileIdOf(profile);
    final namespace = WebLibreProfileMapper.storageNamespaceOf(browserProfileId);

    if (existing != null) {
      if (existing.browserProfileId != browserProfileId) {
        throw ProfileLaunchError('持久化绑定与 Profile 引用不一致: '
            '${existing.browserProfileId} != $browserProfileId');
      }
      final updated = existing.copyWith(lastOpenedAt: _clock());
      await _bindings.save(updated);
      return updated;
    }

    final handle = await _adapter.ensureProfile(profile);
    if (handle.storageNamespace != namespace) {
      throw ProfileLaunchError('适配器返回的存储命名空间与映射不一致: '
          '${handle.storageNamespace} != $namespace');
    }
    await _adapter.prepareProfile(handle);

    final entry = BrowserProfileEntry(
      mobileProfileId: mobileProfileId,
      browserProfileId: browserProfileId,
      storageNamespace: namespace,
      createdAt: _clock(),
      lastOpenedAt: _clock(),
    );
    await _bindings.save(entry);
    return entry;
  }

  /// 关闭浏览器 Profile（数据保留，绑定保留）。
  ///
  /// 真实实现里对应 Gecko runtime 退出；数据目录与绑定不动。
  Future<void> closeBrowserProfile(String mobileProfileId) async {
    final profile = await _profiles.findById(mobileProfileId);
    if (profile == null) return;
    // 当前 Fake/契约层没有持有 runtime 句柄；真实实现在此处向
    // BrowserRuntimeAdapter 发出 stop。这里只验证绑定存在。
    final binding = await _bindings.findByMobileProfileId(mobileProfileId);
    if (binding == null) {
      throw ProfileLaunchError('Profile 尚未建立浏览器绑定: $mobileProfileId');
    }
  }

  /// 删除浏览器 Profile：先删数据目录（适配器），再删绑定。
  Future<void> deleteBrowserProfile(String mobileProfileId) async {
    final binding = await _bindings.findByMobileProfileId(mobileProfileId);
    if (binding == null) return;
    await _adapter.deleteProfile(BrowserProfileHandle(
      id: binding.browserProfileId,
      storageNamespace: binding.storageNamespace,
    ));
    await _bindings.delete(mobileProfileId);
  }
}
