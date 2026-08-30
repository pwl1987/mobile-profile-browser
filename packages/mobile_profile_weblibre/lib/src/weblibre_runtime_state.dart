/// WebLibre Runtime 的生命周期状态（技术负责人 M3.3 Task 3 定义）。
enum WebLibreRuntimeState { created, starting, running, stopping, stopped, failed }

final class WebLibreRuntimeStateError implements Exception {
  const WebLibreRuntimeStateError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeStateError: $message';
}

/// Runtime 句柄：只携带标识与状态，不持有 Gecko/Flutter 运行时对象。
final class WebLibreRuntimeHandle {
  const WebLibreRuntimeHandle({
    required this.profileId,
    required this.browserProfileId,
    required this.state,
  });

  final String profileId;
  final String browserProfileId;
  final WebLibreRuntimeState state;

  WebLibreRuntimeHandle withState(WebLibreRuntimeState next) =>
      WebLibreRuntimeHandle(
        profileId: profileId,
        browserProfileId: browserProfileId,
        state: next,
      );
}

/// 状态机约束：
/// ```text
/// created → starting
/// starting → running | failed
/// running → stopping | failed
/// stopping → stopped | failed
/// stopped → starting（重新启动）
/// failed → starting（重试）
/// ```
final class WebLibreRuntimeController {
  WebLibreRuntimeController._();

  static bool canTransition(WebLibreRuntimeState from, WebLibreRuntimeState to) {
    switch (from) {
      case WebLibreRuntimeState.created:
        return to == WebLibreRuntimeState.starting;
      case WebLibreRuntimeState.starting:
        return to == WebLibreRuntimeState.running ||
            to == WebLibreRuntimeState.failed;
      case WebLibreRuntimeState.running:
        return to == WebLibreRuntimeState.stopping ||
            to == WebLibreRuntimeState.failed;
      case WebLibreRuntimeState.stopping:
        return to == WebLibreRuntimeState.stopped ||
            to == WebLibreRuntimeState.failed;
      case WebLibreRuntimeState.stopped:
      case WebLibreRuntimeState.failed:
        return to == WebLibreRuntimeState.starting;
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
