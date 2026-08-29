import 'mobile_profile.dart';

/// Profile 持久化的领域接口。
///
/// 具体实现可以是 SQLite 或未来的加密数据库，但 Domain 层不依赖具体存储。
abstract interface class MobileProfileRepository {
  Future<List<MobileProfile>> list();
  Future<MobileProfile?> findById(String id);
  Future<void> save(MobileProfile profile);
  Future<void> delete(String id);
}

/// 设备配置持久化接口。
abstract interface class DeviceProfileRepository {
  Future<List<DeviceProfile>> list();
  Future<DeviceProfile?> findById(String id);
  Future<void> save(DeviceProfile profile);
  Future<void> delete(String id);
}

/// 网络线路配置持久化接口。
abstract interface class NetworkRouteRepository {
  Future<List<NetworkRoute>> list();
  Future<NetworkRoute?> findById(String id);
  Future<void> save(NetworkRoute route);
  Future<void> delete(String id);
}

/// 活动运行实例的持久化接口。
abstract interface class ActiveRuntimeRepository {
  Future<RuntimeInstance?> loadActive(String profileId);
  Future<void> save(RuntimeInstance runtime);
  Future<void> clear(String profileId, {String? runtimeId});
}
