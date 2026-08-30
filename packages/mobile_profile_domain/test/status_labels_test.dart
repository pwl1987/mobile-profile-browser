import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:test/test.dart';

/// i18n 规范红线：每个枚举值都有中文标签，且标签非空、不等于枚举名
/// （即 UI 不会把内部 enum 直接显示给用户）。
void main() {
  test('ProfileStatus 全量中文标签：完备、非空、不泄漏枚举名', () {
    for (final status in ProfileStatus.values) {
      final label = profileStatusZhLabel(status);
      expect(label.trim().isEmpty, isFalse, reason: '$status 缺少标签');
      expect(label, isNot(status.name), reason: '$status 的标签不得是枚举名');
      expect(kProfileStatusZhLabels.containsKey(status), isTrue);
    }
    expect(profileStatusZhLabel(ProfileStatus.recovering), '正在恢复');
    expect(profileStatusZhLabel(ProfileStatus.unknown), '状态未知');
    expect(profileStatusZhLabel(ProfileStatus.degraded), '状态受限');
  });
}
