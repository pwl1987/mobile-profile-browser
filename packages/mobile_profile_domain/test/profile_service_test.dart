import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryMobileProfileRepository profiles;
  late InMemoryDeviceProfileRepository devices;
  late InMemoryNetworkRouteRepository routes;
  late InMemoryActiveRuntimeRepository runtimes;
  late MobileProfileService service;

  var uuidSequence = 0;
  var fakeNow = DateTime.utc(2026, 8, 30, 9);

  setUp(() {
    profiles = InMemoryMobileProfileRepository();
    devices = InMemoryDeviceProfileRepository();
    routes = InMemoryNetworkRouteRepository();
    runtimes = InMemoryActiveRuntimeRepository();
    uuidSequence = 0;
    fakeNow = DateTime.utc(2026, 8, 30, 9);
    service = MobileProfileService(
      profileRepository: profiles,
      deviceProfileRepository: devices,
      networkRouteRepository: routes,
      runtimeRepository: runtimes,
      uuidGenerator: () => '00000000-0000-4000-8000-0000000000${(uuidSequence++).toString().padLeft(2, '0')}',
      clock: () => fakeNow,
    );
  });

  test('create 生成 UUID 主键、默认引用并落盘', () async {
    final created = await service.create(name: '工作 Profile');

    expect(created.id, '00000000-0000-4000-8000-000000000000');
    expect(created.name, '工作 Profile');
    expect(created.status, ProfileStatus.created);
    expect(created.deviceProfileRef, OppoFindN3Profiles.china.id);
    expect(created.networkRouteRef, NetworkProviderRegistry.defaultDirectRoute.id);
    expect(created.browserProfileRef, startsWith('browser-'));
    expect(created.metadata, isEmpty);

    // 默认设备与线路被引导写入，保证引用完整。
    expect(await devices.findById(OppoFindN3Profiles.china.id), isNotNull);
    expect(await routes.findById(NetworkProviderRegistry.defaultDirectRoute.id), isNotNull);
    expect(await profiles.findById(created.id), isNotNull);
  });

  test('create 拒绝空白名称', () async {
    await expectLater(
      service.create(name: '   '),
      throwsA(isA<ProfileServiceError>()),
    );
    expect(await profiles.list(), isEmpty);
  });

  test('create 显式指定不存在的设备或线路引用会被拒绝', () async {
    await expectLater(
      service.create(name: 'A', deviceProfileId: 'device-missing'),
      throwsA(isA<ProfileServiceError>()),
    );
    await expectLater(
      service.create(name: 'B', networkRouteId: 'route-missing'),
      throwsA(isA<ProfileServiceError>()),
    );
    expect(await profiles.list(), isEmpty);
  });

  test('create 保存传入的 metadata', () async {
    final created = await service.create(
      name: '带备注',
      metadata: const <String, String>{'note': '测试用途', 'order': '2'},
    );
    expect(created.metadata['note'], '测试用途');
    final loaded = await service.findById(created.id);
    expect(loaded!.metadata['order'], '2');
  });

  test('rename 更新名称与 updatedAt，保留 createdAt 与引用', () async {
    final created = await service.create(name: '旧名称');
    fakeNow = fakeNow.add(const Duration(minutes: 5));

    final renamed = await service.rename(created.id, ' 新名称 ');
    expect(renamed.name, '新名称');
    expect(renamed.createdAt, created.createdAt);
    expect(renamed.updatedAt, isNot(created.updatedAt));
    expect(await (await service.findById(created.id))!.name, '新名称');
  });

  test('updateMetadata 整体替换 metadata', () async {
    final created = await service.create(
      name: 'A',
      metadata: const <String, String>{'k': 'v1'},
    );
    final updated = await service.updateMetadata(created.id, const <String, String>{'k': 'v2'});
    expect(updated.metadata, const <String, String>{'k': 'v2'});
  });

  test('delete 只作用于目标 Profile，共享配置不受影响', () async {
    final a = await service.create(name: 'A');
    final b = await service.create(name: 'B');

    await service.delete(a.id);

    expect(await service.findById(a.id), isNull);
    expect((await service.findById(b.id))!.name, 'B');
    // 共享的设备配置与线路仍然存在。
    expect(await devices.findById(b.deviceProfileRef), isNotNull);
    expect(await routes.findById(b.networkRouteRef), isNotNull);
  });

  test('delete 同时清掉该 Profile 的活动 runtime 指针', () async {
    final a = await service.create(name: 'A');
    final runtime = RuntimeInstanceFactory.create(
      profileId: a.id,
      routeId: a.networkRouteRef,
      providerInstanceId: 'provider-1',
      generation: 1,
    );
    await runtimes.save(runtime);

    await service.delete(a.id);

    expect(await runtimes.loadActive(a.id), isNull);
  });

  test('copy 生成全新 id 与 browserProfileRef，共享 device/route 引用', () async {
    final source = await service.create(name: '原始', metadata: const <String, String>{'k': 'v'});
    fakeNow = fakeNow.add(const Duration(minutes: 1));

    final copied = await service.copy(source.id);

    expect(copied.id, isNot(source.id));
    expect(copied.name, '原始 副本');
    expect(copied.browserProfileRef, isNot(source.browserProfileRef));
    expect(copied.deviceProfileRef, source.deviceProfileRef);
    expect(copied.networkRouteRef, source.networkRouteRef);
    expect(copied.status, ProfileStatus.created);
    expect(copied.metadata['k'], 'v');
    expect(copied.createdAt, isNot(source.createdAt));

    // 两个 Profile 同时存在。
    expect((await service.list()).length, 2);
  });

  test('重复 save 同一 id 是更新而不是新增记录', () async {
    final created = await service.create(name: 'A');
    await profiles.save(created.copyWith(name: 'A2'));
    final all = await service.list();
    expect(all.length, 1);
    expect(all.first.name, 'A2');
  });

  test('排序稳定：createdAt 优先，相同时间按 id 兜底', () async {
    final sameMoment = DateTime.utc(2026, 8, 30, 10);
    fakeNow = sameMoment;
    final first = await service.create(name: '同时创建 B'); // uuid ...00
    final second = await service.create(name: '同时创建 A'); // uuid ...01

    fakeNow = sameMoment.subtract(const Duration(hours: 1));
    final earlier = await service.create(name: '更早'); // uuid ...02

    final ordered = await service.list();
    expect(ordered.map((p) => p.name).toList(), ['更早', '同时创建 B', '同时创建 A']);
    expect(ordered[1].id.compareTo(ordered[2].id), lessThan(0));
    expect(ordered[0].id, isNot(first.id));
    expect(ordered[0].name, '更早');
    expect(second.name, '同时创建 A');
    expect(first.name, '同时创建 B');
  });
}
