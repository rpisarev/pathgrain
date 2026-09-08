import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/walks/analysis/analysis_settings.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';

import 'support/analysis_fixtures.dart';

void main() {
  test(
    'a clearly stronger footway independently wins over a parallel road',
    () {
      // Fabricated meter grid only: both ways are inside the 7 m accuracy
      // envelope, with the footway 2 m away and the road 6 m away.
      final points = straight();
      final result = RouteMatcher.analyze(points, [
        straightPath(tags: {'highway': 'footway'}),
        straightPath(
          id: 2,
          north: 8,
          tags: {'highway': 'residential', 'surface': 'asphalt'},
        ),
      ]);
      for (final s in result.samples.take(2)) {
        expect(s.gps.state, GpsState.warmingUp);
        expect(s.reason, AnalysisReason.gpsUncertain);
        expect(s.selected, isNull);
      }
      for (final s in result.samples.skip(2)) {
        expect(s.gps.state, GpsState.stable);
        expect(s.candidates, hasLength(2));
        final footway = s.candidates[0];
        final road = s.candidates[1];
        for (final candidate in s.candidates) {
          expect(candidate.eligible, isTrue);
          expect(candidate.distanceMeters, lessThan(s.original.accuracyMeters));
          expect(candidate.directionDegrees, closeTo(0, 1e-5));
        }
        expect(footway.feature.key, 'way/1');
        expect(footway.distanceMeters, lessThan(road.distanceMeters));
        expect(footway.pedestrianScore, greaterThan(road.pedestrianScore));
        final independentScore = footway.score - footway.continuityScore;
        final independentMargin =
            independentScore - (road.score - road.continuityScore);
        expect(independentScore, greaterThan(AnalysisSettings.minimumScore));
        expect(independentMargin, greaterThan(AnalysisSettings.strongMargin));
        expect(s.selected?.feature.key, 'way/1');
        // A context-derived assignment must not masquerade as a new anchor.
        expect(s.reason, AnalysisReason.matched);
        expect(s.confidence, MatchConfidence.strong);
        expect(s.surface.assignment, SurfaceAssignment.unknown);
        expect(s.surface.reason, AnalysisReason.missingSurface);
      }
      expect(
        result.edges.every(
          (e) => e.surface.assignment == SurfaceAssignment.unknown,
        ),
        isTrue,
      );
    },
  );

  test(
    'ordinary margin independently resolves a closer footway versus road',
    () {
      // Synthetic parallel lines: scores are about 75 and 60, with a lead
      // above the ordinary margin but below the strong-confidence threshold.
      final result = RouteMatcher.analyze(straight(north: 4.5), [
        straightPath(tags: {'highway': 'footway'}),
        straightPath(
          id: 2,
          north: 10,
          tags: {'highway': 'residential', 'surface': 'asphalt'},
        ),
      ]);
      for (final s in result.samples.skip(2)) {
        expect(s.gps.isStable, isTrue);
        expect(s.candidates, hasLength(2));
        final footway = s.candidates[0];
        final road = s.candidates[1];
        for (final candidate in s.candidates) {
          expect(candidate.eligible, isTrue);
          expect(candidate.distanceMeters, lessThan(s.original.accuracyMeters));
          expect(candidate.directionDegrees, closeTo(0, 1e-5));
        }
        expect(footway.feature.key, 'way/1');
        expect(footway.distanceMeters, lessThan(road.distanceMeters));
        final independentScore = footway.score - footway.continuityScore;
        final roadIndependentScore = road.score - road.continuityScore;
        expect(independentScore, inInclusiveRange(74, 76));
        expect(roadIndependentScore, inInclusiveRange(59, 61));
        expect(
          independentScore - roadIndependentScore,
          inExclusiveRange(
            AnalysisSettings.minimumMargin,
            AnalysisSettings.strongMargin,
          ),
        );
        expect(s.selected?.feature.key, 'way/1');
        expect(s.reason, AnalysisReason.matched);
        expect(s.confidence, MatchConfidence.supported);
        expect(s.surface.assignment, SurfaceAssignment.unknown);
        expect(s.surface.reason, AnalysisReason.missingSurface);
      }
    },
  );

  for (final highway in ['footway', 'pedestrian']) {
    test(
      'a parallel $highway remains ambiguous despite a strong score lead',
      () {
        final result = RouteMatcher.analyze(straight(north: 0), [
          straightPath(tags: {'highway': 'footway'}),
          straightPath(id: 2, north: 6.5, tags: {'highway': highway}),
        ]);
        for (final s in result.samples.skip(2)) {
          expect(s.gps.isStable, isTrue);
          expect(s.candidates.every((c) => c.eligible), isTrue);
          expect(
            s.candidates[0].score - s.candidates[1].score,
            greaterThan(AnalysisSettings.strongMargin),
          );
          expect(s.reason, AnalysisReason.ambiguousCandidates);
          expect(s.selected, isNull);
          expect(s.candidates.every((c) => c.continuityScore == 0), isTrue);
        }
      },
    );
  }

  for (final scenario in [
    (label: 'insufficient minimum margin', north: 5.0),
    (label: 'equal distances', north: 4.0),
  ]) {
    test('footway versus road stays unknown with ${scenario.label}', () {
      final result = RouteMatcher.analyze(straight(north: scenario.north), [
        straightPath(tags: {'highway': 'footway'}),
        straightPath(id: 2, north: 8, tags: {'highway': 'residential'}),
      ]);
      for (final s in result.samples.skip(2)) {
        expect(s.gps.isStable, isTrue);
        expect(s.candidates.first.feature.key, 'way/1');
        expect(
          s.candidates.first.score,
          greaterThan(AnalysisSettings.minimumScore),
        );
        final margin = s.candidates[0].score - s.candidates[1].score;
        expect(margin, inExclusiveRange(0, AnalysisSettings.strongMargin));
        if (scenario.north == 5) {
          expect(margin, lessThan(AnalysisSettings.minimumMargin));
        }
        expect(s.reason, AnalysisReason.ambiguousCandidates);
        expect(s.selected, isNull);
      }
    });
  }

  test(
    'a nearer footway and strong score lead are insufficient without heading',
    () {
      final points = [for (var i = 0; i < 10; i++) sample(i, i * 1.0, 0.5)];
      final result = RouteMatcher.analyze(points, [
        straightPath(tags: {'highway': 'footway'}),
        straightPath(id: 2, north: 6, tags: {'highway': 'residential'}),
      ]);
      for (final s in result.samples.skip(2)) {
        expect(s.gps.isStable, isTrue);
        expect(s.candidates.every((c) => c.directionDegrees == null), isTrue);
        expect(
          s.candidates.first.score,
          greaterThan(AnalysisSettings.minimumScore),
        );
        expect(
          s.candidates[0].score - s.candidates[1].score,
          greaterThan(AnalysisSettings.strongMargin),
        );
        expect(s.reason, AnalysisReason.ambiguousCandidates);
        expect(s.selected, isNull);
      }
    },
  );

  test('a score advantage does not excuse weak footway alignment', () {
    final result = RouteMatcher.analyze(straight(), [
      way(1, [(-30, -35), (150, 55)], tags: {'highway': 'footway'}),
      way(2, [(-30, -9.5), (150, 35.5)], tags: {'highway': 'residential'}),
    ]);
    final s = result.samples[4];
    expect(s.gps.isStable, isTrue);
    expect(s.candidates.every((c) => c.eligible), isTrue);
    expect(s.candidates.first.feature.key, 'way/1');
    expect(
      s.candidates.first.directionDegrees,
      greaterThan(AnalysisSettings.parallelDirectionDegrees),
    );
    expect(
      s.candidates[0].score - s.candidates[1].score,
      greaterThan(AnalysisSettings.strongMargin),
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
  });

  test('reduced and poor GPS confidence still block footway assignments', () {
    for (final accuracy in [16.0, 26.0]) {
      final result = RouteMatcher.analyze(straight(accuracy: accuracy), [
        straightPath(tags: {'highway': 'footway'}),
        straightPath(id: 2, north: 8, tags: {'highway': 'residential'}),
      ]);
      for (final s in result.samples) {
        expect(s.gps.state, GpsState.unreliable);
        expect(s.reason, AnalysisReason.gpsUncertain);
        expect(s.selected, isNull);
      }
    }
  });

  test('one anchor cannot supply the independent footway over road margin', () {
    final result = RouteMatcher.analyze(straight(), [
      // The slight footway tilt leaves its independent lead below the
      // ordinary margin even though it is closer and sufficiently aligned.
      way(1, [(-30, -4.75), (150, 17.75)], tags: {'highway': 'footway'}),
      way(
        2,
        [(-30, 15), (31, 15), (37, 4.5), (150, 4.5)],
        tags: {'highway': 'residential'},
      ),
    ]);
    expect(result.samples[3].reason, AnalysisReason.matched);
    expect(result.samples[3].selected?.feature.key, 'way/1');
    final s = result.samples[4];
    final footway = s.candidates[0];
    final road = s.candidates[1];
    expect(s.gps.isStable, isTrue);
    expect(footway.eligible && road.eligible, isTrue);
    expect(footway.distanceMeters, lessThan(road.distanceMeters));
    expect(
      footway.directionDegrees,
      lessThan(AnalysisSettings.parallelDirectionDegrees),
    );
    expect(road.directionDegrees, isNotNull);
    expect(footway.continuityScore, greaterThan(0));
    expect(
      footway.score - road.score,
      greaterThan(AnalysisSettings.minimumMargin),
    );
    expect(
      (footway.score - footway.continuityScore) -
          (road.score - road.continuityScore),
      inExclusiveRange(0, AnalysisSettings.minimumMargin),
    );
    expect(s.reason, AnalysisReason.ambiguousCandidates);
    expect(s.selected, isNull);
    expect(result.samples[5].selected, isNull);
    expect(
      result.samples[5].candidates.every((c) => c.continuityScore == 0),
      isTrue,
    );
  });

  test(
    'a pedestrian rival behind the road still blocks the footway exception',
    () {
      final result = RouteMatcher.analyze(straight(north: 0, accuracy: 3), [
        straightPath(north: 0.25, tags: {'highway': 'footway'}),
        straightPath(id: 2, north: 3, tags: {'highway': 'residential'}),
        straightPath(id: 3, north: 5.5, tags: {'highway': 'pedestrian'}),
      ]);
      for (final s in result.samples.skip(2)) {
        expect(s.candidates.map((c) => c.feature.key), [
          'way/1',
          'way/2',
          'way/3',
        ]);
        expect(s.candidates.every((c) => c.eligible), isTrue);
        expect(
          s.candidates[0].score - s.candidates[1].score,
          greaterThan(AnalysisSettings.strongMargin),
        );
        expect(s.reason, AnalysisReason.ambiguousCandidates);
        expect(s.selected, isNull);
      }
    },
  );

  test(
    'parallel road matches are deterministic across evidence and node order',
    () {
      final variants = [
        [
          straightPath(tags: {'highway': 'footway'}),
          straightPath(id: 2, north: 8, tags: {'highway': 'residential'}),
        ],
        [
          way(2, [(150, 8), (-30, 8)], tags: {'highway': 'residential'}),
          way(1, [(150, 0), (-30, 0)], tags: {'highway': 'footway'}),
        ],
      ];
      List<Object?> signature(RouteAnalysis result) => [
        for (final s in result.samples)
          [
            s.selected?.feature.key,
            s.reason,
            s.confidence,
            for (final c in s.candidates)
              [
                c.feature.key,
                c.score,
                c.distanceMeters,
                c.directionDegrees,
                c.reason,
              ],
          ],
      ];
      // Exercise the newly accepted ordinary margin under every ordering.
      final points = straight(north: 3.5);
      final baseline = RouteMatcher.analyze(points, variants.first);
      expect(
        baseline.samples
            .skip(2)
            .every((s) => s.selected?.feature.key == 'way/1'),
        isTrue,
      );
      final expected = signature(baseline);
      for (var repeat = 0; repeat < 3; repeat++) {
        for (final features in variants) {
          expect(signature(RouteMatcher.analyze(points, features)), expected);
        }
      }
    },
  );
}
