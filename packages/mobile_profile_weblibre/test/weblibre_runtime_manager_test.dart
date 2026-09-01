import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const uuidA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
const uuidB = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d';

final class RecordingGeckoBinder implements WebLibreGeckoBinder {
  final List<String> bindLog = <String>[];
  final List<String> unbindLog = <String>[];
  Object? bindFailure;

  @override
  Future<WebLibreBindOutcome> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {
    if (bindFailure != null) {
      throw bindFailure!;
    }
    bindLog.add('$browserProfileId|$profileDir|$sessionId|$generation');
    return WebLibreBindOutcome(
        restartRequired: false, targetProfile: browserProfileId);
  }

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async {
    unbindLog.add(browserProfileId);
  }

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async =>
      WebLibreRuntimeHealth(
        alive: false,
        browserProfileId: browserProfileId,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );
}

MobileProfile profileOf(String id, String browserRef) {
  final now = DateTime.utc(2026, 8, 30, 9);
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
  late RecordingGeckoBinder binder;
  late InMemoryBrowserRuntimeSessionRepository sessions;
  late WebLibreRuntimeManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_weblibre_runtime_');
    storage = DirectoryWebLibreProfileStorage(tempDir.path);
    binder = RecordingGeckoBinder();
    sessions = InMemoryBrowserRuntimeSessionRepository();
    manager = WebLibreRuntimeManager(
      storage: storage,
      binder: binder,
      filesDir: tempDir.path,
      sessionStore: sessions,
    );
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });

  test('launch 建立目录并以真实 profileDir 绑定到 running', () async {
    final handle = await manager.launch(profileOf('p1', 'browser-$uuidA'));

    expect(handle.state, WebLibreRuntimeState.running);
    expect(handle.browserProfileId, uuidA);
    expect(
      binder.bindLog.single,
      startsWith('$uuidA|${WebLibreProfilePaths.profileDir(tempDir.path, uuidA)}|rs-'),
      reason: '绑定调用携带目录与会话身份',
    );
    expect(await storage.exists(uuidA), isTrue);
  });

  test('上游一次性绑定约束：绑定期间 launch 第二个 Profile 被拒绝', () async {
    await manager.launch(profileOf('p1', 'browser-$uuidA'));

    await expectLater(
      manager.launch(profileOf('p2', 'browser-$uuidB')),
      throwsA(isA<WebLibreRuntimeBindingError>()),
    );
    expect(binder.bindLog.length, 1, reason: '第二个 Profile 未产生绑定调用');
  });

  test('stop 释放绑定槽位后可以 launch 另一个 Profile', () async {
    await manager.launch(profileOf('p1', 'browser-$uuidA'));
    final stopped = await manager.stop();

    expect(stopped.state, WebLibreRuntimeState.stopped);
    expect(manager.bound, isNull);
    expect(binder.unbindLog, [uuidA]);

    final next = await manager.launch(profileOf('p2', 'browser-$uuidB'));
    expect(next.browserProfileId, uuidB);
    expect(next.state, WebLibreRuntimeState.running);
  });

  test('绑定失败进入 failed 语义并释放槽位，可重试', () async {
    binder.bindFailure = StateError('gecko crash');

    await expectLater(
      manager.launch(profileOf('p1', 'browser-$uuidA')),
      throwsA(isA<WebLibreRuntimeBindingError>()),
    );
    expect(manager.bound, isNull);

    binder.bindFailure = null;
    final retried = await manager.launch(profileOf('p1', 'browser-$uuidA'));
    expect(retried.state, WebLibreRuntimeState.running);
  });

  test('未绑定时 stop 被拒绝', () async {
    await expectLater(
      manager.stop(),
      throwsA(isA<WebLibreRuntimeBindingError>()),
    );
  });

  test('非法 browserProfileRef 在 launch 前被映射层拒绝', () async {
    await expectLater(
      manager.launch(profileOf('p1', 'browser-not-a-uuid')),
      throwsA(anything),
    );
    expect(await storage.listBrowserProfileIds(), isEmpty);
  });

  test('recoverAfterApplicationProcessDeath：持久化 running 收敛为 stopped 并释放启动权', () async {
    await manager.launch(profileOf('p1', 'browser-$uuidA'));

    final report = await manager.recoverAfterApplicationProcessDeath();

    expect(report.recoveredSessions.single.$1, isNotEmpty);
    expect(manager.bound, isNull);
    // 槽位已释放，可以直接 launch 另一个 Profile。
    final next = await manager.launch(profileOf('p2', 'browser-$uuidB'));
    expect(next.browserProfileId, uuidB);
  });

  test('无持久化会话时恢复为空操作', () async {
    final report = await manager.recoverAfterApplicationProcessDeath();
    expect(report.isEmpty, isTrue);
  });
}
