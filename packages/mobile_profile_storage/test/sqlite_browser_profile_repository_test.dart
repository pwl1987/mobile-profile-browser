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

  Future<String> seedProfile(String name) async {
    final service = MobileProfileService(
      profileRepository: store.profiles,
      deviceProfileRepository: store.deviceProfiles,
      networkRouteRepository: store.networkRoutes,
      runtimeRepository: store.runtimes,
    );
    final profile = await service.create(name: name);
    return profile.id;
  }

  BrowserProfileEntry entryFor(String mobileProfileId, String browserProfileId) =>
      BrowserProfileEntry(
        mobileProfileId: mobileProfileId,
        browserProfileId: browserProfileId,
        storageNamespace: 'weblibre_profiles/profile-$browserProfileId',
        createdAt: DateTime.utc(2026, 8, 30, 9),
      );

  test('绑定往返保持字段', () async {
    final profileId = await seedProfile('A');
    final entry = entryFor(profileId, '11111111-1111-4111-8111-111111111111')
        .copyWith(lastOpenedAt: DateTime.utc(2026, 8, 30, 10));
    await store.browserProfiles.save(entry);

    final loaded = await store.browserProfiles.findByMobileProfileId(profileId);
    expect(loaded!.browserProfileId, entry.browserProfileId);
    expect(loaded.storageNamespace, contains('weblibre_profiles/profile-'));
    expect(loaded.lastOpenedAt, entry.lastOpenedAt);

    final byBrowser =
        await store.browserProfiles.findByBrowserProfileId(entry.browserProfileId);
    expect(byBrowser!.mobileProfileId, profileId);
  });

  test('同一 browserProfileId 不能绑定到第二个 MobileProfile', () async {
    final a = await seedProfile('A');
    final b = await seedProfile('B');
    const browserId = '11111111-1111-4111-8111-111111111111';
    await store.browserProfiles.save(entryFor(a, browserId));

    await expectLater(
      store.browserProfiles.save(entryFor(b, browserId)),
      throwsA(isA<StateError>()),
    );
  });

  test('删除 MobileProfile 级联删除其浏览器绑定', () async {
    final profileId = await seedProfile('A');
    await store.browserProfiles
        .save(entryFor(profileId, '11111111-1111-4111-8111-111111111111'));

    await store.profiles.delete(profileId);

    expect(await store.browserProfiles.findByMobileProfileId(profileId), isNull);
  });

  test('外键约束：绑定不存在的 MobileProfile 被拒绝', () async {
    await expectLater(
      store.browserProfiles
          .save(entryFor('missing-profile', '11111111-1111-4111-8111-111111111111')),
      throwsA(anything),
    );
  });
}
