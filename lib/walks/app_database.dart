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

  static const int schemaVersion = 1;
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
  }
}
