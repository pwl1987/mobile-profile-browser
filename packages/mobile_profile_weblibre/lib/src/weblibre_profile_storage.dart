import 'dart:convert';
import 'dart:io';

import 'weblibre_profile_paths.dart';

/// WebLibre 浏览器 Profile 目录存储契约。
///
/// 语义对齐上游 `utils/filesystem.dart` 的 `createNewProfile`：
/// - create 在目录已存在时返回 false（幂等探测），否则创建目录并写
///   `metadata.json`（tmp+rename 原子写）；
/// - 真实 Android 侧的最终实现应调用上游 `createNewProfile`（连同上游
///   的 Profile 实体与发现机制）；本实现用于 CI 验证目录语义与编排链路。
abstract interface class WebLibreProfileStorage {
  /// 创建浏览器 Profile 目录；已存在返回 false。
  Future<bool> create(String browserProfileId, {required String name});

  Future<bool> exists(String browserProfileId);

  Future<void> delete(String browserProfileId);

  /// 当前存在的全部浏览器 Profile id（按目录名）。
  Future<List<String>> listBrowserProfileIds();
}

/// 基于真实文件系统的目录存储实现（CI 可验证，Android 同语义）。
final class DirectoryWebLibreProfileStorage implements WebLibreProfileStorage {
  DirectoryWebLibreProfileStorage(this.filesDir);

  /// 应用 filesDir 绝对路径（Android 上由平台注入；测试用临时目录）。
  final String filesDir;

  Directory get _profilesRoot => Directory(WebLibreProfilePaths.profilesRoot(filesDir));

  @override
  Future<bool> create(String browserProfileId, {required String name}) async {
    final profileDir = Directory(
      WebLibreProfilePaths.profileDir(filesDir, browserProfileId),
    );
    if (await profileDir.exists()) {
      return false;
    }
    await profileDir.create(recursive: true);

    // 与上游一致的原子写：先写 .tmp 再 rename；失败时清理残留。
    final file = File(
      WebLibreProfilePaths.metadataFile(filesDir, browserProfileId),
    );
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(
        jsonEncode(<String, Object?>{'id': browserProfileId, 'name': name}),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // 残留 .tmp 无法被发现机制匹配（上游同名规则），无害。
        }
      }
      rethrow;
    }
    return true;
  }

  @override
  Future<bool> exists(String browserProfileId) async {
    return Directory(
      WebLibreProfilePaths.profileDir(filesDir, browserProfileId),
    ).exists();
  }

  @override
  Future<void> delete(String browserProfileId) async {
    final dir = Directory(
      WebLibreProfilePaths.profileDir(filesDir, browserProfileId),
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> listBrowserProfileIds() async {
    final root = _profilesRoot;
    if (!await root.exists()) return const <String>[];
    const prefix = 'profile-';
    final ids = <String>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      // 目录 URI 可能带尾斜杠，此时 pathSegments.last 为空串。
      final segments =
          entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final base = segments.isEmpty ? '' : segments.last;
      if (base.startsWith(prefix)) {
        ids.add(base.substring(prefix.length));
      }
    }
    return ids..sort();
  }
}
