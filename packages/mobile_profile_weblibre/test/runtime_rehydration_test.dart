import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const uuidA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
const uuidB = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d';

final class HealthStubBinder implements WebLibreGeckoBinder {
  HealthStubBinder({this.unbindFailure});

  Object? unbindFailure;
  WebLibreRuntimeHealth? healthResult;

  @override
  Future<WebLibreBindOutcome> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async =>
      WebLibreBindOutcome(
          restartRequired: false, targetProfile: browserProfileId);

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async {
    if (unbindFailure != null) throw unbindFailure!;
  }

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async {
    final result = healthResult;
    if (result != null) return result;
    return WebLibreRuntimeHealth(
      alive: false,
      browserProfileId: browserProfileId,
      observedAt: DateTime.utc(2026, 8, 31, 12),
    );
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

/// Runtime Recovery Rehydration（ADR-007 补遗）：
/// Dart 重启后 unknown 必须重新形成槽位，而不是变成"不设防"。
void main() {
  late Directory tempDir;
  late DirectoryWebLibreProfileStorage storage;
  late InMemoryBrowserRuntimeSessionRepository sessions;

  final fakeNow = DateTime.utc(2026, 8, 31, 12);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_rehydration_');
    storage = DirectoryWebLibreProfileStorage(tempDir.path);
    sessions = InMemoryBrowserRuntimeSessionRepository();
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });

  WebLibreRuntimeManager managerOf(
    HealthStubBinder binder, {
    BrowserRuntimeSessionRepository? sessionStore,
  }) =>
      WebLibreRuntimeManager(
        storage: storage,
        binder: binder,
        filesDir: tempDir.path,
        sessionStore: sessionStore ?? sessions,
        clock: () => fakeNow,
      );

  test('Rehydration：Dart 重启后 unknown 重建为槽位，launch 被拦截', () async {
    final binderA = HealthStubBinder();
    final managerA = managerOf(binderA);
    final handle = await managerA.launch(profileOf('p1', 'browser-$uuidA'));

    // Flutter engine 重建：新 manager、共享会话存储、应用进程未死。
    final binderB = HealthStubBinder();
    final managerB = managerOf(binderB);

    final report = await managerB.recoverAfterDartRestart();

    expect(report.rehydratedSessionId, handle.sessionId);
    expect(managerB.bound, isNotNull, reason: 'unknown 必须重新形成槽位');
    expect(managerB.bound!.state, WebLibreRuntimeState.unknown);
    expect(managerB.bound!.browserProfileId, uuidA);
    expect(managerB.bound!.generation, handle.generation);

    // 关键回归：unknown 不设防漏洞——新 Profile 启动必须被拦截。
    await expectLater(
      managerB.launch(profileOf('p2', 'browser-$uuidB')),
      throwsA(isA<WebLibreRuntimeBindingError>()),
    );
  });

  test('Rehydration 后健康裁决闭环可用：可信观测 → running', () async {
    final binderA = HealthStubBinder();
    final managerA = managerOf(binderA);
    final handle = await managerA.launch(profileOf('p1', 'browser-$uuidA'));

    final binderB = HealthStubBinder();
    final managerB = managerOf(binderB);
    await managerB.recoverAfterDartRestart();

    // 修复前：resolveUnknownViaHealth 因 _bound == null 直接抛错，闭环矛盾。
    binderB.healthResult = WebLibreRuntimeHealth(
      alive: true,
      browserProfileId: uuidA,
      sessionId: handle.sessionId,
      generation: handle.generation,
      pid: 1024,
      observedAt: fakeNow,
    );

    final resolved = await managerB.resolveUnknownViaHealth();

    expect(resolved.state, WebLibreRuntimeState.running);
    expect((await sessions.latestForProfile('p1'))!.state, 'running');

    // 恢复后走正常 stop，槽位释放。
    final stopped = await managerB.stop();
    expect(stopped.state, WebLibreRuntimeState.stopped);
    final next = await managerB.launch(profileOf('p2', 'browser-$uuidB'));
    expect(next.browserProfileId, uuidB);
  });

  test('Rehydration 后确认死亡：confirmUnknownDirect 释放槽位', () async {
    final managerA = managerOf(HealthStubBinder());
    await managerA.launch(profileOf('p1', 'browser-$uuidA'));

    final binderB = HealthStubBinder();
    final managerB = managerOf(binderB);
    await managerB.recoverAfterDartRestart();

    final released = await managerB.confirmUnknownDead();

    expect(released.state, WebLibreRuntimeState.stopped);
    expect(managerB.bound, isNull);
  });

  test('多条声称存活会话：只 Rehydrate 最新一条，其余按单槽位不变量收敛', () async {
    final t1 = DateTime.utc(2026, 8, 31, 10);
    final t2 = DateTime.utc(2026, 8, 31, 11);
    await sessions.save(BrowserRuntimeSession(
        id: 'rs-old', mobileProfileId: 'p1', browserProfileId: uuidA,
        state: 'running', generation: 1, startedAt: t1, updatedAt: t1));
    await sessions.save(BrowserRuntimeSession(
        id: 'rs-new', mobileProfileId: 'p2', browserProfileId: uuidB,
        state: 'stopping', generation: 1, startedAt: t2, updatedAt: t2));

    final binder = HealthStubBinder();
    final manager = managerOf(binder);
    final report = await manager.recoverAfterDartRestart();

    expect(report.rehydratedSessionId, 'rs-new', reason: '最新者才可能是存活运行时');
    expect(report.recoveredSessions.single.$1, 'rs-old');
    expect((await sessions.latestForProfile('p1'))!.state, 'stopped');
    expect(manager.bound!.browserProfileId, uuidB);

    // 只剩下 rehydrate 的 unknown 在声称存活集合中。
    final claimed = await sessions.findClaimedAlive();
    expect(claimed.single.id, 'rs-new');
  });

  test('无可恢复会话时 Rehydration 为空操作', () async {
    final manager = managerOf(HealthStubBinder());
    final report = await manager.recoverAfterDartRestart();
    expect(report.isEmpty, isTrue);
    expect(manager.bound, isNull);
  });
}
