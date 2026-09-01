import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const uuidA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';

/// 记录调用并返回预设结果的通道 Fake（协议层测试）。
final class FakeBridgeChannel implements WebLibreRuntimeBridgeChannel {
  final List<String> bindLog = <String>[];
  final List<String> unbindLog = <String>[];
  Object? bindFailure;
  Object? unbindFailure;
  Map<String, Object?>? bindResponseOverride;
  Map<String, Object?> healthResponse = <String, Object?>{
    'alive': false,
    'browserProfileId': uuidA,
    'observedAt': '2026-08-31T12:00:00.000Z',
  };

  @override
  Future<Map<String, Object?>> bind({
    required String browserProfileId,
    required String profileDir,
    required String sessionId,
    required int generation,
  }) async {
    if (bindFailure != null) throw bindFailure!;
    bindLog.add('$browserProfileId|$sessionId|$generation');
    return bindResponseOverride ??
        <String, Object?>{
          'result': 'bound',
          'targetProfile': browserProfileId,
        };
  }

  @override
  Future<Map<String, Object?>> unbind({
    required String browserProfileId,
    required String sessionId,
    required int generation,
  }) async {
    if (unbindFailure != null) throw unbindFailure!;
    unbindLog.add('$browserProfileId|$sessionId|$generation');
    return <String, Object?>{};
  }

  @override
  Future<Map<String, Object?>> health({required String browserProfileId}) async {
    return Map<String, Object?>.of(healthResponse);
  }
}

MobileProfile profileOf(String id, String browserRef) {
  final now = DateTime.utc(2026, 8, 31, 9);
  return MobileProfile(
    id: id,
    name: 'Profile $id',
    createdAt: now,
    updatedAt: now,
    browserProfileRef: browserRef,
    deviceProfileRef: 'device-x',
    networkRouteRef: 'route-x',
    status: ProfileStatus.ready,
  );
}

void main() {
  test('bind/unbind 透传会话身份（Android 回调 fencing 的前提）', () async {
    final channel = FakeBridgeChannel();
    final binder = RealWebLibreGeckoBinder(channel: channel);

    final outcome = await binder.bind(
      uuidA,
      '/files/weblibre_profiles/profile-$uuidA',
      sessionId: 'rs-1',
      generation: 3,
    );
    await binder.unbind(uuidA, sessionId: 'rs-1', generation: 3);

    expect(channel.bindLog.single, '$uuidA|rs-1|3');
    expect(channel.unbindLog.single, '$uuidA|rs-1|3');
    expect(outcome.restartRequired, isFalse);
    expect(outcome.targetProfile, uuidA);
  });

  test('bind 返回 restart_required 时映射为切换结果', () async {
    final channel = FakeBridgeChannel();
    channel.bindResponseOverride = <String, Object?>{
      'result': 'restart_required',
      'targetProfile': uuidA,
      'currentProfile': 'another-profile',
      'pid': 4242,
    };
    final binder = RealWebLibreGeckoBinder(channel: channel);

    final outcome = await binder.bind(
      uuidA, '/dir', sessionId: 'rs-1', generation: 1,
    );

    expect(outcome.restartRequired, isTrue);
    expect(outcome.currentProfile, 'another-profile');
    expect(outcome.pid, 4242);
  });

  test('bind 返回未知 result 时抛协议错误', () async {
    final channel = FakeBridgeChannel();
    channel.bindResponseOverride = <String, Object?>{
      'result': 'magic',
      'targetProfile': uuidA,
    };
    final binder = RealWebLibreGeckoBinder(channel: channel);

    await expectLater(
      binder.bind(uuidA, '/dir', sessionId: 'rs-1', generation: 1),
      throwsA(isA<WebLibreRuntimeBridgeError>()),
    );
  });

  test('health 响应映射 RuntimeHealth（含 pid 与可空字段）', () async {
    final channel = FakeBridgeChannel()
      ..healthResponse = <String, Object?>{
        'alive': true,
        'browserProfileId': uuidA,
        'sessionId': 'rs-1',
        'generation': 3,
        'pid': 4242,
        'observedAt': '2026-08-31T12:00:00.000Z',
      };
    final binder = RealWebLibreGeckoBinder(channel: channel);

    final health = await binder.health(uuidA);

    expect(health.alive, isTrue);
    expect(health.browserProfileId, uuidA);
    expect(health.sessionId, 'rs-1');
    expect(health.generation, 3);
    expect(health.pid, 4242);
    expect(health.observedAt, DateTime.utc(2026, 8, 31, 12));
  });

  test('health 缺 sessionId/generation/pid 时映射为空身份（可信判定会拒绝）', () async {
    final channel = FakeBridgeChannel();
    final binder = RealWebLibreGeckoBinder(channel: channel);

    final health = await binder.health(uuidA);

    expect(health.alive, isFalse);
    expect(health.sessionId, '');
    expect(health.generation, 0);
    expect(health.pid, isNull);
  });

  test('health 字段类型非法时抛协议错误（防御性校验）', () async {
    final channel = FakeBridgeChannel()
      ..healthResponse = <String, Object?>{
        'alive': 'yes',
        'browserProfileId': uuidA,
        'observedAt': '2026-08-31T12:00:00.000Z',
      };
    final binder = RealWebLibreGeckoBinder(channel: channel);

    await expectLater(
      binder.health(uuidA),
      throwsA(isA<WebLibreRuntimeBridgeError>()),
    );
  });

  test('bind 抛错原样上抛（fail-closed 契约由 manager 落实）', () async {
    final channel = FakeBridgeChannel()..bindFailure = StateError('native');
    final binder = RealWebLibreGeckoBinder(channel: channel);

    await expectLater(
      binder.bind(uuidA, '/dir', sessionId: 'rs-1', generation: 1),
      throwsA(isA<StateError>()),
    );
  });

  test('Real Binder 接入 manager 的端到端链路（Fake channel）', () async {
    final channel = FakeBridgeChannel();
    final binder = RealWebLibreGeckoBinder(channel: channel);
    final sessions = InMemoryBrowserRuntimeSessionRepository();
    final manager = WebLibreRuntimeManager(
      storage: _MemStorage(),
      binder: binder,
      filesDir: '/files',
      sessionStore: sessions,
      clock: () => DateTime.utc(2026, 8, 31, 12),
    );

    final handle = await manager.launch(profileOf('p1', 'browser-$uuidA'));
    expect(handle.state, WebLibreRuntimeState.running);
    expect(channel.bindLog.single, startsWith('$uuidA|rs-'));

    // 会话身份经通道往返后仍能通过 fencing。
    expect(manager.isCurrentSession(handle.sessionId, handle.generation), isTrue);

    await manager.stop();
    expect(channel.unbindLog.single, startsWith('$uuidA|rs-'));
    expect(manager.bound, isNull);
  });
}

final class _MemStorage implements WebLibreProfileStorage {
  final Set<String> _ids = <String>{};

  @override
  Future<bool> create(String browserProfileId, {required String name}) async =>
      _ids.add(browserProfileId);

  @override
  Future<bool> exists(String browserProfileId) async => _ids.contains(browserProfileId);

  @override
  Future<void> delete(String browserProfileId) async => _ids.remove(browserProfileId);

  @override
  Future<List<String>> listBrowserProfileIds() async => _ids.toList()..sort();
}
