import 'package:mobile_profile_domain/mobile_profile_domain.dart';

/// Provider 网络运行时适配契约。
///
/// Domain 层只依赖 [NetworkRuntime]；这里提供实现层的语义化名称，避免
/// 在 integration 包中重新定义一套参数不同的同名接口。
abstract interface class NetworkRuntimeAdapter implements NetworkRuntime {
  @override
  Future<NetworkRouteStatus> start(
    RuntimeInstance runtime,
    NetworkRoute route,
  );

  @override
  Future<NetworkHealth> health(RuntimeInstance runtime);

  @override
  Future<void> stop(RuntimeInstance runtime);
}

/// 根据 NetworkRoute 创建具体 Provider Runtime。
abstract interface class NetworkRuntimeFactory {
  NetworkRuntimeAdapter create(NetworkRoute route);
}
