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
/// 再收敛（禁止直接判 stopped）。
const Set<String> kClaimedAliveSessionStates = <String>{
  'starting',
  'running',
  'stopping',
  'unknown',
};

/// Runtime 会话持久化契约。
abstract interface class BrowserRuntimeSessionRepository {
  /// 指定 Profile 最近一次会话（按 generation 最大）。
  Future<BrowserRuntimeSession?> latestForProfile(String mobileProfileId);

  /// 全部处于声称存活状态的会话（进程死亡恢复的输入）。
  Future<List<BrowserRuntimeSession>> findClaimedAlive();

  /// 全量替换语义（与其它仓储契约一致，ADR-003）。
  Future<void> save(BrowserRuntimeSession session);
}
