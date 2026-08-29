import 'dart:convert';

import 'mobile_profile.dart';

/// 领域对象的无依赖 JSON 编解码器。
///
/// 仅负责结构化数据转换，不负责文件写入、加密或数据库事务。
final class ProfileCodec {
  ProfileCodec._();

  static String encodeProfile(MobileProfile profile) => jsonEncode({
        'schemaVersion': profile.schemaVersion,
        'id': profile.id,
        'name': profile.name,
        'createdAt': profile.createdAt.toUtc().toIso8601String(),
        'updatedAt': profile.updatedAt.toUtc().toIso8601String(),
        'browserProfileRef': profile.browserProfileRef,
        'deviceProfileRef': profile.deviceProfileRef,
        'networkRouteRef': profile.networkRouteRef,
        'status': profile.status.name,
        'metadata': profile.metadata,
      });

  static MobileProfile decodeProfile(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Profile JSON 顶层必须是对象');
    }
    return MobileProfile(
      id: _requiredString(value, 'id'),
      name: _requiredString(value, 'name'),
      createdAt: _requiredDateTime(value, 'createdAt'),
      updatedAt: _requiredDateTime(value, 'updatedAt'),
      browserProfileRef: _requiredString(value, 'browserProfileRef'),
      deviceProfileRef: _requiredString(value, 'deviceProfileRef'),
      networkRouteRef: _requiredString(value, 'networkRouteRef'),
      status: _enumByName(ProfileStatus.values, _requiredString(value, 'status'), 'status'),
      metadata: _optionalStringMap(value, 'metadata'),
      schemaVersion: _requiredInt(value, 'schemaVersion'),
    );
  }

  static String encodeRoute(NetworkRoute route) => jsonEncode({
        'schemaVersion': route.schemaVersion,
        'id': route.id,
        'name': route.name,
        'provider': route.provider.name,
        'protocol': route.protocol.name,
        'providerConfigRef': route.providerConfigRef,
        'credentialRef': route.credentialRef,
        'trustRef': route.trustRef,
        'policy': {
          'dnsMode': route.policy.dnsMode,
          'ipv6Mode': route.policy.ipv6Mode,
          'webrtcMode': route.policy.webrtcMode,
          'failClosed': route.policy.failClosed,
          'allowBackgroundTraffic': route.policy.allowBackgroundTraffic,
        },
        'failurePolicy': {
          'mode': route.failurePolicy.mode.name,
          'startupFailure': route.failurePolicy.startupFailure,
          'runtimeFailure': route.failurePolicy.runtimeFailure,
          'dnsFailure': route.failurePolicy.dnsFailure,
          'healthFailure': route.failurePolicy.healthFailure,
          'credentialFailure': route.failurePolicy.credentialFailure,
          'maxReconnectAttempts': route.failurePolicy.maxReconnectAttempts,
        },
        'capabilities': {
          'tcp': route.capabilities.tcp,
          'udp': route.capabilities.udp,
          'ipv4': route.capabilities.ipv4,
          'ipv6': route.capabilities.ipv6,
          'dns': route.capabilities.dns,
          'tun': route.capabilities.tun,
          'browserProxy': route.capabilities.browserProxy,
        },
      });

  static NetworkRoute decodeRoute(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('线路 JSON 顶层必须是对象');
    }
    final policy = _requiredMap(value, 'policy');
    final failure = _requiredMap(value, 'failurePolicy');
    final capabilities = _requiredMap(value, 'capabilities');
    return NetworkRoute(
      id: _requiredString(value, 'id'),
      name: _requiredString(value, 'name'),
      provider: _enumByName(NetworkProviderKind.values, _requiredString(value, 'provider'), 'provider'),
      protocol: _enumByName(ProviderProtocol.values, _requiredString(value, 'protocol'), 'protocol'),
      providerConfigRef: value['providerConfigRef'] as String?,
      credentialRef: value['credentialRef'] as String?,
      trustRef: value['trustRef'] as String?,
      policy: NetworkPolicy(
        dnsMode: _requiredString(policy, 'dnsMode'),
        ipv6Mode: _requiredString(policy, 'ipv6Mode'),
        webrtcMode: _requiredString(policy, 'webrtcMode'),
        failClosed: _requiredBool(policy, 'failClosed'),
        allowBackgroundTraffic: _requiredBool(policy, 'allowBackgroundTraffic'),
      ),
      failurePolicy: FailurePolicy(
        mode: _enumByName(FailureMode.values, _requiredString(failure, 'mode'), 'failurePolicy.mode'),
        startupFailure: _requiredBool(failure, 'startupFailure'),
        runtimeFailure: _requiredBool(failure, 'runtimeFailure'),
        dnsFailure: _requiredBool(failure, 'dnsFailure'),
        healthFailure: _requiredBool(failure, 'healthFailure'),
        credentialFailure: _requiredBool(failure, 'credentialFailure'),
        maxReconnectAttempts: _requiredInt(failure, 'maxReconnectAttempts'),
      ),
      capabilities: ProviderCapabilities(
        tcp: _requiredBool(capabilities, 'tcp'),
        udp: _requiredBool(capabilities, 'udp'),
        ipv4: _requiredBool(capabilities, 'ipv4'),
        ipv6: _requiredBool(capabilities, 'ipv6'),
        dns: _requiredBool(capabilities, 'dns'),
        tun: _requiredBool(capabilities, 'tun'),
        browserProxy: _requiredBool(capabilities, 'browserProxy'),
      ),
      schemaVersion: _requiredInt(value, 'schemaVersion'),
    );
  }

  static String encodeRuntime(RuntimeInstance runtime) => jsonEncode({
        'id': runtime.id,
        'profileId': runtime.profileId,
        'routeId': runtime.routeId,
        'providerInstanceId': runtime.providerInstanceId,
        'generation': runtime.generation,
        'startedAt': runtime.startedAt.toUtc().toIso8601String(),
        'stoppedAt': runtime.stoppedAt?.toUtc().toIso8601String(),
        'status': runtime.status.name,
      });

  static RuntimeInstance decodeRuntime(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Runtime JSON 顶层必须是对象');
    }
    final stoppedAt = value['stoppedAt'];
    return RuntimeInstance(
      id: _requiredString(value, 'id'),
      profileId: _requiredString(value, 'profileId'),
      routeId: _requiredString(value, 'routeId'),
      providerInstanceId: _requiredString(value, 'providerInstanceId'),
      generation: _requiredInt(value, 'generation'),
      startedAt: _requiredDateTime(value, 'startedAt'),
      stoppedAt: stoppedAt == null ? null : DateTime.parse(stoppedAt as String).toUtc(),
      status: _enumByName(NetworkRouteStatus.values, _requiredString(value, 'status'), 'status'),
    );
  }

  static String encodeDevice(DeviceProfile device) => jsonEncode({
        'id': device.id,
        'name': device.name,
        'deviceFamily': device.deviceFamily,
        'model': device.model,
        'regionalModel': device.regionalModel,
        'androidVersion': device.androidVersion,
        'browserCompatibility': device.browserCompatibility,
        'mainDisplay': _encodeDisplay(device.mainDisplay),
        'coverDisplay': _encodeDisplay(device.coverDisplay),
        'posture': device.posture.name,
        'locale': device.locale,
        'timezone': device.timezone,
        'hardwareConcurrency': device.hardwareConcurrency,
        'deviceMemoryGb': device.deviceMemoryGb,
        'maxTouchPoints': device.maxTouchPoints,
        'clientHintsState': device.clientHintsState.name,
        'webglState': device.webglState.name,
      });

  static DeviceProfile decodeDevice(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('设备配置 JSON 顶层必须是对象');
    }
    return DeviceProfile(
      id: _requiredString(value, 'id'),
      name: _requiredString(value, 'name'),
      deviceFamily: value['deviceFamily'] as String?,
      model: value['model'] as String?,
      regionalModel: value['regionalModel'] as String?,
      androidVersion: value['androidVersion'] as String?,
      browserCompatibility: value['browserCompatibility'] as String?,
      mainDisplay: _decodeDisplay(value['mainDisplay'], 'mainDisplay'),
      coverDisplay: _decodeDisplay(value['coverDisplay'], 'coverDisplay'),
      posture: _enumByName(FoldablePosture.values, _requiredString(value, 'posture'), 'posture'),
      locale: value['locale'] as String?,
      timezone: value['timezone'] as String?,
      hardwareConcurrency: _optionalInt(value, 'hardwareConcurrency'),
      deviceMemoryGb: _optionalDouble(value, 'deviceMemoryGb'),
      maxTouchPoints: _optionalInt(value, 'maxTouchPoints'),
      clientHintsState: _enumByName(
          CapabilityState.values, _requiredString(value, 'clientHintsState'), 'clientHintsState'),
      webglState:
          _enumByName(CapabilityState.values, _requiredString(value, 'webglState'), 'webglState'),
    );
  }

  static Map<String, Object?>? _encodeDisplay(DisplayProfile? display) {
    if (display == null) return null;
    return <String, Object?>{
      'surface': display.surface.name,
      'resolutionWidth': display.resolutionWidth,
      'resolutionHeight': display.resolutionHeight,
      'viewportWidth': display.viewportWidth,
      'viewportHeight': display.viewportHeight,
      'devicePixelRatio': display.devicePixelRatio,
      'refreshRateHz': display.refreshRateHz,
      'touchSamplingRateHz': display.touchSamplingRateHz,
    };
  }

  static DisplayProfile? _decodeDisplay(Object? raw, String field) {
    if (raw == null) return null;
    if (raw is! Map) throw FormatException('$field 必须是对象');
    final value = raw.cast<String, dynamic>();
    return DisplayProfile(
      surface:
          _enumByName(DisplaySurface.values, _requiredString(value, 'surface'), '$field.surface'),
      resolutionWidth: _requiredInt(value, 'resolutionWidth'),
      resolutionHeight: _requiredInt(value, 'resolutionHeight'),
      viewportWidth: _optionalInt(value, 'viewportWidth'),
      viewportHeight: _optionalInt(value, 'viewportHeight'),
      devicePixelRatio: _optionalDouble(value, 'devicePixelRatio'),
      refreshRateHz: _optionalDouble(value, 'refreshRateHz'),
      touchSamplingRateHz: _optionalDouble(value, 'touchSamplingRateHz'),
    );
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key 必须是非空字符串');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key 必须是整数');
    return value;
  }

  static bool _requiredBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('$key 必须是布尔值');
    return value;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> map, String key) {
    final raw = _requiredString(map, key);
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      throw FormatException('$key 不是有效的 ISO-8601 时间');
    }
  }

  static Map<String, dynamic> _requiredMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Map) throw FormatException('$key 必须是对象');
    return value.cast<String, dynamic>();
  }

  static Map<String, String> _optionalStringMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return const <String, String>{};
    if (value is! Map) throw FormatException('$key 必须是对象');
    return value.map((k, v) => MapEntry(k as String, v as String));
  }

  static int? _optionalInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('$key 必须是整数');
    return value;
  }

  static double? _optionalDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is num && value is! int) return value.toDouble();
    if (value is int) return value.toDouble();
    throw FormatException('$key 必须是数值');
  }

  static T _enumByName<T extends Enum>(List<T> values, String name, String field) {
    try {
      return values.byName(name);
    } on StateError {
      throw FormatException('$field 包含未知枚举值: $name');
    }
  }
}
