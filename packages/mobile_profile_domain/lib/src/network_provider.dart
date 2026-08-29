import 'mobile_profile.dart';

/// 网络提供者类型。
///
/// Provider 表示“运行机制”，具体协议参数由对应 ProviderConfig 表示。
enum NetworkProviderKind {
  direct,
  http,
  socks5,
  singBox,
  ssh,
  wireGuard,
  vpnTun,
  tor,
}

enum ProviderRuntimeState {
  stopped,
  starting,
  running,
  degraded,
  stopping,
  error,
}

/// Provider 的能力声明。
final class NetworkProviderCapabilities {
  const NetworkProviderCapabilities({
    this.tcp = false,
    this.udp = false,
    this.ipv4 = true,
    this.ipv6 = false,
    this.dns = false,
    this.tun = false,
    this.perProfile = true,
  });

  final bool tcp;
  final bool udp;
  final bool ipv4;
  final bool ipv6;
  final bool dns;
  final bool tun;
  final bool perProfile;
}

/// 网络线路的安全故障策略。
final class NetworkFailurePolicy {
  const NetworkFailurePolicy({
    this.failClosed = true,
    this.retryEnabled = true,
    this.maxAttempts,
  });

  final bool failClosed;
  final bool retryEnabled;
  final int? maxAttempts;
}

/// NetworkRoute 指向一个 Provider，而不直接耦合具体协议实现。
final class NetworkProvider {
  const NetworkProvider({
    required this.id,
    required this.kind,
    required this.configRef,
    this.policy = const NetworkFailurePolicy(),
  });

  final String id;
  final NetworkProviderKind kind;
  final String configRef;
  final NetworkFailurePolicy policy;
}

/// 预留给链式代理/路由图。
final class NetworkRouteGraph {
  const NetworkRouteGraph({
    required this.id,
    required this.providerIds,
    required this.defaultProviderId,
  });

  final String id;
  final List<String> providerIds;
  final String defaultProviderId;
}

/// 网络健康状态，与 ProviderRuntimeState 分离。
final class NetworkHealth {
  const NetworkHealth({
    this.connected = false,
    this.internetReachable = false,
    this.dnsHealthy = false,
    this.ipv4Healthy = false,
    this.ipv6Healthy = false,
    this.webrtcSafe = false,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.message,
  });

  final bool connected;
  final bool internetReachable;
  final bool dnsHealthy;
  final bool ipv4Healthy;
  final bool ipv6Healthy;
  final bool webrtcSafe;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? message;
}
