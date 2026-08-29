enum ProfileStatus { created, ready, starting, running, stopping, error, degraded }

enum CapabilityState { controlled, derived, observed, unsupported }

/// 本项目自己的完整移动 Profile 领域对象。
///
/// 它只描述业务身份及其引用，不直接持有 WebLibre、Gecko、sing-box
/// 或 SSH 的具体实现对象。
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

/// 描述设备/浏览器能力组合。
///
/// Find N3 等折叠屏必须同时描述外屏和内屏，而不是假设只有一套固定
/// screen metrics。V0.1 只建立模型，不声称能够修改底层 Gecko 能力。
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

enum NetworkRouteType { direct, http, socks5, sshTunnel, vpnTunnel }

enum NetworkRouteStatus {
  unknown,
  starting,
  healthy,
  degraded,
  stopping,
  stopped,
  error,
}

/// Profile 对网络出口的逻辑引用。
final class NetworkRoute {
  const NetworkRoute({
    required this.id,
    required this.type,
    this.endpointRef,
    this.credentialRef,
    this.hostKeyRef,
    this.dnsPolicy = 'default',
    this.ipv6Policy = 'default',
    this.webrtcPolicy = 'default',
    this.failClosed = true,
    this.healthStatus = NetworkRouteStatus.unknown,
  });

  final String id;
  final NetworkRouteType type;
  final String? endpointRef;

  /// 指向 Android Keystore / 安全存储中的凭据，而不是凭据正文。
  final String? credentialRef;

  /// 指向已验证的 SSH 主机密钥记录；建议生产环境固定主机密钥。
  final String? hostKeyRef;

  final String dnsPolicy;
  final String ipv6Policy;
  final String webrtcPolicy;
  final bool failClosed;
  final NetworkRouteStatus healthStatus;
}
