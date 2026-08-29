import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

void main() {
  late ProfileStore store;
  const profileId = '11111111-1111-4111-8111-111111111111';

  setUp(() async {
    store = await ProfileStore.openInMemory();
    await store.deviceProfiles.save(OppoFindN3Profiles.china);
    await store.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);
    final now = DateTime.utc(2026, 8, 30, 9);
    await store.profiles.save(MobileProfile(
      id: profileId,
      name: '运行时测试',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-x',
      deviceProfileRef: OppoFindN3Profiles.china.id,
      networkRouteRef: NetworkProviderRegistry.defaultDirectRoute.id,
      status: ProfileStatus.running,
    ));
  });

  tearDown(() async {
    await store.close();
  });

  test('保存后成为活动实例，标记 stopped 后不再是活动实例', () async {
    final runtime = RuntimeInstanceFactory.create(
      profileId: profileId,
      routeId: NetworkProviderRegistry.defaultDirectRoute.id,
      providerInstanceId: 'provider-1',
      generation: 1,
    );
    await store.runtimes.save(runtime);

    final active = await store.runtimes.loadActive(profileId);
    expect(active!.id, runtime.id);
    expect(active.generation, 1);

    await store.runtimes.save(RuntimeInstance(
      id: runtime.id,
      profileId: runtime.profileId,
      routeId: runtime.routeId,
      providerInstanceId: runtime.providerInstanceId,
      generation: runtime.generation,
      startedAt: runtime.startedAt,
      stoppedAt: DateTime.utc(2026, 8, 30, 10),
      status: NetworkRouteStatus.stopped,
    ));

    expect(await store.runtimes.loadActive(profileId), isNull);
    // 历史记录仍然可查。
    final history = await store.runtimes.listAll(profileId);
    expect(history.length, 1);
    expect(history.first.status, NetworkRouteStatus.stopped);
    expect(history.first.stoppedAt, isNotNull);
  });

  test('旧 generation 不能覆盖新 generation 的活动状态', () async {
    final newer = RuntimeInstanceFactory.create(
      profileId: profileId,
      routeId: NetworkProviderRegistry.defaultDirectRoute.id,
      providerInstanceId: 'provider-2',
      generation: 2,
    );
    await store.runtimes.save(newer);

    final older = RuntimeInstanceFactory.create(
      profileId: profileId,
      routeId: NetworkProviderRegistry.defaultDirectRoute.id,
      providerInstanceId: 'provider-1',
      generation: 1,
    );
    await expectLater(store.runtimes.save(older), throwsA(isA<StateError>()));

    final active = await store.runtimes.loadActive(profileId);
    expect(active!.generation, 2);
  });

  test('clear 按 runtimeId 精确清理', () async {
    final runtime = RuntimeInstanceFactory.create(
      profileId: profileId,
      routeId: NetworkProviderRegistry.defaultDirectRoute.id,
      providerInstanceId: 'provider-1',
      generation: 1,
    );
    await store.runtimes.save(runtime);

    // 指向不存在的 runtimeId 时不清理。
    await store.runtimes.clear(profileId, runtimeId: 'runtime-other');
    expect(await store.runtimes.loadActive(profileId), isNotNull);

    await store.runtimes.clear(profileId, runtimeId: runtime.id);
    expect(await store.runtimes.loadActive(profileId), isNull);
  });

  test('删除 Profile 级联清理其运行实例记录', () async {
    final runtime = RuntimeInstanceFactory.create(
      profileId: profileId,
      routeId: NetworkProviderRegistry.defaultDirectRoute.id,
      providerInstanceId: 'provider-1',
      generation: 1,
    );
    await store.runtimes.save(runtime);

    await store.profiles.delete(profileId);

    expect(await store.runtimes.listAll(profileId), isEmpty);
    expect(await store.runtimes.loadActive(profileId), isNull);
  });
}
