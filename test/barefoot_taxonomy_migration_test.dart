import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';
import 'package:pathgrain/walks/walk_distance.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

// Serialized v2 values, independent of the current enum and classifier.
const legacySurfaces = [
  'grass',
  'asphalt',
  'concrete',
  'ground',
  'gravel',
  'pavingStones',
  'other',
  'unknown',
];
const legacyCorrections = [
  'asphalt',
  'concrete',
  'ground',
  'grass',
  'pavingStones',
  'other',
  'unknown',
  'gravel',
];
const expectedMigration = {
  'grass': 'grass',
  'asphalt': 'asphalt',
  'concrete': 'concrete',
  'ground': 'ground',
  'gravel': 'unknown',
  'pavingStones': 'unknown',
  'other': 'unknown',
  'unknown': 'unknown',
};
const ambiguous = {'gravel', 'pavingStones', 'other'};

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late String file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp(
      'pathgrain_taxonomy_migration_',
    );
    file = path.join(dir.path, 'v2.sqlite');
  });
  tearDown(() => dir.delete(recursive: true));

  test('real v2 journals migrate every legacy value without changing original data or ranges', () async {
    final old = await createLegacy(file);
    const unchangedTables = [
      'walks',
      'walk_points',
      'walk_surface_analyses',
      'sqlite_sequence',
    ];
    final unchanged = {
      for (final table in unchangedTables)
        table: await old.query(table, orderBy: 'rowid'),
    };
    final segments = await old.query(
      'walk_surface_segments',
      orderBy: 'ordinal',
    );
    final corrections = await old.query(
      'walk_surface_corrections',
      orderBy: 'start_edge',
    );
    final expectedSegments = [
      for (final row in segments)
        {
          ...row,
          if (ambiguous.contains(row['surface'])) ...{
            'surface': 'unknown',
            'assignment': 'unknown',
            'surface_reason': 'legacySurfaceAmbiguous',
          },
        },
    ];
    final expectedCorrections = [
      for (final row in corrections)
        {...row, 'surface': expectedMigration[row['surface']]},
    ];
    await old.close();
    AppDatabase open() =>
        AppDatabase(databaseFactory: databaseFactoryFfi, databasePath: file);
    var app = open();
    addTearDown(() => app.close());
    final db = await app.database;
    expect(await db.getVersion(), 3);
    for (final table in unchangedTables) {
      expect(
        await db.query(table, orderBy: 'rowid'),
        unchanged[table],
        reason: table,
      );
    }
    expect(
      await db.query('walk_surface_segments', orderBy: 'ordinal'),
      expectedSegments,
    );
    expect(
      await db.query('walk_surface_corrections', orderBy: 'start_edge'),
      expectedCorrections,
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    var walks = WalkRepository(app);
    var points = await walks.pointsForWalk(7);
    final migrated = (await walks.surfaces.load(7, points))!;
    expect(migrated.automatic.segments, hasLength(legacySurfaces.length));
    expect(migrated.corrections, hasLength(legacyCorrections.length));
    for (var i = 0; i < legacySurfaces.length; i++) {
      final segment = migrated.automatic.segments[i];
      expect(
        (segment.startEdgeIndex, segment.endEdgeIndex),
        (2 * i, 2 * i + 2),
      );
      expect(
        segment.surface.surface.name,
        expectedMigration[legacySurfaces[i]],
      );
      expect(
        migrated.corrections[i].surface.name,
        expectedMigration[legacyCorrections[i]],
      );
    }
    expect(
      migrated.effective.reconcilesWith(
        (await walks.walkById(7))!.distanceMeters,
      ),
      isTrue,
    );
    // Migration is not an explicit Save: UNKNOWN corrections still have precedence.
    expect(migrated.effective.segments.every((s) => s.isCorrected), isTrue);
    final map = SurfaceRouteGeoJson.build(migrated.effective);
    await app.close();
    app = open();
    walks = WalkRepository(app);
    points = await walks.pointsForWalk(7);
    final reopened = (await walks.surfaces.load(7, points))!;
    expect(SurfaceRouteGeoJson.build(reopened.effective), map);
    expect(
      await (await app.database).query(
        'walk_surface_segments',
        orderBy: 'ordinal',
      ),
      expectedSegments,
    );

    final newAnalysis = WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis(
        List.filled(points.length - 1, CanonicalSurface.tile),
        points: points,
      ),
    );
    final reanalyzed = await walks.surfaces.saveAnalysis(
      7,
      newAnalysis,
      evidenceComplete: true,
    );
    expect(
      await (await app.database).query(
        'walk_surface_corrections',
        orderBy: 'start_edge',
      ),
      expectedCorrections,
    );
    expect(reanalyzed.corrections[4].surface, CanonicalSurface.unknown);
    expect(reanalyzed.corrections[4].startEdgeIndex, 8);
    final restored = await walks.surfaces.restoreAutomatic(
      7,
      points,
      reanalyzed.corrections[4],
    );
    expect(restored.corrections, hasLength(7));
    expect(
      restored.effective.segments
          .singleWhere((s) => s.startEdgeIndex == 8)
          .surface,
      CanonicalSurface.tile,
    );
    // Explicit equality now performs the existing restore semantics.
    final selected = await walks.surfaces.saveCorrection(
      7,
      points,
      const SurfaceCorrection(
        startEdgeIndex: 10,
        endEdgeIndex: 12,
        surface: CanonicalSurface.tile,
      ),
    );
    expect(selected.corrections, hasLength(6));
    final latest = await app.database;
    for (final table in unchangedTables) {
      expect(
        await latest.query(table, orderBy: 'rowid'),
        unchanged[table],
        reason: table,
      );
    }
    await walks.deleteWalk(7);
    for (final table in [
      'walk_points',
      'walk_surface_analyses',
      'walk_surface_segments',
      'walk_surface_corrections',
    ]) {
      expect(await latest.query(table, where: 'walk_id = 7'), isEmpty);
    }
    expect(await walks.walkById(8), isNotNull);
    expect(await walks.walkById(9), isNotNull);
    expect(
      await latest.query('walk_points', where: 'walk_id = 8 OR walk_id = 9'),
      (unchanged['walk_points']!).where((r) => r['walk_id'] != 7).toList(),
    );
    expect(await latest.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('failure migrating corrections rolls back automatic changes and schema version', () async {
    final old = await createLegacy(file);
    final segments = await old.query(
      'walk_surface_segments',
      orderBy: 'ordinal',
    );
    final corrections = await old.query(
      'walk_surface_corrections',
      orderBy: 'start_edge',
    );
    await old.execute('''CREATE TRIGGER fail_taxonomy_migration
      BEFORE UPDATE ON walk_surface_corrections
      BEGIN SELECT RAISE(ABORT, 'Synthetic migration failure'); END''');
    await old.close();
    final app = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: file,
    );
    await expectLater(app.database, throwsA(isA<DatabaseException>()));
    final reopened = await databaseFactoryFfi.openDatabase(file);
    try {
      expect(await reopened.getVersion(), 2);
      expect(
        await reopened.query('walk_surface_segments', orderBy: 'ordinal'),
        segments,
      );
      expect(
        await reopened.query('walk_surface_corrections', orderBy: 'start_edge'),
        corrections,
      );
    } finally {
      await reopened.close();
    }
  });

  for (final table in ['walk_surface_segments', 'walk_surface_corrections']) {
    test('v2 $table corruption is not silently converted to UNKNOWN', () async {
      final old = await createLegacy(file);
      await old.execute(
        "UPDATE $table SET surface = 'invalidMaterial' WHERE start_edge = 0",
      );
      await old.close();
      final app = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
      );
      addTearDown(app.close);
      final walks = WalkRepository(app);
      await expectLater(
        walks.surfaces.load(7, await walks.pointsForWalk(7)),
        throwsFormatException,
      );
      expect(
        (await (await app.database).query(
          table,
          where: 'start_edge = 0',
        )).single['surface'],
        'invalidMaterial',
      );
    });
  }
}

