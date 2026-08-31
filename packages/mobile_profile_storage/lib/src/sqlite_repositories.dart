import 'dart:convert';

import 'package:mobile_profile_domain/mobile_profile_domain.dart';
import 'package:sqlite3/sqlite3.dart';

/// 把领域日期统一为 UTC ISO-8601 文本，保证排序与往返稳定。
String _formatDate(DateTime value) => value.toUtc().toIso8601String();

DateTime _parseDate(String value) => DateTime.parse(value).toUtc();

Map<String, String> _decodeMetadata(String source) {
  if (source.trim().isEmpty) return const <String, String>{};
  final value = jsonDecode(source);
  if (value is! Map) {
    throw const FormatException('profile.metadata 必须是 JSON 对象');
  }
  return value.map((k, v) => MapEntry(k as String, v as String));
}

final class SqliteMobileProfileRepository implements MobileProfileRepository {
  SqliteMobileProfileRepository(this._db);

  final Database _db;

  @override
  Future<List<MobileProfile>> list() async {
    final rows = _db.select(
      'SELECT id, name, created_at, updated_at, browser_profile_ref, '
      'device_profile_ref, network_route_ref, status, metadata '
      'FROM profiles ORDER BY created_at, id',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<MobileProfile?> findById(String id) async {
    final rows = _db.select(
      'SELECT id, name, created_at, updated_at, browser_profile_ref, '
      'device_profile_ref, network_route_ref, status, metadata '
      'FROM profiles WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(MobileProfile profile) async {
    if (profile.id.trim().isEmpty) {
      throw ArgumentError.value(profile.id, 'profile.id', '不能为空');
    }
    final stmt = _db.prepare(
      'INSERT INTO profiles (id, name, created_at, updated_at, browser_profile_ref, '
      'device_profile_ref, network_route_ref, status, metadata) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      // 与内存实现的全量替换语义一致：save 覆盖除主键外的全部列。
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, '
      'created_at = excluded.created_at, updated_at = excluded.updated_at, '
      'browser_profile_ref = excluded.browser_profile_ref, '
      'device_profile_ref = excluded.device_profile_ref, '
      'network_route_ref = excluded.network_route_ref, '
      'status = excluded.status, metadata = excluded.metadata',
    );
    try {
      stmt.execute([
        profile.id,
        profile.name,
        _formatDate(profile.createdAt),
        _formatDate(profile.updatedAt),
        profile.browserProfileRef,
        profile.deviceProfileRef,
        profile.networkRouteRef,
        profile.status.name,
        profile.metadata.isEmpty ? '{}' : jsonEncode(profile.metadata),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> delete(String id) async {
    final stmt = _db.prepare('DELETE FROM profiles WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
  }

  static MobileProfile _fromRow(Row row) {
    final metadataRaw = row['metadata'] as String;
    return MobileProfile(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: _parseDate(row['created_at'] as String),
      updatedAt: _parseDate(row['updated_at'] as String),
      browserProfileRef: row['browser_profile_ref'] as String,
      deviceProfileRef: row['device_profile_ref'] as String,
      networkRouteRef: row['network_route_ref'] as String,
      status: ProfileStatus.values.byName(row['status'] as String),
      metadata: _decodeMetadata(metadataRaw),
    );
  }
}

final class SqliteDeviceProfileRepository implements DeviceProfileRepository {
  SqliteDeviceProfileRepository(this._db);

  final Database _db;

  @override
  Future<List<DeviceProfile>> list() async {
    final rows = _db.select('SELECT document FROM device_profiles ORDER BY id');
    return rows.map((r) => ProfileCodec.decodeDevice(r['document'] as String))
        .toList(growable: false);
  }

  @override
  Future<DeviceProfile?> findById(String id) async {
    final rows = _db.select(
      'SELECT document FROM device_profiles WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : ProfileCodec.decodeDevice(rows.first['document'] as String);
  }

  @override
  Future<void> save(DeviceProfile profile) async {
    if (profile.id.trim().isEmpty) {
      throw ArgumentError.value(profile.id, 'deviceProfile.id', '不能为空');
    }
    final stmt = _db.prepare(
      'INSERT INTO device_profiles (id, name, document) VALUES (?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, document = excluded.document',
    );
    try {
      stmt.execute([profile.id, profile.name, ProfileCodec.encodeDevice(profile)]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> delete(String id) async {
    final stmt = _db.prepare('DELETE FROM device_profiles WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
  }
}

final class SqliteNetworkRouteRepository implements NetworkRouteRepository {
  SqliteNetworkRouteRepository(this._db);

  final Database _db;

  @override
  Future<List<NetworkRoute>> list() async {
    final rows = _db.select('SELECT document FROM network_routes ORDER BY id');
    return rows.map((r) => ProfileCodec.decodeRoute(r['document'] as String))
        .toList(growable: false);
  }

  @override
  Future<NetworkRoute?> findById(String id) async {
    final rows = _db.select('SELECT document FROM network_routes WHERE id = ?', [id]);
    return rows.isEmpty ? null : ProfileCodec.decodeRoute(rows.first['document'] as String);
  }

  @override
  Future<void> save(NetworkRoute route) async {
    if (route.id.trim().isEmpty) {
      throw ArgumentError.value(route.id, 'networkRoute.id', '不能为空');
    }
    final stmt = _db.prepare(
      'INSERT INTO network_routes (id, name, provider, document) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name = excluded.name, '
      'provider = excluded.provider, document = excluded.document',
    );
    try {
      stmt.execute([route.id, route.name, route.provider.name, ProfileCodec.encodeRoute(route)]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> delete(String id) async {
    final stmt = _db.prepare('DELETE FROM network_routes WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
  }
}

final class SqliteActiveRuntimeRepository implements ActiveRuntimeRepository {
  SqliteActiveRuntimeRepository(this._db);

  final Database _db;

  @override
  Future<RuntimeInstance?> loadActive(String profileId) async {
    final rows = _db.select(
      'SELECT id, profile_id, route_id, provider_instance_id, generation, '
      'started_at, stopped_at, status FROM runtime_instances '
      'WHERE profile_id = ? AND stopped_at IS NULL '
      'ORDER BY generation DESC LIMIT 1',
      [profileId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(RuntimeInstance runtime) async {
    final active = await loadActive(runtime.profileId);
    if (active != null &&
        active.id != runtime.id &&
        active.generation > runtime.generation) {
      throw StateError('拒绝旧 runtime 覆盖新 runtime');
    }
    final stmt = _db.prepare(
      'INSERT INTO runtime_instances (id, profile_id, route_id, provider_instance_id, '
      'generation, started_at, stopped_at, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET stopped_at = excluded.stopped_at, '
      'status = excluded.status',
    );
    try {
      stmt.execute([
        runtime.id,
        runtime.profileId,
        runtime.routeId,
        runtime.providerInstanceId,
        runtime.generation,
        _formatDate(runtime.startedAt),
        runtime.stoppedAt == null ? null : _formatDate(runtime.stoppedAt!),
        runtime.status.name,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> clear(String profileId, {String? runtimeId}) async {
    final stmt = runtimeId == null
        ? _db.prepare(
            'UPDATE runtime_instances SET stopped_at = ?, status = ? '
            'WHERE profile_id = ? AND stopped_at IS NULL',
          )
        : _db.prepare(
            'UPDATE runtime_instances SET stopped_at = ?, status = ? '
            'WHERE profile_id = ? AND id = ? AND stopped_at IS NULL',
          );
    try {
      final now = _formatDate(DateTime.now().toUtc());
      if (runtimeId == null) {
        stmt.execute([now, NetworkRouteStatus.stopped.name, profileId]);
      } else {
        stmt.execute([now, NetworkRouteStatus.stopped.name, profileId, runtimeId]);
      }
    } finally {
      stmt.dispose();
    }
  }

  /// 全量历史实例（含已停止），用于审计与测试。
  Future<List<RuntimeInstance>> listAll(String profileId) async {
    final rows = _db.select(
      'SELECT id, profile_id, route_id, provider_instance_id, generation, '
      'started_at, stopped_at, status FROM runtime_instances '
      'WHERE profile_id = ? ORDER BY generation',
      [profileId],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  static RuntimeInstance _fromRow(Row row) {
    final stoppedAt = row['stopped_at'];
    return RuntimeInstance(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      routeId: row['route_id'] as String,
      providerInstanceId: row['provider_instance_id'] as String,
      generation: row['generation'] as int,
      startedAt: _parseDate(row['started_at'] as String),
      stoppedAt: stoppedAt == null ? null : _parseDate(stoppedAt as String),
      status: NetworkRouteStatus.values.byName(row['status'] as String),
    );
  }
}

final class SqliteBrowserProfileRepository implements BrowserProfileRepository {
  SqliteBrowserProfileRepository(this._db);

  final Database _db;

  static const String _columns =
      'mobile_profile_id, browser_profile_id, storage_namespace, created_at, last_opened_at';

  @override
  Future<BrowserProfileEntry?> findByMobileProfileId(String mobileProfileId) async {
    final rows = _db.select(
      'SELECT $_columns FROM browser_profiles WHERE mobile_profile_id = ?',
      [mobileProfileId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<BrowserProfileEntry?> findByBrowserProfileId(String browserProfileId) async {
    final rows = _db.select(
      'SELECT $_columns FROM browser_profiles WHERE browser_profile_id = ?',
      [browserProfileId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(BrowserProfileEntry entry) async {
    final clash = await findByBrowserProfileId(entry.browserProfileId);
    if (clash != null && clash.mobileProfileId != entry.mobileProfileId) {
      throw StateError('浏览器 Profile 已被其他 MobileProfile 绑定: '
          '${entry.browserProfileId}');
    }
    final stmt = _db.prepare(
      'INSERT INTO browser_profiles (mobile_profile_id, browser_profile_id, '
      'storage_namespace, created_at, last_opened_at) VALUES (?, ?, ?, ?, ?) '
      // 与内存实现的全量替换语义一致；browser_profile_id 的 UNIQUE 冲突
      // 已在上方显式拦截。
      'ON CONFLICT(mobile_profile_id) DO UPDATE SET '
      'browser_profile_id = excluded.browser_profile_id, '
      'storage_namespace = excluded.storage_namespace, '
      'created_at = excluded.created_at, '
      'last_opened_at = excluded.last_opened_at',
    );
    try {
      stmt.execute([
        entry.mobileProfileId,
        entry.browserProfileId,
        entry.storageNamespace,
        _formatDate(entry.createdAt),
        entry.lastOpenedAt == null ? null : _formatDate(entry.lastOpenedAt!),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<void> delete(String mobileProfileId) async {
    final stmt = _db.prepare('DELETE FROM browser_profiles WHERE mobile_profile_id = ?');
    try {
      stmt.execute([mobileProfileId]);
    } finally {
      stmt.dispose();
    }
  }

  static BrowserProfileEntry _fromRow(Row row) {
    final lastOpenedAt = row['last_opened_at'];
    return BrowserProfileEntry(
      mobileProfileId: row['mobile_profile_id'] as String,
      browserProfileId: row['browser_profile_id'] as String,
      storageNamespace: row['storage_namespace'] as String,
      createdAt: _parseDate(row['created_at'] as String),
      lastOpenedAt: lastOpenedAt == null ? null : _parseDate(lastOpenedAt as String),
    );
  }
}

final class SqliteBrowserRuntimeSessionRepository
    implements BrowserRuntimeSessionRepository {
  SqliteBrowserRuntimeSessionRepository(this._db);

  final Database _db;

  @override
  Future<BrowserRuntimeSession?> latestForProfile(String mobileProfileId) async {
    final rows = _db.select(
      'SELECT id, mobile_profile_id, browser_profile_id, state, generation, '
      'started_at, updated_at FROM runtime_sessions '
      'WHERE mobile_profile_id = ? ORDER BY generation DESC LIMIT 1',
      [mobileProfileId],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<BrowserRuntimeSession>> findClaimedAlive() async {
    // 集合元素为代码内常量（非外部输入），仍以参数绑定传入。
    final placeholders =
        List.filled(kClaimedAliveSessionStates.length, '?').join(', ');
    final rows = _db.select(
      'SELECT id, mobile_profile_id, browser_profile_id, state, generation, '
      'started_at, updated_at FROM runtime_sessions '
      'WHERE state IN ($placeholders)',
      kClaimedAliveSessionStates.toList(),
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> save(BrowserRuntimeSession session) async {
    final stmt = _db.prepare(
      'INSERT INTO runtime_sessions (id, mobile_profile_id, browser_profile_id, '
      'state, generation, started_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) '
      // 全量替换语义（ADR-003）。
      'ON CONFLICT(id) DO UPDATE SET state = excluded.state, '
      'generation = excluded.generation, started_at = excluded.started_at, '
      'updated_at = excluded.updated_at, '
      'browser_profile_id = excluded.browser_profile_id, '
      'mobile_profile_id = excluded.mobile_profile_id',
    );
    try {
      stmt.execute([
        session.id,
        session.mobileProfileId,
        session.browserProfileId,
        session.state,
        session.generation,
        _formatDate(session.startedAt),
        _formatDate(session.updatedAt),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  @override
  Future<BrowserRuntimeSession> allocateSession({
    required String id,
    required String mobileProfileId,
    required String browserProfileId,
    required String state,
    required DateTime startedAt,
  }) async {
    // ADR-007：generation 的读-算-写必须在一个写事务内完成，
    // 否则并发 Manager 会分配到重复 generation。
    _db.execute('BEGIN IMMEDIATE');
    try {
      final rows = _db.select(
        'SELECT COALESCE(MAX(generation), 0) AS g FROM runtime_sessions '
        'WHERE mobile_profile_id = ?',
        [mobileProfileId],
      );
      final generation = (rows.first['g'] as int) + 1;
      final session = BrowserRuntimeSession(
        id: id,
        mobileProfileId: mobileProfileId,
        browserProfileId: browserProfileId,
        state: state,
        generation: generation,
        startedAt: startedAt,
        updatedAt: startedAt,
      );
      final stmt = _db.prepare(
        'INSERT INTO runtime_sessions (id, mobile_profile_id, browser_profile_id, '
        'state, generation, started_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      );
      try {
        stmt.execute([
          session.id,
          session.mobileProfileId,
          session.browserProfileId,
          session.state,
          session.generation,
          _formatDate(session.startedAt),
          _formatDate(session.updatedAt),
        ]);
      } finally {
        stmt.dispose();
      }
      _db.execute('COMMIT');
      return session;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  static BrowserRuntimeSession _fromRow(Row row) => BrowserRuntimeSession(
        id: row['id'] as String,
        mobileProfileId: row['mobile_profile_id'] as String,
        browserProfileId: row['browser_profile_id'] as String,
        state: row['state'] as String,
        generation: row['generation'] as int,
        startedAt: _parseDate(row['started_at'] as String),
        updatedAt: _parseDate(row['updated_at'] as String),
      );
}
