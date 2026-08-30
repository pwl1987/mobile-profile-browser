import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';
import 'package:mobile_profile_domain/mobile_profile_domain.dart';

import 'weblibre_profile_paths.dart';
import 'weblibre_profile_storage.dart';
import 'weblibre_runtime_state.dart';

/// Gecko 进程绑定契约（真实实现在 Android/Flutter 侧）。
///
/// 上游硬约束（vendor/weblibre b4721ae6，core/filesystem.dart）：
/// Gecko runtime 与进程**一次性绑定**，绑定后不能重定向——第二次激活
/// 会让 Dart 与 Gecko 读取不同 Profile 且无法调和。因此一个应用进程
/// 同时最多存在一个已绑定浏览器 Profile；切换必须先 unbind 再 bind。
abstract interface class WebLibreGeckoBinder {
  /// 把本进程绑定到浏览器 Profile。失败必须抛错（不得静默半绑定）。
  Future<void> bind(String browserProfileId, String profileDir);

  /// 解除当前绑定并让 Gecko 退出。
  Future<void> unbind(String browserProfileId);
}

final class WebLibreRuntimeBindingError implements Exception {
  const WebLibreRuntimeBindingError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeBindingError: $message';
}

/// WebLibre Runtime 编排：目录存储 + 进程绑定 + 状态机。
///
/// launch 流程：
/// ```text
/// 校验 browserProfileRef → storage.create（幂等）
///   → created → starting → binder.bind → running
/// 失败 → failed（绑定未成立，可重试）
/// ```
/// stop 流程：`running → stopping → binder.unbind → stopped`，释放
/// 进程绑定槽位。切换 Profile 必须 stop 后再 launch。
///
/// 真机验收（M3.3 Gate）以同一流程对真实 GeckoView 执行。
final class WebLibreRuntimeManager {
  WebLibreRuntimeManager({
    required this.storage,
    required this.binder,
    required String filesDir,
  }) : _filesDir = filesDir;

  final WebLibreProfileStorage storage;
  final WebLibreGeckoBinder binder;
  final String _filesDir;

  WebLibreRuntimeHandle? _bound;

  /// 当前绑定句柄；未绑定为 null。UI 只订阅状态，不作为真相来源。
  WebLibreRuntimeHandle? get bound => _bound;

  Future<WebLibreRuntimeHandle> launch(MobileProfile profile) async {
    if (_bound != null) {
      throw WebLibreRuntimeBindingError(
          '进程已绑定浏览器 Profile ${_bound!.browserProfileId}，'
          '切换前必须先 stop（上游 Gecko runtime 一次性绑定约束）');
    }

    final browserProfileId = WebLibreProfileMapper.browserProfileIdOf(profile);
    // 幂等：已存在的目录直接复用（与上游 createNewProfile 语义一致）。
    await storage.create(browserProfileId, name: profile.name);
    var handle = WebLibreRuntimeHandle(
      profileId: profile.id,
      browserProfileId: browserProfileId,
      state: WebLibreRuntimeState.created,
    );

    handle = WebLibreRuntimeController.transition(
        handle, WebLibreRuntimeState.starting);
    _bound = handle;

    try {
      await binder.bind(
        browserProfileId,
        WebLibreProfilePaths.profileDir(_filesDir, browserProfileId),
      );
      handle = WebLibreRuntimeController.transition(
          handle, WebLibreRuntimeState.running);
      _bound = handle;
      return handle;
    } catch (error) {
      handle = WebLibreRuntimeController.transition(
          handle, WebLibreRuntimeState.failed);
      // 绑定未成立：释放槽位允许重试；failed 状态经异常携带，供上层诊断。
      _bound = null;
      throw WebLibreRuntimeBindingError(
          'Gecko 绑定失败（${handle.browserProfileId}）: $error');
    }
  }

  Future<WebLibreRuntimeHandle> stop() async {
    final current = _bound;
    if (current == null) {
      throw const WebLibreRuntimeBindingError('进程当前没有已绑定的浏览器 Profile');
    }

    var handle = WebLibreRuntimeController.transition(
        current, WebLibreRuntimeState.stopping);
    _bound = handle;
    try {
      await binder.unbind(current.browserProfileId);
      handle = WebLibreRuntimeController.transition(
          handle, WebLibreRuntimeState.stopped);
      _bound = null;
      return handle;
    } catch (error) {
      handle = WebLibreRuntimeController.transition(
          handle, WebLibreRuntimeState.failed);
      _bound = null;
      throw WebLibreRuntimeBindingError('Gecko 解绑失败: $error');
    }
  }

  /// 进程重启后的恢复（ADR-004）：持久化声称 starting/running/stopping
  /// 的句柄不得直接当作真相——先降级 unknown，再收敛。
  ///
  /// 新进程内不存在旧 Gecko runtime，健康检查结论恒为 stopped，
  /// 因此这里不经过外部 binder，直接 unknown → stopped 并释放槽位。
  /// （持久化句柄的接线属于 M4 Runtime 持久化；当前作用于内存态。）
  Future<WebLibreRuntimeHandle?> recoverAfterRestart() async {
    final current = _bound;
    if (current == null) return null;
    switch (current.state) {
      case WebLibreRuntimeState.starting:
      case WebLibreRuntimeState.running:
      case WebLibreRuntimeState.stopping:
        var handle = WebLibreRuntimeController.transition(
            current, WebLibreRuntimeState.unknown);
        handle = WebLibreRuntimeController.transition(
            handle, WebLibreRuntimeState.stopped);
        _bound = null;
        return handle;
      case WebLibreRuntimeState.created:
      case WebLibreRuntimeState.stopped:
      case WebLibreRuntimeState.failed:
      case WebLibreRuntimeState.unknown:
        return current;
    }
  }
}
