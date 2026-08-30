import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:test/test.dart';

/// 一组同源仓储（同一存储后端）。
final class RepositoryBundle {
  RepositoryBundle({
    required this.profiles,
    required this.bindings,
    required this.deviceProfiles,
    required this.networkRoutes,
    this.onClose,
  });

  final MobileProfileRepository profiles;
  final BrowserProfileRepository bindings;
  final DeviceProfileRepository deviceProfiles;
  final NetworkRouteRepository networkRoutes;
  final Future<void> Function()? onClose;
}

/// 播种测试用到的设备/线路引用。SQLite 有外键约束；内存实现接收
/// 完全相同的输入序列，保证语义对比公平。
Future<void> seedReferences(RepositoryBundle bundle) async {
  for (final id in ['device-a', 'device-b']) {
    await bundle.deviceProfiles.save(DeviceProfile(id: id, name: id));
  }
  for (final id in ['route-a', 'route-b']) {
    await bundle.networkRoutes
        .save(NetworkRoute(id: id, name: id, provider: NetworkProviderKind.direct));
  }
}

/// 内存实现与 SQLite 实现的语义一致性套件（ADR-003）。
///
/// 同一组输入在两个实现上必须产生完全一致的结果——包括"全量替换"
/// 这类曾经分叉过的语义。新增 Repository 实现时必须跑通本套件。
void main() {
  Future<void> runSemantics(
    String label,
    Future<RepositoryBundle> Function() create,
  ) async {
    group('$label 实现', () {
      late RepositoryBundle bundle;

      setUp(() async {
        bundle = await create();
        await seedReferences(bundle);
      });

      tearDown(() async {
        await bundle.onClose?.call();
      });

      test('save 全量替换：引用字段改写必须生效（回归 upsert 分叉 bug）', () async {
        final now = DateTime.utc(2026, 8, 30, 9);
        final original = MobileProfile(
          id: '11111111-1111-4111-8111-111111111111',
          name: '原名',
          createdAt: now,
          updatedAt: now,
          browserProfileRef: 'browser-0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
          deviceProfileRef: 'device-a',
          networkRouteRef: 'route-a',
          status: ProfileStatus.ready,
          metadata: const <String, String>{'k': 'v1'},
        );
        await bundle.profiles.save(original);
        await bundle.profiles.save(MobileProfile(
          id: original.id,
          name: '改名',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
          browserProfileRef: 'browser-1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d',
          deviceProfileRef: 'device-b',
          networkRouteRef: 'route-b',
          status: ProfileStatus.error,
          metadata: const <String, String>{'k': 'v2'},
        ));

        final loaded = await bundle.profiles.findById(original.id);
        expect(loaded!.name, '改名');
        expect(
          loaded.browserProfileRef,
          'browser-1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d',
          reason: '引用字段改写必须持久化',
        );
        expect(loaded.deviceProfileRef, 'device-b');
        expect(loaded.status, ProfileStatus.error);
        expect(loaded.metadata['k'], 'v2');
      });

      test('save 同 id 是更新不是新增，list 只有一条', () async {
        final now = DateTime.utc(2026, 8, 30, 9);
        MobileProfile build(String name) => MobileProfile(
              id: '11111111-1111-4111-8111-111111111111',
              name: name,
              createdAt: now,
              updatedAt: now,
              browserProfileRef: 'browser-0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b',
              deviceProfileRef: 'device-a',
              networkRouteRef: 'route-a',
              status: ProfileStatus.ready,
            );
        await bundle.profiles.save(build('A'));
        await bundle.profiles.save(build('B'));
        expect((await bundle.profiles.list()).length, 1);
      });

      test('delete 隔离：只影响目标记录', () async {
        final now = DateTime.utc(2026, 8, 30, 9);
        for (final entry in <(String, String)>[
          ('11111111-1111-4111-8111-111111111111', 'A'),
          ('22222222-2222-4222-8222-222222222222', 'B'),
        ]) {
          await bundle.profiles.save(MobileProfile(
            id: entry.$1,
            name: entry.$2,
            createdAt: now,
            updatedAt: now,
            browserProfileRef: 'browser-${entry.$1}',
            deviceProfileRef: 'device-a',
            networkRouteRef: 'route-a',
            status: ProfileStatus.ready,
          ));
        }

        await bundle.profiles.delete('11111111-1111-4111-8111-111111111111');

        expect(
            await bundle.profiles.findById('11111111-1111-4111-8111-111111111111'),
            isNull);
        expect(
            (await bundle.profiles
                    .findById('22222222-2222-4222-8222-222222222222'))!
                .name,
            'B');
      });

      test('绑定唯一性：跨 MobileProfile 复用 browserProfileId 被拒绝', () async {
        final now = DateTime.utc(2026, 8, 30, 9);
        // 先落两条 Profile（满足 SQLite 外键；内存实现无此要求但语义一致）。
        for (final id in [
          '11111111-1111-4111-8111-111111111111',
          '22222222-2222-4222-8222-222222222222',
        ]) {
          await bundle.profiles.save(MobileProfile(
            id: id,
            name: id,
            createdAt: now,
            updatedAt: now,
            browserProfileRef: 'browser-$id',
            deviceProfileRef: 'device-a',
            networkRouteRef: 'route-a',
            status: ProfileStatus.ready,
          ));
        }

        const browserId = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
        BrowserProfileEntry entryFor(String mobileId) => BrowserProfileEntry(
              mobileProfileId: mobileId,
              browserProfileId: browserId,
              storageNamespace: 'weblibre_profiles/profile-$browserId',
              createdAt: now,
            );

        await bundle.bindings
            .save(entryFor('11111111-1111-4111-8111-111111111111'));
        await expectLater(
          bundle.bindings.save(entryFor('22222222-2222-4222-8222-222222222222')),
          throwsA(isA<StateError>()),
        );
      });

      test('排序契约：createdAt 优先，同刻 id 兜底', () async {
        final same = DateTime.utc(2026, 8, 30, 10);
        Future<void> put(String id, DateTime created) => bundle.profiles.save(
              MobileProfile(
                id: id,
                name: id,
                createdAt: created,
                updatedAt: created,
                browserProfileRef: 'browser-$id',
                deviceProfileRef: 'device-a',
                networkRouteRef: 'route-a',
                status: ProfileStatus.ready,
              ),
            );

        await put('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            same.subtract(const Duration(hours: 1)));
        await put('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', same);
        await put('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', same);

        final ordered = await bundle.profiles.list();
        expect(ordered.map((p) => p.id).toList(), <String>[
          'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ]);
      });
    });
  }

  runSemantics('内存', () async => RepositoryBundle(
        profiles: InMemoryMobileProfileRepository(),
        bindings: InMemoryBrowserProfileRepository(),
        deviceProfiles: InMemoryDeviceProfileRepository(),
        networkRoutes: InMemoryNetworkRouteRepository(),
      ));

  runSemantics('SQLite', () async {
    final store = await ProfileStore.openInMemory();
    return RepositoryBundle(
      profiles: store.profiles,
      bindings: store.browserProfiles,
      deviceProfiles: store.deviceProfiles,
      networkRoutes: store.networkRoutes,
      onClose: store.close,
    );
  });
}
