import 'package:sqlite3/sqlite3.dart';

final class StorageVersionError implements Exception {
  const StorageVersionError(this.message);

  final String message;

  @override
  String toString() => 'StorageVersionError: $message';
}

/// 单个 schema 版本的迁移脚本。DDL 为静态语句；所有数据行操作必须使用
/// 参数绑定，禁止把外部输入拼接进 SQL。
final class StorageMigration {
  const StorageMigration({required this.version, required this.statements});

  final int version;
  final List<String> statements;
}

/// 版本化迁移框架。
///
/// - 版本从 1 开始连续递增，只支持向前迁移，不自动降级；
/// - 每个迁移在独立事务中执行，全部成功后才写入 schema_version；
/// - 数据库版本高于代码已知版本时拒绝打开，防止旧代码写坏新库。
final class StorageMigrations {
  const StorageMigrations();

  static const List<StorageMigration> baseline = <StorageMigration>[
    StorageMigration(version: 1, statements: <String>[
      '''
      CREATE TABLE schema_version (
        version INTEGER NOT NULL PRIMARY KEY,
        applied_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE device_profiles (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        document TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE network_routes (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL,
        document TEXT NOT NULL
      )
      ''',
      // browser_profiles 表在 M3 BrowserProfileAdapter 落地时引入；
      // 当前 Profile 的浏览器引用以 browser_profile_ref 列存在。
      '''
      CREATE TABLE profiles (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        browser_profile_ref TEXT NOT NULL,
        device_profile_ref TEXT NOT NULL,
        network_route_ref TEXT NOT NULL,
        status TEXT NOT NULL,
        metadata TEXT NOT NULL DEFAULT '{}',
        CONSTRAINT fk_profiles_device
          FOREIGN KEY (device_profile_ref) REFERENCES device_profiles (id),
        CONSTRAINT fk_profiles_route
          FOREIGN KEY (network_route_ref) REFERENCES network_routes (id)
      )
      ''',
      'CREATE INDEX idx_profiles_order ON profiles (created_at, id)',
      '''
      CREATE TABLE runtime_instances (
        id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL,
        route_id TEXT NOT NULL,
        provider_instance_id TEXT NOT NULL,
        generation INTEGER NOT NULL,
        started_at TEXT NOT NULL,
        stopped_at TEXT,
        status TEXT NOT NULL,
        CONSTRAINT fk_runtime_profile
          FOREIGN KEY (profile_id) REFERENCES profiles (id) ON DELETE CASCADE
      )
      ''',
      'CREATE INDEX idx_runtime_active ON runtime_instances (profile_id, generation)',
    ]),
  ];

  static int databaseVersion(Database db) {
    try {
      final rows = db.select('SELECT COALESCE(MAX(version), 0) AS v FROM schema_version');
      return rows.first['v'] as int;
    } on SqliteException {
      // 全新数据库还没有 schema_version 表。
      return 0;
    }
  }

  static void apply(Database db, List<StorageMigration> migrations, {required DateTime now}) {
    if (migrations.isEmpty) {
      throw const StorageVersionError('迁移列表不能为空');
    }
    for (var expected = 1; expected <= migrations.length; expected++) {
      if (migrations[expected - 1].version != expected) {
        throw StorageVersionError('迁移版本必须从 1 连续递增，当前位置 $expected 实际 '
            '${migrations[expected - 1].version}');
      }
    }

    final current = databaseVersion(db);
    if (current > migrations.length) {
      throw StorageVersionError('数据库 schema 版本 $current 高于代码支持的版本 '
          '${migrations.length}，拒绝打开以避免降级写入');
    }

    for (final migration in migrations) {
      if (migration.version <= current) continue;
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final statement in migration.statements) {
          db.execute(statement);
        }
        final insert = db.prepare(
          'INSERT INTO schema_version (version, applied_at) VALUES (?, ?)',
        );
        try {
          insert.execute([migration.version, now.toUtc().toIso8601String()]);
        } finally {
          insert.dispose();
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }
}
