import 'dart:async';

import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';
import 'package:mobile_profile_domain/mobile_profile_domain.dart';

import 'weblibre_profile_paths.dart';
import 'weblibre_profile_storage.dart';
import 'weblibre_runtime_state.dart';

/// Gecko 进程绑定契约（真实实现在 Android/Flutter 侧；形状由 ADR-007 冻结）。
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
///
/// 边界（ADR-007）：Binder 只做 Gecko 操作，禁止依赖 SQLite /
/// Repository / NetworkRoute / DeviceProfile。
abstract interface class WebLibreGeckoBinder {
  /// 把本进程绑定到浏览器 Profile。失败必须抛错（不得静默半绑定）。
  ///
  /// [sessionId]/[generation] 是本次启动的会话身份：Android 侧回调
  /// 必须原样携带，供 `isCurrentSession` 校验（防旧回调污染新会话）。
  Future<void> bind(
    String browserProfileId,
    String profileDir, {
    required String sessionId,
    required int generation,
  });

  /// 解除当前绑定并让 Gecko 退出。抛错不代表已解绑。
  Future<void> unbind(
    String browserProfileId, {
    required String sessionId,
    required int generation,
  });

  /// 观测实际真相（ADR-007 第三层）：Gecko 现在到底活没活。
  ///
  /// 这是编排层了解实际运行状态的**唯一途径**；health 同时承载
  /// runtimeInfo（pid、观测时间、Gecko 侧会话身份）。
  Future<WebLibreRuntimeHealth> health(String browserProfileId);
}

/// Gecko 运行时的健康观测结果（health 即 runtimeInfo）。
final class WebLibreRuntimeHealth {
  const WebLibreRuntimeHealth({
    required this.alive,
    required this.browserProfileId,
    required this.observedAt,
    this.sessionId = '',
    this.generation = 0,
    this.pid,
  });

  final bool alive;
  final String browserProfileId;

  /// Gecko 侧记录的会话身份；与编排层当前会话不一致即视为过期观测。
  final String sessionId;
  final int generation;

  /// Android 进程 PID；Binder 接入前可空（ADR-007：无数据来源不造假）。
  final int? pid;
  final DateTime observedAt;
}

final class WebLibreRuntimeBindingError implements Exception {
  const WebLibreRuntimeBindingError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreRuntimeBindingError: $message';
}

/// 一次进程死亡恢复的结论。
final class RuntimeRecoveryReport {
  const RuntimeRecoveryReport({
    required this.recoveredSessions,
    this.rehydratedSessionId,
  });

  /// 被收敛的会话（id + 恢复前的持久化状态）。
  final List<(String sessionId, String previousState)> recoveredSessions;

  /// Dart 重启后重建为 unknown 槽位的会话（ADR-007 Rehydration；无则 null）。
  final String? rehydratedSessionId;