Future<Database> createLegacy(String file) async {
  final db = await databaseFactoryFfi.openDatabase(
    file,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchemaV2,
    ),
  );
  final points = straight(count: 17);
  for (final (id, status) in [
    (7, 'completed'),
    (8, 'interrupted'),
    (9, 'recording'),
  ]) {
    final start = points.first.recordedAt.millisecondsSinceEpoch;
    final end = points.last.recordedAt.millisecondsSinceEpoch + 3000;
    await db.insert('walks', {
      'id': id,
      'started_at_ms': start,
      'ended_at_ms': status == 'recording' ? null : end,
      'duration_ms': status == 'recording' ? null : end - start,
      'distance_meters': status == 'recording'
          ? 0.0
          : WalkDistance.total(points),
      'status': status,
    });
    for (final p in points) {
      await db.insert('walk_points', {
        'walk_id': id,
        'sequence': p.sequence,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'recorded_at_ms': p.recordedAt.millisecondsSinceEpoch,
        'accuracy_meters': p.accuracyMeters,
      });
    }
  }
  await db.insert('walk_surface_analyses', {
    'walk_id': 7,
    'point_count': 17,
    'points_valid': 1,
  });
  for (var i = 0; i < legacySurfaces.length; i++) {
    final surface = legacySurfaces[i];
    await db.insert('walk_surface_segments', {
      'walk_id': 7,
      'ordinal': i,
      'start_edge': i * 2,
      'end_edge': i * 2 + 2,
      'surface': surface,
      'assignment': surface == 'unknown'
          ? 'unknown'
          : surface == 'grass'
          ? 'inferred'
          : 'direct',
      'surface_reason': surface == 'unknown'
          ? 'missingSurface'
          : surface == 'grass'
          ? 'grassLandcover'
          : 'explicitSurface',
      'edge_reason': surface == 'unknown' ? 'missingSurface' : 'matched',
      'from_feature_key': 'way/$i',
      'to_feature_key': 'way/$i',
    });
    await db.insert('walk_surface_corrections', {
      'walk_id': 7,
      'start_edge': i * 2,
      'end_edge': i * 2 + 2,
      'surface': legacyCorrections[i],
    });
  }
  return db;
}

