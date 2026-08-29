enum ProfileStatus { created, ready, starting, running, stopping, error, degraded }

enum CapabilityState { controlled, derived, observed, unsupported }

/// 完整的移动 Profile 领域对象。
///
/// Profile 只保存其他领域对象的稳定引用，不直接持有浏览器内核、代理
/// runtime 或 SSH client 等具体实现对象。
final class MobileProfile {
  const MobileProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.browserProfileRef,
    required this.deviceProfileRef,
    required this.networkRouteRef,
    required this.status,
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String browserProfileRef;
  final String deviceProfileRef;
  final String networkRouteRef;
  final ProfileStatus status;
  final int schemaVersion;

  MobileProfile copyWith({
    String? name,
    DateTime? updatedAt,
    ProfileStatus? status,
  }) {
    return MobileProfile(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      browserProfileRef: browserProfileRef,
      deviceProfileRef: deviceProfileRef,
      networkRouteRef: networkRouteRef,
      status: status ?? this.status,
      schemaVersion: schemaVersion,
    );
  }
}

enum FoldablePosture { folded, unfolded, transitioning }

enum DisplaySurface { cover, main }

final class DisplayProfile {
  const DisplayProfile({
    required this.surface,
    required this.resolutionWidth,
    required this.resolutionHeight,
    this.viewportWidth,
    this.viewportHeight,
    this.devicePixelRatio,
    this.refreshRateHz,
    this.touchSamplingRateHz,
  });

  final DisplaySurface surface;
  final int resolutionWidth;
  final int resolutionHeight;
  final int? viewportWidth;
  final int? viewportHeight;
  final double? devicePixelRatio;
  final double? refreshRateHz;
  final double? touchSamplingRateHz;
}

/// 描述一个相互一致的 Android 设备/浏览器能力组合。
///
/// 注意：硬件规格不能自动等价于浏览器运行时可见值。运行时观测得到的
/// screen metrics、DPR、Client Hints、WebGL 等必须单独记录。
final class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.name,
    this.deviceFamily,
    this.model,
    this.regionalModel,
    this.androidVersion,
    this.browserCompatibility,
    this.mainDisplay,
    this.coverDisplay,
    this.posture = FoldablePosture.unfolded,
    this.locale,
    this.timezone,
    this.hardwareConcurrency,
    this.deviceMemoryGb,
    this.maxTouchPoints,
    this.clientHintsState = CapabilityState.unsupported,
    this.webglState = CapabilityState.unsupported,
  });

  final String id;
  final String name;
  final String? deviceFamily;
  final String? model;
  final String? regionalModel;
  final String? androidVersion;
  final String? browserCompatibility;
  final DisplayProfile? mainDisplay;
  final DisplayProfile? coverDisplay;
  final FoldablePosture posture;
  final String? locale;
  final String? timezone;
  final int? hardwareConcurrency;
  final double? deviceMemoryGb;
  final int? maxTouchPoints;
  final CapabilityState clientHintsState;
  final CapabilityState webglState;
}

enum NetworkProviderKind {
  direct,
  http,
  socks5,
  singbox,
  ssh,
  wireguard,
  vpnTun,
  tor,
}

enum ProviderProtocol {
  http,
  socks5,
  shadowsocks,
  vmess,
  vless,
  trojan,
  naive,
  hysteria,
  hysteria2,
  tuic,
  ssh,
  wireguard,
  shadowTls,
  anyTls,
  customOutbound,
  none,
}

enum NetworkRouteStatus {
  unknown,
  starting,
  connected,
  degraded,
  reconnecting,
  stopping,
  stopped,
  blocked,
  error,
}

enum NetworkHealthState { unknown, checking, healthy, degraded, unsafe, failed }

enum TrafficState { unknown, allowed, blocked }

enum LeakState { unknown, checking, safe, detected, unavailable }

enum FailureMode { closed, open }

final class ProviderCapabilities {
  const ProviderCapabilities({
    this.tcp = false,
    this.udp = false,
    this.ipv4 = true,
    this.ipv6 = false,
    this.dns = false,
    this.tun = false,
    this.browserProxy = false,
  });

  final bool tcp;
  final bool udp;
  final bool ipv4;
  final bool ipv6;
  final bool dns;
  final bool tun;
  final bool browserProxy;
}

final class NetworkPolicy {
  const NetworkPolicy({
    this.dnsMode = 'proxy',
    this.ipv6Mode = 'follow_provider',
    this.webrtcMode = 'proxy',
    this.failClosed = true,
    this.allowBackgroundTraffic = false,
  });

  final String dnsMode;
  final String ipv6Mode;
  final String webrtcMode;
  final bool failClosed;
  final bool allowBackgroundTraffic;
}

final class FailurePolicy {
  const FailurePolicy({
    this.mode = FailureMode.closed,
    this.startupFailure = true,
    this.runtimeFailure = true,
    this.dnsFailure = true,
    this.healthFailure = true,
    this.credentialFailure = true,
    this.maxReconnectAttempts = 0,
  });

  final FailureMode mode;
  final bool startupFailure;
  final bool runtimeFailure;
  final bool dnsFailure;
  final bool healthFailure;
  final bool credentialFailure;
  final int maxReconnectAttempts;
}

/// 线路只描述逻辑关系；具体协议配置放在 providerConfigRef 中。
final class NetworkRoute {
  const NetworkRoute({
    required this.id,
    required this.name,
    required this.provider,
    this.protocol = ProviderProtocol.none,
    this.providerConfigRef,
    this.credentialRef,
    this.trustRef,
    this.policy = const NetworkPolicy(),
    this.failurePolicy = const FailurePolicy(),
    this.capabilities = const ProviderCapabilities(),
    this.schemaVersion = 1,
  });

  final String id;
  final String name;
  final NetworkProviderKind provider;
  final ProviderProtocol protocol;
  final String? providerConfigRef;
  final String? credentialRef;
  final String? trustRef;
  final NetworkPolicy policy;
  final FailurePolicy failurePolicy;
  final ProviderCapabilities capabilities;
  final int schemaVersion;
}

final class NetworkHealth {
  const NetworkHealth({
    this.connection = NetworkRouteStatus.unknown,
    this.health = NetworkHealthState.unknown,
    this.traffic = TrafficState.unknown,
    this.leak = LeakState.unknown,
    this.lastSuccess,
    this.lastFailure,
  });

  final NetworkRouteStatus connection;
  final NetworkHealthState health;
  final TrafficState traffic;
  final LeakState leak;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
}

/// 一次真实运行实例。用于区分崩溃前后的 runtime，避免旧状态覆盖新状态。
final class RuntimeInstance {
  const RuntimeInstance({
    required this.id,
    required this.profileId,
    required this.routeId,
    required this.providerInstanceId,
    required this.generation,
    required this.startedAt,
    this.stoppedAt,
    this.status = NetworkRouteStatus.unknown,
  });

  final String id;
  final String profileId;
  final String routeId;
  final String providerInstanceId;
  final int generation;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final NetworkRouteStatus status;
}
