import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';
import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

void main() {
  late ProfileStore store;
  late FakeWebLibreBrowserProfileAdapter adapter;
  late ProfileLaunchService launch;
  late MobileProfileService profiles;

  setUp(() async {
    store = await ProfileStore.openInMemory();
    adapter = FakeWebLibreBrowserProfileAdapter();
    launch = ProfileLaunchService(
      profileRepository: store.profiles,
      browserProfileRepository: store.browserProfiles,
      adapter: adapter,
    );
    profiles = MobileProfileService(
      profileRepository: store.profiles,
      deviceProfileRepository: store.deviceProfiles,
      networkRouteRepository: store.networkRoutes,
      runtimeRepository: store.runtimes,
    );
  });

  tearDown(() async {
    await store.close();
  });

  test('首次打开建立绑定并创建浏览器 Profile', () async {
    final profile = await profiles.create(name: 'A');
    final entry = await launch.openBrowserProfile(profile.id);

    expect(entry.mobileProfileId, profile.id);
    expect(entry.storageNamespace,
        'weblibre_profiles/profile-${WebLibreProfileMapper.browserProfileIdOf(profile)}');
    expect(entry.lastOpenedAt, isNotNull);
    expect(adapter.storages.keys, contains(entry.storageNamespace));
    expect(
      await store.browserProfiles.findByBrowserProfileId(entry.browserProfileId),
      isNotNull,
    );
  });

  test('重复打开幂等：复用绑定，仅更新 lastOpenedAt', () async {
    var fakeNow = DateTime.utc(2026, 8, 30, 9);
    final clock = () => fakeNow;
    final launchWithClock = ProfileLaunchService(
      profileRepository: store.profiles,
      browserProfileRepository: store.browserProfiles,
      adapter: adapter,
      clock: clock,
    );

    final profile = await profiles.create(name: 'A');
    final first = await launchWithClock.openBrowserProfile(profile.id);
    fakeNow = fakeNow.add(const Duration(minutes: 3));
    final second = await launchWithClock.openBrowserProfile(profile.id);

    expect(second.browserProfileId, first.browserProfileId);
    expect(second.createdAt, first.createdAt);
    expect(second.lastOpenedAt!.isAfter(first.lastOpenedAt!), isTrue);
    expect(adapter.storages.length, 1);
  });

  test('绑定不一致时拒绝打开（引用被外力改写）', () async {
    final profile = await profiles.create(name: 'A');
    await launch.openBrowserProfile(profile.id);

    // 模拟持久化绑定与 profile.browserProfileRef 漂移。
    final now = DateTime.utc(2026, 8, 30, 9);
    await store.browserProfiles.save(BrowserProfileEntry(
      mobileProfileId: profile.id,
      browserProfileId: '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      storageNamespace: 'weblibre_profiles/profile-0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
      createdAt: now,
    ));

    await expectLater(
      launch.openBrowserProfile(profile.id),
      throwsA(isA<ProfileLaunchError>()),
    );
  });

  test('删除浏览器 Profile 清空存储并移除绑定，MobileProfile 保留', () async {
    final profile = await profiles.create(name: 'A');
    final entry = await launch.openBrowserProfile(profile.id);

    await launch.deleteBrowserProfile(profile.id);

    expect(adapter.storages[entry.storageNamespace], isNull);
    expect(await store.browserProfiles.findByMobileProfileId(profile.id), isNull);
    expect(await store.profiles.findById(profile.id), isNotNull);
  });

  test('不存在的 Profile 打开被拒绝', () async {
    await expectLater(
      launch.openBrowserProfile('missing'),
      throwsA(isA<ProfileLaunchError>()),
    );
  });

  test('复制 Profile 得到全新浏览器 Profile 与隔离存储', () async {
    final source = await profiles.create(name: '源');
    final copied = await profiles.copy(source.id);

    final sourceEntry = await launch.openBrowserProfile(source.id);
    final copiedEntry = await launch.openBrowserProfile(copied.id);

    expect(copiedEntry.browserProfileId, isNot(sourceEntry.browserProfileId));
    expect(copiedEntry.storageNamespace, isNot(sourceEntry.storageNamespace));
    expect(adapter.storages.length, 2);
  });
}
