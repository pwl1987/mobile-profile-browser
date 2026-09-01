import 'weblibre_runtime_manager.dart';

/// Dart ↔ Android 运行时桥的通道契约（方法名与参数结构，PR-B.1 冻结）。
///
/// 物理通道（Flutter MethodChannel / Pigeon）由应用层注入实现；本接口
/// 保持纯 Dart，使桥接逻辑可在 CI 中以 Fake channel 全面测试。
/// Android 侧实现（vendor 补丁）属 PR-B.2/B.3。
///
/// 协议（channel 名建议 `weblibre/runtime_bridge`）：
///
/// | 方法 | 参数 | 返回 |
/// | --- | --- | --- |
/// | bind | browserProfileId, profileDir, sessionId, generation | {pid?} |
/// | unbind | browserProfileId, sessionId, generation | {} |
/// | health | browserProfileId | {alive, browserProfileId, sessionId, generation, pid?, observedAt} |
///
/// 事件（EventChannel `weblibre/runtime_bridge/events`）：
/// {event, browserProfileId, sessionId, generation}——Android 回调必须
/// 原样携带 sessionId+generation（双重 fencing，见 isCurrentSession）。
abstract interface class WebLibreRuntimeBridgeChannel {
  /// 请求绑定。抛错 = 保证未绑定（ADR-006 Binder 契约）。
  Future<Map<String, Object?>> bind({
    required String browserProfileId,
    required String profileDir,
    required String sessionId,
    required int generation,
  });

  /// 请求解绑。抛错 = 不保证已解绑（fail-closed）。
  Future<Map<String, Object?>> unbind({
    required String browserProfileId,
    required String sessionId,
    required int generation,
  });

  /// 实时观测 Gecko 状态。**禁止缓存**：observedAt 必须是本次查询完成
  /// 时刻（ADR-007 freshness；healthMaxAge 默认 30s）。
  Future<Map<String, Object?>> health({required String browserProfileId});
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
  Future<void> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  }) async {
    await _channel.bind(
      browserProfileId: browserProfileId,
      profileDir: profileDir,
      sessionId: sessionId,
      generation: generation,
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
