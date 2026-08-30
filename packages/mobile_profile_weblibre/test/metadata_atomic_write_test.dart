import 'dart:convert';
import 'dart:io';

import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const id = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';

/// metadata.json 原子写专项（评审要求永久保留）：
/// 任何可见时刻文件要么完整、要么不存在，绝不出现半文件。
void main() {
  late Directory tempDir;
  late DirectoryWebLibreProfileStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_metadata_atomic_');
    storage = DirectoryWebLibreProfileStorage(tempDir.path);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });

  test('create 后无 .tmp 残留且内容是完整 JSON', () async {
    await storage.create(id, name: '原子性');

    final metadata = File(WebLibreProfilePaths.metadataFile(tempDir.path, id));
    final content = await metadata.readAsString();
    expect(jsonDecode(content), isA<Map<String, dynamic>>());
    expect(await File('${metadata.path}.tmp').exists(), isFalse);
  });

  test('重复 create 不改写既有内容（幂等，不产生半写风险）', () async {
    await storage.create(id, name: '第一次');
    final metadata = File(WebLibreProfilePaths.metadataFile(tempDir.path, id));
    final first = await metadata.readAsString();

    final createdAgain = await storage.create(id, name: '第二次');

    expect(createdAgain, isFalse, reason: '已存在目录返回 false，不触碰内容');
    expect(await metadata.readAsString(), first);
    expect(await File('${metadata.path}.tmp').exists(), isFalse);
  });

  test('残留的 .tmp 是惰性垃圾：不影响存在性判断与再次创建', () async {
    final metadata = File(WebLibreProfilePaths.metadataFile(tempDir.path, id));
    await metadata.parent.create(recursive: true);
    await File('${metadata.path}.tmp').writeAsString('半文件');

    expect(await storage.create(id, name: '清道夫'), isFalse,
        reason: '目录已存在，幂等返回 false');
    // 目录级存在性判断只看目录，不被 .tmp 干扰。
    expect(await storage.exists(id), isTrue);
  });
}