  bool get isEmpty => recoveredSessions.isEmpty && rehydratedSessionId == null;
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
    this.healthMaxAge = const Duration(seconds: 30),
  })  : _filesDir = filesDir,
        _sessions = sessionStore,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final WebLibreProfileStorage storage;
  final WebLibreGeckoBinder binder;
  final String _filesDir;
  final BrowserRuntimeSessionRepository? _sessions;
  final DateTime Function() _clock;

  /// health 观测的新鲜度上限（ADR-007）：超过视为过期观测，fail-closed。
  final Duration healthMaxAge;

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
        final current = _bound;
        if (current != null) {
          throw WebLibreRuntimeBindingError(
            current.state == WebLibreRuntimeState.unknown
                ? '存在 unknown 状态的运行时槽位（${current.browserProfileId}；'
                    '解绑结果未知或 Dart 重启遗留，Gecko 可能仍存活）：'
                    '禁止新启动，先经健康检查裁决'
                    '（resolveUnknownViaHealth / confirmUnknownDead）'
                : '进程已绑定浏览器 Profile ${current.browserProfileId}；'
                    '切换前必须先 stop（上游 Gecko runtime 一次性绑定约束）',
          );
        }

        final browserProfileId = WebLibreProfileMapper.browserProfileIdOf(profile);
        // 幂等：已存在的目录直接复用（与上游 createNewProfile 语义一致）。
        await storage.create(browserProfileId, name: profile.name);

        // ADR-007：generation 由持久化层在事务内原子分配（MAX+1），
        // Manager 禁止自行读后 +1——并发 Manager 交错会分配到重复值。
        // 启动意图随分配一起落盘：此窗口内进程死亡会留下 STARTING 待恢复。
        final session = await _sessions?.allocateSession(
              id: 'rs-${ProfileIdentity.newUuidV4()}',
              mobileProfileId: profile.id,
              browserProfileId: browserProfileId,
              state: WebLibreRuntimeState.starting.name,
              startedAt: _clock(),
            ) ??
            BrowserRuntimeSession(
              id: 'rs-${ProfileIdentity.newUuidV4()}',
              mobileProfileId: profile.id,
              browserProfileId: browserProfileId,
              state: WebLibreRuntimeState.starting.name,
              generation: 1,
              startedAt: _clock(),
              updatedAt: _clock(),
            );

        var handle = WebLibreRuntimeHandle(
          profileId: profile.id,
          browserProfileId: browserProfileId,
          state: WebLibreRuntimeState.created,
          sessionId: session.id,
          generation: session.generation,
        );
        handle = WebLibreRuntimeController.transition(
            handle, WebLibreRuntimeState.starting);
        _bound = handle;

        try {
          await binder.bind(
            browserProfileId,
            WebLibreProfilePaths.profileDir(_filesDir, browserProfileId),
            sessionId: session.id,
            generation: session.generation,
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
          await binder.unbind(
            current.browserProfileId,
            sessionId: current.sessionId,
            generation: current.generation,
          );
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

  /// **应用进程死亡**后的恢复（ADR-007 恢复语义三分之一）。
  ///
  /// 前提（显式声明）：当前 WebLibre 架构下 Gecko 运行于应用进程内，
  /// 进程死 ⇒ Gecko 必死。因此持久化声称存活（starting/running/
  /// stopping/unknown）的会话可以经 unknown 直接收敛 stopped。
  /// **若未来 Gecko 迁移到独立进程，此前提失效，必须改走健康检查路径
  /// （recoverAfterDartRestart + resolveUnknownViaHealth）。**
  Future<RuntimeRecoveryReport> recoverAfterApplicationProcessDeath() =>
      _serialized(() async {
        final recovered = <(String, String)>[];
        final claimed =
            await _sessions?.findClaimedAlive() ?? const <BrowserRuntimeSession>[];
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
        _bound = null;
        return RuntimeRecoveryReport(recoveredSessions: recovered);
      });

  /// **Dart engine 重启、应用进程未死**时的恢复（ADR-007 之二）。
  ///
  /// Gecko 可能仍存活（Flutter engine 重建等），禁止假设死亡：
  /// - 取持久化声称存活会话中**最新**的一条 **Rehydration** 为 unknown
  ///   槽位：继续占用逻辑上的独占绑定槽位、阻止新 launch，裁决交给
  ///   实际真相观测（`resolveUnknownViaHealth` / confirmUnknown*）；
  /// - 其余较旧的声称存活会话按单槽位不变量收敛 stopped——单绑定约束
  ///   下同一时刻至多一个真实运行时，更早的会话必然已死。
  Future<RuntimeRecoveryReport> recoverAfterDartRestart() =>
      _serialized(() async {
        final converged = <(String, String)>[];
        final claimed =
            await _sessions?.findClaimedAlive() ?? const <BrowserRuntimeSession>[];
        if (claimed.isEmpty) {
          _bound = null;
          return const RuntimeRecoveryReport(recoveredSessions: <(String, String)>[]);
        }

        final ordered = [...claimed]..sort((a, b) {
            final byTime = b.updatedAt.compareTo(a.updatedAt);
            if (byTime != 0) return byTime;
            final byGeneration = b.generation.compareTo(a.generation);
            if (byGeneration != 0) return byGeneration;
            return b.id.compareTo(a.id);
          });
        final candidate = ordered.first;

        for (final session in ordered.skip(1)) {
          // 单槽位不变量下较旧会话必死：直接收敛 stopped（P2：无需
          // 经过 unknown 中间写）。
          await _sessions?.save(session.copyWith(
            state: WebLibreRuntimeState.stopped.name,
            updatedAt: _clock(),
          ));
          converged.add((session.id, session.state));
        }

        await _sessions?.save(candidate.copyWith(
          state: WebLibreRuntimeState.unknown.name,
          updatedAt: _clock(),
        ));
        _bound = WebLibreRuntimeHandle(
          profileId: candidate.mobileProfileId,
          browserProfileId: candidate.browserProfileId,
          state: WebLibreRuntimeState.unknown,
          sessionId: candidate.id,
          generation: candidate.generation,
        );
        return RuntimeRecoveryReport(
          recoveredSessions: converged,
          rehydratedSessionId: candidate.id,
        );
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

  /// 用 Binder health（实际真相）自动裁决 unknown 槽位（ADR-007）。
  ///
  /// 可信判定 fail-closed（`_isTrustedHealth`）：alive + browserProfileId
  /// + sessionId + generation + 新鲜度**全部满足**才回 running；
  /// 身份缺失（含 sessionId 为空）、不匹配、观测过期或时钟超前一律
  /// 按 stopped 处理并释放槽位。
  Future<WebLibreRuntimeHandle> resolveUnknownViaHealth() => _serialized(() async {
        final current = _bound;
        if (current == null) {
          throw const WebLibreRuntimeBindingError('进程当前没有已绑定的浏览器 Profile');
        }
        if (current.state != WebLibreRuntimeState.unknown) {
          throw WebLibreRuntimeBindingError(
              '仅 unknown 状态可健康裁决，当前为 ${current.state.name}');
        }
        final health = await binder.health(current.browserProfileId);
        if (_isTrustedHealth(health, current)) {
          final handle = WebLibreRuntimeController.transition(
              current, WebLibreRuntimeState.running);
          _bound = handle;
          await _persist(current, WebLibreRuntimeState.running);
          return handle;
        }
        final handle = WebLibreRuntimeController.transition(
            current, WebLibreRuntimeState.stopped);
        _bound = null;
        await _persist(current, WebLibreRuntimeState.stopped);
        return handle;
      });

  /// health 观测的可信判定（fail-closed，缺一不可）。
  bool _isTrustedHealth(
      WebLibreRuntimeHealth health, WebLibreRuntimeHandle current) {
    if (!health.alive) return false;
    if (health.browserProfileId != current.browserProfileId) return false;
    if (health.sessionId.isEmpty) return false;
    if (health.sessionId != current.sessionId) return false;
    if (health.generation != current.generation) return false;
    final now = _clock();
    if (health.observedAt.isAfter(now)) return false; // 时钟超前不可信
    return !health.observedAt.isBefore(now.subtract(healthMaxAge));
  }

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
