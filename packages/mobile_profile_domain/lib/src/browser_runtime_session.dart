/// 浏览器 Runtime 会话（一次真实启动生命周期）。
///
/// 进程死亡恢复的持久化真相来源（ADR-006）：启动前先落盘 STARTING，
/// 之后每次状态迁移都落盘；进程被杀后数据库中的声称存活状态
/// （starting/running/stopping/unknown）经恢复流程收敛为 stopped。
///
/// state 以字符串保存（WebLibreRuntimeState.name），领域层不依赖
/// weblibre 包的枚举；claimedAliveStateNames 是跨层共享的判定集合。
final class BrowserRuntimeSession {
  const BrowserRuntimeSession({
    required this.id,
    required this.mobileProfileId,
    required this.browserProfileId,
    required this.state,
    required this.generation,
    required this.startedAt,
    required this.updatedAt,
  });

  final String id;
  final String mobileProfileId;
  final String browserProfileId;
  final String state;
  final int generation;
  final DateTime startedAt;
  final DateTime updatedAt;

  BrowserRuntimeSession copyWith({String? state, DateTime? updatedAt}) =>
      BrowserRuntimeSession(
        id: id,
        mobileProfileId: mobileProfileId,
        browserProfileId: browserProfileId,
        state: state ?? this.state,
        generation: generation,
        startedAt: startedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 声称存活的会话状态集合：进程重启后这些都不可信，必须先降级 unknown
/// 再收敛（禁止直接判 stopped）。restart_pending 是切换事务意图
/// （PR-B.2）：arm 重启后进程死亡，是否落地由下一进程健康检查裁决。
const Set<String> kClaimedAliveSessionStates = <String>{
  'starting',
  'running',
  'stopping',
  'unknown',
  'restart_pending',
};

/// 切换事务意图状态的持久化名（枚举名为驼峰，会话状态约定蛇形）。
const String kRuntimeSessionStateRestartPending = 'restart_pending';

/// Runtime 会话持久化契约。
abstract interface class BrowserRuntimeSessionRepository {
  /// 指定 Profile 最近一次会话（按 generation 最大）。
  Future<BrowserRuntimeSession?> latestForProfile(String mobileProfileId);

  /// 全部处于声称存活状态的会话（进程死亡恢复的输入）。
  Future<List<BrowserRuntimeSession>> findClaimedAlive();

  /// 全量替换语义（与其它仓储契约一致，ADR-003）。
  Future<void> save(BrowserRuntimeSession session);

  /// 原子分配并落盘一个新会话：generation 由持久化层在事务内取
  /// `MAX(generation)+1`（ADR-007）。
  ///
  /// 调用方（Manager）**禁止**自行读 latestForProfile 后 +1——并发
  /// Manager 交错时会分配到重复 generation。初始 state 由调用方传入
  /// （启动意图为 `starting`）。
  Future<BrowserRuntimeSession> allocateSession({
    required String id,
    required String mobileProfileId,
    required String browserProfileId,
    required String state,
    required DateTime startedAt,
  });
}
