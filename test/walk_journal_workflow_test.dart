import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pathgrain/map/evidence/evidence_repository.dart';
import 'package:pathgrain/map/evidence/geographic_cell.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/map/evidence/osm_evidence_provider.dart';
import 'package:pathgrain/platform/notification_permission.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_recording_controller.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/analysis_fixtures.dart';
import 'support/evidence_fakes.dart';
import 'support/surface_fixtures.dart';
import 'support/test_doubles.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('new recording through durable journal, restart, re-analysis and deletion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pathgrain_workflow_',
    );
    final file = path.join(directory.path, 'walks.sqlite');
    AppDatabase open() =>
        AppDatabase(databaseFactory: databaseFactoryFfi, databasePath: file);
    var app = open();
    var walks = WalkRepository(app);
    final location = TestLocationRecorder();
    final originals = straight(count: 12);
    var now = originals.first.recordedAt;
    WalkRecordingController recorder() => WalkRecordingController(
      repository: walks,
      locationRecorder: location,
      notificationPermissionGateway: const TestNotificationPermissionGateway(
        NotificationPermissionState.notRequired,
      ),
      now: () => now,
    );
    var controller = recorder();
    addTearDown(() async {
      controller.dispose();
      await location.close();
      await app.close();
      await directory.delete(recursive: true);
    });

    var offline = false;
    final concretePath = straightPath(
      tags: {'highway': 'footway', 'surface': 'concrete'},
    );
    var evidenceData = OsmEvidence(
      features: [concretePath],
      raw: {
        'elements': [concretePath.raw],
      },
      unparsedElements: 0,
    );
    final provider = FakeEvidenceProvider((_) async {
      if (offline) throw const EvidenceException(EvidenceFailure.offline);
      return evidenceData;
    });
    final cache = MemoryEvidenceCache();
    final evidence = EvidenceRepository(provider: provider, cache: cache);
    Future<EvidenceSnapshot> inspect(List<WalkPoint> points) => evidence
        .inspect(points.map((p) => GeoCoordinate(p.latitude, p.longitude)))
        .last;
    WalkSurfaceSummary analyze(
      List<WalkPoint> points,
      EvidenceSnapshot snapshot,
    ) => WalkSurfaceSummary.fromAnalysis(
      RouteMatcher.analyze(
        points,
        snapshot.features,
        evidenceComplete: snapshot.hasCompleteCoverage,
      ),
    );
    Future<void> start() => controller.startWalk(
      notificationTitle: 'Recording',
      notificationText: 'Local only',
      notificationChannelName: 'Walk recording',
    );
    Future<void> emitPoints(List<WalkPoint> points) async {
      final persisted = Completer<void>();
      void check() {
        if (controller.activePointCount == points.length &&
            !persisted.isCompleted) {
          persisted.complete();
        }
      }

      controller.addListener(check);
      for (final p in points) {
        location.emit(
          LocationSample(
            latitude: p.latitude,
            longitude: p.longitude,
            recordedAt: now.add(
              p.recordedAt.difference(points.first.recordedAt),
            ),
            accuracyMeters: p.accuracyMeters,
          ),
        );
      }
      await persisted.future.timeout(const Duration(seconds: 5));
      controller.removeListener(check);
    }

    await controller.initialize();
    final starting = start();
    await start(); // Repeated Start cannot create another walk or subscription.
    await starting;
    expect(location.positionStreamCalls, 1);
    await emitPoints(originals);
    final id = controller.activeWalk!.id;
    expect(controller.walks, isEmpty);
    final database = await app.database;
    expect(await database.getVersion(), 3);
    expect(await database.query('walk_surface_analyses'), isEmpty);
    expect(provider.calls, isEmpty);
    now = originals.last.recordedAt.add(const Duration(seconds: 3));
    final saved = (await controller.stopWalk())!;
    expect(saved.status, WalkStatus.completed);
    expect(saved.duration, now.difference(originals.first.recordedAt));
    expect(controller.walks.single.id, id);
    final points = await walks.pointsForWalk(id);
    expect(
      points.map(
        (p) => (
          p.sequence,
          p.latitude,
          p.longitude,
          p.recordedAt,
          p.accuracyMeters,
        ),
      ),
      originals.map(
        (p) => (
          p.sequence,
          p.latitude,
          p.longitude,
          p.recordedAt,
          p.accuracyMeters,
        ),
      ),
    );
    expect(await walks.surfaces.load(id, points), isNull);
    expect(
      provider.calls,
      isEmpty,
    ); // Stop is local and independent of evidence.
    final originalWalkRow = await database.query(
      'walks',
      where: 'id = ?',
      whereArgs: [id],
    );
    final originalPointRows = await database.query(
      'walk_points',
      where: 'walk_id = ?',
      whereArgs: [id],
      orderBy: 'sequence',
    );

    // Missing evidence is a failed analysis, not a saved all-UNKNOWN snapshot.
    offline = true;
    var snapshot = await inspect(points);
    expect(snapshot.hasCompleteCoverage, isFalse);
    await expectLater(
      walks.surfaces.saveAnalysis(
        id,
        analyze(points, snapshot),
        evidenceComplete: false,
      ),
      throwsFormatException,
    );
    expect(await walks.surfaces.load(id, points), isNull);
    expect((await walks.walkById(id))!.pointCount, originals.length);
    offline = false;
    snapshot = await inspect(points);
    expect(snapshot.hasCompleteCoverage, isTrue);
    var journal = await walks.surfaces.saveAnalysis(
      id,
      analyze(points, snapshot),
      evidenceComplete: true,
    );
    expect(journal.effective.reconcilesWith(saved.distanceMeters), isTrue);
    expect(journal.effective.unknownDistanceMeters, greaterThan(0));
    final automaticMap = SurfaceRouteGeoJson.build(journal.effective);
    final segment = journal.effective.segments.firstWhere(
      (s) => s.surface == CanonicalSurface.concrete,
    );
    final correction = SurfaceCorrection(
      startEdgeIndex: segment.startEdgeIndex,
      endEdgeIndex: segment.endEdgeIndex,
      surface: CanonicalSurface.grass,
    );
    journal = await walks.surfaces.saveCorrection(id, points, correction);
    final correctedMap = SurfaceRouteGeoJson.build(journal.effective);
    expect(correctedMap, isNot(automaticMap));
    expect(
      journal.effective.distanceBySurface[CanonicalSurface.grass],
      segment.distanceMeters,
    );
    expect(journal.effective.reconcilesWith(saved.distanceMeters), isTrue);

    // Reconstruct fresh repositories/controller from an actual SQLite reopen.
    controller.dispose();
    await app.close();
    app = open();
    walks = WalkRepository(app);
    controller = recorder();
    offline = true;
    cache.entries.clear();
    final callsBeforeReopen = provider.calls.length;
    await controller.initialize();
    expect(controller.walks.single.id, id);
    final reloadedPoints = await walks.pointsForWalk(id);
    journal = (await walks.surfaces.load(id, reloadedPoints))!;
    expect(SurfaceRouteGeoJson.build(journal.effective), correctedMap);
    expect(provider.calls.length, callsBeforeReopen);

    // Normal v2 recording alongside another walk's journal must not invalidate it.
    now = now.add(const Duration(minutes: 10));
    await start();
    await emitPoints(originals.take(3).toList());
    final secondId = controller.activeWalk!.id;
    final activePoints = await walks.pointsForWalk(secondId);
    await expectLater(
      walks.surfaces.saveAnalysis(
        secondId,
        WalkSurfaceSummary.fromAnalysis(
          RouteMatcher.analyze(activePoints, [concretePath]),
        ),
        evidenceComplete: true,
      ),
      throwsFormatException,
    );
    expect(await walks.surfaces.load(secondId, activePoints), isNull);
    now = now.add(const Duration(minutes: 1));
    await controller.stopWalk();
    journal = (await walks.surfaces.load(id, reloadedPoints))!;
    expect(SurfaceRouteGeoJson.build(journal.effective), correctedMap);
    final reopened = await app.database;
    expect(
      (await reopened.query('walk_surface_analyses')).single['points_valid'],
      1,
    );

    // Replacement uses the real matcher with different automatic boundaries.
    offline = false;
    evidenceData = mixedSurfaceEvidence();
    snapshot = await inspect(reloadedPoints);
    journal = await walks.surfaces.saveAnalysis(
      id,
      analyze(reloadedPoints, snapshot),
      evidenceComplete: true,
    );
    expect(
      journal.automatic.segments.any(
        (s) => s.surface.surface == CanonicalSurface.tile,
      ),
      isTrue,
    );
    expect(journal.corrections.single.sameRange(correction), isTrue);
    final effectiveCorrection = journal.effective.segments.singleWhere(
      (s) => s.isCorrected,
    );
    expect(
      (
        effectiveCorrection.startEdgeIndex,
        effectiveCorrection.endEdgeIndex,
        effectiveCorrection.surface,
      ),
      (
        correction.startEdgeIndex,
        correction.endEdgeIndex,
        CanonicalSurface.grass,
      ),
    );
    expect(journal.effective.reconcilesWith(saved.distanceMeters), isTrue);
    final beforeFailure = SurfaceRouteGeoJson.build(journal.effective);
    offline = true;
    cache.entries.clear();
    snapshot = await inspect(reloadedPoints);
    await expectLater(
      walks.surfaces.saveAnalysis(
        id,
        analyze(reloadedPoints, snapshot),
        evidenceComplete: false,
      ),
      throwsFormatException,
    );
    journal = (await walks.surfaces.load(id, reloadedPoints))!;
    expect(SurfaceRouteGeoJson.build(journal.effective), beforeFailure);
    expect(journal.corrections.single.sameRange(correction), isTrue);

    journal = await walks.surfaces.restoreAutomatic(
      id,
      reloadedPoints,
      correction,
    );
    expect(journal.corrections, isEmpty);
    final restoredMap = SurfaceRouteGeoJson.build(journal.effective);
    final current = journal.effective.segments.first;
    journal = await walks.surfaces.saveCorrection(
      id,
      reloadedPoints,
      SurfaceCorrection(
        startEdgeIndex: current.startEdgeIndex,
        endEdgeIndex: current.endEdgeIndex,
        surface: current.surface,
      ),
    );
    expect(journal.corrections, isEmpty);
    expect(journal.effective.segments.every((s) => !s.isCorrected), isTrue);
    expect(SurfaceRouteGeoJson.build(journal.effective), restoredMap);
    expect(await reopened.query('walk_surface_corrections'), isEmpty);
    expect(
      await reopened.query('walks', where: 'id = ?', whereArgs: [id]),
      originalWalkRow,
    );
    expect(
      await reopened.query(
        'walk_points',
        where: 'walk_id = ?',
        whereArgs: [id],
        orderBy: 'sequence',
      ),
      originalPointRows,
    );

    // Keep a correction present when checking deletion cascades.
    await walks.surfaces.saveCorrection(id, reloadedPoints, correction);
    await walks.deleteWalk(id);
    for (final table in [
      'walk_points',
      'walk_surface_analyses',
      'walk_surface_segments',
      'walk_surface_corrections',
    ]) {
      expect(
        await reopened.query(table, where: 'walk_id = ?', whereArgs: [id]),
        isEmpty,
      );
    }
    expect((await walks.listWalks()).single.id, secondId);
    expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
