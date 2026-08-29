import 'package:mobile_profile_storage/mobile_profile_storage.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('全新数据库应用 v1 并记录 schema_version', () async {
    final store = await ProfileStore.openInMemory();

    expect(store.schemaVersion, 1);
    await store.close();
  });

  test('打开两次迁移幂等，不重复应用', () async {
    final store = await ProfileStore.openInMemory();
    await store.close();

    final store2 = await ProfileStore.openInMemory();
    expect(store2.schemaVersion, 1);
    await store2.close();
  });

  test('扩展迁移列表按版本递增应用', () async {
    final v2 = StorageMigration(version: 2, statements: [
      'CREATE TABLE m2_probe (id TEXT NOT NULL PRIMARY KEY)',
    ]);
    final store = await ProfileStore.openInMemory(
      migrations: [...StorageMigrations.baseline, v2],
    );

    expect(store.schemaVersion, 2);
    await store.close();
  });

  test('数据库版本高于代码已知版本时拒绝打开', () async {
    final v2 = StorageMigration(version: 2, statements: [
      'CREATE TABLE m2_probe (id TEXT NOT NULL PRIMARY KEY)',
    ]);
    final upgraded = await ProfileStore.openInMemory(
      migrations: [...StorageMigrations.baseline, v2],
    );
    // 取出底层句柄模拟“未来版本”数据库，交给只知道 v1 的代码打开。
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    StorageMigrations.apply(db, [...StorageMigrations.baseline, v2], now: DateTime.now());
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
