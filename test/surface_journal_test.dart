import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/surface_journal.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/surface_route_geojson.dart';
import 'package:pathgrain/walks/walk_distance.dart';

import 'support/surface_fixtures.dart';

const grass = CanonicalSurface.grass;
const asphalt = CanonicalSurface.asphalt;
const paving = CanonicalSurface.pavingStones;
const unknown = CanonicalSurface.unknown;

AutomaticSurfaceSnapshot automatic(List<CanonicalSurface> surfaces) =>
    AutomaticSurfaceSnapshot.fromSummary(
      WalkSurfaceSummary.fromAnalysis(surfaceAnalysis(surfaces)),
    );
SurfaceCorrection correction(int start, int end, CanonicalSurface surface) =>
    SurfaceCorrection(
      startEdgeIndex: start,
      endEdgeIndex: end,
      surface: surface,
    );

void checkCoverage(EffectiveSurfaceSummary summary) {
  expect([
    for (final s in summary.segments)
      for (var i = s.startEdgeIndex; i < s.endEdgeIndex; i++) i,
  ], List.generate(summary.points.length - 1, (i) => i));
  expect(summary.reconcilesWith(WalkDistance.total(summary.points)), isTrue);
  expect(
    summary.distanceBySurface.values.fold<double>(0, (a, b) => a + b),
    closeTo(summary.totalDistanceMeters, 1e-6),
  );
  for (final s in summary.segments) {
    expect(
      s.distanceMeters,
      WalkDistance.total(
        summary.points.getRange(s.startEdgeIndex, s.endEdgeIndex + 1),
      ),
    );
  }
}

void main() {
  for (final (from, to) in [
    (unknown, grass),
    (asphalt, paving),
    (asphalt, unknown),
  ]) {
    test('$from to $to changes exactly the corrected original meters', () {
      final source = automatic([from, from, from, from]);
      final observation = correction(1, 3, to);
      final result = SurfaceJournal(source, [observation]).effective;
      expect(result.segments.map((s) => s.surface), [from, to, from]);
      final meters = WalkDistance.total(source.points.getRange(1, 4));
      expect(result.distanceBySurface[to], closeTo(meters, 1e-6));
      expect(
        result.distanceBySurface[from],
        closeTo(result.totalDistanceMeters - meters, 1e-6),
      );
      expect(result.segments[1].correction, same(observation));
      expect(source.segments.single.surface.surface, from);
      checkCoverage(result);
    });
  }

  test('new automatic boundaries cannot shrink or expand a correction', () {
    final observation = correction(1, 5, grass);
    final old = SurfaceJournal(
      automatic([unknown, unknown, unknown, unknown, unknown, unknown]),
      [observation],
    );
    final source = automatic([
      asphalt,
      asphalt,
      paving,
      paving,
      paving,
      paving,
    ]);
    final changed = SurfaceJournal(source, old.corrections).effective;
    expect(
      changed.segments.map(
        (s) => (s.startEdgeIndex, s.endEdgeIndex, s.surface, s.isCorrected),
      ),
      [(0, 1, asphalt, false), (1, 5, grass, true), (5, 6, paving, false)],
    );
    checkCoverage(changed);
    final restored = SurfaceJournal(source, const []).effective;
    expect(restored.segments.map((s) => s.surface), [asphalt, paving]);
    checkCoverage(restored);
  });

  test(
    'same-surface automatic and distinct corrections retain all boundaries',
    () {
      final result = SurfaceJournal(automatic([grass, grass, grass, grass]), [
        correction(1, 2, grass),
        correction(2, 3, grass),
      ]).effective;
      expect(
        result.segments.map(
          (s) => (s.startEdgeIndex, s.endEdgeIndex, s.isCorrected),
        ),
        [(0, 1, false), (1, 2, true), (2, 3, true), (3, 4, false)],
      );
      checkCoverage(result);
    },
  );

  test(
    'corrected GeoJSON preserves original geometry and explicit provenance',
    () {
      final source = automatic([asphalt, asphalt, asphalt]);
      final result = SurfaceJournal(source, [
        correction(1, 2, unknown),
      ]).effective;
      final features = SurfaceRouteGeoJson.build(result)['features'] as List;
      expect(features[1]['properties'], {
        'surface': 'unknown',
        'color': SurfaceRouteGeoJson.color(unknown),
        'startEdge': 1,
        'endEdge': 2,
        'corrected': true,
      });
      expect(features[0]['properties']['corrected'], false);
      expect(features[1]['geometry']['coordinates'], [
        for (final p in source.points.getRange(1, 3)) [p.longitude, p.latitude],
      ]);
    },
  );

  for (final invalid in [
    [correction(-1, 2, grass)],
    [correction(0, 0, grass)],
    [correction(1, 5, grass)],
    [correction(0, 3, grass), correction(2, 4, paving)],
    [correction(2, 3, grass), correction(0, 1, paving)],
  ]) {
    test(
      'malformed correction ranges are rejected: ${invalid.map((c) => (c.startEdgeIndex, c.endEdgeIndex))}',
      () {
        expect(
          () => SurfaceJournal(
            automatic([unknown, unknown, unknown, unknown]),
            invalid,
          ),
          throwsFormatException,
        );
      },
    );
  }

  test('automatic snapshots require complete ordered coverage', () {
    final source = automatic([asphalt, unknown, grass]);
    for (final segments in [
      source.segments.skip(1),
      source.segments.reversed,
      [...source.segments, source.segments.last],
    ]) {
      expect(
        () =>
            AutomaticSurfaceSnapshot(points: source.points, segments: segments),
        throwsFormatException,
      );
    }
  });

  test('journal collections cannot be mutated', () {
    final source = automatic([asphalt]);
    final input = [correction(0, 1, grass)];
    final journal = SurfaceJournal(source, input);
    input.clear();
    expect(journal.corrections, hasLength(1));
    expect(() => journal.corrections.clear(), throwsUnsupportedError);
    expect(() => journal.effective.segments.clear(), throwsUnsupportedError);
    expect(
      () => journal.effective.distanceBySurface.clear(),
      throwsUnsupportedError,
    );
  });
}
