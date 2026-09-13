import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'evidence_assembly.dart';
import 'geographic_cell.dart';

import 'osm_evidence.dart';

export 'evidence_assembly.dart' show CachedEvidence;

abstract interface class EvidenceCache {
  Future<CachedEvidence?> read(String namespace, GeographicCell cell);
  Future<void> write(
    String namespace,
    GeographicCell cell,
    CachedEvidence entry,
  );
}

/// Disposable source data. This database has no walk IDs, foreign keys, or
/// access to the authoritative walks/walk_points database.
class SqliteEvidenceCache implements EvidenceCache {
  SqliteEvidenceCache({
    required DatabaseFactory databaseFactory,
    required String databasePath,
  }) : _factory = databaseFactory,
       _path = databasePath;

  static const fileName = 'pathgrain_osm_evidence_cache.sqlite';
  final DatabaseFactory _factory;
  final String _path;
  Future<Database>? _opening;

  static Future<SqliteEvidenceCache> openDefault() async => SqliteEvidenceCache(
    databaseFactory: databaseFactory,
    databasePath: path.join(await getDatabasesPath(), fileName),
  );

  Future<Database> get _database => _opening ??= _factory.openDatabase(
    _path,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (database, _) async {
        await database.execute('''
        CREATE TABLE evidence_cells (
          namespace TEXT NOT NULL,
          cell TEXT NOT NULL,
          fetched_at_ms INTEGER NOT NULL,
          evidence_json TEXT NOT NULL,
          PRIMARY KEY (namespace, cell)
        )
      ''');
      },
    ),
  );

  @override
  Future<CachedEvidence?> read(String namespace, GeographicCell cell) async {
    final database = await _database;
    final rows = await database.query(
      'evidence_cells',
      where: 'namespace = ? AND cell = ?',
      whereArgs: [namespace, cell.key],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CachedEvidence(
      evidence: OsmEvidence.parse(row['evidence_json']! as String),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        row['fetched_at_ms']! as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> write(
    String namespace,
    GeographicCell cell,
    CachedEvidence entry,
  ) async {
    final database = await _database;
    // Atomic replacement only after a complete, successfully parsed response.
    await database.insert('evidence_cells', {
      'namespace': namespace,
      'cell': cell.key,
      'fetched_at_ms': entry.fetchedAt.toUtc().millisecondsSinceEpoch,
      'evidence_json': jsonEncode(entry.evidence.raw),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) await (await opening).close();
    _opening = null;
  }
}
