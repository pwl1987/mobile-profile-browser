import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

void main() {
  test('WebLibreRuntimeState 全量中文标签：完备、非空、不泄漏枚举名', () {
    for (final state in WebLibreRuntimeState.values) {
      final label = webLibreRuntimeStateZhLabel(state);
      expect(label.trim().isEmpty, isFalse, reason: '$state 缺少标签');
      expect(label, isNot(state.name), reason: '$state 的标签不得是枚举名');
      expect(kWebLibreRuntimeStateZhLabels.containsKey(state), isTrue);
    }
    expect(webLibreRuntimeStateZhLabel(WebLibreRuntimeState.failed), '启动失败');
    expect(webLibreRuntimeStateZhLabel(WebLibreRuntimeState.unknown), '状态未知');
  });
}
