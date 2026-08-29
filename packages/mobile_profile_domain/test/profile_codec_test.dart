import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  test('MobileProfile JSON 往返保持关键字段', () {
    final now = DateTime.utc(2026, 8, 29, 8, 30);
    final profile = MobileProfile(
      id: 'profile-001',
      name: '测试 Profile',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-001',
      deviceProfileRef: OppoFindN3Profiles.china.id,
      networkRouteRef: 'route-001',
      status: ProfileStatus.ready,
    );

    final decoded = ProfileCodec.decodeProfile(ProfileCodec.encodeProfile(profile));
    expect(decoded.id, profile.id);
    expect(decoded.name, profile.name);
    expect(decoded.browserProfileRef, profile.browserProfileRef);
    expect(decoded.deviceProfileRef, profile.deviceProfileRef);
    expect(decoded.networkRouteRef, profile.networkRouteRef);
    expect(decoded.status, profile.status);
    expect(decoded.createdAt, profile.createdAt);
  });

  test('NetworkRoute JSON 往返保持故障策略和 capability', () {
    const route = NetworkRoute(
      id: 'route-vless',
      name: 'VLESS',
      provider: NetworkProviderKind.singbox,
      protocol: ProviderProtocol.vless,
      providerConfigRef: 'config-vless',
      credentialRef: 'credential-001',
      trustRef: 'trust-001',
      policy: NetworkPolicy(failClosed: true, ipv6Mode: 'follow_provider'),
      failurePolicy: FailurePolicy(maxReconnectAttempts: 5),
      capabilities: ProviderCapabilities(
        tcp: true,
        udp: true,
        ipv4: true,
        ipv6: true,
        dns: true,
        tun: true,
        browserProxy: true,
      ),
    );

    final decoded = ProfileCodec.decodeRoute(ProfileCodec.encodeRoute(route));
    expect(decoded.provider, NetworkProviderKind.singbox);
    expect(decoded.protocol, ProviderProtocol.vless);
    expect(decoded.failurePolicy.maxReconnectAttempts, 5);
    expect(decoded.capabilities.udp, isTrue);
    expect(decoded.policy.failClosed, isTrue);
  });

  test('Runtime JSON 往返保持 generation', () {
    final runtime = RuntimeInstanceFactory.create(
      profileId: 'profile-001',
      routeId: 'route-001',
      providerInstanceId: 'provider-001',
      generation: 3,
    );

    final decoded = ProfileCodec.decodeRuntime(ProfileCodec.encodeRuntime(runtime));
    expect(decoded.id, runtime.id);
    expect(decoded.profileId, runtime.profileId);
    expect(decoded.routeId, runtime.routeId);
    expect(decoded.providerInstanceId, runtime.providerInstanceId);
    expect(decoded.generation, 3);
    expect(decoded.status, NetworkRouteStatus.unknown);
  });
}
