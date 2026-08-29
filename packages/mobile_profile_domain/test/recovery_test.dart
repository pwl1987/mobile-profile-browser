import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

void main() {
  late InMemoryMobileProfileRepository profiles;
  late InMemoryActiveRuntimeRepository runtimes;
  late ProfileRecoveryService recovery;

  setUp(() {
    profiles = InMemoryMobileProfileRepository();
    runtimes = InMemoryActiveRuntimeRepository();
    recovery = ProfileRecoveryService(
      profileRepository: profiles,
      runtimeRepository: runtimes,
      clock: () => DateTime.utc(2026, 8, 30, 12),
    );
  });

  MobileProfile persistProfile(String id, ProfileStatus status) {
    final now = DateTime.utc(2026, 8, 30, 8);
    final profile = MobileProfile(
      id: id,
      name: 'Profile $id',
      createdAt: now,
      updatedAt: now,
      browserProfileRef: 'browser-$id',
      deviceProfileRef: 'device-x',
      networkRouteRef: 'route-x',
      status: status,
    );
    profiles.save(profile);
    return profile;
  }

  test('持久化 running 的 Profile 恢复后回到 ready，活动 runtime 被清理', () async {
    final crashed = persistProfile('p-running', ProfileStatus.running);
    await runtimes.save(RuntimeInstanceFactory.create(
      profileId: 'p-running',
      routeId: 'route-x',
      providerInstanceId: 'provider-1',
      generation: 1,
    ));

    final report = await recovery.recover();

    expect(report.recovered.single.profileId, 'p-running');
    expect(report.recovered.single.previousStatus, ProfileStatus.running);
    final after = await profiles.findById('p-running');
    expect(after!.status, ProfileStatus.ready);
    expect(after.createdAt, crashed.createdAt, reason: '恢复不得改写创建时间');
    expect(await runtimes.loadActive('p-running'), isNull);
  });

  test('starting / stopping / degraded 都被视为声称存活并恢复', () async {
    persistProfile('p-starting', ProfileStatus.starting);
    persistProfile('p-stopping', ProfileStatus.stopping);
    persistProfile('p-degraded', ProfileStatus.degraded);

    final report = await recovery.recover();

    expect(report.recovered.map((r) => r.profileId).toSet(),
        {'p-starting', 'p-stopping', 'p-degraded'});
    for (final id in ['p-starting', 'p-stopping', 'p-degraded']) {
      expect((await profiles.findById(id))!.status, ProfileStatus.ready);
    }
  });

  test('created / ready / error 状态不受恢复影响', () async {
    persistProfile('p-created', ProfileStatus.created);
    persistProfile('p-ready', ProfileStatus.ready);
    persistProfile('p-error', ProfileStatus.error);

    final report = await recovery.recover();

    expect(report.isEmpty, isTrue);
    expect((await profiles.findById('p-created'))!.status, ProfileStatus.created);
    expect((await profiles.findById('p-ready'))!.status, ProfileStatus.ready);
    expect((await profiles.findById('p-error'))!.status, ProfileStatus.error);
  });

  test('没有活动 runtime 的声称存活 Profile 也能完成状态恢复', () async {
    persistProfile('p-orphan', ProfileStatus.running);

    final report = await recovery.recover();

    expect(report.recovered.single.profileId, 'p-orphan');
    expect((await profiles.findById('p-orphan'))!.status, ProfileStatus.ready);
  });

  test('恢复流程经过 unknown 与 recovering 中间状态', () async {
    persistProfile('p-trace', ProfileStatus.running);
    final observed = <ProfileStatus>[];

    final traced = ProfileRecoveryService(
      profileRepository: _TracingProfileRepository(profiles, observed),
      runtimeRepository: runtimes,
      clock: () => DateTime.utc(2026, 8, 30, 12),
    );
    await traced.recover();

    expect(observed, containsAll([ProfileStatus.unknown, ProfileStatus.recovering]));
    expect(observed.last, ProfileStatus.ready);
  });
}

/// 记录每次 save 的状态序列，用于验证恢复中间状态确实被持久化。
final class _TracingProfileRepository implements MobileProfileRepository {
  _TracingProfileRepository(this._inner, this._observed);

  final MobileProfileRepository _inner;
  final List<ProfileStatus> _observed;

  @override
  Future<List<MobileProfile>> list() => _inner.list();

  @override
  Future<MobileProfile?> findById(String id) => _inner.findById(id);

  @override
  Future<void> save(MobileProfile profile) async {
    _observed.add(profile.status);
    await _inner.save(profile);
  }

  @override
  Future<void> delete(String id) => _inner.delete(id);
}
