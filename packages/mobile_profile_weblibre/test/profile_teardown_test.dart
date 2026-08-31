import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const uuidA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';

/// 目录删除可注入失败的存储，用于验证数据残留防护。
final class FailingDeleteStorage implements WebLibreProfileStorage {
  FailingDeleteStorage(this.delegate);

  final WebLibreProfileStorage delegate;
  Object? deleteFailure;

  @override
  Future<bool> create(String browserProfileId, {required String name}) =>
      delegate.create(browserProfileId, name: name);

  @override
  Future<bool> exists(String browserProfileId) => delegate.exists(browserProfileId);

  @override
  Future<void> delete(String browserProfileId) async {
    if (deleteFailure != null) throw deleteFailure!;
    await delegate.delete(browserProfileId);
  }

  @override
  Future<List<String>> listBrowserProfileIds() => delegate.listBrowserProfileIds();
}

final class OkBinder implements WebLibreGeckoBinder {
  @override
  Future<void> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {}

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async {}

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async =>
      WebLibreRuntimeHealth(
        alive: false,
        browserProfileId: browserProfileId,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );
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
  late InMemoryBrowserProfileRepository bindings;
  late WebLibreRuntimeManager runtime;
  late ProfileTeardownService teardown;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_teardown_');
    storage = DirectoryWebLibreProfileStorage(tempDir.path);
    bindings = InMemoryBrowserProfileRepository();
    runtime = WebLibreRuntimeManager(
      storage: storage,
      binder: OkBinder(),
      filesDir: tempDir.path,
      sessionStore: InMemoryBrowserRuntimeSessionRepository(),
    );
    teardown = ProfileTeardownService(
      runtime: runtime,
      bindings: bindings,
      browserStorage: storage,
    );
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });

  Future<void> seedBinding(String mobileProfileId) async {
    final now = DateTime.utc(2026, 8, 31, 9);
    await bindings.save(BrowserProfileEntry(
      mobileProfileId: mobileProfileId,
      browserProfileId: uuidA,
      storageNamespace: 'weblibre_profiles/profile-$uuidA',
      createdAt: now,
    ));
    await storage.create(uuidA, name: 'A');
  }

  test('运行中的 Profile 拒绝删除（先停止并确认）', () async {
    await runtime.launch(profileOf('p1', 'browser-$uuidA'));
    await seedBinding('p1');

    await expectLater(teardown.teardown('p1'), throwsA(isA<ProfileTeardownError>()));
    expect(await storage.exists(uuidA), isTrue, reason: '数据未动');
    expect(await bindings.findByMobileProfileId('p1'), isNotNull);
  });

  test('解绑未知（unknown 槽位）同样拒绝删除', () async {
    final binder = _UnbindFailsBinder();
    final runtimeUnknown = WebLibreRuntimeManager(
      storage: storage,
      binder: binder,
      filesDir: tempDir.path,
    );
    final teardownUnknown = ProfileTeardownService(
      runtime: runtimeUnknown,
      bindings: bindings,
      browserStorage: storage,
    );
    await runtimeUnknown.launch(profileOf('p1', 'browser-$uuidA'));
    await seedBinding('p1');
    await expectLater(runtimeUnknown.stop(), throwsA(anything));

    await expectLater(
        teardownUnknown.teardown('p1'), throwsA(isA<ProfileTeardownError>()));
  });

  test('正常清理：先删磁盘目录，再删绑定', () async {
    await seedBinding('p1');

    await teardown.teardown('p1');

    expect(await storage.exists(uuidA), isFalse);
    expect(await bindings.findByMobileProfileId('p1'), isNull);
  });

  test('数据残留防护：磁盘删除失败时绑定保留（可重试），不产生孤儿目录', () async {
    final failing = FailingDeleteStorage(storage)..deleteFailure = StateError('io');
    final teardownFailing = ProfileTeardownService(
      runtime: runtime,
      bindings: bindings,
      browserStorage: failing,
    );
    await seedBinding('p1');

    await expectLater(teardownFailing.teardown('p1'), throwsA(anything));

    // 关键断言：数据库绑定仍在，指向仍存在的目录——两者一起保留。
    expect(await bindings.findByMobileProfileId('p1'), isNotNull);
    expect(await storage.exists(uuidA), isTrue);

    // 故障恢复后重试成功。
    failing.deleteFailure = null;
    await teardownFailing.teardown('p1');
    expect(await bindings.findByMobileProfileId('p1'), isNull);
    expect(await storage.exists(uuidA), isFalse);
  });

  test('无绑定时为幂等空操作', () async {
    await teardown.teardown('missing-profile');
    expect(await bindings.findByMobileProfileId('missing-profile'), isNull);
  });
}

final class _UnbindFailsBinder implements WebLibreGeckoBinder {
  @override
  Future<void> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {}

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async =>
      throw StateError('gecko hang');

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async =>
      WebLibreRuntimeHealth(
        alive: false,
        browserProfileId: browserProfileId,
        observedAt: DateTime.utc(2026, 8, 31, 9),
      );
}
