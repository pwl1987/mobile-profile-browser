import 'weblibre_runtime_state.dart';

/// WebLibreRuntimeState → 中文 UI 标签（规范：docs/standards/i18n.md）。
///
/// 领域枚举**绝不直接显示给用户**；failed 在 UI 语境呈现为"启动失败"，
/// unknown 呈现为"状态未知"（ADR-004 进程死亡恢复语义）。
const Map<WebLibreRuntimeState, String> kWebLibreRuntimeStateZhLabels =
    <WebLibreRuntimeState, String>{
  WebLibreRuntimeState.created: '已创建',
  WebLibreRuntimeState.starting: '正在启动',
  WebLibreRuntimeState.running: '运行中',
  WebLibreRuntimeState.stopping: '正在停止',
  WebLibreRuntimeState.stopped: '已停止',
  WebLibreRuntimeState.failed: '启动失败',
  WebLibreRuntimeState.unknown: '状态未知',
};

String webLibreRuntimeStateZhLabel(WebLibreRuntimeState state) {
  final label = kWebLibreRuntimeStateZhLabels[state];
  if (label == null) {
    throw StateError('缺少中文标签的 WebLibreRuntimeState: $state（新增枚举值必须同步映射）');
  }
  return label;
}
