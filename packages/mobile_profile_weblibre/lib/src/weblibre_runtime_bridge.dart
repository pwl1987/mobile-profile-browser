import 'weblibre_runtime_manager.dart';

/// Dart ↔ Android 运行时桥的通道契约（方法名与参数结构；PR-B.2 修订）。
///
/// 物理通道（Flutter MethodChannel）由应用层注入实现；本接口保持纯
/// Dart，使桥接逻辑可在 CI 中以 Fake channel 全面测试。
/// Android 侧实现（vendor 补丁）属 PR-B.2/B.3。
///
/// 协议（channel 名 `weblibre/runtime_bridge`）：
///
/// | 方法 | 参数 | 返回 |
/// | --- | --- | --- |
/// | bind | browserProfileId, profileDir, sessionId, generation | {result: bound\|restart_required, targetProfile, currentProfile?, pid?} |
/// | unbind | browserProfileId, sessionId, generation | {result: exiting}（应答后进程退出） |
/// | health | browserProfileId | {alive, browserProfileId, sessionId, generation, pid?, observedAt} |
///
/// 事件（EventChannel `weblibre/runtime_bridge/events`）：
/// {event, browserProfileId, sessionId, generation}——Android 回调必须
/// 原样携带 sessionId+generation（双重 fencing，见 isCurrentSession）。
///
/// bind 的两种结局（对应上游"切换=进程重启"模型，禁止运行时 rebind）：
/// - `bound`：本进程已绑定目标 Profile（首次启动路径）；
/// - `restart_required`：当前进程绑定着其他 Profile，已 arm
///   persistNextStartProfile + RestartCoordinator，进程即将重启——
///   上层负责向用户呈现"正在切换浏览环境"并等待重启完成。
abstract interface class WebLibreRuntimeBridgeChannel {
  /// 请求绑定。抛错 = 保证未发起绑定（ADR-006 Binder 契约）。
  Future<Map<String, Object?>> bind({
    required String browserProfileId,
    required String profileDir,
    required String sessionId,
    required int generation,
  });

  /// 请求解绑（退出浏览进程）。抛错 = 不保证已退出（fail-closed）；
  /// 成功返回 {result: 'exiting'} 后进程即将退出，调用方不应再做别的。
  Future<Map<String, Object?>> unbind({
    required String browserProfileId,
    required String sessionId,
    required int generation,
  });

  /// 实时观测 Gecko 状态。**禁止缓存**：observedAt 必须是本次查询完成
  /// 时刻（ADR-007 freshness；healthMaxAge 默认 30s）。
  Future<Map<String, Object?>> health({required String browserProfileId});
}

/// bind 的执行结果（上游无运行时 rebind——切换只能经由进程重启）。
final class WebLibreBindOutcome {
  const WebLibreBindOutcome({
    required this.restartRequired,
    required this.targetProfile,
    this.currentProfile,
    this.pid,
  });

  /// true = 已 arm 重启切换；false = 本进程已绑定目标。
  final bool restartRequired;
  final String targetProfile;
  final String? currentProfile;
  final int? pid;
}

final class WebLibreRuntimeBridgeError implements Exception {
  const WebLibreRuntimeBridgeError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeBridgeError: $message';
}

/// `WebLibreGeckoBinder` 的真实实现（PR-B.1）：经通道契约对接
/// Android/WebLibre 运行时。
///
/// 上游事实（docs/architecture/m3-runtime-bridge.md）：
/// - Gecko runtime 进程级一次性绑定；切换 Profile 的官方途径是
///   persistNextStartProfile + 进程重启（RestartCoordinator）；
/// - 因此 bind/unbind 的 Android 侧实现本质是"提交/退出浏览进程"，
///   health 对应 StartupArbiter.currentState + Gecko runtime 探测。
///
/// 本类只做协议转换与防御性校验，不持有任何业务状态（不知道
/// SQLite/Repository/NetworkRoute——ADR-007 边界）。
final class RealWebLibreGeckoBinder implements WebLibreGeckoBinder {
  RealWebLibreGeckoBinder({required WebLibreRuntimeBridgeChannel channel})
      : _channel = channel;

  final WebLibreRuntimeBridgeChannel _channel;

  @override
  Future<WebLibreBindOutcome> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {
    final raw = await _channel.bind(
      browserProfileId: browserProfileId,
      profileDir: profileDir,
      sessionId: sessionId,
      generation: generation,
    );
    final result = _readString(raw, 'result');
    if (result != 'bound' && result != 'restart_required') {
      throw WebLibreRuntimeBridgeError(
          'bind.result 必须是 bound 或 restart_required，实际: $result');
    }
    return WebLibreBindOutcome(
      restartRequired: result == 'restart_required',
      targetProfile: _readString(raw, 'targetProfile'),
      currentProfile:
          raw['currentProfile'] == null ? null : _readString(raw, 'currentProfile'),
      pid: raw['pid'] == null ? null : _readInt(raw, 'pid'),
    );
  }

  @override
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  }) async {
    await _channel.unbind(
      browserProfileId: browserProfileId,
      sessionId: sessionId,
      generation: generation,
    );
  }

  @override
  Future<WebLibreRuntimeHealth> health(String browserProfileId) async {
    final raw = await _channel.health(browserProfileId: browserProfileId);
    return WebLibreRuntimeHealth(
      alive: _readBool(raw, 'alive'),
      browserProfileId: _readString(raw, 'browserProfileId'),
      sessionId: raw['sessionId'] == null ? '' : _readString(raw, 'sessionId'),
      generation: raw['generation'] == null ? 0 : _readInt(raw, 'generation'),
      pid: raw['pid'] == null ? null : _readInt(raw, 'pid'),
      observedAt: DateTime.parse(_readString(raw, 'observedAt')).toUtc(),
    );
  }

  static bool _readBool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw WebLibreRuntimeBridgeError('health.$key 必须是布尔值');
    }
    return value;
  }

  static String _readString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw WebLibreRuntimeBridgeError('health.$key 必须是字符串');
    }
    return value;
  }

  static int _readInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw WebLibreRuntimeBridgeError('health.$key 必须是整数');
    }
    return value;
  }
}
