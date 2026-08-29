import 'mobile_profile.dart';
import 'repositories.dart';

/// 单个 Profile 的恢复记录。
final class RecoveredProfileRecord {
  const RecoveredProfileRecord({
    required this.profileId,
    required this.previousStatus,
  });

  final String profileId;
  final ProfileStatus previousStatus;
}

/// 一次恢复流程的结果汇总。
final class RecoveryReport {
  const RecoveryReport({required this.recovered});

  final List<RecoveredProfileRecord> recovered;

  bool get isEmpty => recovered.isEmpty;
}

/// 崩溃恢复服务。
///
/// 进程被系统杀死后，持久化的 starting/running/stopping/degraded 状态
/// 不再可信——不存在可以验证的 Runtime 与之对应。恢复流程：
///
/// ```text
/// persisted RUNNING → unknown（承认知识失效）
///                  → recovering（清理中）
///                  → ready（空闲，等待用户重新启动）
/// ```
///
/// 每一步都先落盘再进入下一步：即使恢复过程本身再次被杀死，数据库里
/// 也只会留下 unknown/recovering，绝不会留下伪装成真实运行的 running。
///
/// 恢复只清理 Runtime 记录，不删除 Profile 本体和用户数据。
final class ProfileRecoveryService {
  ProfileRecoveryService({
    required MobileProfileRepository profileRepository,
    required ActiveRuntimeRepository runtimeRepository,
    DateTime Function()? clock,
  })  : _profiles = profileRepository,
        _runtimes = runtimeRepository,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final MobileProfileRepository _profiles;
  final ActiveRuntimeRepository _runtimes;
  final DateTime Function() _clock;

  /// 持久化后声称“正在运行”的状态集合；进程重启后这些都不可信。
  static const Set<ProfileStatus> claimedAlive = <ProfileStatus>{
    ProfileStatus.starting,
    ProfileStatus.running,
    ProfileStatus.stopping,
    ProfileStatus.degraded,
  };

  Future<RecoveryReport> recover() async {
    final recovered = <RecoveredProfileRecord>[];
    for (final profile in await _profiles.list()) {
      if (!claimedAlive.contains(profile.status)) continue;
      final now = _clock();

      await _profiles.save(profile.copyWith(status: ProfileStatus.unknown, updatedAt: now));
      await _profiles.save(profile.copyWith(status: ProfileStatus.recovering, updatedAt: now));

      final active = await _runtimes.loadActive(profile.id);
      if (active != null) {
        await _runtimes.save(RuntimeInstance(
          id: active.id,
          profileId: active.profileId,
          routeId: active.routeId,
          providerInstanceId: active.providerInstanceId,
          generation: active.generation,
          startedAt: active.startedAt,
          stoppedAt: now,
          status: NetworkRouteStatus.stopped,
        ));
        await _runtimes.clear(profile.id, runtimeId: active.id);
      }

      await _profiles.save(profile.copyWith(status: ProfileStatus.ready, updatedAt: now));
      recovered.add(RecoveredProfileRecord(
        profileId: profile.id,
        previousStatus: profile.status,
      ));
    }
    return RecoveryReport(recovered: recovered);
  }
}
