import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_integration/mobile_profile_integration.dart';

/// WebLibre 浏览器 Profile 身份映射。
///
/// 上游事实（vendor/weblibre b4721ae6）：
/// - `lib/utils/filesystem.dart`：`profilesDirName = 'weblibre_profiles'`、
///   `profileDirPrefix = 'profile-'`；
/// - Profile 目录为 `{filesDir}/weblibre_profiles/profile-<uuid36>/`，
///   Gecko 存储在其中的 `files/mozilla/`；
/// - 上游 `Profile.id` 是可被 `UuidValue.fromString` 解析的 UUID
///   （上游新建用 v7；v4 同样合法）。
///
/// 本映射把 `MobileProfile.browserProfileRef`（形如 `browser-<uuid36>`）
/// 解析为上游浏览器 Profile 身份。常量必须与上游保持一致，升级上游时
/// 需同步核对 `docs/upstream/weblibre.md`。
final class WebLibreProfileMapper {
  WebLibreProfileMapper._();

  static const String profilesDirName = 'weblibre_profiles';
  static const String profileDirPrefix = 'profile-';
  static const String browserRefPrefix = 'browser-';

  /// 与上游路径段规则一致：36 位 UUID（32 hex + 4 连字符）。
  static final RegExp uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidBrowserProfileId(String id) => uuidPattern.hasMatch(id);

  /// 从 browserProfileRef 提取上游浏览器 Profile 的 UUID。
  static String browserProfileIdOf(MobileProfile profile) {
    final ref = profile.browserProfileRef;
    if (!ref.startsWith(browserRefPrefix)) {
      throw const WebLibreProfileMappingError(
          'browserProfileRef 必须以 "browser-" 开头');
    }
    final id = ref.substring(browserRefPrefix.length);
    if (!isValidBrowserProfileId(id)) {
      throw WebLibreProfileMappingError(
          'browserProfileRef 不是合法 UUID: $ref（上游要求 36 位 UUID 目录名）');
    }
    return id;
  }

  /// 浏览器数据目录的相对路径（相对应用 filesDir），不含设备相关绝对前缀。
  static String storageNamespaceOf(String browserProfileId) {
    if (!isValidBrowserProfileId(browserProfileId)) {
      throw WebLibreProfileMappingError('浏览器 Profile id 不是合法 UUID: '
          '$browserProfileId');
    }
    return '$profilesDirName/$profileDirPrefix$browserProfileId';
  }

  /// MobileProfile → 上游浏览器 Profile 句柄。
  static BrowserProfileHandle handleFor(MobileProfile profile) {
    final id = browserProfileIdOf(profile);
    return BrowserProfileHandle(
      id: id,
      storageNamespace: storageNamespaceOf(id),
    );
  }
}

final class WebLibreProfileMappingError implements Exception {
  const WebLibreProfileMappingError(this.message);

  final String message;

  @override
  String toString() => 'WebLibreProfileMappingError: $message';
}
