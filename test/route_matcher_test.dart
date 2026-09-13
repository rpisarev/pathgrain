import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/walk_distance.dart';

import 'support/analysis_fixtures.dart';

void main() {
  test('good straight route stabilizes and preserves original samples and distance', () {
    final points = straight();
    final before = WalkDistance.total(points);
    final result = RouteMatcher.analyze(points, [straightPath()]);
    expect(
      result.samples
          .take(2)
          .every((s) => s.reason == AnalysisReason.gpsUncertain),
      isTrue,
    );
    for (var i = 0; i < points.length; i++) {
      expect(result.samples[i].original, same(points[i]));
    }
    for (final s in result.samples.skip(2)) {
      expect(s.gps.state, GpsState.stable);
      expect(s.selected?.feature.key, 'way/1');
      expect(s.confidence, MatchConfidence.strong);
      expect(s.surface.assignment, SurfaceAssignment.direct);
      expect(s.surface.surface, CanonicalSurface.grass);
    }
    expect(
      result.edges
          .take(2)
          .every((e) => e.surface.assignment == SurfaceAssignment.unknown),
      isTrue,
    );
    expect(
      result.edges
          .skip(2)
          .every((e) => e.surface.assignment == SurfaceAssignment.direct),
      isTrue,
    );
    expect(WalkDistance.total(points), before);
    expect(() => result.samples.clear(), throwsUnsupportedError);
  });

  test(
    'accuracy-driven warm-up does not assign the nearby wrong startup surface',
    () {
      final points = [
        sample(0, -53, 30, accuracy: 33.3, seconds: 0),
        sample(1, 0, 30, accuracy: 38.7, seconds: 12.4),
        sample(2, 5, 16, accuracy: 25.7, seconds: 20),
        sample(3, 10, 3, accuracy: 14.8, seconds: 28),
        sample(4, 20, 2, accuracy: 7.6, seconds: 36),
        for (var i = 5; i < 10; i++)
          sample(i, (i - 2) * 10.0, 2, seconds: 44 + (i - 5) * 8.0),
      ];
      final result = RouteMatcher.analyze(points, [
        straightPath(),
        straightPath(
          id: 2,
          north: 30,
          tags: {'highway': 'footway', 'surface': 'asphalt'},
        ),
      ]);
      expect(
        result.samples
            .take(5)
            .every(
              (s) =>
                  s.selected == null &&
                  s.surface.surface == CanonicalSurface.unknown,
            ),
        isTrue,
      );
      expect(
        result.samples[0].gps.reasons,
        contains(AnalysisReason.poorAccuracy),
      );
      expect(
        result.samples[1].gps.reasons,
        contains(AnalysisReason.fastMotion),
      );
      expect(result.samples[4].gps.state, GpsState.warmingUp);
      expect(
        result.samples.skip(5).every((s) => s.selected?.feature.key == 'way/1'),
        isTrue,
      );
    },
  );

  test(
    'lateral spike at ordinary accuracy is unknown even below speed limit',
    () {
      final points = [
        for (var i = 0; i < 12; i++)
          sample(i, i * 5.0, i == 5 ? 17 : 0, accuracy: i == 5 ? 14 : 7),
      ];
      final result = RouteMatcher.analyze(points, [
        straightPath(),
        straightPath(
          id: 2,
          north: 17,
          tags: {'highway': 'footway', 'surface': 'asphalt'},
        ),
      ]);
      final spike = result.samples[5];
      expect(spike.gps.reasons, contains(AnalysisReason.isolatedSpike));
      expect(spike.gps.reasons, isNot(contains(AnalysisReason.fastMotion)));
      expect(spike.selected, isNull);
      expect(spike.candidates.any((c) => c.feature.key == 'way/2'), isTrue);
      expect(result.edges[4].surface.assignment, SurfaceAssignment.unknown);
      expect(result.edges[5].surface.assignment, SurfaceAssignment.unknown);
      expect(result.samples[6].gps.state, GpsState.recovering);
      expect(result.samples[7].gps.state, GpsState.recovering);
      expect(result.samples[8].gps.state, GpsState.stable);
      expect(result.samples[8].selected?.feature.key, 'way/1');
    },
  );

  test('17.5 m in 4.5 s at 14 m accuracy invalidates both edge endpoints', () {
    final points = [
      for (var i = 0; i < 5; i++) sample(i, i * 5.0, 0, accuracy: 14),
      sample(5, 37.5, 0, accuracy: 14, seconds: 36.5),
      for (var i = 6; i < 11; i++)
        sample(
          i,
          37.5 + (i - 5) * 5.0,
          0,
          accuracy: 14,
          seconds: 36.5 + (i - 5) * 8.0,
        ),
    ];
    final result = RouteMatcher.analyze(points, [straightPath()]);
    expect(result.edges[4].gps.reason, AnalysisReason.fastMotion);
    expect(result.samples[4].selected, isNull);
    expect(result.samples[5].selected, isNull);
    expect(result.samples[8].gps.state, GpsState.stable);
  });

  test('direction rejects a nearer crossing way', () {
    final result = RouteMatcher.analyze(straight(), [
      straightPath(),
      way(
        2,
        [(40, -30), (40, 30)],
        tags: {'highway': 'footway', 'surface': 'asphalt'},
      ),
    ]);
    final s = result.samples[4];
    expect(s.selected?.feature.key, 'way/1');
    final rejected = s.candidates.singleWhere((c) => c.feature.key == 'way/2');
    expect(rejected.distanceMeters, lessThan(s.selected!.distanceMeters));
    expect(rejected.reason, AnalysisReason.directionConflict);
  });

  test('two independent neighbors support the farther parallel path', () {
    final points = [
      for (var i = 0; i < 10; i++) sample(i, i * 10.0, i == 4 ? 6 : 0),
    ];
    final features = [
      straightPath(),
      way(
        2,
        [(40, 8), (50, 8)],
        tags: {'highway': 'footway', 'surface': 'asphalt'},
      ),
    ];
    final result = RouteMatcher.analyze(points, features);
    final s = result.samples[4];
    expect(s.selected?.feature.key, 'way/1');
    expect(s.reason, AnalysisReason.continuitySupported);
    expect(s.confidence, MatchConfidence.supported);
    expect(s.selected!.continuityScore, greaterThan(0));
    expect(
      s.candidates.singleWhere((c) => c.feature.id == 2).distanceMeters,
      lessThan(s.selected!.distanceMeters),
    );
    final reversed = RouteMatcher.analyze(points, features.reversed.toList());
    expect(
      reversed.samples.map((s) => s.selected?.feature.key),
      result.samples.map((s) => s.selected?.feature.key),
    );
  });

  test(
    'unresolved parallel candidates stay unknown even with identical surfaces',
    () {
      for (final surface in ['asphalt', 'grass']) {
        final result = RouteMatcher.analyze(straight(), [
          straightPath(),
          straightPath(
            id: 2,
            north: 8,
            tags: {'highway': 'path', 'surface': surface},
          ),
        ]);
        expect(
          result.samples
              .skip(2)
              .every((s) => s.reason == AnalysisReason.ambiguousCandidates),
          isTrue,
        );
        expect(result.samples.every((s) => s.selected == null), isTrue);
      }
    },
  );

  test('missing and broad surface tags never fabricate DIRECT evidence', () {
    for (final surface in [
      null,
      'paved',
      'unpaved',
      'gravel',
      'concrete:lanes',
      'asphalt;grass',
      'invented',
    ]) {
      final result = RouteMatcher.analyze(straight(), [
        straightPath(tags: {'highway': 'footway', 'surface': ?surface}),
      ]);
      expect(result.samples[4].selected, isNotNull);
      expect(result.samples[4].surface.assignment, SurfaceAssignment.unknown);
    }
  });

  test(
    'only the same safely containing pedestrian grass area allows inference',
    () {
      final area = way(
        3,
        [(-30, -30), (150, -30), (150, 30), (-30, 30), (-30, -30)],
        tags: {'area:highway': 'pedestrian', 'landcover': 'grass'},
      );
      final result = RouteMatcher.analyze(straight(north: 0), [area]);
      expect(result.samples[4].surface.assignment, SurfaceAssignment.inferred);
      expect(result.samples[4].surface.surface, CanonicalSurface.grass);
      final boundary = RouteMatcher.analyze(straight(north: 27), [area]);
      expect(boundary.samples[4].selected, isNull);
      final line = RouteMatcher.analyze(straight(), [
        straightPath(tags: {'highway': 'footway', 'landcover': 'grass'}),
      ]);
      expect(line.samples[4].surface.assignment, SurfaceAssignment.unknown);
    },
  );

  test('partial evidence suppresses assignment while retaining candidates', () {
    final result = RouteMatcher.analyze(straight(), [
      straightPath(),
    ], evidenceComplete: false);
    expect(result.samples[4].reason, AnalysisReason.evidenceIncomplete);
    expect(result.samples[4].candidates, isNotEmpty);
    expect(result.samples.every((s) => s.selected == null), isTrue);
  });

  test('gaps and poor accuracy require a new stable sequence', () {
    final points = [
      for (var i = 0; i < 10; i++)
        sample(
          i,
          i * 10.0,
          0,
          accuracy: i == 4 ? 26 : 7,
          seconds: i * 8.0 + (i >= 7 ? 40 : 0),
        ),
    ];
    final result = RouteMatcher.analyze(points, [straightPath()]);
    expect(
      result.samples[4].gps.reasons,
      contains(AnalysisReason.poorAccuracy),
    );
    expect(result.samples[5].gps.state, GpsState.recovering);
    expect(result.samples[7].gps.reasons, contains(AnalysisReason.sequenceGap));
    expect(result.samples[9].gps.state, GpsState.recovering);
  });

  test('access restrictions and tagged road sidewalks are not snapped to the carriageway', () {
    for (final tags in [
      {'highway': 'footway', 'foot': 'no'},
      {'highway': 'footway', 'access': 'private'},
      {'highway': 'footway', 'foot:conditional': 'yes @ (sunrise-sunset)'},
      {'highway': 'residential', 'surface': 'asphalt', 'sidewalk': 'both'},
      {'highway': 'cycleway'},
      {'highway': 'motorway'},
    ]) {
      final result = RouteMatcher.analyze(straight(), [
        straightPath(tags: tags),
      ]);
      expect(result.samples[4].selected, isNull);
      expect(result.samples[4].candidates, hasLength(1));
    }
  });

  test('empty and invalid inputs remain unknown without mutating input', () {
    expect(RouteMatcher.analyze([], []).samples, isEmpty);
    for (final accuracy in [0.0, -1.0, double.nan, double.infinity]) {
      final result = RouteMatcher.analyze(
        [sample(0, 0, 0, accuracy: accuracy)],
        [straightPath()],
      );
      expect(result.samples.single.selected, isNull);
      expect(
        result.samples.single.gps.reasons,
        contains(AnalysisReason.invalidSample),
      );
    }
    final result = RouteMatcher.analyze(straight(), []);
    expect(result.samples[4].reason, AnalysisReason.noCandidate);
  });
}