// Frozen v2 schema from pushed 1986348, including constraints, index and triggers.
// Do not build a "legacy" fixture through the current AppDatabase schema.
Future<void> createSchemaV2(Database db, int version) async {
  for (final statement in [
    '''CREATE TABLE walks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at_ms INTEGER NOT NULL, ended_at_ms INTEGER, duration_ms INTEGER,
      distance_meters REAL NOT NULL DEFAULT 0,
      status TEXT NOT NULL CHECK (status IN ('recording', 'completed', 'interrupted'))
    )''',
    '''CREATE TABLE walk_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT, walk_id INTEGER NOT NULL,
      sequence INTEGER NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL,
      recorded_at_ms INTEGER NOT NULL, accuracy_meters REAL NOT NULL,
      FOREIGN KEY (walk_id) REFERENCES walks(id) ON DELETE CASCADE,
      UNIQUE (walk_id, sequence)
    )''',
    'CREATE INDEX walk_points_walk_sequence ON walk_points (walk_id, sequence)',
    '''CREATE TABLE walk_surface_analyses (
      walk_id INTEGER PRIMARY KEY REFERENCES walks(id) ON DELETE CASCADE,
      point_count INTEGER NOT NULL CHECK (point_count >= 2),
      points_valid INTEGER NOT NULL DEFAULT 1 CHECK (points_valid IN (0, 1))
    )''',
    '''CREATE TABLE walk_surface_segments (
      walk_id INTEGER NOT NULL REFERENCES walk_surface_analyses(walk_id) ON DELETE CASCADE,
      ordinal INTEGER NOT NULL CHECK (ordinal >= 0),
      start_edge INTEGER NOT NULL CHECK (start_edge >= 0),
      end_edge INTEGER NOT NULL CHECK (end_edge > start_edge),
      surface TEXT NOT NULL, assignment TEXT NOT NULL, surface_reason TEXT NOT NULL,
      edge_reason TEXT NOT NULL, from_feature_key TEXT, to_feature_key TEXT,
      PRIMARY KEY (walk_id, ordinal)
    )''',
    '''CREATE TABLE walk_surface_corrections (
      walk_id INTEGER NOT NULL REFERENCES walk_surface_analyses(walk_id) ON DELETE CASCADE,
      start_edge INTEGER NOT NULL CHECK (start_edge >= 0),
      end_edge INTEGER NOT NULL CHECK (end_edge > start_edge),
      surface TEXT NOT NULL,
      PRIMARY KEY (walk_id, start_edge, end_edge)
    )''',
    '''CREATE TRIGGER surface_points_insert AFTER INSERT ON walk_points BEGIN
      UPDATE walk_surface_analyses SET points_valid = 0 WHERE walk_id IN (NEW.walk_id);
    END''',
    '''CREATE TRIGGER surface_points_update AFTER UPDATE ON walk_points BEGIN
      UPDATE walk_surface_analyses SET points_valid = 0 WHERE walk_id IN (OLD.walk_id, NEW.walk_id);
    END''',
    '''CREATE TRIGGER surface_points_delete AFTER DELETE ON walk_points BEGIN
      UPDATE walk_surface_analyses SET points_valid = 0 WHERE walk_id IN (OLD.walk_id);
    END''',
  ]) {
    await db.execute(statement);
  }
}
