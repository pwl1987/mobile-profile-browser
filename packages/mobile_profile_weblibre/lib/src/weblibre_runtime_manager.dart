import 'dart:async';

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
///
/// 错误语义（ADR-006 fail-closed）：
/// - `bind` 抛错 ⇒ **必须保证未绑定**（实现负责清理半绑定状态）；
/// - `unbind` 抛错 ⇒ **不保证已解绑**——调用方会保留绑定槽位并进入
///   unknown，直到健康检查确认死亡（confirmUnknownDead）。
abstract interface class WebLibreGeckoBinder {
  /// 把本进程绑定到浏览器 Profile。失败必须抛错（不得静默半绑定）。
  Future<void> bind(String browserProfileId, String profileDir);

  /// 解除当前绑定并让 Gecko 退出。抛错不代表已解绑。
  Future<void> unbind(String browserProfileId);
}

final class WebLibreRuntimeBindingError implements Exception {
  const WebLibreRuntimeBindingError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeBindingError: $message';
}

/// 一次进程死亡恢复的结论。
final class RuntimeRecoveryReport {
  const RuntimeRecoveryReport({required this.recoveredSessions});

  /// 被收敛的会话（id + 恢复前的持久化状态）。
  final List<(String sessionId, String previousState)> recoveredSessions;

  bool get isEmpty => recoveredSessions.isEmpty;
}

/// WebLibre Runtime 编排：目录存储 + 进程绑定 + 状态机 + 会话持久化。
///
/// 运行时硬化（ADR-006）：
/// - **操作互斥**：launch/stop/recover/confirm 串行执行，消灭
///   check-then-act 竞态（并发 launch(A)+launch(B) 不可能双双通过槽位检查）；
/// - **fail-closed 解绑**：unbind 失败 → unknown 并**保留槽位**，
///   阻止新 Profile 启动，直到 confirmUnknownDead 确认死亡后释放；
/// - **generation/会话 id**：每次启动 generation 单调 +1；旧 Runtime 的
///   回调必须经 isCurrentSession 校验，过期即丢弃；
/// - **进程死亡恢复**：启动前 STARTING 先落盘，迁移逐次落盘；重启后
///   recoverAfterProcessRestart 把持久化声称存活状态经 unknown 收敛为
///   stopped（新进程内旧 runtime 必死）。
///
/// [sessionStore] 为空时仅工作在内存态（早期测试）；真实接入必须提供。
final class WebLibreRuntimeManager {
  WebLibreRuntimeManager({
    required this.storage,
    required this.binder,
    required String filesDir,
    BrowserRuntimeSessionRepository? sessionStore,
    DateTime Function()? clock,
  })  : _filesDir = filesDir,
        _sessions = sessionStore,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final WebLibreProfileStorage storage;
  final WebLibreGeckoBinder binder;
  final String _filesDir;
  final BrowserRuntimeSessionRepository? _sessions;
  final DateTime Function() _clock;

  WebLibreRuntimeHandle? _bound;
  Future<void> _lock = Future<void>.value();

  /// 当前绑定句柄；未绑定为 null。UI 只订阅状态，不作为真相来源。
  WebLibreRuntimeHandle? get bound => _bound;

