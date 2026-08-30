import 'dart:io';

import 'package:mobile_profile_weblibre/mobile_profile_weblibre.dart';
import 'package:test/test.dart';

const idA = '0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b';
const idB = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d';

void main() {
  late Directory tempDir;
  late DirectoryWebLibreProfileStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mpb_weblibre_storage_');
    storage = DirectoryWebLibreProfileStorage(tempDir.path);
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 句柄延迟释放；交给系统清理。
    }
  });

  test('create 建立目录与 metadata.json，重复 create 返回 false（上游幂等语义）', () async {
    final first = await storage.create(idA, name: 'Profile A');
    expect(first, isTrue);

    final profileDir = Directory(
      WebLibreProfilePaths.profileDir(tempDir.path, idA),
    );
    expect(await profileDir.exists(), isTrue);
    final metadata = File(
      WebLibreProfilePaths.metadataFile(tempDir.path, idA),
    );
    expect(await metadata.exists(), isTrue);
    expect(await metadata.readAsString(), contains(idA));
    expect(await File('${metadata.path}.tmp').exists(), isFalse,
        reason: '原子写不得残留 .tmp');

    final second = await storage.create(idA, name: 'Profile A');
    expect(second, isFalse);
  });

  test('两个 Profile 目录完全独立（M3 DoD：目录隔离）', () async {
    await storage.create(idA, name: 'A');
    await storage.create(idB, name: 'B');

    final dirA = WebLibreProfilePaths.profileDir(tempDir.path, idA);
    final dirB = WebLibreProfilePaths.profileDir(tempDir.path, idB);
    expect(dirA, isNot(dirB));
    expect(await storage.exists(idA), isTrue);
    expect(await storage.exists(idB), isTrue);
    expect(await storage.listBrowserProfileIds(), containsAll([idA, idB]));
  });

  test('delete 只删除目标 Profile 目录', () async {
    await storage.create(idA, name: 'A');
    await storage.create(idB, name: 'B');

    await storage.delete(idA);

    expect(await storage.exists(idA), isFalse);
    expect(await storage.exists(idB), isTrue);
    expect(await storage.listBrowserProfileIds(), [idB]);
  });
}
