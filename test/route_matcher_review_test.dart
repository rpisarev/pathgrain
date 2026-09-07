import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_geometry.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';

void main() {
  test('a tied bend tangent is unavailable regardless of OSM node order', () {
    final vertices = <(double, double)>[(-30, 0), (40, 0), (40, 80)];
    final forward = way(1, vertices);
    final backward = way(1, vertices.reversed.toList());
    for (final feature in [forward, backward]) {
      final hit = RouteGeometry.inspect(feature, grid(40, 0));
      expect(hit.supported, isTrue);
      expect(hit.bearing, isNull);
    }
    final a = RouteMatcher.analyze(straight(north: 0, accuracy: 3), [forward]);
    final b = RouteMatcher.analyze(straight(north: 0, accuracy: 3), [backward]);
    expect(
      a.samples.map((s) => s.selected?.feature.key),
      b.samples.map((s) => s.selected?.feature.key),
    );
  });

  test('one unflagged GPS deviation cannot pull adjacent good samples onto a detour', () {
    final points = [
      for (var i = 0; i < 16; i++)
        sample(i, i * 3.5, i == 8 ? 9.9 : 0, accuracy: 3),
    ];
    final detour = way(
      2,
      [(14, -4.9), (25, 2.8), (27, 9.9), (29, 9.9), (31, 2.8), (42, -4.9)],
      tags: {'highway': 'footway', 'surface': 'asphalt'},
    );
    for (final features in [
      [straightPath(), detour],
      [detour, straightPath()],
    ]) {
      final result = RouteMatcher.analyze(points, features);
      // This is below the provisional spike threshold. The matcher still must
      // not manufacture mutually agreeing headings from this one deviation.
      expect(result.samples[8].gps.isStable, isTrue);
      for (final index in [7, 9]) {
        expect(result.samples[index].gps.isStable, isTrue);
        expect(result.samples[index].selected?.feature.key, isNot('way/2'));
      }
    }
  });

  test('direction has no score when a containing area has no tangent', () {
    final area = way(
      3,
      [(-30, -30), (150, -30), (150, 30), (-30, 30), (-30, -30)],
      tags: {'area:highway': 'pedestrian', 'landcover': 'grass'},
    );
    final sample = RouteMatcher.analyze(straight(), [area]).samples[4];
    expect(sample.selected?.feature.key, 'way/3');
    expect(sample.selected!.directionDegrees, isNull);
    expect(sample.selected!.directionScore, 0);
    expect(sample.surface.assignment, SurfaceAssignment.inferred);
  });

  test('a sharp GPS bend does not provide a straight chord direction', () {
    final points = [
      for (var i = 0; i < 10; i++)
        sample(i, i < 4 ? i * 10.0 : 40, i < 4 ? 0 : (i - 4) * 10.0),
    ];
    final path = way(1, [(-30, 0), (40, 0), (40, 100)]);
    final result = RouteMatcher.analyze(points, [path]);
    expect(result.samples[4].gps.isStable, isTrue);
    expect(result.samples[4].candidates.single.directionDegrees, isNull);
  });

  test(
    'context-supported matches never become anchors for the next sample',
    () {
      final points = [
        for (var i = 0; i < 13; i++) sample(i, i * 10.0, i >= 4 ? 6 : 0),
      ];
      final road = straightPath(
        tags: {'highway': 'residential', 'surface': 'asphalt'},
      );
      final result = RouteMatcher.analyze(points, [road]);
      expect(result.samples[4].reason, AnalysisReason.continuitySupported);
      expect(result.samples[4].selected?.feature.key, 'way/1');
      expect(result.samples[5].gps.isStable, isTrue);
      expect(result.samples[5].candidates.single.continuityScore, 0);
      expect(result.samples[5].reason, AnalysisReason.weakScore);
      expect(result.samples[5].selected, isNull);
    },
  );

  test('repeated runs and reordered or reversed OSM geometry have identical scores', () {
    final points = [
      for (var i = 0; i < 10; i++) sample(i, i * 10.0, i == 4 ? 6 : 0),
    ];
    final alternatives = [
      [
        straightPath(),
        way(2, [(40, 8), (50, 8)]),
      ],
      [
        way(2, [(50, 8), (40, 8)]),
        way(1, [(150, 0), (-30, 0)]),
      ],
    ];
    List<Object?> signature(RouteAnalysis result) => [
      for (final sample in result.samples)
        [
          sample.reason,
          sample.confidence,
          sample.selected?.feature.key,
          sample.surface.surface,
          sample.surface.assignment,
          for (final candidate in sample.candidates)
            [
              candidate.feature.key,
              candidate.score,
              candidate.distanceMeters,
              candidate.directionDegrees,
              candidate.reason,
            ],
        ],
    ];
    final expected = signature(
      RouteMatcher.analyze(points, alternatives.first),
    );
    for (var repeat = 0; repeat < 3; repeat++) {
      for (final features in alternatives) {
        expect(signature(RouteMatcher.analyze(points, features)), expected);
      }
    }
  });
}
