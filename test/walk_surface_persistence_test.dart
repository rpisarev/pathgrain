import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pathgrain/map/evidence/evidence_cache.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:pathgrain/walks/walk_surface_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

const asphalt = CanonicalSurface.asphalt;
const concrete = CanonicalSurface.concrete;
const unknown = CanonicalSurface.unknown;
const grass = CanonicalSurface.grass;
const paving = CanonicalSurface.tile;
const observation = SurfaceCorrection(
  startEdgeIndex: 2,
  endEdgeIndex: 5,
  surface: grass,
);

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'real schema v1 upgrades without changing any walk or point value',
    () async {
      final dir = await Directory.systemTemp.createTemp('pathgrain_migration_');
      final file = path.join(dir.path, 'legacy.sqlite');
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            // Exact Prototype 0.0 / A / B / C schema, including constraints/index.
            await db.execute('''CREATE TABLE walks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          started_at_ms INTEGER NOT NULL, ended_at_ms INTEGER, duration_ms INTEGER,
          distance_meters REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL CHECK (status IN ('recording', 'completed', 'interrupted'))
        )''');
            await db.execute('''CREATE TABLE walk_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT, walk_id INTEGER NOT NULL,
          sequence INTEGER NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL,
          recorded_at_ms INTEGER NOT NULL, accuracy_meters REAL NOT NULL,
          FOREIGN KEY (walk_id) REFERENCES walks(id) ON DELETE CASCADE,
          UNIQUE (walk_id, sequence)
        )''');
            await db.execute(
              'CREATE INDEX walk_points_walk_sequence ON walk_points (walk_id, sequence)',
            );
          },
        ),
      );
      for (final (id, status) in [
        (7, 'completed'),
        (8, 'interrupted'),
        (9, 'recording'),
      ]) {
        await old.insert('walks', {
          'id': id,
          'started_at_ms': 1000,
          'ended_at_ms': status == 'recording' ? null : 10000,
          'duration_ms': status == 'recording' ? null : 9000,
          'distance_meters': 12.345,
          'status': status,
        });
        for (final p in straight(count: 4)) {
          await old.insert('walk_points', {
            'walk_id': id,
            'sequence': p.sequence,
            'latitude': p.latitude,
            'longitude': p.longitude,
            'recorded_at_ms': p.recordedAt.millisecondsSinceEpoch,
            'accuracy_meters': p.accuracyMeters,
          });
        }
      }
      final walksBefore = await old.query('walks', orderBy: 'id');
      final pointsBefore = await old.query('walk_points', orderBy: 'id');
      await old.close();
      final app = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
      );
      addTearDown(() async {
        await app.close();
        await dir.delete(recursive: true);
      });
      final upgraded = await app.database;
      expect(await upgraded.getVersion(), 3);
      expect(await upgraded.query('walks', orderBy: 'id'), walksBefore);
      expect(await upgraded.query('walk_points', orderBy: 'id'), pointsBefore);
      expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final walks = WalkRepository(app);
      expect(
        await walks.surfaces.load(7, await walks.pointsForWalk(7)),
        isNull,
      );
      for (final table in [
        'walk_surface_analyses',
        'walk_surface_segments',
        'walk_surface_corrections',
      ]) {
        expect(await upgraded.query(table), isEmpty);
      }
      // The original AUTOINCREMENT state and recorder writes remain usable.
      expect((await walks.createWalk(DateTime.utc(2026))).id, 10);
    },
  );

  group('durable journal', () {
    late Directory dir;
    late String file;
    late AppDatabase app;
    late WalkRepository walks;
    late WalkSurfaceRepository repository;
    late Walk walk;
    late List<WalkPoint> points;
    late WalkSurfaceSummary initial;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('pathgrain_journal_');
      file = path.join(dir.path, 'walks.sqlite');
      app = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: file,
      );
      walks = WalkRepository(app);
      repository = walks.surfaces;
      final originals = straight(count: 9);
      walk = await walks.createWalk(originals.first.recordedAt);
      for (final p in originals) {
        await walks.appendPoint(
          walk.id,
          LocationSample(
            latitude: p.latitude,
            longitude: p.longitude,
            recordedAt: p.recordedAt,
            accuracyMeters: p.accuracyMeters,
          ),
        );
      }
      walk = await walks.finishWalk(
        walkId: walk.id,
        endedAt: originals.last.recordedAt,
        status: WalkStatus.completed,
      );
      points = await walks.pointsForWalk(walk.id);
      initial = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis([
          asphalt,
          asphalt,
          unknown,
          unknown,
          unknown,
          paving,
          paving,
          paving,
        ], points: points),
      );
    });
    tearDown(() async {
      await app.close();
      await dir.delete(recursive: true);
    });

    Future<SurfaceJournal> persist() =>
        repository.saveAnalysis(walk.id, initial, evidenceComplete: true);
    Future<SurfaceJournal> load() async =>
        (await repository.load(walk.id, points))!;

    for (final surface in CanonicalSurface.values) {
      test(
        'v3 $surface correction, re-analysis, restore and automatic equality survive SQLite reopen',
        () async {
          final db = await app.database;
          expect(await db.getVersion(), 3);
          final originalWalks = await db.query('walks');
          final originalPoints = await db.query('walk_points');
          final alternatives = CanonicalSurface.values
              .where((s) => s != surface)
              .take(2)
              .toList();
          WalkSurfaceSummary summary(
            List<CanonicalSurface> labels, {
            List<AnalysisReason>? reasons,
          }) => WalkSurfaceSummary.fromAnalysis(
            surfaceAnalysis(labels, points: points, reasons: reasons),
          );
          await repository.saveAnalysis(
            walk.id,
            summary(List.filled(points.length - 1, alternatives.first)),
            evidenceComplete: true,
          );
          final selected = SurfaceCorrection(
            startEdgeIndex: 2,
            endEdgeIndex: 5,
            surface: surface,
          );
          final saved = await repository.saveCorrection(
            walk.id,
            points,
            selected,
          );
          expect(saved.corrections.single.surface, surface);
          final savedMap = SurfaceRouteGeoJson.build(saved.effective);
          await app.close();
          app = AppDatabase(
            databaseFactory: databaseFactoryFfi,
            databasePath: file,
          );
          walks = WalkRepository(app);
          repository = walks.surfaces;
          points = await walks.pointsForWalk(walk.id);
          expect(SurfaceRouteGeoJson.build((await load()).effective), savedMap);
          expect(
            (await (await app.database).query('walk_surface_corrections'))
                .single['surface'],
            surface.name,
          );

          final replacement = summary(
            List.generate(points.length - 1, (i) => alternatives[i % 2]),
          );
          final reanalyzed = await repository.saveAnalysis(
            walk.id,
            replacement,
            evidenceComplete: true,
          );
          expect(reanalyzed.corrections.single.sameRange(selected), isTrue);
          expect(reanalyzed.corrections.single.surface, surface);
          final effective = reanalyzed.effective.segments.singleWhere(
            (s) => s.isCorrected,
          );
          expect(
            (
              effective.startEdgeIndex,
              effective.endEdgeIndex,
              effective.surface,
            ),
            (2, 5, surface),
          );
          expect(
            reanalyzed.effective.reconcilesWith(walk.distanceMeters),
            isTrue,
          );
          final restored = await repository.restoreAutomatic(
            walk.id,
            points,
            selected,
          );
          expect(restored.corrections, isEmpty);
          expect(
            restored.effective.distanceBySurface,
            replacement.distanceBySurface,
          );

          await repository.saveCorrection(walk.id, points, selected);
          final sameAcrossBoundaries = summary(
            List.filled(points.length - 1, surface),
            reasons: List.generate(
              points.length - 1,
              (i) => i.isEven
                  ? AnalysisReason.matched
                  : AnalysisReason.continuitySupported,
            ),
          );
          final same = await repository.saveAnalysis(
            walk.id,
            sameAcrossBoundaries,
            evidenceComplete: true,
          );
          expect(same.automatic.segments, hasLength(points.length - 1));
          expect(same.corrections.single.surface, surface);
          final redundant = await repository.saveCorrection(
            walk.id,
            points,
            selected,
          );
          expect(redundant.corrections, isEmpty);
          expect(
            redundant.effective.reconcilesWith(walk.distanceMeters),
            isTrue,
          );
          final automaticMap = SurfaceRouteGeoJson.build(redundant.effective);
          await app.close();
          app = AppDatabase(
            databaseFactory: databaseFactoryFfi,
            databasePath: file,
          );
          walks = WalkRepository(app);
          repository = walks.surfaces;
          points = await walks.pointsForWalk(walk.id);
          final reopened = await load();
          expect(reopened.corrections, isEmpty);
          expect(
            reopened.automatic.segments.every(
              (s) => s.surface.surface == surface,
            ),
            isTrue,
          );
          expect(SurfaceRouteGeoJson.build(reopened.effective), automaticMap);
          final current = await app.database;
          expect(await current.query('walks'), originalWalks);
          expect(await current.query('walk_points'), originalPoints);
          expect(await current.query('walk_surface_corrections'), isEmpty);
          expect(await current.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        },
      );
    }

    test('ordered automatic segments and provenance round-trip from original points', () async {
      final db = await app.database;
      final originalWalks = await db.query('walks');
      final originalPoints = await db.query('walk_points');
      await persist();
      final saved = await load();
      expect(
        saved.automatic.segments.map(
          (s) => (
            s.startEdgeIndex,
            s.endEdgeIndex,
            s.surface.surface,
            s.surface.assignment,
            s.surface.reason,
            s.reason,
            s.fromFeatureKey,
            s.toFeatureKey,
            s.distanceMeters,
          ),
        ),
        initial.segments.map(
          (s) => (
            s.startEdgeIndex,
            s.endEdgeIndex,
            s.surface.surface,
            s.surface.assignment,
            s.surface.reason,
            s.reason,
            s.fromFeatureKey,
            s.toFeatureKey,
            s.distanceMeters,
          ),
        ),
      );
      expect(saved.effective.reconcilesWith(walk.distanceMeters), isTrue);
      expect(await db.query('walks'), originalWalks);
      expect(await db.query('walk_points'), originalPoints);
    });

    test(
      'analysis and correction survive repository and SQLite close/reopen',
      () async {
        await persist();
        final before = await repository.saveCorrection(
          walk.id,
          points,
          observation,
        );
        final data = SurfaceRouteGeoJson.build(before.effective);
        await app.close();
        app = AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: file,
        );
        walks = WalkRepository(app);
        repository = walks.surfaces;
        points = await walks.pointsForWalk(walk.id);
        final after = await load();
        expect(SurfaceRouteGeoJson.build(after.effective), data);
        expect(
          after.effective.distanceBySurface,
          before.effective.distanceBySurface,
        );
        expect(after.automatic.segments[1].surface.surface, unknown);
        expect(after.corrections.single.surface, grass);
        expect(
          after.effective.reconcilesWith(
            (await walks.walkById(walk.id))!.distanceMeters,
          ),
          isTrue,
        );
      },
    );

    for (final (automaticSurface, previous) in [
      (concrete, null),
      (concrete, grass),
      (concrete, concrete),
      (unknown, null),
      (unknown, grass),
    ]) {
      test(
        'saving automatic $automaticSurface with previous $previous leaves no row after reopen',
        () async {
          final summary = WalkSurfaceSummary.fromAnalysis(
            surfaceAnalysis(
              List.filled(points.length - 1, automaticSurface),
              points: points,
            ),
          );
          await repository.saveAnalysis(
            walk.id,
            summary,
            evidenceComplete: true,
          );
          final selected = SurfaceCorrection(
            startEdgeIndex: 0,
            endEdgeIndex: points.length - 1,
            surface: automaticSurface,
          );
          final db = await app.database;
          if (previous == automaticSurface) {
            // Simulate a redundant row saved by the earlier D implementation.
            await db.insert('walk_surface_corrections', {
              'walk_id': walk.id,
              'start_edge': 0,
              'end_edge': points.length - 1,
              'surface': previous!.name,
            });
          } else if (previous != null) {
            await repository.saveCorrection(
              walk.id,
              points,
              SurfaceCorrection(
                startEdgeIndex: 0,
                endEdgeIndex: points.length - 1,
                surface: previous,
              ),
            );
          }
          final saved = await repository.saveCorrection(
            walk.id,
            points,
            selected,
          );
          expect(saved.corrections, isEmpty);
          expect(saved.effective.segments.every((s) => !s.isCorrected), isTrue);
          expect(saved.effective.distanceBySurface, summary.distanceBySurface);
          expect(saved.effective.reconcilesWith(walk.distanceMeters), isTrue);
          expect(await db.query('walk_surface_corrections'), isEmpty);
          final map = SurfaceRouteGeoJson.build(saved.effective);
          await app.close();
          app = AppDatabase(
            databaseFactory: databaseFactoryFfi,
            databasePath: file,
          );
          walks = WalkRepository(app);
          repository = walks.surfaces;
          points = await walks.pointsForWalk(walk.id);
          final reopened = await load();
          expect(reopened.corrections, isEmpty);
          expect(SurfaceRouteGeoJson.build(reopened.effective), map);
          expect(
            await (await app.database).query('walk_surface_corrections'),
            isEmpty,
          );
        },
      );
    }

    test(
      'concrete to grass to paving remains a persisted correction after reopen',
      () async {
        final summary = WalkSurfaceSummary.fromAnalysis(
          surfaceAnalysis(
            List.filled(points.length - 1, concrete),
            points: points,
          ),
        );
        await repository.saveAnalysis(walk.id, summary, evidenceComplete: true);
        await repository.saveCorrection(walk.id, points, observation);
        final saved = await repository.saveCorrection(
          walk.id,
          points,
          const SurfaceCorrection(
            startEdgeIndex: 2,
            endEdgeIndex: 5,
            surface: paving,
          ),
        );
        final map = SurfaceRouteGeoJson.build(saved.effective);
        await app.close();
        app = AppDatabase(
          databaseFactory: databaseFactoryFfi,
          databasePath: file,
        );
        walks = WalkRepository(app);
        repository = walks.surfaces;
        points = await walks.pointsForWalk(walk.id);
        final reopened = await load();
        expect(reopened.corrections.single.surface, paving);
        expect(reopened.corrections.single.sameRange(observation), isTrue);
        expect(reopened.automatic.segments.single.surface.surface, concrete);
        expect(SurfaceRouteGeoJson.build(reopened.effective), map);
        expect(
          (await (await app.database).query('walk_surface_corrections'))
              .single['surface'],
          'tile',
        );
      },
    );

    for (final middleSurface in [grass, concrete]) {
      test(
        'Save checks all current automatic pieces after re-analysis: $middleSurface',
        () async {
          await persist();
          await repository.saveCorrection(walk.id, points, observation);
          final updated = WalkSurfaceSummary.fromAnalysis(
            surfaceAnalysis(
              [
                asphalt,
                asphalt,
                grass,
                middleSurface,
                grass,
                paving,
                paving,
                paving,
              ],
              points: points,
              // Keep several automatic provenance boundaries even when all labels agree.
              reasons: [
                AnalysisReason.matched,
                AnalysisReason.matched,
                AnalysisReason.matched,
                AnalysisReason.continuitySupported,
                AnalysisReason.matched,
                AnalysisReason.matched,
                AnalysisReason.matched,
                AnalysisReason.matched,
              ],
            ),
          );
          final reanalyzed = await repository.saveAnalysis(
            walk.id,
            updated,
            evidenceComplete: true,
          );
          // Re-analysis itself retains corrections, including newly equal values.
          expect(reanalyzed.corrections.single.surface, grass);
          final saved = await repository.saveCorrection(
            walk.id,
            points,
            observation,
          );
          final rows = await (await app.database).query(
            'walk_surface_corrections',
          );
          if (middleSurface == grass) {
            expect(saved.corrections, isEmpty);
            expect(rows, isEmpty);
            expect(
              saved.effective.segments.every((s) => !s.isCorrected),
              isTrue,
            );
          } else {
            expect(saved.corrections.single.sameRange(observation), isTrue);
            expect(saved.corrections.single.surface, grass);
            expect(rows, hasLength(1));
            expect(
              saved.effective.segments
                  .where((s) => s.isCorrected)
                  .single
                  .endEdgeIndex,
              5,
            );
          }
          expect(saved.effective.reconcilesWith(walk.distanceMeters), isTrue);
        },
      );
    }

    test('saving equal automatic value shares restore rollback semantics', () async {
      await persist();
      await repository.saveCorrection(walk.id, points, observation);
      final db = await app.database;
      await db.execute(
        '''CREATE TRIGGER fail_restore BEFORE DELETE ON walk_surface_corrections
        BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END''',
      );
      await expectLater(
        repository.saveCorrection(
          walk.id,
          points,
          const SurfaceCorrection(
            startEdgeIndex: 2,
            endEdgeIndex: 5,
            surface: unknown,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await load()).corrections.single.surface, grass);
      expect(
        (await db.query('walk_surface_corrections')).single['surface'],
        'grass',
      );
    });

    test('exact correction edit replaces one row; restore reveals current automatic', () async {
      await persist();
      await repository.saveCorrection(walk.id, points, observation);
      const edit = SurfaceCorrection(
        startEdgeIndex: 2,
        endEdgeIndex: 5,
        surface: paving,
      );
      await repository.saveCorrection(walk.id, points, edit);
      final changed = await load();
      expect(changed.corrections, hasLength(1));
      expect(changed.corrections.single.surface, paving);
      final restored = await repository.restoreAutomatic(walk.id, points, edit);
      expect(restored.corrections, isEmpty);
      expect(restored.effective.distanceBySurface, initial.distanceBySurface);
      expect((await load()).corrections, isEmpty);
    });

    test('new segmentation preserves exact correction identity and automatic evidence', () async {
      await persist();
      await repository.saveCorrection(walk.id, points, observation);
      final replacement = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis([
          asphalt,
          asphalt,
          asphalt,
          asphalt,
          paving,
          paving,
          paving,
          paving,
        ], points: points),
      );
      final changed = await repository.saveAnalysis(
        walk.id,
        replacement,
        evidenceComplete: true,
      );
      expect(
        changed.effective.segments.map(
          (s) => (s.startEdgeIndex, s.endEdgeIndex, s.surface, s.isCorrected),
        ),
        [(0, 2, asphalt, false), (2, 5, grass, true), (5, 8, paving, false)],
      );
      expect(
        changed.automatic.segments.map(
          (s) => (s.startEdgeIndex, s.endEdgeIndex),
        ),
        [(0, 4), (4, 8)],
      );
      final restored = await repository.restoreAutomatic(
        walk.id,
        points,
        observation,
      );
      expect(
        restored.effective.distanceBySurface,
        replacement.distanceBySurface,
      );
    });

    test('incomplete evidence and malformed new analysis preserve the saved journal', () async {
      await persist();
      final before = await repository.saveCorrection(
        walk.id,
        points,
        observation,
      );
      await expectLater(
        repository.saveAnalysis(walk.id, initial, evidenceComplete: false),
        throwsFormatException,
      );
      expect(
        () => WalkSurfaceSummary.fromAnalysis(
          RouteAnalysis(
            samples: initial.analysis.samples,
            edges: initial.analysis.edges.skip(1),
          ),
        ),
        throwsFormatException,
      );
      expect(
        SurfaceRouteGeoJson.build((await load()).effective),
        SurfaceRouteGeoJson.build(before.effective),
      );
    });

    test('failed replacement transaction rolls back deletion and inserted segment rows', () async {
      await persist();
      final before = await repository.saveCorrection(
        walk.id,
        points,
        observation,
      );
      final db = await app.database;
      await db.execute(
        '''CREATE TRIGGER fail_segment BEFORE INSERT ON walk_surface_segments
        WHEN NEW.ordinal = 1 BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END''',
      );
      final replacement = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis([
          grass,
          asphalt,
          grass,
          asphalt,
          grass,
          asphalt,
          grass,
          asphalt,
        ], points: points),
      );
      await expectLater(
        repository.saveAnalysis(walk.id, replacement, evidenceComplete: true),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        SurfaceRouteGeoJson.build((await load()).effective),
        SurfaceRouteGeoJson.build(before.effective),
      );
      expect((await load()).automatic.segments.length, initial.segments.length);
    });

    test(
      'failed first analysis leaves no partial header or segments',
      () async {
        final db = await app.database;
        await db.execute(
          '''CREATE TRIGGER fail_segment BEFORE INSERT ON walk_surface_segments
        WHEN NEW.ordinal = 1 BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END''',
        );
        await expectLater(persist(), throwsA(isA<DatabaseException>()));
        expect(await db.query('walk_surface_analyses'), isEmpty);
        expect(await db.query('walk_surface_segments'), isEmpty);
        expect(await repository.load(walk.id, points), isNull);
      },
    );

    test('failed correction replacement and restore roll back without losing observation', () async {
      await persist();
      await repository.saveCorrection(walk.id, points, observation);
      final db = await app.database;
      await db.execute('''CREATE TRIGGER fail_correction BEFORE INSERT ON walk_surface_corrections
        BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END''');
      await expectLater(
        repository.saveCorrection(
          walk.id,
          points,
          const SurfaceCorrection(
            startEdgeIndex: 2,
            endEdgeIndex: 5,
            surface: paving,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await load()).corrections.single.surface, grass);
      await db.execute(
        '''CREATE TRIGGER fail_restore BEFORE DELETE ON walk_surface_corrections
        BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END''',
      );
      await expectLater(
        repository.restoreAutomatic(walk.id, points, observation),
        throwsA(isA<DatabaseException>()),
      );
      expect((await load()).corrections.single.surface, grass);
    });

    test(
      'overlapping edit is rejected without changing the existing correction',
      () async {
        await persist();
        await repository.saveCorrection(walk.id, points, observation);
        await expectLater(
          repository.saveCorrection(
            walk.id,
            points,
            const SurfaceCorrection(
              startEdgeIndex: 1,
              endEdgeIndex: 3,
              surface: paving,
            ),
          ),
          throwsFormatException,
        );
        expect(
          (await load()).corrections.single.sameRange(observation),
          isTrue,
        );
      },
    );

    for (final (name, sql) in [
      (
        'missing coverage',
        'DELETE FROM walk_surface_segments WHERE ordinal = 1',
      ),
      (
        'overlap',
        'UPDATE walk_surface_segments SET start_edge = 1 WHERE ordinal = 1',
      ),
      (
        'gap',
        'UPDATE walk_surface_segments SET start_edge = 3 WHERE ordinal = 1',
      ),
      (
        'out of range',
        'UPDATE walk_surface_segments SET end_edge = 99 WHERE ordinal = 2',
      ),
      (
        'ordering',
        'UPDATE walk_surface_segments SET ordinal = 10 WHERE ordinal = 0',
      ),
      (
        'surface enum',
        "UPDATE walk_surface_segments SET surface = 'invalidMaterial' WHERE ordinal = 1",
      ),
      (
        'assignment enum',
        "UPDATE walk_surface_segments SET assignment = 'user' WHERE ordinal = 1",
      ),
      (
        'reason enum',
        "UPDATE walk_surface_segments SET surface_reason = 'invented' WHERE ordinal = 1",
      ),
      (
        'inconsistent assignment',
        "UPDATE walk_surface_segments SET assignment = 'direct' WHERE ordinal = 1",
      ),
      ('header count', 'UPDATE walk_surface_analyses SET point_count = 90'),
    ]) {
      test(
        'corrupt automatic $name rejected without touching the walk',
        () async {
          await persist();
          final db = await app.database;
          final original = await db.query('walk_points');
          await db.execute(sql);
          await expectLater(load(), throwsFormatException);
          expect(await db.query('walk_points'), original);
        },
      );
    }

    test('explicit re-analysis repairs automatic coverage while retaining valid corrections', () async {
      await persist();
      await repository.saveCorrection(walk.id, points, observation);
      await (await app.database).delete(
        'walk_surface_segments',
        where: 'ordinal = 0',
      );
      await expectLater(load(), throwsFormatException);
      await persist();
      expect((await load()).corrections.single.sameRange(observation), isTrue);
    });

    for (final sql in [
      "UPDATE walk_surface_corrections SET surface = 'invalidMaterial'",
      'UPDATE walk_surface_corrections SET end_edge = 99',
      "INSERT INTO walk_surface_corrections SELECT walk_id, 1, 3, 'grass' FROM walk_surface_analyses",
    ]) {
      test(
        'corrupt correction fails closed and cannot be lost through re-analysis: $sql',
        () async {
          await persist();
          await repository.saveCorrection(walk.id, points, observation);
          final db = await app.database;
          await db.execute(sql);
          final before = await db.query('walk_surface_corrections');
          await expectLater(load(), throwsFormatException);
          await expectLater(persist(), throwsFormatException);
          expect(await db.query('walk_surface_corrections'), before);
        },
      );
    }

    for (final sql in [
      'UPDATE walk_points SET latitude = latitude + 0.00001 WHERE sequence = 3',
      'UPDATE walk_points SET recorded_at_ms = recorded_at_ms + 1 WHERE sequence = 3',
      'UPDATE walk_points SET sequence = 90 WHERE sequence = 3',
      'DELETE FROM walk_points WHERE sequence = 3',
      'INSERT INTO walk_points (walk_id, sequence, latitude, longitude, recorded_at_ms, accuracy_meters) SELECT walk_id, 90, latitude, longitude, recorded_at_ms, accuracy_meters FROM walk_points WHERE sequence = 3',
    ]) {
      test('point mutation invalidates exact journal identity: $sql', () async {
        await persist();
        await repository.saveCorrection(walk.id, points, observation);
        final db = await app.database;
        await db.execute(sql);
        points = await walks.pointsForWalk(walk.id);
        await expectLater(load(), throwsFormatException);
        expect(
          (await db.query('walk_surface_analyses')).single['points_valid'],
          0,
        );
        // Even a fresh analysis of the changed geometry cannot reassign observations.
        final changed = WalkSurfaceSummary.fromAnalysis(
          surfaceAnalysis(
            List.filled(points.length - 1, asphalt),
            points: points,
          ),
        );
        await expectLater(
          repository.saveAnalysis(walk.id, changed, evidenceComplete: true),
          throwsFormatException,
        );
        expect(await db.query('walk_surface_corrections'), hasLength(1));
      });
    }

    test(
      'walk deletion cascades only its own points, snapshot and corrections',
      () async {
        await persist();
        await repository.saveCorrection(walk.id, points, observation);
        final other = await walks.createWalk(DateTime.utc(2026));
        await walks.deleteWalk(walk.id);
        final db = await app.database;
        for (final table in [
          'walk_points',
          'walk_surface_analyses',
          'walk_surface_segments',
          'walk_surface_corrections',
        ]) {
          expect(await db.query(table), isEmpty);
        }
        expect(await walks.walkById(other.id), isNotNull);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );

    test('deleting the separate evidence database cannot erase the surface journal', () async {
      await persist();
      final before = await repository.saveCorrection(
        walk.id,
        points,
        observation,
      );
      final cachePath = path.join(dir.path, SqliteEvidenceCache.fileName);
      final cache = SqliteEvidenceCache(
        databaseFactory: databaseFactoryFfi,
        databasePath: cachePath,
      );
      await cache.write(
        'synthetic',
        GeographicCell.covering([const GeoCoordinate(1, 2)]).single,
        CachedEvidence(
          evidence: mixedSurfaceEvidence(),
          fetchedAt: DateTime.utc(2026),
        ),
      );
      await cache.close();
      await databaseFactoryFfi.deleteDatabase(cachePath);
      expect(await File(cachePath).exists(), isFalse);
      expect(
        SurfaceRouteGeoJson.build((await load()).effective),
        SurfaceRouteGeoJson.build(before.effective),
      );
    });
  });
}
