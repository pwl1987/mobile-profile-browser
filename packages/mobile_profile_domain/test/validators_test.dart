import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceProfileValidator', () {
    test('允许合理的折叠屏设备配置', () {
      const profile = OppoFindN3Profiles.china;
      expect(
        () => const DeviceProfileValidator().validate(profile),
        returnsNormally,
      );
    });

    test('拒绝非法屏幕尺寸', () {
      const profile = DeviceProfile(
        id: 'device-002',
        name: '非法设备',
        mainDisplay: DisplayProfile(
          surface: DisplaySurface.main,
          resolutionWidth: 0,
          resolutionHeight: 2400,
        ),
      );

      expect(
        () => const DeviceProfileValidator().validate(profile),
        throwsA(isA<DeviceProfileValidationError>()),
      );
    });
  });

  group('NetworkProviderRegistry', () {
    test('支持常用 Provider', () {
      expect(
        NetworkProviderRegistry.supports(
          const NetworkRoute(
            id: 'route-socks',
            name: 'SOCKS',
            provider: NetworkProviderKind.socks5,
            protocol: ProviderProtocol.socks5,
            providerConfigRef: 'config-socks',
          ),
        ),
        isTrue,
      );

      expect(
        NetworkProviderRegistry.supports(
          const NetworkRoute(
            id: 'route-vless',
            name: 'VLESS',
            provider: NetworkProviderKind.singbox,
            protocol: ProviderProtocol.vless,
            providerConfigRef: 'config-vless',
          ),
        ),
        isTrue,
      );
    });

    test('拒绝错误的 Provider / 协议组合', () {
      const route = NetworkRoute(
        id: 'route-bad',
        name: '错误线路',
        provider: NetworkProviderKind.http,
        protocol: ProviderProtocol.vless,
        providerConfigRef: 'config',
      );

      expect(
        () => const NetworkRouteValidator().validate(route),
        throwsA(isA<NetworkRouteValidationError>()),
      );
    });
  });

  group('RuntimeInstanceController', () {
    test('按状态机运行并允许重新连接', () {
      final instance = RuntimeInstanceFactory.create(
        profileId: 'profile-1',
        routeId: 'route-1',
        providerInstanceId: 'provider-1',
        generation: 1,
      );
      final controller = RuntimeInstanceController(instance);

      controller.transition(NetworkRouteStatus.starting);
      controller.transition(NetworkRouteStatus.connected);
      controller.transition(NetworkRouteStatus.reconnecting);
      controller.transition(NetworkRouteStatus.connected);
      controller.transition(NetworkRouteStatus.stopping);
      controller.transition(NetworkRouteStatus.stopped);

      expect(controller.runtime.status, NetworkRouteStatus.stopped);
    });

    test('拒绝非法状态跳转', () {
      final instance = RuntimeInstanceFactory.create(
        profileId: 'profile-1',
        routeId: 'route-1',
        providerInstanceId: 'provider-1',
        generation: 1,
      );
      final controller = RuntimeInstanceController(instance);

      expect(
        () => controller.transition(NetworkRouteStatus.connected),
        throwsA(isA<RuntimeStateTransitionError>()),
      );
    });

    test('旧 runtime 不能覆盖新代际', () {
      final oldRuntime = RuntimeInstanceFactory.create(
        profileId: 'profile-1',
        routeId: 'route-1',
        providerInstanceId: 'provider-1',
        generation: 1,
      );
      final newRuntime = RuntimeInstanceFactory.create(
        profileId: 'profile-1',
        routeId: 'route-1',
        providerInstanceId: 'provider-2',
        generation: 2,
      );

      expect(RuntimeInstanceController.isCurrent(oldRuntime, newRuntime), isFalse);
      expect(RuntimeInstanceController.isCurrent(newRuntime, newRuntime), isTrue);
    });
  });
}
