import 'dart:math';

/// Profile 相关稳定 ID 的生成规则。
///
/// Domain 不引入第三方 uuid 依赖，UUID v4 用加密随机源自行实现，
/// 保证离线可生成、格式可校验、碰撞概率可忽略。
final class ProfileIdentity {
  ProfileIdentity._();

  static final Random _random = Random.secure();

  static const int _uuidV4 = 0x4000; // 版本位
  static const int _rfc4122Variant = 0x8000; // variant 位

  /// 生成小写 UUID v4 字符串。
  static String newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (_uuidV4 >> 8) | (bytes[6] & 0x0F);
    bytes[8] = (_rfc4122Variant >> 8) | (bytes[8] & 0x3F);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// Profile 主键：直接使用 UUID，保证全局唯一且稳定。
  static String newProfileId() => newUuidV4();

  /// 浏览器侧 Profile 引用。M3 起映射到 WebLibre Profile；创建副本时
  /// 必须生成新的引用，为浏览器存储隔离预留边界。
  static String newBrowserProfileRef() => 'browser-${newUuidV4()}';
}
