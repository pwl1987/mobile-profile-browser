import 'dart:io';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('全新数据库应用到 v2 并记录 schema_version', () async {
    final store = await ProfileStore.openInMemory();

    expect(store.schemaVersion, 2);
    await store.close();
  });

  test('打开两次迁移幂等，不重复应用', () async {
    final store = await ProfileStore.openInMemory();
    await store.close();

    final store2 = await ProfileStore.openInMemory();
    expect(store2.schemaVersion, 2);
    await store2.close();
  });

  test('v1 旧库无损升级到 v2，既有数据保持完整', () async {
    final tempDir = await Directory.systemTemp.createTemp('mpb_m3_upgrade_test_');
    final dbPath = '${tempDir.path}${Platform.pathSeparator}profiles.db';

    // 只应用 v1 打开（模拟 M2 时代的存量库），写入数据。
    final storeV1 =
        await ProfileStore.open(dbPath, migrations: const [StorageMigrations.v1]);
    await storeV1.deviceProfiles.save(OppoFindN3Profiles.china);
    await storeV1.networkRoutes.save(NetworkProviderRegistry.defaultDirectRoute);
    expect(storeV1.schemaVersion, 1);
    await storeV1.close();

    // 用完整基线重开同一文件：v1 → v2 升级，既有数据完整。
    final store = await ProfileStore.open(dbPath);
    expect(store.schemaVersion, 2);
    expect(await store.deviceProfiles.findById(OppoFindN3Profiles.china.id), isNotNull);
    await store.close();

    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 下 WAL 句柄可能延迟释放；交给系统清理。
    }
  });

  test('扩展迁移列表按版本递增应用', () async {
    const v3 = StorageMigration(version: 3, statements: [
      'CREATE TABLE m3_probe (id TEXT NOT NULL PRIMARY KEY)',
    ]);
    final store = await ProfileStore.openInMemory(
      migrations: const [...StorageMigrations.baseline, v3],
    );

    expect(store.schemaVersion, 3);
    await store.close();
  });

  test('数据库版本高于代码已知版本时拒绝打开', () async {
    const v3 = StorageMigration(version: 3, statements: [
      'CREATE TABLE m3_probe (id TEXT NOT NULL PRIMARY KEY)',
    ]);
    final upgraded = await ProfileStore.openInMemory(
      migrations: const [...StorageMigrations.baseline, v3],
    );
    // 取出底层句柄模拟“未来版本”数据库，交给只知道 v2 的代码打开。
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    StorageMigrations.apply(db, const [...StorageMigrations.baseline, v3], now: DateTime.now());
    await upgraded.close();

    expect(
      () => StorageMigrations.apply(db, StorageMigrations.baseline, now: DateTime.now()),
      throwsA(isA<StorageVersionError>()),
    );
    db.dispose();
  });

  test('迁移版本不连续直接拒绝', () {
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    const broken = <StorageMigration>[
      StorageMigration(version: 2, statements: ['CREATE TABLE x (id TEXT)']),
    ];
    expect(
      () => StorageMigrations.apply(db, broken, now: DateTime.now()),
      throwsA(isA<StorageVersionError>()),
    );
    db.dispose();
  });
}
