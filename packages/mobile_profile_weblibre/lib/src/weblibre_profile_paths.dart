import 'package:mobile_profile_browser_adapter/mobile_profile_browser_adapter.dart';

/// WebLibre 浏览器 Profile 的真实目录布局（镜像上游 utils/filesystem.dart）。
///
/// 上游事实（vendor/weblibre b4721ae6）：
/// - profilesDirName = 'weblibre_profiles'，profileDirPrefix = 'profile-'；
/// - Profile 目录：`{filesDir}/weblibre_profiles/profile-<uuid36>/`；
/// - 元数据文件：目录内 `metadata.json`（上游以 tmp+rename 原子写入）；
/// - Gecko 存储出现在 `{profileDir}/files/mozilla/`（首次绑定时产生）。
///
/// filesDir 由调用方注入（Android 上为应用 filesDir 绝对路径），
/// 本类只做无副作用的路拼与校验。分隔符固定为 '/'：目标平台是
/// Android，且 dart:io 在 Windows 上也接受 '/'。
final class WebLibreProfilePaths {
  WebLibreProfilePaths._();

  static const String metadataFileName = 'metadata.json';
  static const String separator = '/';

  static String profilesRoot(String filesDir) =>
      _join(filesDir, WebLibreProfileMapper.profilesDirName);

  static String profileDir(String filesDir, String browserProfileId) {
    _requireValidId(browserProfileId);
    return _join(
      profilesRoot(filesDir),
      '${WebLibreProfileMapper.profileDirPrefix}$browserProfileId',
    );
  }

  static String metadataFile(String filesDir, String browserProfileId) =>
      _join(profileDir(filesDir, browserProfileId), metadataFileName);

  static String mozillaStorageDir(String filesDir, String browserProfileId) {
    _requireValidId(browserProfileId);
    return <String>[
      profileDir(filesDir, browserProfileId),
      'files',
      'mozilla',
    ].join(separator);
  }

  static void _requireValidId(String browserProfileId) {
    if (!WebLibreProfileMapper.isValidBrowserProfileId(browserProfileId)) {
      throw WebLibreProfileMappingError(
          '浏览器 Profile id 不是合法 UUID: $browserProfileId');
    }
  }

  static String _join(String a, String b) =>
      a.endsWith(separator) ? '$a$b' : '$a$separator$b';
}
