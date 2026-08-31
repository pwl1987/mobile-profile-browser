import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_m2_recovery_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 下 WAL 句柄可能延迟释放导致删除失败；临时目录交给系统
      // 清理，测试断言在此之前已经完成。
    }
  });

  test('进程被杀死场景：持久化 running 的 Profile 重开后恢复为 ready', () async {
    final dbPath = '${tempDir.path}${Platform.pathSeparator}profiles.db';

    // ---- 第一次进程生命周期：创建 Profile 并让它处于 running ----
    {
      final store = await ProfileStore.open(dbPath);
      final service = MobileProfileService(
        profileRepository: store.profiles,
        deviceProfileRepository: store.deviceProfiles,
        networkRouteRepository: store.networkRoutes,
        runtimeRepository: store.runtimes,
      );
      final profile = await service.create(name: '崩溃前 Profile');
      await store.profiles.save(profile.copyWith(status: ProfileStatus.running));
      await store.runtimes.save(RuntimeInstanceFactory.create(
        profileId: profile.id,
        routeId: profile.networkRouteRef,
        providerInstanceId: 'provider-1',
        generation: 1,
      ));
      // 模拟进程被系统杀死：不做任何 stop/清理，直接关闭数据库。
      await store.close();
    }

    // ---- 第二次进程生命周期：重新打开并执行恢复 ----
    {
      final store = await ProfileStore.open(dbPath);
      expect(store.schemaVersion, 3, reason: '重开后 schema 版本保持一致');

      final beforeRecovery = await store.profiles.list();
      expect(beforeRecovery.single.status, ProfileStatus.running,
          reason: '数据库如实保留了崩溃前的持久化状态');

      final recovery = ProfileRecoveryService(
        profileRepository: store.profiles,
        runtimeRepository: store.runtimes,
      );
      final report = await store.runInTransaction(recovery.recover);

      expect(report.recovered.single.previousStatus, ProfileStatus.running);
      final recovered = await store.profiles.list();
      expect(recovered.single.status, ProfileStatus.ready);
      expect(await store.runtimes.loadActive(recovered.single.id), isNull);
      final history = await store.runtimes.listAll(recovered.single.id);
      expect(history.single.status, NetworkRouteStatus.stopped);
      expect(history.single.stoppedAt, isNotNull);

      await store.close();
    }
  });

  test('runInTransaction 中任一步失败则整体回滚', () async {
    final store = await ProfileStore.openInMemory();

    Future<void> failingBatch() async {
      await store.deviceProfiles.save(OppoFindN3Profiles.china);
      await store.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);
      final now = DateTime.utc(2026, 8, 30, 9);
      await store.profiles.save(MobileProfile(
        id: '11111111-1111-4111-8111-111111111111',
        name: '事务内 Profile',
        createdAt: now,
        updatedAt: now,
        browserProfileRef: 'browser-x',
        deviceProfileRef: OppoFindN3Profiles.china.id,
        networkRouteRef: NetworkProviderRegistry.defaultDirectRoute.id,
        status: ProfileStatus.created,
      ));
      // 故意触发约束失败：引用不存在的设备配置。
      await store.profiles.save(MobileProfile(
        id: '22222222-2222-4222-8222-222222222222',
        name: '坏引用 Profile',
        createdAt: now,
        updatedAt: now,
        browserProfileRef: 'browser-y',
        deviceProfileRef: 'device-missing',
        networkRouteRef: NetworkProviderRegistry.defaultDirectRoute.id,
        status: ProfileStatus.created,
      ));
    }

    await expectLater(store.runInTransaction(failingBatch), throwsA(anything));

    // 前面成功的写入也必须一起回滚。
    expect(await store.deviceProfiles.list(), isEmpty);
    expect(await store.networkRoutes.list(), isEmpty);
    expect(await store.profiles.list(), isEmpty);

    await store.close();
  });
}
