import 'mobile_profile.dart';

/// ProfileStatus → 中文 UI 标签（规范：docs/standards/i18n.md）。
///
/// 领域枚举**绝不直接显示给用户**；UI 一律经本映射或 l10n 资源取标签。
/// 注意：ProfileStatus 没有 stopped（空闲态是 ready，见 M2 设计）；
/// stopped 只存在于 WebLibre Runtime 状态。
/// Flutter UI 落地后由 lib/l10n/app_zh.arb 承接同一映射，本表保持为
/// 纯 Dart 层的唯一权威，避免两处漂移。
const Map<ProfileStatus, String> kProfileStatusZhLabels = <ProfileStatus, String>{
  ProfileStatus.created: '已创建',
  ProfileStatus.ready: '就绪',
  ProfileStatus.starting: '正在启动',
  ProfileStatus.running: '运行中',
  ProfileStatus.stopping: '正在停止',
  ProfileStatus.error: '出错',
  ProfileStatus.degraded: '状态受限',
  ProfileStatus.unknown: '状态未知',
  ProfileStatus.recovering: '正在恢复',
};

String profileStatusZhLabel(ProfileStatus status) {
  final label = kProfileStatusZhLabels[status];
  if (label == null) {
    throw StateError('缺少中文标签的 ProfileStatus: $status（新增枚举值必须同步映射）');
  }
  return label;
}
