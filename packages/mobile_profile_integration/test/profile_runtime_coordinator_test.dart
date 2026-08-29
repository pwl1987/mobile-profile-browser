import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_integration/mobile_profile_integration.dart';
import 'package:test/test.dart';

void main() {
  test('启动顺序为浏览器 Profile 准备→网络→浏览器 Runtime', () async {
    final events = <String>[];
    final coordinator = ProfileRuntimeCoordinator(
      browserProfileAdapter: _FakeBrowserProfileAdapter(events),
      browserRuntimeAdapter: _FakeBrowserRuntimeAdapter(events),
      networkRuntimeFactory: _FakeNetworkRuntimeFactory(events),
    );

    final session = await coordinator.start(
      profile: _profile(),
      runtime: _runtime(),
      route: _route(),
    );

    expect(events, <String>[
      'ensure-profile',
      'prepare-profile',
      'network-start',
      'browser-start',
    ]);
    expect(session.browserProfile.id, 'browser-profile-001');
  });

  test('浏览器启动失败时会释放网络 Runtime', () async {
    final events = <String>[];
    final coordinator = ProfileRuntimeCoordinator(
      browserProfileAdapter: _FakeBrowserProfileAdapter(events),
      browserRuntimeAdapter: _FakeBrowserRuntimeAdapter(events, failOnStart: true),
      networkRuntimeFactory: _FakeNetworkRuntimeFactory(events),
    );

    await expectLater(
      coordinator.start(
        profile: _profile(),
        runtime: _runtime(),
        route: _route(),
      ),
      throwsA(isA<StateError>()),
    );

    expect(events.last, 'network-stop');
  });
}

MobileProfile _profile() {
  final now = DateTime.utc(2026, 8, 29);
  return MobileProfile(
    id: 'profile-001',
    name: '测试 Profile',
    createdAt: now,
    updatedAt: now,
    browserProfileRef: 'browser-profile-001',
    deviceProfileRef: 'device-find-n3',
    networkRouteRef: 'route-001',
    status: ProfileStatus.ready,
  );
}

RuntimeInstance _runtime() {
  return RuntimeInstance(
    id: 'runtime-001',
    profileId: 'profile-001',
    routeId: 'route-001',
    providerInstanceId: 'provider-001',
    generation: 1,
    startedAt: DateTime.utc(2026, 8, 29),
  );
}

NetworkRoute _route() {
  return const NetworkRoute(
    id: 'route-001',
    name: '测试线路',
    provider: NetworkProviderKind.socks5,
    protocol: ProviderProtocol.socks5,
    providerConfigRef: 'provider-001',
  );
}

final class _FakeBrowserProfileAdapter implements BrowserProfileAdapter {
  _FakeBrowserProfileAdapter(this.events);
  final List<String> events;

  @override
  Future<BrowserProfileHandle> ensureProfile(MobileProfile profile) async {
    events.add('ensure-profile');
    return const BrowserProfileHandle(
      id: 'browser-profile-001',
      storageNamespace: 'storage-001',
    );
  }

  @override
  Future<void> prepareProfile(BrowserProfileHandle handle) async {
    events.add('prepare-profile');
  }

  @override
  Future<void> deleteProfile(BrowserProfileHandle handle) async {}
}

final class _FakeBrowserRuntimeAdapter implements BrowserRuntimeAdapter {
  _FakeBrowserRuntimeAdapter(this.events, {this.failOnStart = false});
  final List<String> events;
  final bool failOnStart;

  @override
  Future<BrowserRuntimeHandle> start({
    required MobileProfile profile,
    required BrowserProfileHandle browserProfile,
  }) async {
    events.add('browser-start');
    if (failOnStart) {
      throw StateError('browser-start-failed');
    }
    return const BrowserRuntimeHandle(
      id: 'browser-runtime-001',
      profileId: 'profile-001',
    );
  }

  @override
  Future<void> stop(BrowserRuntimeHandle runtime) async {
    events.add('browser-stop');
  }
}

final class _FakeNetworkRuntimeFactory implements NetworkRuntimeFactory {
  _FakeNetworkRuntimeFactory(this.events);
  final List<String> events;

  @override
  NetworkRuntimeAdapter create(NetworkRoute route) {
    return _FakeNetworkRuntime(events);
  }
}

final class _FakeNetworkRuntime implements NetworkRuntimeAdapter {
  _FakeNetworkRuntime(this.events);
  final List<String> events;

  @override
  Future<NetworkRouteStatus> start(
    RuntimeInstance runtime,
    NetworkRoute route,
  ) async {
    events.add('network-start');
    return NetworkRouteStatus.connected;
  }

  @override
  Future<NetworkHealth> health(RuntimeInstance runtime) async {
    return const NetworkHealth(
      connection: NetworkRouteStatus.connected,
      health: NetworkHealthState.healthy,
      traffic: TrafficState.allowed,
      leak: LeakState.safe,
    );
  }

  @override
  Future<void> stop(RuntimeInstance runtime) async {
    events.add('network-stop');
  }
}
