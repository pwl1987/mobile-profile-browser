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

  static T _enumByName<T extends Enum>(List<T> values, String name, String field) {
    try {
      return values.byName(name);
    } on StateError {
      throw FormatException('$field 包含未知枚举值: $name');
    }
  }
}
