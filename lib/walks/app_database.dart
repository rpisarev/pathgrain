import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  factory AppDatabase({
    required DatabaseFactory databaseFactory,
    required String databasePath,
  }) {
    return AppDatabase._(databaseFactory, databasePath);
  }

  AppDatabase._(this._databaseFactory, this._databasePath);

  static const int schemaVersion = 3;
  static const String fileName = 'pathgrain.sqlite';

  final DatabaseFactory _databaseFactory;
  final String _databasePath;
  Future<Database>? _openingDatabase;

  static Future<AppDatabase> openDefault() async {
    final databasePath = path.join(await getDatabasesPath(), fileName);
    final appDatabase = AppDatabase(
      databaseFactory: databaseFactory,
      databasePath: databasePath,
    );
    await appDatabase.database;
    return appDatabase;
  }

  Future<Database> get database {
    return _openingDatabase ??= _databaseFactory.openDatabase(
      _databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createSurfaceSchema(database);
          if (oldVersion < 3) await _migrateBarefootTaxonomy(database);
        },
      ),
    );
  }

  Future<void> close() async {
    final openingDatabase = _openingDatabase;
    if (openingDatabase == null) {
      return;
    }
    final database = await openingDatabase;
    await database.close();
    _openingDatabase = null;
  }

  static Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE walks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at_ms INTEGER NOT NULL,
        ended_at_ms INTEGER,
        duration_ms INTEGER,
        distance_meters REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL CHECK (
          status IN ('recording', 'completed', 'interrupted')
        )
      )
    ''');
    await database.execute('''
      CREATE TABLE walk_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        walk_id INTEGER NOT NULL,
        sequence INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        recorded_at_ms INTEGER NOT NULL,
        accuracy_meters REAL NOT NULL,
        FOREIGN KEY (walk_id) REFERENCES walks(id) ON DELETE CASCADE,
        UNIQUE (walk_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE INDEX walk_points_walk_sequence
      ON walk_points (walk_id, sequence)
    ''');
    await _createSurfaceSchema(database);
  }

  /// sqflite runs the upgrade callback in one transaction. Durable v2 rows
  /// contain no raw surface tags or correction locale: these three labels
  /// cannot be split honestly. Never consult the disposable OSM cache here.
  static Future<void> _migrateBarefootTaxonomy(Database database) async {
    await database.execute('''
      UPDATE walk_surface_segments
      SET surface = 'unknown', assignment = 'unknown',
          surface_reason = 'legacySurfaceAmbiguous'
      WHERE surface IN ('pavingStones', 'gravel', 'other')
    ''');
    // Keep the observation and its immutable range, even if both layers now
    // say UNKNOWN. Only an explicit Save/Restore can remove that precedence.
    await database.execute('''
      UPDATE walk_surface_corrections
      SET surface = 'unknown'
      WHERE surface IN ('pavingStones', 'gravel', 'other')
    ''');
  }

  static Future<void> _createSurfaceSchema(Database database) async {
    await database.execute('''
      CREATE TABLE walk_surface_analyses (
        walk_id INTEGER PRIMARY KEY REFERENCES walks(id) ON DELETE CASCADE,
        point_count INTEGER NOT NULL CHECK (point_count >= 2),
        points_valid INTEGER NOT NULL DEFAULT 1 CHECK (points_valid IN (0, 1))
      )
    ''');
    await database.execute('''
      CREATE TABLE walk_surface_segments (
        walk_id INTEGER NOT NULL REFERENCES walk_surface_analyses(walk_id)
          ON DELETE CASCADE,
        ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
        start_edge INTEGER NOT NULL CHECK (start_edge >= 0),
        end_edge INTEGER NOT NULL CHECK (end_edge > start_edge),
        surface TEXT NOT NULL,
        assignment TEXT NOT NULL,
        surface_reason TEXT NOT NULL,
        edge_reason TEXT NOT NULL,
        from_feature_key TEXT,
        to_feature_key TEXT,
        PRIMARY KEY (walk_id, ordinal)
      )
    ''');
    await database.execute('''
      CREATE TABLE walk_surface_corrections (
        walk_id INTEGER NOT NULL REFERENCES walk_surface_analyses(walk_id)
          ON DELETE CASCADE,
        start_edge INTEGER NOT NULL CHECK (start_edge >= 0),
        end_edge INTEGER NOT NULL CHECK (end_edge > start_edge),
        surface TEXT NOT NULL,
        PRIMARY KEY (walk_id, start_edge, end_edge)
      )
    ''');
    // Exact point-sequence mutation detection, without geometry copies or hashes.
    // These triggers never modify recorder rows or delete user corrections.
    for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
      final ids = switch (operation) {
        'INSERT' => 'NEW.walk_id',
        'DELETE' => 'OLD.walk_id',
        _ => 'OLD.walk_id, NEW.walk_id',
      };
      await database.execute('''
        CREATE TRIGGER surface_points_${operation.toLowerCase()}
        AFTER $operation ON walk_points
        BEGIN
          UPDATE walk_surface_analyses SET points_valid = 0
          WHERE walk_id IN ($ids);
        END
      ''');
    }
  }
}
