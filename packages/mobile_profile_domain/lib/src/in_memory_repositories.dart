import 'mobile_profile.dart';
import 'repositories.dart';

/// 用于 Domain 单元测试和早期应用骨架的内存实现。
///
/// 正式生产环境将替换为 SQLite/加密存储实现。
final class InMemoryMobileProfileRepository implements MobileProfileRepository {
  final Map<String, MobileProfile> _profiles = <String, MobileProfile>{};

  @override
  Future<List<MobileProfile>> list() async {
    final result = _profiles.values.toList(growable: false);
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  @override
  Future<MobileProfile?> findById(String id) async => _profiles[id];

  @override
  Future<void> save(MobileProfile profile) async {
    if (profile.id.trim().isEmpty) {
      throw ArgumentError.value(profile.id, 'profile.id', '不能为空');
    }
    _profiles[profile.id] = profile;
  }

  @override
  Future<void> delete(String id) async {
    _profiles.remove(id);
  }
}

final class InMemoryActiveRuntimeRepository implements ActiveRuntimeRepository {
  final Map<String, RuntimeInstance> _active = <String, RuntimeInstance>{};

  @override
  Future<RuntimeInstance?> loadActive(String profileId) async => _active[profileId];

  @override
  Future<void> save(RuntimeInstance runtime) async {
    final existing = _active[runtime.profileId];
    if (existing != null && existing.generation > runtime.generation) {
      throw StateError('拒绝旧 runtime 覆盖更新 runtime');
    }
    _active[runtime.profileId] = runtime;
  }

  @override
  Future<void> clear(String profileId, {String? runtimeId}) async {
    final existing = _active[profileId];
    if (existing == null) return;
    if (runtimeId != null && existing.id != runtimeId) return;
    _active.remove(profileId);
  }
}
