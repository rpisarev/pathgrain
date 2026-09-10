import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/app_database.dart';
import 'package:pathgrain/walks/walk_models.dart';
import 'package:pathgrain/walks/walk_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('surface totals reconcile with SQLite completion distance and leave the walk intact', () async {
    final database = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final repository = WalkRepository(database);
    final originalPoints = straight(count: 30);
    final walk = await repository.createWalk(originalPoints.first.recordedAt);
    for (final point in originalPoints) {
      await repository.appendPoint(
        walk.id,
        LocationSample(
          latitude: point.latitude,
          longitude: point.longitude,
          recordedAt: point.recordedAt,
          accuracyMeters: point.accuracyMeters,
        ),
      );
    }
    final saved = await repository.finishWalk(
      walkId: walk.id,
      endedAt: originalPoints.last.recordedAt,
      status: WalkStatus.completed,
    );
    final points = await repository.pointsForWalk(walk.id);
    final summary = WalkSurfaceSummary.fromAnalysis(
      RouteMatcher.analyze(points, mixedSurfaceEvidence().features),
    );
    expect(summary.reconcilesWith(saved.distanceMeters), isTrue);
    expect(summary.distanceBySurface, hasLength(4));
    final after = (await repository.walkById(walk.id))!;
    final afterPoints = await repository.pointsForWalk(walk.id);
    expect(after.distanceMeters, saved.distanceMeters);
    expect(after.duration, saved.duration);
    expect(after.pointCount, saved.pointCount);
    expect(after.status, saved.status);
    expect(
      afterPoints.map(
        (p) => (
          p.sequence,
          p.latitude,
          p.longitude,
          p.recordedAt,
          p.accuracyMeters,
        ),
      ),
      points.map(
        (p) => (
          p.sequence,
          p.latitude,
          p.longitude,
          p.recordedAt,
          p.accuracyMeters,
        ),
      ),
    );
  });
}
