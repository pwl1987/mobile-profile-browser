import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceProfileValidator', () {
    test('允许合理的折叠屏设备配置', () {
      const profile = DeviceProfile(
        id: 'device-001',
        name: 'OPPO Find N3',
        deviceFamily: 'OPPO Find N3',
        model: 'OPPO Find N3',
        regionalModel: 'PHN110',
        androidVersion: '13',
        browserCompatibility: 'gecko',
        mainDisplay: DisplayProfile(
          surface: DisplaySurface.main,
          resolutionWidth: 2440,
          resolutionHeight: 2268,
          devicePixelRatio: 2.5,
        ),
        coverDisplay: DisplayProfile(
          surface: DisplaySurface.cover,
          resolutionWidth: 2484,
          resolutionHeight: 1116,
          devicePixelRatio: 3,
        ),
        maxTouchPoints: 5,
        locale: 'zh-CN',
        timezone: 'Asia/Shanghai',
        hardwareConcurrency: 8,
      );

      expect(
        () => const DeviceProfileValidator().validate(profile),
        returnsNormally,
      );
    });

    test('拒绝非法主屏尺寸', () {
      const profile = DeviceProfile(
        id: 'device-002',
        name: '非法设备',
        mainDisplay: DisplayProfile(
          surface: DisplaySurface.main,
          resolutionWidth: 0,
          resolutionHeight: 2268,
        ),
      );

      expect(
        () => const DeviceProfileValidator().validate(profile),
        throwsA(isA<DeviceProfileValidationError>()),
      );
    });
  });

  group('NetworkRouteValidator', () {
    test('非直连线路必须具有 Provider 配置引用', () {
      const route = NetworkRoute(
        id: 'route-001',
        name: 'VPS SSH',
        provider: NetworkProviderKind.ssh,
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        throwsA(isA<NetworkRouteValidationError>()),
      );
    });

    test('SSH 线路具备配置和信任引用时通过结构校验', () {
      const route = NetworkRoute(
        id: 'route-002',
        name: 'VPS SSH',
        provider: NetworkProviderKind.ssh,
        protocol: ProviderProtocol.ssh,
        providerConfigRef: 'ssh-config-001',
        credentialRef: 'credential-001',
        trustRef: 'hostkey-001',
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        returnsNormally,
      );
    });

    test('SING_BOX 可以承载具体协议', () {
      const route = NetworkRoute(
        id: 'route-003',
        name: 'VLESS',
        provider: NetworkProviderKind.singbox,
        protocol: ProviderProtocol.vless,
        providerConfigRef: 'singbox-config-001',
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        returnsNormally,
      );
    });

    test('要求故障关闭时拒绝冲突的故障策略', () {
      const route = NetworkRoute(
        id: 'route-004',
        name: 'SOCKS5',
        provider: NetworkProviderKind.socks5,
        protocol: ProviderProtocol.socks5,
        providerConfigRef: 'socks-config-001',
        failurePolicy: FailurePolicy(mode: FailureMode.open),
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        throwsA(isA<NetworkRouteValidationError>()),
      );
    });
  });
}
