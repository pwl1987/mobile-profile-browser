import 'mobile_profile.dart';
import 'identity.dart';
import 'oppo_find_n3.dart';
import 'provider_registry.dart';
import 'repositories.dart';

final class ProfileServiceError implements Exception {
  const ProfileServiceError(this.message);

  final String message;

  @override
  String toString() => 'ProfileServiceError: $message';
}

/// Profile CRUD / 复制 / 排序的应用服务。
///
/// 规则：
/// - id 由 UUID v4 生成，不允许调用方指定重复 id；
/// - 排序稳定：先 createdAt，再 id 兜底，同刻创建的 Profile 顺序确定；
/// - 删除只作用于目标 Profile，共享的设备配置与网络线路不被删除；
/// - 复制生成全新 id 与全新 browserProfileRef（为 M3 存储隔离预留），
///   但共享 deviceProfileRef / networkRouteRef。
///
/// 注意：真实运行时的启动/停止属于 M4 Runtime Gate，本服务不伪造
/// starting/running 状态转换。
final class MobileProfileService {
  MobileProfileService({
    required MobileProfileRepository profileRepository,
    required DeviceProfileRepository deviceProfileRepository,
    required NetworkRouteRepository networkRouteRepository,
    required ActiveRuntimeRepository runtimeRepository,
    String Function()? uuidGenerator,
    DateTime Function()? clock,
  })  : _profiles = profileRepository,
        _devices = deviceProfileRepository,
        _routes = networkRouteRepository,
        _runtimes = runtimeRepository,
        _uuidGenerator = uuidGenerator ?? ProfileIdentity.newUuidV4,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final MobileProfileRepository _profiles;
  final DeviceProfileRepository _devices;
  final NetworkRouteRepository _routes;
  final ActiveRuntimeRepository _runtimes;
  final String Function() _uuidGenerator;
  final DateTime Function() _clock;

  Future<MobileProfile> create({
    required String name,
    String? deviceProfileId,
    String? networkRouteId,
    Map<String, String>? metadata,
  }) async {
    final trimmed = _requireName(name);
    final deviceId = deviceProfileId ?? OppoFindN3Profiles.china.id;
    final routeId = networkRouteId ?? NetworkProviderRegistry.defaultDirectRoute.id;

    await _ensureBootstrapEntity(
      requestedId: deviceProfileId,
      fallback: OppoFindN3Profiles.china,
      loader: _devices.findById,
      saver: _devices.save,
      label: '设备配置',
    );
    await _ensureBootstrapEntity(
      requestedId: networkRouteId,
      fallback: NetworkProviderRegistry.defaultDirectRoute,
      loader: _routes.findById,
      saver: _routes.save,
      label: '网络线路',
    );

    final now = _clock();
    final profile = MobileProfile(
      id: _uuidGenerator(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
      browserProfileRef: ProfileIdentity.newBrowserProfileRef(),
      deviceProfileRef: deviceId,
      networkRouteRef: routeId,
      status: ProfileStatus.created,
      metadata: metadata ?? const <String, String>{},
    );
    await _profiles.save(profile);
    return profile;
  }

  Future<List<MobileProfile>> list() async {
    final profiles = await _profiles.list();
    profiles.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return profiles;
  }

  Future<MobileProfile?> findById(String id) => _profiles.findById(id);

  Future<MobileProfile> rename(String id, String newName) async {
    final existing = await _requireProfile(id);
    final updated = existing.copyWith(
      name: _requireName(newName),
      updatedAt: _clock(),
    );
    await _profiles.save(updated);
    return updated;
  }

  Future<MobileProfile> updateMetadata(String id, Map<String, String> metadata) async {
    final existing = await _requireProfile(id);
    final updated = existing.copyWith(metadata: Map.unmodifiable(metadata), updatedAt: _clock());
    await _profiles.save(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    final existing = await _profiles.findById(id);
    if (existing == null) return;
    await _runtimes.clear(id);
    await _profiles.delete(id);
  }

  Future<MobileProfile> copy(String id, {String? name}) async {
    final source = await _requireProfile(id);
    final now = _clock();
    final copied = MobileProfile(
      id: _uuidGenerator(),
      name: name == null ? '${source.name} 副本' : _requireName(name),
      createdAt: now,
      updatedAt: now,
      browserProfileRef: ProfileIdentity.newBrowserProfileRef(),
      deviceProfileRef: source.deviceProfileRef,
      networkRouteRef: source.networkRouteRef,
      status: ProfileStatus.created,
      metadata: source.metadata,
      schemaVersion: source.schemaVersion,
    );
    await _profiles.save(copied);
    return copied;
  }

  Future<MobileProfile> _requireProfile(String id) async {
    final profile = await _profiles.findById(id);
    if (profile == null) {
      throw ProfileServiceError('Profile 不存在: $id');
    }
    return profile;
  }

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ProfileServiceError('Profile 名称不能为空');
    }
    return trimmed;
  }

  /// 调用方未显式指定引用时，把默认实体写入存储（保证外键完整）；
  /// 显式指定了不存在的引用则直接拒绝，绝不静默替换成别的配置。
  Future<void> _ensureBootstrapEntity<T>({
    required String? requestedId,
    required T fallback,
    required Future<T?> Function(String) loader,
    required Future<void> Function(T) saver,
    required String label,
  }) async {
    if (requestedId != null) {
      final existing = await loader(requestedId);
      if (existing == null) {
        throw ProfileServiceError('$label不存在: $requestedId');
      }
      return;
    }
    final existing = await loader(_entityId(fallback));
    if (existing == null) {
      await saver(fallback);
    }
  }

  static String _entityId(Object entity) {
    if (entity is DeviceProfile) return entity.id;
    if (entity is NetworkRoute) return entity.id;
    throw StateError('未知实体类型');
  }
}
