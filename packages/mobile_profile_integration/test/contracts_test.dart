import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_integration/mobile_profile_integration.dart';
import 'package:test/test.dart';

void main() {
  test('浏览器 Profile 句柄只暴露稳定标识', () {
    const handle = BrowserProfileHandle(
      id: 'browser-001',
      storageNamespace: 'profile-storage-001',
    );

    expect(handle.id, 'browser-001');
    expect(handle.storageNamespace, isNotEmpty);
  });

  test('网络 Runtime 句柄只绑定线路', () {
    const handle = NetworkRuntimeHandle(
      id: 'runtime-provider-001',
      routeId: 'route-001',
    );

    expect(handle.id, 'runtime-provider-001');
    expect(handle.routeId, 'route-001');
  });

  test('集成契约不要求具体 Provider 实现', () {
    const route = NetworkRoute(
      id: 'route-ssh',
      name: 'VPS SSH',
      provider: NetworkProviderKind.ssh,
      protocol: ProviderProtocol.ssh,
      providerConfigRef: 'provider-config-001',
      credentialRef: 'credential-001',
      trustRef: 'trust-001',
    );

    expect(NetworkProviderRegistry.supports(route), isTrue);
  });
}
