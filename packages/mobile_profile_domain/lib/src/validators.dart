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
    if (profile.viewportWidth != null && profile.viewportWidth! <= 0) {
      throw const DeviceProfileValidationError('viewportWidth 必须大于 0');
    }
    if (profile.viewportHeight != null && profile.viewportHeight! <= 0) {
      throw const DeviceProfileValidationError('viewportHeight 必须大于 0');
    }
    if (profile.devicePixelRatio != null && profile.devicePixelRatio! <= 0) {
      throw const DeviceProfileValidationError('devicePixelRatio 必须大于 0');
    }
    if (profile.maxTouchPoints != null && profile.maxTouchPoints! < 0) {
      throw const DeviceProfileValidationError('maxTouchPoints 不能小于 0');
    }
    if (profile.hardwareConcurrency != null && profile.hardwareConcurrency! <= 0) {
      throw const DeviceProfileValidationError('hardwareConcurrency 必须大于 0');
    }

    if (profile.locale != null && !profile.locale!.contains('-')) {
      throw const DeviceProfileValidationError(
        'locale 应使用明确的语言-地区格式，例如 zh-CN',
      );
    }

    if (profile.clientHintsState == CapabilityState.controlled &&
        profile.browserCompatibility == null) {
      throw const DeviceProfileValidationError(
        'Client Hints 标记为 controlled 时必须声明浏览器兼容版本',
      );
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

    if (route.type != NetworkRouteType.direct &&
        (route.endpointRef == null || route.endpointRef!.trim().isEmpty)) {
      throw const NetworkRouteValidationError(
        '非直连线路必须引用 endpoint',
      );
    }

    if (route.type == NetworkRouteType.direct && !route.failClosed) {
      throw const NetworkRouteValidationError(
        'DIRECT 不允许依赖 failClosed 表示安全策略；请通过用户明确配置表达直连意图',
      );
    }
  }
}
