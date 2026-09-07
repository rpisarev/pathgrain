import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_geometry.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';

void main() {
  test('concave and self-intersecting pedestrian areas cannot infer grass', () {
    for (final ring in [
      [
        (-30.0, -30.0),
        (150.0, -30.0),
        (150.0, 30.0),
        (60.0, 0.0),
        (-30.0, 30.0),
        (-30.0, -30.0),
      ],
      [
        (-30.0, -30.0),
        (150.0, 30.0),
        (-30.0, 30.0),
        (150.0, -30.0),
        (-30.0, -30.0),
      ],
    ]) {
      final area = way(
        2,
        ring,
        tags: {'area:highway': 'pedestrian', 'landcover': 'grass'},
      );
      expect(RouteGeometry.inspect(area, grid(40, 0)).supported, isFalse);
      expect(
        RouteMatcher.analyze(straight(), [area]).samples[4].selected,
        isNull,
      );
    }
  });

  test('incomplete nearby pedestrian geometry prevents a confident rival assignment', () {
    final path = straightPath(id: 2, north: 3);
    final broken = OsmEvidence.parse(
      jsonEncode({
        'elements': [
          {
            ...path.raw,
            'geometry': [
              path.raw['geometry'][0],
              {'lat': grid(45, 3).latitude, 'lon': grid(45, 3).longitude},
              null,
              path.raw['geometry'][1],
            ],
          },
        ],
      }),
    ).features.single;
    final result = RouteMatcher.analyze(straight(), [straightPath(), broken]);
    expect(
      result.samples[4].candidates.any(
        (c) => c.reason == AnalysisReason.unsupportedGeometry,
      ),
      isTrue,
    );
    expect(result.samples[4].reason, AnalysisReason.ambiguousCandidates);
    expect(result.samples[4].selected, isNull);
  });

  test(
    'matched endpoints do not classify an edge that cuts across an OSM bend',
    () {
      final points = [
        for (final (i, east) in [-22.0, -12.0, -2.0, 32.0, 42.0, 52.0].indexed)
          sample(i, east, 0, accuracy: 3, seconds: i * 12.0),
      ];
      final path = way(1, [
        (-30, 0),
        (0, 0),
        (0, 50),
        (30, 50),
        (30, 0),
        (90, 0),
      ]);
      final result = RouteMatcher.analyze(points, [path]);
      expect(result.samples[2].selected?.feature.key, 'way/1');
      expect(result.samples[3].selected?.feature.key, 'way/1');
      expect(result.edges[2].gps.isStable, isTrue);
      expect(result.edges[2].reason, AnalysisReason.edgeOffGeometry);
      expect(result.edges[2].surface.assignment, SurfaceAssignment.unknown);
    },
  );

  test('reversing OSM way geometry preserves direction compatibility', () {
    final path = straightPath();
    final reversed = way(1, [(150, 0), (-30, 0)]);
    final a = RouteMatcher.analyze(straight(), [path]);
    final b = RouteMatcher.analyze(straight(), [reversed]);
    expect(
      b.samples.map((s) => s.selected?.feature.key),
      a.samples.map((s) => s.selected?.feature.key),
    );
    expect(
      b.samples[4].selected!.directionDegrees,
      closeTo(a.samples[4].selected!.directionDegrees!, 1e-5),
    );
  });
}
