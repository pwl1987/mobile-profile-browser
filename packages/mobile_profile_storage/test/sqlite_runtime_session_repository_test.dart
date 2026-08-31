import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

const profileId = '11111111-1111-4111-8111-111111111111';
const browserId = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';

BrowserRuntimeSession sessionOf(
  String id,
  String state,
  int generation, {
  String mobileProfileId = profileId,
}) =>
    BrowserRuntimeSession(
      id: id,
      mobileProfileId: mobileProfileId,
      browserProfileId: browserId,
      state: state,
      generation: generation,
      startedAt: DateTime.utc(2026, 8, 31, 9),
      updatedAt: DateTime.utc(2026, 8, 31, 9),
    );

void main() {
  late ProfileStore store;

  setUp(() async {
    store = await ProfileStore.openInMemory();
    await store.deviceProfiles.save(DeviceProfile(id: 'device-x', name: 'X'));
    await store.networkRoutes.save(NetworkRoute(
        id: 'route-x', name: 'X', provider: NetworkProviderKind.direct));
    await store.profiles.save(MobileProfile(
      id: profileId,
      name: '会话测试',
      createdAt: DateTime.utc(2026, 8, 31, 9),
      updatedAt: DateTime.utc(2026, 8, 31, 9),
      browserProfileRef: 'browser-$browserId',
      deviceProfileRef: 'device-x',
      networkRouteRef: 'route-x',
      status: ProfileStatus.ready,
    ));
  });

  tearDown(() async {
    await store.close();
  });

  test('全新数据库应用到 v3', () async {
    expect(store.schemaVersion, 3);
  });

  test('会话往返与 latestForProfile 按 generation 取最新', () async {
    await store.runtimeSessions.save(sessionOf('rs-1', 'stopped', 1));
    await store.runtimeSessions.save(sessionOf('rs-2', 'running', 2));

    final latest = await store.runtimeSessions.latestForProfile(profileId);
    expect(latest!.id, 'rs-2');
    expect(latest.generation, 2);
    expect(latest.state, 'running');
  });

  test('allocateSession 在事务内原子分配 generation（并发不重复）', () async {
    final now = DateTime.utc(2026, 8, 31, 9);
    final results = await Future.wait(<Future<BrowserRuntimeSession>>[
      for (var i = 0; i < 3; i++)
        store.runtimeSessions.allocateSession(
          id: 'rs-concurrent-$i',
          mobileProfileId: profileId,
          browserProfileId: browserId,
          state: 'starting',
          startedAt: now,
        ),
    ]);

    final generations = results.map((s) => s.generation).toSet();
    expect(generations, {1, 2, 3}, reason: '严格不同且连续（ADR-007）');
    expect(results.every((s) => s.state == 'starting'), isTrue);

    // 与既有会话衔接：下一次分配从最大值继续。
    final next = await store.runtimeSessions.allocateSession(
      id: 'rs-next', mobileProfileId: profileId, browserProfileId: browserId,
      state: 'starting', startedAt: now,
    );
    expect(next.generation, 4);
  });

  test('findClaimedAlive 只取声称存活状态（参数绑定 IN）', () async {
    await store.runtimeSessions.save(sessionOf('rs-1', 'stopped', 1));
    await store.runtimeSessions.save(sessionOf('rs-2', 'starting', 2));
    await store.runtimeSessions.save(sessionOf('rs-3', 'running', 3));
    await store.runtimeSessions.save(sessionOf('rs-4', 'unknown', 4));
    await store.runtimeSessions.save(sessionOf('rs-5', 'failed', 5));
    await store.runtimeSessions.save(sessionOf('rs-6', 'stopping', 6));

    final claimed = await store.runtimeSessions.findClaimedAlive();
    expect(claimed.map((s) => s.state).toSet(), {'starting', 'running', 'unknown', 'stopping'});
  });

  test('save 全量替换：同 id 更新状态与 updated_at', () async {
    await store.runtimeSessions.save(sessionOf('rs-1', 'starting', 3));
    await store.runtimeSessions.save(sessionOf('rs-1', 'running', 3)
        .copyWith(updatedAt: DateTime.utc(2026, 8, 31, 10)));

    final latest = await store.runtimeSessions.latestForProfile(profileId);
    expect(latest!.state, 'running');
    expect(latest.updatedAt, DateTime.utc(2026, 8, 31, 10));
  });

  test('删除 Profile 级联清理会话', () async {
    await store.runtimeSessions.save(sessionOf('rs-1', 'running', 1));
    await store.profiles.delete(profileId);
    expect(await store.runtimeSessions.latestForProfile(profileId), isNull);
    expect(await store.runtimeSessions.findClaimedAlive(), isEmpty);
  });

  test('v2 旧库无损升级到 v3（文件库）', () async {
    final tempDir = await Directory.systemTemp.createTemp('mpb_v3_upgrade_');
    final dbPath = '${tempDir.path}${Platform.pathSeparator}profiles.db';

    final storeV2 =
        await ProfileStore.open(dbPath, migrations: const [StorageMigrations.v1, StorageMigrations.v2]);
    await storeV2.deviceProfiles.save(DeviceProfile(id: 'device-x', name: 'X'));
    expect(storeV2.schemaVersion, 2);
    await storeV2.close();

    final upgraded = await ProfileStore.open(dbPath);
    expect(upgraded.schemaVersion, 3);
    expect(await upgraded.deviceProfiles.findById('device-x'), isNotNull);
    await upgraded.close();

    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });
}
