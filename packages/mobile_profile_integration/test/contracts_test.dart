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

  test('网络 Runtime 适配器实现 Domain Runtime 契约', () {
    final adapter = _FakeNetworkRuntime();
    final NetworkRuntime domainPort = adapter;

    expect(domainPort, same(adapter));
    expect(adapter, isA<NetworkRuntimeAdapter>());
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

final class _FakeNetworkRuntime implements NetworkRuntimeAdapter {
  @override
  Future<NetworkRouteStatus> start(
    RuntimeInstance runtime,
    NetworkRoute route,
  ) async {
    return NetworkRouteStatus.connected;
  }

  @override
  Future<NetworkHealth> health(RuntimeInstance runtime) async {
    return const NetworkHealth(
      reachable: true,
      latencyMs: 1,
      detail: 'fake',
    );
  }

  @override
  Future<void> stop(RuntimeInstance runtime) async {}
}