  /// 操作互斥：所有状态迁移操作串行排队，错误不阻断后续排队。
  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        completer.complete();
      }
    }();
  }

  Future<WebLibreRuntimeHandle> launch(MobileProfile profile) =>
      _serialized(() async {
        if (_bound != null) {
          throw WebLibreRuntimeBindingError(
              '进程已绑定浏览器 Profile ${_bound!.browserProfileId}'
              '${_bound!.state == WebLibreRuntimeState.unknown ? '（解绑结果未知，需先确认死亡）' : ''}；'
              '切换前必须先 stop（上游 Gecko runtime 一次性绑定约束）');
        }

        final browserProfileId = WebLibreProfileMapper.browserProfileIdOf(profile);
        // 幂等：已存在的目录直接复用（与上游 createNewProfile 语义一致）。
        await storage.create(browserProfileId, name: profile.name);

        // generation 随 Profile 单调递增：旧 Runtime 的迟到回调会被
        // isCurrentSession 拦截，不会污染新会话。
        final previous = await _sessions?.latestForProfile(profile.id);
        final generation = (previous?.generation ?? 0) + 1;
        final now = _clock();
        final session = BrowserRuntimeSession(
          id: 'rs-${ProfileIdentity.newUuidV4()}',
          mobileProfileId: profile.id,
          browserProfileId: browserProfileId,
          state: WebLibreRuntimeState.starting.name,
          generation: generation,
          startedAt: now,
          updatedAt: now,
        );
        // 启动意图先落盘：此窗口内进程死亡会留下 STARTING 待恢复。
        await _sessions?.save(session);

        var handle = WebLibreRuntimeHandle(
          profileId: profile.id,
          browserProfileId: browserProfileId,
          state: WebLibreRuntimeState.created,
          sessionId: session.id,
          generation: generation,
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
          await _sessions?.save(session.copyWith(
            state: WebLibreRuntimeState.running.name,
            updatedAt: _clock(),
          ));
          return handle;
        } catch (error) {
          // Binder 契约：bind 抛错 = 未绑定。释放槽位允许重试。
          handle = WebLibreRuntimeController.transition(
              handle, WebLibreRuntimeState.failed);
          _bound = null;
          await _sessions?.save(session.copyWith(
            state: WebLibreRuntimeState.failed.name,
            updatedAt: _clock(),
          ));
          throw WebLibreRuntimeBindingError(
              'Gecko 绑定失败（${handle.browserProfileId}）: $error');
        }
      });

  Future<WebLibreRuntimeHandle> stop() => _serialized(() async {
        final current = _bound;
        if (current == null) {
          throw const WebLibreRuntimeBindingError('进程当前没有已绑定的浏览器 Profile');
        }

        var handle = WebLibreRuntimeController.transition(
            current, WebLibreRuntimeState.stopping);
        _bound = handle;
        await _persist(current, WebLibreRuntimeState.stopping);

        try {
          await binder.unbind(current.browserProfileId);
          handle = WebLibreRuntimeController.transition(
              handle, WebLibreRuntimeState.stopped);
          _bound = null;
          await _persist(current, WebLibreRuntimeState.stopped);
          return handle;
        } catch (error) {
          // fail-closed（ADR-006）：unbind 失败 ≠ 已解绑。进入 unknown 并
          // 保留绑定槽位，阻止新 Profile 启动，直到健康检查确认死亡。
          handle = WebLibreRuntimeController.transition(
              handle, WebLibreRuntimeState.unknown);
          _bound = handle;
          await _persist(current, WebLibreRuntimeState.unknown);
          throw WebLibreRuntimeBindingError(
              'Gecko 解绑失败（${current.browserProfileId}），解绑结果未知：'
              '槽位保留，新 Profile 启动被阻止；健康检查确认死亡后调用 '
              'confirmUnknownDead 释放。原始错误: $error');
        }
      });

  /// 对 unknown（解绑结果未知）槽位的健康裁决：确认死亡后释放。
  ///
  /// 典型调用时机：健康检查超时/失败、或进程重启后发现持久化 unknown。
  Future<WebLibreRuntimeHandle> confirmUnknownDead() => _serialized(() async {
        final current = _bound;
        if (current == null) {
          throw const WebLibreRuntimeBindingError('进程当前没有已绑定的浏览器 Profile');
        }
        if (current.state != WebLibreRuntimeState.unknown) {
          throw WebLibreRuntimeBindingError(
              '仅 unknown 状态可确认死亡，当前为 ${current.state.name}');
        }
        final handle = WebLibreRuntimeController.transition(
            current, WebLibreRuntimeState.stopped);
        _bound = null;
        await _persist(current, WebLibreRuntimeState.stopped);
        return handle;
      });

  /// 进程死亡恢复（ADR-004/006）：以持久化会话为真相来源。
  ///
  /// 持久化声称存活（starting/running/stopping/unknown）的会话：
  /// 先降级 unknown 落盘，再收敛 stopped（新进程内不存在旧 Gecko
  /// runtime，健康结论恒为死亡）。内存态 `_bound` 同步防御性清理。
  Future<RuntimeRecoveryReport> recoverAfterProcessRestart() =>
      _serialized(() async {
        final recovered = <(String, String)>[];
        final claimed = await _sessions?.findClaimedAlive() ?? const <BrowserRuntimeSession>[];
        for (final session in claimed) {
          await _sessions?.save(session.copyWith(
            state: WebLibreRuntimeState.unknown.name,
            updatedAt: _clock(),
          ));
          await _sessions?.save(session.copyWith(
            state: WebLibreRuntimeState.stopped.name,
            updatedAt: _clock(),
          ));
          recovered.add((session.id, session.state));
        }

        // 内存兜底：无持久化时的旧语义（直接处理 _bound 声称存活）。
        if (_sessions == null) {
          final current = _bound;
          if (current != null &&
              WebLibreRuntimeController.canTransition(
                  current.state, WebLibreRuntimeState.unknown)) {
            var handle = WebLibreRuntimeController.transition(
                current, WebLibreRuntimeState.unknown);
            handle = WebLibreRuntimeController.transition(
                handle, WebLibreRuntimeState.stopped);
            recovered.add((current.sessionId, current.state.name));
            _bound = null;
          }
        } else {
          _bound = null;
        }
        return RuntimeRecoveryReport(recoveredSessions: recovered);
      });

  /// 对 unknown 槽位的健康裁决：确认仍存活（Gecko 仍在响应该 Profile）。
  ///
  /// 回到 running 并继续持有槽位——调用方随后走正常 stop 流程。
  /// 与 [confirmUnknownDead] 一起构成 ADR-006 恢复流程的"仍存活/已死亡"
  /// 两个分支；裁决前 unknown 状态阻止一切新启动。
  Future<WebLibreRuntimeHandle> confirmUnknownAlive() => _serialized(() async {
        final current = _bound;
        if (current == null) {
          throw const WebLibreRuntimeBindingError('进程当前没有已绑定的浏览器 Profile');
        }
        if (current.state != WebLibreRuntimeState.unknown) {
          throw WebLibreRuntimeBindingError(
              '仅 unknown 状态可确认存活，当前为 ${current.state.name}');
        }
        final handle = WebLibreRuntimeController.transition(
            current, WebLibreRuntimeState.running);
        _bound = handle;
        await _persist(current, WebLibreRuntimeState.running);
        return handle;
      });

  /// 旧 Runtime 回调守卫：仅当前活跃会话（id 与 generation 都匹配）的
  /// 回调可被接受，过期回调一律丢弃（防旧回调误杀新会话）。
  bool isCurrentSession(String sessionId, int generation) {
    final current = _bound;
    if (current == null) return false;
    return current.sessionId == sessionId && current.generation == generation;
  }

  Future<void> _persist(
      WebLibreRuntimeHandle handle, WebLibreRuntimeState state) async {
    if (_sessions == null) return;
    final session = await _sessions.latestForProfile(handle.profileId);
    if (session == null || session.id != handle.sessionId) return;
    await _sessions.save(session.copyWith(state: state.name, updatedAt: _clock()));
  }
}
