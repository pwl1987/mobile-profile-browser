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

  test('MobileProfile JSON 往返保持 metadata，缺失字段回退为空', () {
    final now = DateTime.utc(2026, 8, 30, 9);
    final profile = MobileProfile(
      id: 'profile-002',
      name: '带元数据',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-002',
      deviceProfileRef: 'device-x',
      networkRouteRef: 'route-x',
      status: ProfileStatus.unknown,
      metadata: const <String, String>{'note': '恢复中', 'order': '7'},
    );

    final decoded = ProfileCodec.decodeProfile(ProfileCodec.encodeProfile(profile));
    expect(decoded.metadata, profile.metadata);
    expect(decoded.status, ProfileStatus.unknown);

    // 旧版本 JSON 不含 metadata 时按空映射解析。
    final legacy = ProfileCodec.decodeProfile(
      '{"schemaVersion":1,"id":"p","name":"n","createdAt":"2026-01-01T00:00:00.000Z",'
      '"updatedAt":"2026-01-01T00:00:00.000Z","browserProfileRef":"b",'
      '"deviceProfileRef":"d","networkRouteRef":"r","status":"ready"}',
    );
    expect(legacy.metadata, isEmpty);
  });

  test('DeviceProfile JSON 往返保持双屏规格与能力状态', () {
    const device = OppoFindN3Profiles.china;

    final decoded = ProfileCodec.decodeDevice(ProfileCodec.encodeDevice(device));
    expect(decoded.id, device.id);
    expect(decoded.model, device.model);
    expect(decoded.posture, device.posture);
    expect(decoded.mainDisplay!.resolutionWidth, device.mainDisplay!.resolutionWidth);
    expect(decoded.mainDisplay!.refreshRateHz, device.mainDisplay!.refreshRateHz);
    expect(decoded.coverDisplay!.resolutionHeight, device.coverDisplay!.resolutionHeight);
    expect(decoded.hardwareConcurrency, device.hardwareConcurrency);
    expect(decoded.maxTouchPoints, device.maxTouchPoints);
    expect(decoded.clientHintsState, CapabilityState.observed);
    expect(decoded.webglState, CapabilityState.observed);
  });

  test('DeviceProfile JSON 往返保持可选 viewport 与 DPR', () {
    const device = DeviceProfile(
      id: 'device-optional',
      name: '可选字段设备',
      mainDisplay: DisplayProfile(
        surface: DisplaySurface.main,
        resolutionWidth: 1080,
        resolutionHeight: 2400,
        viewportWidth: 360,
        viewportHeight: 800,
        devicePixelRatio: 3.0,
      ),
    );

    final decoded = ProfileCodec.decodeDevice(ProfileCodec.encodeDevice(device));
    final display = decoded.mainDisplay!;
    expect(display.viewportWidth, 360);
    expect(display.viewportHeight, 800);
    expect(display.devicePixelRatio, 3.0);
    expect(decoded.coverDisplay, isNull);
    expect(decoded.locale, isNull);
    expect(decoded.timezone, isNull);
    expect(decoded.deviceMemoryGb, isNull);
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
