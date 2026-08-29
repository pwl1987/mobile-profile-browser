import 'mobile_profile.dart';

final class RuntimeStateTransitionError implements Exception {
  const RuntimeStateTransitionError(this.message);

  final String message;

  @override
  String toString() => 'RuntimeStateTransitionError: $message';
}

/// 对单个 Profile 的运行实例进行状态机约束。
///
/// generation 必须单调递增；旧 runtime 不能覆盖新 runtime 的状态。
final class RuntimeInstanceController {
  RuntimeInstanceController(this.runtime);

  RuntimeInstance runtime;

  void transition(NetworkRouteStatus next) {
    if (!_isAllowed(runtime.status, next)) {
      throw RuntimeStateTransitionError(
        '不允许的状态转换: ${runtime.status} -> $next',
      );
    }

    runtime = RuntimeInstance(
      id: runtime.id,
      profileId: runtime.profileId,
      routeId: runtime.routeId,
      providerInstanceId: runtime.providerInstanceId,
      generation: runtime.generation,
      startedAt: runtime.startedAt,
      stoppedAt: next == NetworkRouteStatus.stopped ? DateTime.now().toUtc() : runtime.stoppedAt,
      status: next,
    );
  }

  static bool isCurrent(RuntimeInstance current, RuntimeInstance candidate) {
    return current.profileId == candidate.profileId &&
        current.id == candidate.id &&
        current.generation == candidate.generation;
  }

  static bool _isAllowed(NetworkRouteStatus from, NetworkRouteStatus to) {
    switch (from) {
      case NetworkRouteStatus.unknown:
        return {
          NetworkRouteStatus.starting,
          NetworkRouteStatus.stopped,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.starting:
        return {
          NetworkRouteStatus.connected,
          NetworkRouteStatus.degraded,
          NetworkRouteStatus.error,
          NetworkRouteStatus.stopping,
        }.contains(to);
      case NetworkRouteStatus.connected:
        return {
          NetworkRouteStatus.degraded,
          NetworkRouteStatus.reconnecting,
          NetworkRouteStatus.stopping,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.degraded:
        return {
          NetworkRouteStatus.connected,
          NetworkRouteStatus.reconnecting,
          NetworkRouteStatus.stopping,
          NetworkRouteStatus.blocked,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.reconnecting:
        return {
          NetworkRouteStatus.connected,
          NetworkRouteStatus.degraded,
          NetworkRouteStatus.blocked,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.stopping:
        return {
          NetworkRouteStatus.stopped,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.stopped:
        return {NetworkRouteStatus.starting}.contains(to);
      case NetworkRouteStatus.blocked:
        return {
          NetworkRouteStatus.reconnecting,
          NetworkRouteStatus.stopping,
          NetworkRouteStatus.error,
        }.contains(to);
      case NetworkRouteStatus.error:
        return {
          NetworkRouteStatus.starting,
          NetworkRouteStatus.stopping,
          NetworkRouteStatus.stopped,
        }.contains(to);
    }
  }
}

final class RuntimeInstanceFactory {
  RuntimeInstanceFactory._();

  static RuntimeInstance create({
    required String profileId,
    required String routeId,
    required String providerInstanceId,
    required int generation,
  }) {
    if (profileId.trim().isEmpty || routeId.trim().isEmpty) {
      throw ArgumentError('profileId 与 routeId 不能为空');
    }
    if (generation < 1) {
      throw ArgumentError.value(generation, 'generation', '必须从 1 开始');
    }

    final now = DateTime.now().toUtc();
    return RuntimeInstance(
      id: 'runtime-${now.microsecondsSinceEpoch}-$generation',
      profileId: profileId,
      routeId: routeId,
      providerInstanceId: providerInstanceId,
      generation: generation,
      startedAt: now,
    );
  }
}
