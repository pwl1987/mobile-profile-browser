import 'dart:async';
import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const uuidA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
const uuidB = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d';

final class RecordingBinder implements WebLibreGeckoBinder {
  final List<String> bindLog = <String>[];
  final List<String> unbindLog = <String>[];
  Object? bindFailure;
  Object? unbindFailure;
  WebLibreRuntimeHealth? healthResult;

  @override
  Future<void> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {
    if (bindFailure != null) throw bindFailure!;
    bindLog.add('$browserProfileId|$sessionId|$generation');
  }

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async {
    if (unbindFailure != null) throw unbindFailure!;
    unbindLog.add('$browserProfileId|$sessionId|$generation');
  }

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async {
    final result = healthResult;
    if (result != null) return result;
    return WebLibreRuntimeHealth(
      alive: false,
      browserProfileId: browserProfileId,
      observedAt: DateTime.utc(2026, 8, 31, 9),
    );
  }
}

/// 在 create 上设闸门的目录存储：用于确定性地复现 check-then-act 竞态窗口。
final class GatedStorage implements WebLibreProfileStorage {
  GatedStorage(this.delegate, this.gate);

  final WebLibreProfileStorage delegate;
  final Completer<void> gate;

  @override
  Future<bool> create(String browserProfileId, {required String name}) async {
    await gate.future;
    return delegate.create(browserProfileId, name: name);
  }

  @override
  Future<bool> exists(String browserProfileId) => delegate.exists(browserProfileId);

  @override
  Future<void> delete(String browserProfileId) => delegate.delete(browserProfileId);

