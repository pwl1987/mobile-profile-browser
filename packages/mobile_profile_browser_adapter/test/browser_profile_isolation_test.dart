import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';
import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

/// M3.2 隔离契约验收（假 runtime 全链路）。
///
/// 口径与技术负责人定义的 M3.2 一致：
///   Profile A 写入 cookie=A → 关闭 → Profile B 打开同一站点
///   → B 读不到 A 的 cookie；反向亦然。
///
/// 本文件在 CI 中以 FakeWebLibreBrowserProfileAdapter 验证**隔离契约与
/// 编排链路**（Profile → 绑定 → 命名空间 → 存储桶）。真机 GeckoView 的
/// 真实 Cookie/Storage 隔离验收在 M3 真机阶段以同一断言结构对
/// WebLibre 适配器执行（OPPO Find N3）。
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

  test('核心场景：A 与 B 的 Cookie / LocalStorage 完全隔离', () async {
    final a = await profiles.create(name: 'Profile A');
    final b = await profiles.create(name: 'Profile B');

    final handleA =
        WebLibreProfileMapper.handleFor((await profiles.findById(a.id))!);
    final handleB =
        WebLibreProfileMapper.handleFor((await profiles.findById(b.id))!);

    // A 打开 → 写入 → 关闭。
    await launch.openBrowserProfile(a.id);
    await adapter.writeCookie(handleA, 'session', 'profile=A');
    await adapter.writeLocalStorage(handleA, 'lastUser', 'A');
    await launch.closeBrowserProfile(a.id);

    // B 打开同一"站点"，读写自己的数据。
    await launch.openBrowserProfile(b.id);
    await adapter.writeCookie(handleB, 'session', 'profile=B');

    expect(await adapter.readCookie(handleB, 'session'), 'profile=B');
    expect(await adapter.readCookie(handleB, 'lastUser'), isNull,
        reason: 'B 不应看到 A 的 LocalStorage');
    expect(await adapter.readCookie(handleA, 'session'), 'profile=A');
    expect(await adapter.readLocalStorage(handleA, 'lastUser'), 'A');
    expect(await adapter.readCookie(handleA, 'session'), isNot('profile=B'));

    // 数据层：绑定与命名空间一一对应。
    final entryA = await store.browserProfiles.findByMobileProfileId(a.id);
    final entryB = await store.browserProfiles.findByMobileProfileId(b.id);
    expect(entryA!.browserProfileId, isNot(entryB!.browserProfileId));
    expect(entryA.storageNamespace, isNot(entryB.storageNamespace));
  });

  test('删除 A 的浏览器 Profile 不影响 B 的数据', () async {
    final a = await profiles.create(name: 'A');
    final b = await profiles.create(name: 'B');
    final handleA =
        WebLibreProfileMapper.handleFor((await profiles.findById(a.id))!);
    final handleB =
        WebLibreProfileMapper.handleFor((await profiles.findById(b.id))!);

    await launch.openBrowserProfile(a.id);
    await launch.openBrowserProfile(b.id);
    await adapter.writeCookie(handleA, 'k', 'A');
    await adapter.writeCookie(handleB, 'k', 'B');

    await launch.deleteBrowserProfile(a.id);

    expect(adapter.storages[handleA.storageNamespace], isNull);
    expect(await adapter.readCookie(handleB, 'k'), 'B');
    expect((await store.browserProfiles.findByMobileProfileId(b.id))!,
        isNotNull);
  });

  test('复制的 Profile 继承不了源 Profile 的浏览数据', () async {
    final source = await profiles.create(name: '源');
    final handleSource =
        WebLibreProfileMapper.handleFor((await profiles.findById(source.id))!);
    await launch.openBrowserProfile(source.id);
    await adapter.writeCookie(handleSource, 'session', 'source');

    final copied = await profiles.copy(source.id);
    final handleCopied =
        WebLibreProfileMapper.handleFor((await profiles.findById(copied.id))!);
    await launch.openBrowserProfile(copied.id);

    expect(await adapter.readCookie(handleCopied, 'session'), isNull,
        reason: '复制产生全新浏览器 Profile，不共享存储');
    expect(await adapter.readCookie(handleSource, 'session'), 'source');
  });

  test('两个 MobileProfile 不能映射到同一浏览器存储命名空间', () async {
    final a = await profiles.create(name: 'A');
    final b = await profiles.create(name: 'B');

    // 篡改 B 的 browserProfileRef 指向 A 的浏览器身份（模拟最危险的配置错误）。
    final now = DateTime.utc(2026, 8, 30, 9);
    final aProfile = (await profiles.findById(a.id))!;
    await store.profiles.save(MobileProfile(
      id: b.id,
      name: 'B',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: aProfile.browserProfileRef,
      deviceProfileRef: aProfile.deviceProfileRef,
      networkRouteRef: aProfile.networkRouteRef,
      status: ProfileStatus.ready,
    ));

    await launch.openBrowserProfile(a.id);
    await expectLater(
      launch.openBrowserProfile(b.id),
      throwsA(anything),
      reason: '适配器必须拒绝跨 Profile 共享存储命名空间',
    );

    // 数据层同样拒绝：UNIQUE 约束挡住第二份绑定。
    final entryA = await store.browserProfiles.findByMobileProfileId(a.id);
    await expectLater(
      store.browserProfiles.save(BrowserProfileEntry(
        mobileProfileId: b.id,
        browserProfileId: entryA!.browserProfileId,
        storageNamespace: entryA.storageNamespace,
        createdAt: now,
      )),
      throwsA(isA<StateError>()),
    );
  });

  test('浏览器 Profile 句柄与绑定持久化后重开数据库仍然一致', () async {
    final a = await profiles.create(name: 'A');
    final entry = await launch.openBrowserProfile(a.id);

    // 通过句柄语义验证（不持有运行时对象），绑定重读一致。
    final reloaded = await store.browserProfiles
        .findByBrowserProfileId(entry.browserProfileId);
    expect(reloaded!.mobileProfileId, a.id);
    expect(reloaded.storageNamespace, entry.storageNamespace);
    expect(
      reloaded.storageNamespace.startsWith('weblibre_profiles/profile-'),
      isTrue,
    );
  });
}
