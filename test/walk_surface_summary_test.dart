import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/analysis/route_matcher.dart';
import 'package:pathgrain/walks/analysis/walk_surface_summary.dart';
import 'package:pathgrain/walks/walk_distance.dart';
import 'package:pathgrain/walks/walk_models.dart';

import 'support/analysis_fixtures.dart';
import 'support/surface_fixtures.dart';

const asphalt = CanonicalSurface.asphalt;
const grass = CanonicalSurface.grass;
const unknown = CanonicalSurface.unknown;

void main() {
  test('all barefoot categories aggregate repeated original edges without double counting', () {
    final labels = [
      ...CanonicalSurface.values,
      ...CanonicalSurface.values.reversed,
    ];
    final summary = WalkSurfaceSummary.fromAnalysis(surfaceAnalysis(labels));
    expect(
      summary.distanceBySurface.keys.toSet(),
      CanonicalSurface.values.toSet(),
    );
    for (final surface in CanonicalSurface.values) {
      var expected = 0.0;
      for (var i = 0; i < labels.length; i++) {
        if (labels[i] == surface) {
          expected += edgeMeters(summary.analysis.edges[i]);
        }
      }
      expect(summary.distanceBySurface[surface], closeTo(expected, 1e-6));
    }
    checkAllocation(summary);
  });

  test(
    'compatible edges merge without splitting on sample confidence or support',
    () {
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis(List.filled(1000, asphalt)),
      );
      expect(summary.segments, hasLength(1));
      expect(summary.segments.single.startEdgeIndex, 0);
      expect(summary.segments.single.endEdgeIndex, 1000);
      expect(summary.segments.single.sourceFeatureKey, 'way/1');
      checkAllocation(summary);
    },
  );

  test('ordered surface changes and a single UNKNOWN gap survive', () {
    final summary = WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis([
        unknown,
        unknown,
        asphalt,
        asphalt,
        unknown,
        asphalt,
        grass,
        grass,
      ]),
    );
    expect(summary.segments.map((s) => (s.startEdgeIndex, s.endEdgeIndex)), [
      (0, 2),
      (2, 4),
      (4, 5),
      (5, 6),
      (6, 8),
    ]);
    expect(summary.segments.map((s) => s.surface.surface), [
      unknown,
      asphalt,
      unknown,
      asphalt,
      grass,
    ]);
    checkAllocation(summary);
  });

  test('UNKNOWN reasons split segments and aggregate without overlap', () {
    final summary = WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis(
        List.filled(6, unknown),
        reasons: [
          AnalysisReason.missingSurface,
          AnalysisReason.missingSurface,
          AnalysisReason.uncertainEndpoint,
          AnalysisReason.ambiguousCandidates,
          AnalysisReason.missingSurface,
          AnalysisReason.edgeOffGeometry,
        ],
      ),
    );
    expect(summary.segments, hasLength(5));
    final reasons = summary.unknownDistanceByReason;
    expect(
      reasons.keys,
      containsAll([
        AnalysisReason.missingSurface,
        AnalysisReason.uncertainEndpoint,
        AnalysisReason.ambiguousCandidates,
        AnalysisReason.edgeOffGeometry,
      ]),
    );
    final edges = summary.analysis.edges;
    expect(
      reasons[AnalysisReason.missingSurface],
      closeTo(
        edgeMeters(edges[0]) + edgeMeters(edges[1]) + edgeMeters(edges[4]),
        1e-6,
      ),
    );
    expect(
      reasons[AnalysisReason.uncertainEndpoint],
      closeTo(edgeMeters(edges[2]), 1e-6),
    );
    expect(summary.unknownDistanceMeters, summary.totalDistanceMeters);
    checkAllocation(summary);
  });

  test('object identity and ordered transition endpoints remain distinct', () {
    final a = straightPath();
    final b = straightPath(id: 2);
    final summary = WalkSurfaceSummary.fromAnalysis(
      surfaceAnalysis(
        [asphalt, unknown, asphalt, unknown],
        reasons: [
          AnalysisReason.matched,
          AnalysisReason.differentObjects,
          AnalysisReason.matched,
          AnalysisReason.differentObjects,
        ],
        selections: [a, a, b, b, a],
      ),
    );
    expect(summary.segments, hasLength(4));
    expect(summary.segments.map((s) => s.sourceFeatureKey), [
      'way/1',
      null,
      'way/2',
      null,
    ]);
    expect(summary.segments[1].fromFeatureKey, 'way/1');
    expect(summary.segments[1].toFeatureKey, 'way/2');
    expect(summary.segments[3].fromFeatureKey, 'way/2');
    expect(summary.segments[3].toFeatureKey, 'way/1');
    checkAllocation(summary);
  });

  test(
    'equal labels on different objects never coalesce in unexpected input',
    () {
      final a = straightPath();
      final b = straightPath(id: 2);
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis([asphalt, asphalt, asphalt], selections: [a, a, b, b]),
      );
      expect(summary.segments, hasLength(3));
      expect(
        summary.distanceBySurface[asphalt],
        closeTo(summary.totalDistanceMeters, 1e-6),
      );
    },
  );

  test(
    'same key across feature instances merges; null provenance does not',
    () {
      final a = straightPath();
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis(
          [unknown, unknown, unknown, unknown],
          selections: [a, straightPath(), a, null, null],
        ),
      );
      expect(summary.segments.map((s) => s.edgeCount), [2, 1, 1]);
      expect(summary.segments.first.sourceFeatureKey, 'way/1');
      expect(summary.segments.last.sourceFeatureKey, isNull);
    },
  );

  test(
    'assignment, surface reason and edge reason each preserve boundaries',
    () {
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis(
          [grass, grass, grass, grass],
          assignments: [
            SurfaceAssignment.direct,
            SurfaceAssignment.inferred,
            SurfaceAssignment.inferred,
            SurfaceAssignment.inferred,
          ],
          surfaceReasons: [
            AnalysisReason.explicitSurface,
            AnalysisReason.grassLandcover,
            AnalysisReason.grassLandcover,
            AnalysisReason.explicitSurface,
          ],
          reasons: [
            AnalysisReason.matched,
            AnalysisReason.matched,
            AnalysisReason.continuitySupported,
            AnalysisReason.continuitySupported,
          ],
        ),
      );
      expect(summary.segments, hasLength(4));
      checkAllocation(summary);
    },
  );

  test(
    'repeated surface segments aggregate original distances including UNKNOWN',
    () {
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis(
          [asphalt, unknown, asphalt, grass, unknown],
          points: [
            sample(0, 0, 0),
            sample(1, 1, 0),
            sample(2, 4, 0),
            sample(3, 11, 0),
            sample(4, 22, 0),
            sample(5, 40, 0),
          ],
        ),
      );
      expect(summary.distanceBySurface[asphalt], closeTo(8, 1e-5));
      expect(summary.distanceBySurface[grass], closeTo(11, 1e-5));
      expect(summary.distanceBySurface[unknown], closeTo(21, 1e-5));
      expect(summary.totalDistanceMeters, closeTo(40, 1e-5));
      checkAllocation(summary);
    },
  );

  test('empty and single-point routes have no synthetic categories', () {
    for (final points in [
      <WalkPoint>[],
      [sample(0, 0, 0)],
    ]) {
      final summary = WalkSurfaceSummary.fromAnalysis(
        RouteMatcher.analyze(points, []),
      );
      expect(summary.segments, isEmpty);
      expect(summary.distanceBySurface, isEmpty);
      expect(summary.unknownDistanceByReason, isEmpty);
      expect(summary.totalDistanceMeters, 0);
      expect(summary.unknownDistanceMeters, 0);
      expect(summary.reconcilesWith(0), isTrue);
    }
  });

  test(
    'two points, zero and near-zero edges retain distance and provenance',
    () {
      for (final displacement in [0.0, 1e-7, 0.01, 2.0]) {
        final points = [sample(0, 0, 0), sample(1, displacement, 0)];
        final summary = WalkSurfaceSummary.fromAnalysis(
          RouteMatcher.analyze(points, []),
        );
        expect(summary.segments.single.edgeCount, 1);
        expect(summary.distanceBySurface.keys, [unknown]);
        expect(summary.unknownDistanceMeters, WalkDistance.total(points));
        checkAllocation(summary);
      }
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis(
          [asphalt, unknown, asphalt],
          points: [
            sample(0, 0, 0),
            sample(1, 5, 0),
            sample(2, 5, 0),
            sample(3, 10, 0),
          ],
        ),
      );
      expect(summary.segments, hasLength(3));
      expect(summary.segments[1].distanceMeters, 0);
      expect(summary.distanceBySurface.containsKey(unknown), isTrue);
      checkAllocation(summary);
    },
  );

  test('no evidence, incomplete evidence and missing tags reconcile matcher output', () {
    for (final complete in [true, false]) {
      for (final features in <List<OsmFeature>>[
        [],
        [
          straightPath(tags: {'highway': 'footway'}),
        ],
      ]) {
        final summary = WalkSurfaceSummary.fromAnalysis(
          RouteMatcher.analyze(
            straight(),
            features,
            evidenceComplete: complete,
          ),
        );
        expect(summary.distanceBySurface.keys, [unknown]);
        expect(summary.unknownDistanceMeters, summary.totalDistanceMeters);
        if (!complete) {
          expect(
            summary.unknownDistanceByReason,
            contains(AnalysisReason.evidenceIncomplete),
          );
        } else if (features.isNotEmpty) {
          expect(
            summary.unknownDistanceByReason,
            contains(AnalysisReason.missingSurface),
          );
        }
        checkAllocation(summary);
      }
    }
  });

  test(
    'GPS gaps, poor accuracy, and unsupported analysis latitude stay allocated',
    () {
      final points = [
        sample(0, 0, 0, accuracy: 38),
        sample(1, 30, 0, seconds: 1),
        sample(9, 50, 0, seconds: 90),
        WalkPoint(
          walkId: 17,
          sequence: 10,
          latitude: 81,
          longitude: 2,
          recordedAt: DateTime.utc(2026, 1, 1, 0, 2),
          accuracyMeters: 7,
        ),
      ];
      final summary = WalkSurfaceSummary.fromAnalysis(
        RouteMatcher.analyze(points, []),
      );
      expect(summary.unknownDistanceMeters, summary.totalDistanceMeters);
      checkAllocation(summary);
    },
  );

  test(
    'randomized alternating short/long edges allocate once deterministically',
    () {
      final random = math.Random(71);
      final points = [sample(0, 0, 0)];
      var x = 0.0;
      for (var i = 1; i <= 300; i++) {
        x += random.nextDouble() * 20;
        points.add(sample(i, x, random.nextDouble()));
      }
      final analysis = surfaceAnalysis([
        for (var i = 0; i < 300; i++) i.isEven ? asphalt : unknown,
      ], points: points);
      final first = WalkSurfaceSummary.fromAnalysis(analysis);
      final second = WalkSurfaceSummary.fromAnalysis(analysis);
      expect(first.segments, hasLength(300));
      expect(second.distanceBySurface, first.distanceBySurface);
      expect(
        second.segments.map(
          (s) => (s.startEdgeIndex, s.endEdgeIndex, s.distanceMeters),
        ),
        first.segments.map(
          (s) => (s.startEdgeIndex, s.endEdgeIndex, s.distanceMeters),
        ),
      );
      checkAllocation(first);
    },
  );

  test('incomplete, duplicated and reordered edges are rejected', () {
    final valid = surfaceAnalysis([asphalt, unknown, grass]);
    for (final edges in [
      valid.edges.take(2).toList(),
      valid.edges.reversed.toList(),
      [valid.edges[0], valid.edges[0], valid.edges[2]],
      [...valid.edges, valid.edges.last],
    ]) {
      expect(
        () => WalkSurfaceSummary.fromAnalysis(
          RouteAnalysis(samples: valid.samples, edges: edges),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'invalid coordinates and inconsistent surface state produce an error',
    () {
      final point = WalkPoint(
        walkId: 17,
        sequence: 1,
        latitude: double.nan,
        longitude: 2,
        recordedAt: DateTime.utc(2026),
        accuracyMeters: 7,
      );
      expect(
        () => WalkSurfaceSummary.fromAnalysis(
          surfaceAnalysis([unknown], points: [sample(0, 0, 0), point]),
        ),
        throwsFormatException,
      );
      for (final (surface, assignment) in [
        (asphalt, SurfaceAssignment.unknown),
        (unknown, SurfaceAssignment.direct),
      ]) {
        expect(
          () => WalkSurfaceSummary.fromAnalysis(
            surfaceAnalysis([surface], assignments: [assignment]),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'results are immutable and saved distance mismatch is never rescaled',
    () {
      final summary = WalkSurfaceSummary.fromAnalysis(
        surfaceAnalysis([asphalt, unknown]),
      );
      expect(() => summary.segments.clear(), throwsUnsupportedError);
      expect(() => summary.distanceBySurface.clear(), throwsUnsupportedError);
      expect(
        () => summary.unknownDistanceByReason.clear(),
        throwsUnsupportedError,
      );
      final original = summary.totalDistanceMeters;
      expect(summary.reconcilesWith(original + 0.0000001), isTrue);
      expect(summary.reconcilesWith(original + 1), isFalse);
      expect(summary.reconcilesWith(double.nan), isFalse);
      expect(summary.totalDistanceMeters, original);
    },
  );
}

double edgeMeters(EdgeAnalysis edge) =>
    WalkDistance.total([edge.from.original, edge.to.original]);

void checkAllocation(WalkSurfaceSummary summary) {
  final analysis = summary.analysis;
  expect([
    for (final segment in summary.segments)
      for (var i = segment.startEdgeIndex; i < segment.endEdgeIndex; i++) i,
  ], List.generate(analysis.edges.length, (i) => i));
  for (final segment in summary.segments) {
    expect(
      segment.distanceMeters,
      closeTo(
        WalkDistance.total(
          analysis.samples
              .sublist(segment.startEdgeIndex, segment.endEdgeIndex + 1)
              .map((s) => s.original),
        ),
        1e-6,
      ),
    );
  }
  final total = WalkDistance.total(analysis.samples.map((s) => s.original));
  expect(summary.reconcilesWith(total), isTrue);
  expect(
    summary.distanceBySurface.values.fold(0.0, (a, b) => a + b),
    closeTo(total, 1e-6),
  );
  expect(
    summary.unknownDistanceByReason.values.fold(0.0, (a, b) => a + b),
    closeTo(summary.unknownDistanceMeters, 1e-6),
  );
}