  @override
  Future<List<String>> listBrowserProfileIds() => delegate.listBrowserProfileIds();
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
  late Directory tempDir;
  late DirectoryWebLibreProfileStorage storage;
  late InMemoryBrowserRuntimeSessionRepository sessions;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_hardening_');
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
    RecordingBinder binder, {
    WebLibreProfileStorage? store,
    BrowserRuntimeSessionRepository? sessionStore,
  }) =>
      WebLibreRuntimeManager(
        storage: store ?? storage,
        binder: binder,
        filesDir: tempDir.path,
        sessionStore: sessionStore,
      );

  group('fail-closed 解绑（ADR-006）', () {
    test('unbind 失败 → unknown 且槽位保留，阻止新 Profile 启动', () async {
      final binder = RecordingBinder()..unbindFailure = StateError('gecko hang');
      final manager = managerOf(binder, sessionStore: sessions);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));

      await expectLater(manager.stop(), throwsA(isA<WebLibreRuntimeBindingError>()));

      expect(manager.bound!.state, WebLibreRuntimeState.unknown);
      expect(manager.bound!.browserProfileId, uuidA);
      // 持久化也是 unknown。
      expect((await sessions.latestForProfile('p1'))!.state, 'unknown');

      // 新 Profile 启动被阻止（宁可阻止，不可冒险）。
      await expectLater(
        manager.launch(profileOf('p2', 'browser-$uuidB')),
        throwsA(isA<WebLibreRuntimeBindingError>()),
      );

      // 健康检查确认死亡后释放，才允许新启动。
      final released = await manager.confirmUnknownDead();
      expect(released.state, WebLibreRuntimeState.stopped);
      expect(manager.bound, isNull);
      final next = await manager.launch(profileOf('p2', 'browser-$uuidB'));
      expect(next.browserProfileId, uuidB);
    });

    test('confirmUnknownDead 只接受 unknown 状态', () async {
      final binder = RecordingBinder();
      final manager = managerOf(binder);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));

      await expectLater(
        manager.confirmUnknownDead(),
        throwsA(isA<WebLibreRuntimeBindingError>()),
      );
    });

    test('健康裁决"仍存活"：unknown 回到 running 并继续持有槽位', () async {
      final binder = RecordingBinder()..unbindFailure = StateError('gecko hang');
      final manager = managerOf(binder, sessionStore: sessions);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));
      await expectLater(manager.stop(), throwsA(isA<WebLibreRuntimeBindingError>()));
      expect(manager.bound!.state, WebLibreRuntimeState.unknown);

      // 健康检查发现 Gecko 仍在响应：回到 running，继续持有槽位。
      final alive = await manager.confirmUnknownAlive();
      expect(alive.state, WebLibreRuntimeState.running);
      expect(manager.bound!.browserProfileId, uuidA);
      expect((await sessions.latestForProfile('p1'))!.state, 'running');

      // 恢复后走正常 stop（故障解除）成功释放。
      binder.unbindFailure = null;
      final stopped = await manager.stop();
      expect(stopped.state, WebLibreRuntimeState.stopped);
      expect(manager.bound, isNull);
      final next = await manager.launch(profileOf('p2', 'browser-$uuidB'));
      expect(next.browserProfileId, uuidB);
    });

    test('confirmUnknownAlive 只接受 unknown 状态', () async {
      final binder = RecordingBinder();
      final manager = managerOf(binder, sessionStore: sessions);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));

      await expectLater(
        manager.confirmUnknownAlive(),
        throwsA(isA<WebLibreRuntimeBindingError>()),
      );
    });
  });

  group('操作互斥（check-then-act 竞态）', () {
    test('并发 launch 不可能双双通过槽位检查', () async {
      final binder = RecordingBinder();
      final gate = Completer<void>();
      final manager = managerOf(binder, store: GatedStorage(storage, gate), sessionStore: sessions);

      // A 在 storage.create 处挂起（已通过槽位检查、尚未绑定完成）。
      final launchA = manager.launch(profileOf('p1', 'browser-$uuidA'));
      await Future<void>.delayed(Duration.zero);
      // B 在 A 挂起期间发起：必须排队等待 A 完成，然后被槽位拒绝。
      final launchB = manager.launch(profileOf('p2', 'browser-$uuidB'));

      gate.complete();
      final handleA = await launchA;
      expect(handleA.browserProfileId, uuidA);
      await expectLater(launchB, throwsA(isA<WebLibreRuntimeBindingError>()));
      expect(binder.bindLog.length, 1, reason: '只允许一次真实绑定');
      expect(binder.bindLog.single, startsWith(uuidA));
    });

    test('并发 stop 与 launch 串行化', () async {
      final binder = RecordingBinder();
      final manager = managerOf(binder, sessionStore: sessions);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));

      final stopFuture = manager.stop();
      final launchFuture = manager.launch(profileOf('p2', 'browser-$uuidB'));

      await stopFuture;
      final handle = await launchFuture;
      expect(handle.browserProfileId, uuidB);
      expect(binder.unbindLog.single, startsWith(uuidA));
      expect(binder.bindLog.length, 2);
      expect(binder.bindLog.first, startsWith(uuidA));
      expect(binder.bindLog.last, startsWith(uuidB));
    });
  });

  group('generation 与回调守卫', () {
    test('同 Profile 重启 generation 单调递增，旧回调被丢弃', () async {
      final binder = RecordingBinder();
      final manager = managerOf(binder, sessionStore: sessions);

      final first = await manager.launch(profileOf('p1', 'browser-$uuidA'));
      final oldSessionId = first.sessionId;
      final oldGeneration = first.generation;
      await manager.stop();

      final second = await manager.launch(profileOf('p1', 'browser-$uuidA'));
      expect(second.generation, oldGeneration + 1);
      expect(second.sessionId, isNot(oldSessionId));

      // 旧 Runtime 的迟到回调必须被丢弃。
      expect(manager.isCurrentSession(oldSessionId, oldGeneration), isFalse);
      expect(manager.isCurrentSession(second.sessionId, second.generation), isTrue);
    });

    test('bind 抛错按契约视为未绑定：failed 落盘、槽位释放、可重试', () async {
      final binder = RecordingBinder()..bindFailure = StateError('native crash');
      final manager = managerOf(binder, sessionStore: sessions);

      await expectLater(
        manager.launch(profileOf('p1', 'browser-$uuidA')),
        throwsA(isA<WebLibreRuntimeBindingError>()),
      );
      expect(manager.bound, isNull);
      expect((await sessions.latestForProfile('p1'))!.state, 'failed');

      binder.bindFailure = null;
      final retried = await manager.launch(profileOf('p1', 'browser-$uuidA'));
      expect(retried.generation, 2, reason: '重试也递增 generation');
      expect(retried.state, WebLibreRuntimeState.running);
    });
  });

  group('真正的进程死亡恢复（持久化真相来源）', () {
    test('应用进程死亡：新实例基于持久化 running 收敛为 stopped', () async {
      final binderA = RecordingBinder();
      final managerA = managerOf(binderA, sessionStore: sessions);
      final handle = await managerA.launch(profileOf('p1', 'browser-$uuidA'));
      expect((await sessions.latestForProfile('p1'))!.state, 'running');

      // 进程死亡：Dart heap（含 _bound）消失，只剩 SQLite/内存仓储中的会话。
      // 新进程、新 manager，共享同一 sessionStore。
      final binderB = RecordingBinder();
      final managerB = managerOf(binderB, sessionStore: sessions);

      final report = await managerB.recoverAfterApplicationProcessDeath();

      expect(report.recoveredSessions.single,
          (handle.sessionId, 'running'),
          reason: '恢复前持久化状态为 running');
      final after = await sessions.latestForProfile('p1');
      expect(after!.state, 'stopped');
      expect(managerB.bound, isNull);

      // 恢复后可立即重新启动。
      final relaunched = await managerB.launch(profileOf('p1', 'browser-$uuidA'));
      expect(relaunched.generation, handle.generation + 1);
    });

    test('Dart 重启（进程未死）：只降级 unknown，禁止自动判死', () async {
      final binderA = RecordingBinder();
      final managerA = managerOf(binderA, sessionStore: sessions);
      final handle = await managerA.launch(profileOf('p1', 'browser-$uuidA'));

      // Flutter engine 重建：新 manager、共享会话存储、应用进程未死。
      final binderB = RecordingBinder();
      final managerB = managerOf(binderB, sessionStore: sessions);

      final report = await managerB.recoverAfterDartRestart();

      expect(report.recoveredSessions.single, (handle.sessionId, 'running'));
      final after = await sessions.latestForProfile('p1');
      expect(after!.state, 'unknown', reason: 'Gecko 可能仍存活，裁决交给健康检查');
      expect(await sessions.findClaimedAlive().then((l) => l.length), 1,
          reason: 'unknown 仍是声称存活状态，未被静默收敛');
    });

    test('崩溃窗口：持久化 STARTING（bind 未完成即死亡）也会被收敛', () async {
      // 手工构造启动窗口落盘的会话（manager 在 allocate(starting) 后、bind 前被杀）。
      final now = DateTime.utc(2026, 8, 31, 9);
      await sessions.save(BrowserRuntimeSession(
        id: 'rs-window',
        mobileProfileId: 'p1',
        browserProfileId: uuidA,
        state: 'starting',
        generation: 7,
        startedAt: now,
        updatedAt: now,
      ));

      final binder = RecordingBinder();
      final manager = managerOf(binder, sessionStore: sessions);
      final report = await manager.recoverAfterApplicationProcessDeath();

      expect(report.recoveredSessions.single.$1, 'rs-window');
      expect((await sessions.latestForProfile('p1'))!.state, 'stopped');
    });

    test('多 Profile 残留会话全部收敛', () async {
      final now = DateTime.utc(2026, 8, 31, 9);
      await sessions.save(BrowserRuntimeSession(
          id: 'rs-1', mobileProfileId: 'p1', browserProfileId: uuidA,
          state: 'running', generation: 1, startedAt: now, updatedAt: now));
      await sessions.save(BrowserRuntimeSession(
          id: 'rs-2', mobileProfileId: 'p2', browserProfileId: uuidB,
          state: 'stopping', generation: 1, startedAt: now, updatedAt: now));
      await sessions.save(BrowserRuntimeSession(
          id: 'rs-3', mobileProfileId: 'p3',
          browserProfileId: '2b3c4d5e-6f7a-8b9c-0d1e-2f3a4b5c6d7e',
          state: 'stopped', generation: 1, startedAt: now, updatedAt: now));

      final manager = managerOf(RecordingBinder(), sessionStore: sessions);
      final report = await manager.recoverAfterApplicationProcessDeath();

      expect(report.recoveredSessions.length, 2, reason: 'stopped 不需要恢复');
      expect(await sessions.findClaimedAlive(), isEmpty);
    });
  });

  group('unknown 槽位的健康裁决（实际真相观测）', () {
    Future<WebLibreRuntimeManager> unknownManager(RecordingBinder binder) async {
      binder.unbindFailure = StateError('gecko hang');
      final manager = managerOf(binder, sessionStore: sessions);
      await manager.launch(profileOf('p1', 'browser-$uuidA'));
      await expectLater(manager.stop(), throwsA(isA<WebLibreRuntimeBindingError>()));
      expect(manager.bound!.state, WebLibreRuntimeState.unknown);
      return manager;
    }

    test('health 存活且会话身份匹配 → running 继续持有', () async {
      final binder = RecordingBinder();
      final manager = await unknownManager(binder);
      final bound = manager.bound!;
      binder.unbindFailure = null;
      binder.healthResult = WebLibreRuntimeHealth(
        alive: true,
        browserProfileId: uuidA,
        sessionId: bound.sessionId,
        generation: bound.generation,
        pid: 4242,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );

      final resolved = await manager.resolveUnknownViaHealth();

      expect(resolved.state, WebLibreRuntimeState.running);
      expect(manager.bound!.browserProfileId, uuidA);
      expect((await sessions.latestForProfile('p1'))!.state, 'running');

      // 恢复 running 后可正常 stop。
      final stopped = await manager.stop();
      expect(stopped.state, WebLibreRuntimeState.stopped);
    });

    test('health 死亡 → stopped 释放槽位', () async {
      final binder = RecordingBinder();
      final manager = await unknownManager(binder);
      binder.healthResult = WebLibreRuntimeHealth(
        alive: false,
        browserProfileId: uuidA,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );

      final resolved = await manager.resolveUnknownViaHealth();

      expect(resolved.state, WebLibreRuntimeState.stopped);
      expect(manager.bound, isNull);
      final next = await manager.launch(profileOf('p2', 'browser-$uuidB'));
      expect(next.browserProfileId, uuidB);
    });

    test('health 存活但会话身份过期 → 按死亡处理（fail-closed）', () async {
      final binder = RecordingBinder();
      final manager = await unknownManager(binder);
      binder.healthResult = WebLibreRuntimeHealth(
        alive: true,
        browserProfileId: uuidA,
        sessionId: 'rs-stale',
        generation: 99,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );

      final resolved = await manager.resolveUnknownViaHealth();

      expect(resolved.state, WebLibreRuntimeState.stopped, reason: '过期观测不可信，宁死勿混');
      expect(manager.bound, isNull);
    });
  });

  group('generation 原子分配（ADR-007）', () {
    test('并发 allocateSession 得到严格不同的 generation', () async {
      final now = DateTime.utc(2026, 8, 31, 9);
      final results = await Future.wait(<Future<BrowserRuntimeSession>>[
        sessions.allocateSession(
            id: 'rs-a', mobileProfileId: 'p1', browserProfileId: uuidA,
            state: 'starting', startedAt: now),
        sessions.allocateSession(
            id: 'rs-b', mobileProfileId: 'p1', browserProfileId: uuidA,
            state: 'starting', startedAt: now),
        sessions.allocateSession(
            id: 'rs-c', mobileProfileId: 'p1', browserProfileId: uuidA,
            state: 'starting', startedAt: now),
      ]);
      final generations = results.map((s) => s.generation).toSet();
      expect(generations, {1, 2, 3}, reason: '无重复且连续');
    });
  });
}
