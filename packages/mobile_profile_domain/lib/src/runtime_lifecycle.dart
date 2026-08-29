import 'mobile_profile.dart';
import 'repositories.dart';

/// 网络运行时适配接口。
///
/// Android/Gecko/sing-box/SSH 等具体实现都在 Domain 层之外。
abstract interface class NetworkRuntime {
  Future<NetworkRouteStatus> start(RuntimeInstance runtime, NetworkRoute route);
  Future<void> stop(RuntimeInstance runtime);
  Future<NetworkHealth> health(RuntimeInstance runtime);
}

final class RuntimeLifecycleError implements Exception {
  const RuntimeLifecycleError(this.message);

  final String message;

  @override
  String toString() => 'RuntimeLifecycleError: $message';
}

/// 管理一个 Profile 的网络运行实例。
///
/// 规则：
/// - 同一 Profile 同时最多存在一个活动 runtime；
/// - 启动前先持久化 starting 状态，避免进程崩溃后完全失去运行意图；
/// - runtime 启动成功后保存实际状态；
/// - 启动失败时尽可能持久化 error；
/// - 停止时按 runtimeId 精确清理，避免新旧 runtime 互相覆盖。
final class RuntimeLifecycleManager {
  RuntimeLifecycleManager({
    required this.runtimeRepository,
    required this.networkRuntime,
  });

  final ActiveRuntimeRepository runtimeRepository;
  final NetworkRuntime networkRuntime;

  Future<RuntimeInstance> start(
    RuntimeInstance runtime,
    NetworkRoute route,
  ) async {
    final existing = await runtimeRepository.loadActive(runtime.profileId);
    if (existing != null && existing.id != runtime.id) {
      throw const RuntimeLifecycleError('该 Profile 已存在其他活动运行实例');
    }

    var controller = RuntimeInstanceController(runtime);
    controller.transition(NetworkRouteStatus.starting);
    await runtimeRepository.save(controller.runtime);

    try {
      final nextStatus = await networkRuntime.start(controller.runtime, route);
      if (nextStatus != NetworkRouteStatus.connected &&
          nextStatus != NetworkRouteStatus.degraded &&
          nextStatus != NetworkRouteStatus.blocked) {
        throw RuntimeLifecycleError('Provider 返回了不可接受的启动状态: $nextStatus');
      }
      controller.transition(nextStatus);
      await runtimeRepository.save(controller.runtime);
      return controller.runtime;
    } catch (error) {
      try {
        controller.transition(NetworkRouteStatus.error);
        await runtimeRepository.save(controller.runtime);
      } catch (_) {
        // 原始启动异常优先返回；错误持久化失败另行由上层诊断。
      }
      rethrow;
    }
  }

  Future<RuntimeInstance> stop(RuntimeInstance runtime) async {
    var controller = RuntimeInstanceController(runtime);
    if (runtime.status != NetworkRouteStatus.stopping &&
        runtime.status != NetworkRouteStatus.stopped) {
      controller.transition(NetworkRouteStatus.stopping);
      await runtimeRepository.save(controller.runtime);
    }

    try {
      await networkRuntime.stop(runtime);
      if (controller.runtime.status != NetworkRouteStatus.stopped) {
        controller.transition(NetworkRouteStatus.stopped);
        await runtimeRepository.save(controller.runtime);
      }
      await runtimeRepository.clear(runtime.profileId, runtimeId: runtime.id);
      return controller.runtime;
    } catch (error) {
      try {
        controller.transition(NetworkRouteStatus.error);
        await runtimeRepository.save(controller.runtime);
      } catch (_) {
        // 原始停止异常优先返回。
      }
      rethrow;
    }
  }

  Future<NetworkHealth> health(RuntimeInstance runtime) {
    return networkRuntime.health(runtime);
  }
}
