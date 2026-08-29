import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

void main() {
  late ProfileStore store;

  setUp(() async {
    store = await ProfileStore.openInMemory();
  });

  tearDown(() async {
    await store.close();
  });

  test('DeviceProfile 文档往返保持双屏规格', () async {
    await store.deviceProfiles.save(OppoFindN3Profiles.china);

    final loaded = await store.deviceProfiles.findById(OppoFindN3Profiles.china.id);
    expect(loaded!.model, OppoFindN3Profiles.china.model);
    expect(loaded!.regionalModel, OppoFindN3Profiles.china.regionalModel);
    expect(loaded.mainDisplay!.resolutionWidth, 2440);
    expect(loaded.coverDisplay!.resolutionWidth, 2484);
    expect(loaded.hardwareConcurrency, 8);
    expect((await store.deviceProfiles.list()).length, 1);
  });

  test('NetworkRoute 文档往返并保持 provider 列可查', () async {
    await store.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);

    final loaded =
        await store.networkRoutes.findById(NetworkProviderRegistry.defaultDirectRoute.id);
    expect(loaded!.provider, NetworkProviderKind.direct);
    expect(loaded.protocol, ProviderProtocol.none);
    expect(loaded.policy.failClosed, isTrue);
    expect((await store.networkRoutes.list()).length, 1);
  });

  test('save 同 id 的线路是更新而不是新增', () async {
    await store.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);
    final updated = NetworkRoute(
      id: NetworkProviderRegistry.defaultDirectRoute.id,
      name: '默认直连（改名）',
      provider: NetworkProviderKind.direct,
    );
    await store.networkRoutes.save(updated);

    final all = await store.networkRoutes.list();
    expect(all.length, 1);
    expect(all.first.name, '默认直连（改名）');
  });
}
