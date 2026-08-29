import 'package:mobile_profile_domain/mobile_profile_domain.dart';

/// 网络运行时句柄。
final class NetworkRuntimeHandle {
  const NetworkRuntimeHandle({
    required this.id,
    required this.routeId,
  });

  final String id;
  final String routeId;
}

/// Provider 运行时统一契约。
///
/// 实现层可以基于 WebLibre、sing-box、Android VpnService 或其他成熟组件，
/// 但上层不应感知具体实现。
abstract interface class NetworkRuntime {
  Future<NetworkRuntimeHandle> start(NetworkRoute route);

  Future<NetworkHealth> health(NetworkRuntimeHandle handle);

  Future<void> stop(NetworkRuntimeHandle handle);
}

/// 根据 NetworkRoute 创建具体 Provider Runtime。
abstract interface class NetworkRuntimeFactory {
  NetworkRuntime create(NetworkRoute route);
}
