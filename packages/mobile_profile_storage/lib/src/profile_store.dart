import 'package:sqlite3/sqlite3.dart';

import 'migrations.dart';
import 'sqlite_repositories.dart';

/// SQLite 存储门面：负责打开数据库、执行迁移、提供仓储与事务。
///
/// 生命周期：
/// ```dart
/// final store = await ProfileStore.open(path);
/// // 使用 store.profiles / store.deviceProfiles / ...
/// await store.close();
/// ```
///
/// 说明：sqlite3 的 Dart 绑定是同步调用；本类的 API 保持 async 以对齐
/// Domain 契约。接入 Android 应用时，应放在后台 isolate 中执行，避免
/// 阻塞 UI 线程（M3+ 集成时处理）。
final class ProfileStore {
  ProfileStore._(this._db, this._ownsDb);

  final Database _db;
  final bool _ownsDb;

  late final SqliteMobileProfileRepository profiles = SqliteMobileProfileRepository(_db);
  late final SqliteDeviceProfileRepository deviceProfiles = SqliteDeviceProfileRepository(_db);
  late final SqliteNetworkRouteRepository networkRoutes = SqliteNetworkRouteRepository(_db);
  late final SqliteActiveRuntimeRepository runtimes = SqliteActiveRuntimeRepository(_db);

  /// 打开（或创建）指定路径的数据库并应用迁移。
  ///
  /// [migrations] 默认为当前代码的基线迁移；测试可以传入扩展列表验证
  /// 未来版本的升级路径。
  static Future<ProfileStore> open(
    String path, {
    List<StorageMigration> migrations = StorageMigrations.baseline,
  }) async {
    final db = sqlite3.open(path);
    db.execute('PRAGMA foreign_keys = ON');
    try {
      StorageMigrations.apply(db, migrations, now: DateTime.now());
      // WAL 只对磁盘库有意义；内存库保持默认日志模式。
      if (!path.contains(':memory:')) {
        db.execute('PRAGMA journal_mode = WAL');
      }
      return ProfileStore._(db, true);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  /// 打开内存数据库（测试用）。进程关闭即消失。
  static Future<ProfileStore> openInMemory({
    List<StorageMigration> migrations = StorageMigrations.baseline,
  }) async {
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    try {
      StorageMigrations.apply(db, migrations, now: DateTime.now());
      return ProfileStore._(db, true);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  int get schemaVersion => StorageMigrations.databaseVersion(_db);

  /// 在单个事务中执行多步写入；任一步失败则整体回滚。
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = await action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> close() async {
    if (!_ownsDb) return;
    _db.dispose();
  }
}
