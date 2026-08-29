import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

void main() {
  late ProfileStore store;

  setUp(() async {
    store = await ProfileStore.openInMemory();
    await store.deviceProfiles.save(OppoFindN3Profiles.china);
    await store.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);
  });

  tearDown(() async {
    await store.close();
  });

  MobileProfile buildProfile(String id, {String name = 'Profile', DateTime? createdAt}) {
    final now = createdAt ?? DateTime.utc(2026, 8, 30, 9);
    return MobileProfile(
      id: id,
      name: name,
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-$id',
      deviceProfileRef: OppoFindN3Profiles.china.id,
      networkRouteRef: NetworkProviderRegistry.defaultDirectRoute.id,
      status: ProfileStatus.created,
      metadata: const <String, String>{'tag': 'm2'},
    );
  }

  test('Profile 全字段往返保持一致（含 metadata 与恢复状态）', () async {
    final original = buildProfile(
      '11111111-1111-4111-8111-111111111111',
      name: '完整字段',
    ).copyWith(status: ProfileStatus.recovering);
    await store.profiles.save(original);

    final loaded = await store.profiles.findById(original.id);

    expect(loaded!.id, original.id);
    expect(loaded.name, original.name);
    expect(loaded.createdAt, original.createdAt);
    expect(loaded.updatedAt, original.updatedAt);
    expect(loaded.browserProfileRef, original.browserProfileRef);
    expect(loaded.deviceProfileRef, original.deviceProfileRef);
    expect(loaded.networkRouteRef, original.networkRouteRef);
    expect(loaded.status, ProfileStatus.recovering);
    expect(loaded.metadata, const <String, String>{'tag': 'm2'});
  });

  test('重复 save 同一 id 是更新而不是新增', () async {
    final a = buildProfile('11111111-1111-4111-8111-111111111111', name: '原名');
    await store.profiles.save(a);
    await store.profiles.save(a.copyWith(name: '改名'));

    final all = await store.profiles.list();
    expect(all.length, 1);
    expect(all.first.name, '改名');
  });

  test('删除一个 Profile 不影响其他 Profile 与共享配置', () async {
    final a = buildProfile('11111111-1111-4111-8111-111111111111', name: 'A');
    final b = buildProfile('22222222-2222-4222-8222-222222222222', name: 'B');
    await store.profiles.save(a);
    await store.profiles.save(b);

    await store.profiles.delete(a.id);

    expect(await store.profiles.findById(a.id), isNull);
    expect((await store.profiles.findById(b.id))!.name, 'B');
    expect(await store.deviceProfiles.findById(OppoFindN3Profiles.china.id), isNotNull);
    expect(
      await store.networkRoutes.findById(NetworkProviderRegistry.defaultDirectRoute.id),
      isNotNull,
    );
  });

  test('排序稳定：createdAt 优先，同刻按 id 兜底', () async {
    final same = DateTime.utc(2026, 8, 30, 10);
    final bFirst = buildProfile('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', createdAt: same);
    final aSecond = buildProfile('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', createdAt: same);
    final earlier = buildProfile(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      createdAt: same.subtract(const Duration(hours: 1)),
    );
    await store.profiles.save(bFirst);
    await store.profiles.save(aSecond);
    await store.profiles.save(earlier);

    final ordered = await store.profiles.list();
    expect(
      ordered.map((p) => p.id).toList(),
      ['cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
       'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'],
    );
  });

  test('外键约束：引用不存在的设备配置被数据库拒绝', () async {
    final now = DateTime.utc(2026, 8, 30, 9);
    // 显式构造坏引用（copyWith 不覆盖引用字段），触发外键拒绝路径。
    final broken = MobileProfile(
      id: '11111111-1111-4111-8111-111111111111',
      name: '坏引用',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-x',
      deviceProfileRef: 'device-missing',
      networkRouteRef: NetworkProviderRegistry.defaultDirectRoute.id,
      status: ProfileStatus.created,
    );

    await expectLater(store.profiles.save(broken), throwsA(anything));
    expect(await store.profiles.list(), isEmpty);
  });
}
