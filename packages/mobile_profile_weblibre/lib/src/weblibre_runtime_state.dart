/// WebLibre Runtime 的生命周期状态（M3.3 定义；unknown 为 ADR-004 进程
/// 死亡恢复状态；restartPending 为 PR-B.2 切换事务状态）。
enum WebLibreRuntimeState {
  created,
  starting,
  running,
  stopping,
  stopped,
  failed,
  unknown,
  restartPending,
}

final class WebLibreRuntimeStateError implements Exception {
  const WebLibreRuntimeStateError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeStateError: $message';
}

/// Runtime 句柄：只携带标识与状态，不持有 Gecko/Flutter 运行时对象。
///
/// [sessionId]/[generation] 标识本次启动对应的持久化会话（ADR-006）：
/// Android 侧回调必须携带同值并经 `isCurrentSession` 校验，过期回调
/// 一律丢弃。未接入会话持久化的早期用法可省略（默认空串/0）。
final class WebLibreRuntimeHandle {
  const WebLibreRuntimeHandle({
    required this.profileId,
    required this.browserProfileId,
    required this.state,
    this.sessionId = '',
    this.generation = 0,
  });

  final String profileId;
  final String browserProfileId;
  final WebLibreRuntimeState state;
  final String sessionId;
  final int generation;

  WebLibreRuntimeHandle withState(WebLibreRuntimeState next) =>
      WebLibreRuntimeHandle(
        profileId: profileId,
        browserProfileId: browserProfileId,
        state: next,
        sessionId: sessionId,
        generation: generation,
      );
}

/// 状态机约束：
/// ```text
/// created → starting
/// starting → running | failed | restartPending
/// running → stopping | failed | unknown
/// stopping → stopped | failed | unknown
/// stopped → starting（重新启动）
/// failed → starting（重试）
/// starting/running/stopping → unknown（进程死亡，知识失效——ADR-004）
/// unknown → running（健康检查证实）| stopped（确认死亡）| failed
/// restartPending → 本进程内终态（进程即将重启，交由下一进程恢复收敛）
/// ```
final class WebLibreRuntimeController {
  WebLibreRuntimeController._();

  static bool canTransition(WebLibreRuntimeState from, WebLibreRuntimeState to) {
    switch (from) {
      case WebLibreRuntimeState.created:
        return to == WebLibreRuntimeState.starting;
      case WebLibreRuntimeState.starting:
        return to == WebLibreRuntimeState.running ||
            to == WebLibreRuntimeState.failed ||
            to == WebLibreRuntimeState.unknown ||
            to == WebLibreRuntimeState.restartPending;
      case WebLibreRuntimeState.running:
        return to == WebLibreRuntimeState.stopping ||
            to == WebLibreRuntimeState.failed ||
            to == WebLibreRuntimeState.unknown;
      case WebLibreRuntimeState.stopping:
        return to == WebLibreRuntimeState.stopped ||
            to == WebLibreRuntimeState.failed ||
            to == WebLibreRuntimeState.unknown;
      case WebLibreRuntimeState.stopped:
      case WebLibreRuntimeState.failed:
        return to == WebLibreRuntimeState.starting;
      case WebLibreRuntimeState.unknown:
        return to == WebLibreRuntimeState.running ||
            to == WebLibreRuntimeState.stopped ||
            to == WebLibreRuntimeState.failed;
      case WebLibreRuntimeState.restartPending:
        // 本进程即将重启；重启是否落地由下一进程的恢复/健康检查裁决，
        // 本进程内不允许任何转出（避免"数据库认为 B 已运行"的漂移）。
        return false;
    }
  }

  static WebLibreRuntimeHandle transition(
      WebLibreRuntimeHandle handle, WebLibreRuntimeState next) {
    if (!canTransition(handle.state, next)) {
      throw WebLibreRuntimeStateError(
          '不允许的状态转换: ${handle.state.name} -> ${next.name}');
    }
    return handle.withState(next);
  }
}
