import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceProfileValidator', () {
    test('允许合理的设备配置', () {
      const profile = DeviceProfile(
        id: 'device-001',
        name: 'Android 旗舰机',
        deviceFamily: 'Android',
        model: 'Example X1',
        androidVersion: '16',
        browserCompatibility: 'gecko',
        viewportWidth: 1080,
        viewportHeight: 2400,
        devicePixelRatio: 3,
        maxTouchPoints: 10,
        locale: 'zh-CN',
        timezone: 'Asia/Shanghai',
        hardwareConcurrency: 8,
      );

      expect(
        () => const DeviceProfileValidator().validate(profile),
        returnsNormally,
      );
    });

    test('拒绝非法屏幕尺寸', () {
      const profile = DeviceProfile(
        id: 'device-002',
        name: '非法设备',
        viewportWidth: 0,
      );

      expect(
        () => const DeviceProfileValidator().validate(profile),
        throwsA(isA<DeviceProfileValidationError>()),
      );
    });
  });

  group('NetworkRouteValidator', () {
    test('非直连线路必须具有 endpoint 引用', () {
      const route = NetworkRoute(
        id: 'route-001',
        type: NetworkRouteType.sshTunnel,
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        throwsA(isA<NetworkRouteValidationError>()),
      );
    });

    test('SSH 线路具有 endpoint 引用时可以通过结构校验', () {
      const route = NetworkRoute(
        id: 'route-002',
        type: NetworkRouteType.sshTunnel,
        endpointRef: 'ssh-endpoint-001',
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        returnsNormally,
      );
    });
  });
}
