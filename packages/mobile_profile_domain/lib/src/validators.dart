import 'mobile_profile.dart';

final class DeviceProfileValidationError implements Exception {
  const DeviceProfileValidationError(this.message);

  final String message;

  @override
  String toString() => 'DeviceProfileValidationError: $message';
}

final class DeviceProfileValidator {
  const DeviceProfileValidator();

  void validate(DeviceProfile profile) {
    if (profile.id.trim().isEmpty) {
      throw const DeviceProfileValidationError('设备配置 ID 不能为空');
    }
    if (profile.name.trim().isEmpty) {
      throw const DeviceProfileValidationError('设备配置名称不能为空');
    }
    _validateDisplay(profile.mainDisplay, '主屏');
    _validateDisplay(profile.coverDisplay, '外屏');
    if (profile.maxTouchPoints != null && profile.maxTouchPoints! < 0) {
      throw const DeviceProfileValidationError('maxTouchPoints 不能小于 0');
    }
    if (profile.hardwareConcurrency != null && profile.hardwareConcurrency! <= 0) {
      throw const DeviceProfileValidationError('hardwareConcurrency 必须大于 0');
    }
    if (profile.deviceMemoryGb != null && profile.deviceMemoryGb! <= 0) {
      throw const DeviceProfileValidationError('deviceMemoryGb 必须大于 0');
    }

    if (profile.clientHintsState == CapabilityState.controlled &&
        profile.browserCompatibility == null) {
      throw const DeviceProfileValidationError(
        'Client Hints 标记为 controlled 时必须声明浏览器兼容版本',
      );
    }
  }

  void _validateDisplay(DisplayProfile? display, String label) {
    if (display == null) return;
    if (display.resolutionWidth <= 0 || display.resolutionHeight <= 0) {
      throw DeviceProfileValidationError('$label分辨率必须大于 0');
    }
    if (display.viewportWidth != null && display.viewportWidth! <= 0) {
      throw DeviceProfileValidationError('$label viewportWidth 必须大于 0');
    }
    if (display.viewportHeight != null && display.viewportHeight! <= 0) {
      throw DeviceProfileValidationError('$label viewportHeight 必须大于 0');
    }
    if (display.devicePixelRatio != null && display.devicePixelRatio! <= 0) {
      throw DeviceProfileValidationError('$label devicePixelRatio 必须大于 0');
    }
    if (display.refreshRateHz != null && display.refreshRateHz! <= 0) {
      throw DeviceProfileValidationError('$label refreshRateHz 必须大于 0');
    }
    if (display.touchSamplingRateHz != null &&
        display.touchSamplingRateHz! <= 0) {
      throw DeviceProfileValidationError('$label touchSamplingRateHz 必须大于 0');
    }
  }
}

final class NetworkRouteValidationError implements Exception {
  const NetworkRouteValidationError(this.message);

  final String message;

  @override
  String toString() => 'NetworkRouteValidationError: $message';
}

final class NetworkRouteValidator {
  const NetworkRouteValidator();

  void validate(NetworkRoute route) {
    if (route.id.trim().isEmpty) {
      throw const NetworkRouteValidationError('线路 ID 不能为空');
    }
    if (route.name.trim().isEmpty) {
      throw const NetworkRouteValidationError('线路名称不能为空');
    }

    if (route.provider == NetworkProviderKind.direct) {
      if (route.providerConfigRef != null || route.credentialRef != null) {
        throw const NetworkRouteValidationError('直连线路不应引用外部 Provider 配置或凭据');
      }
      if (route.failurePolicy.mode == FailureMode.open && route.policy.failClosed) {
        throw const NetworkRouteValidationError('故障策略与线路 Fail Closed 配置冲突');
      }
      return;
    }

    if (route.providerConfigRef == null || route.providerConfigRef!.trim().isEmpty) {
      throw const NetworkRouteValidationError('非直连线路必须引用 Provider 配置');
    }

    if (route.policy.failClosed && route.failurePolicy.mode != FailureMode.closed) {
      throw const NetworkRouteValidationError('线路要求 Fail Closed 时，FailurePolicy 必须为 closed');
    }

    if (route.failurePolicy.maxReconnectAttempts < 0) {
      throw const NetworkRouteValidationError('maxReconnectAttempts 不能小于 0');
    }

    if (route.provider == NetworkProviderKind.ssh &&
        route.credentialRef == null &&
        route.trustRef == null) {
      throw const NetworkRouteValidationError('SSH 线路至少需要凭据或受信任主机配置引用');
    }

    if (route.protocol != ProviderProtocol.none &&
        route.provider != NetworkProviderKind.singbox &&
        route.provider != NetworkProviderKind.http &&
        route.provider != NetworkProviderKind.socks5 &&
        route.provider != NetworkProviderKind.ssh) {
      throw const NetworkRouteValidationError('当前 Provider 与协议类型组合不受支持');
    }
  }
}
