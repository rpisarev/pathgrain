import 'package:pathgrain/map/evidence/osm_evidence.dart';
import 'package:pathgrain/walks/analysis/route_analysis.dart';
import 'package:pathgrain/walks/walk_models.dart';

import 'analysis_fixtures.dart';

/// Fabricated edge outputs isolate segmentation from matcher thresholds.
RouteAnalysis surfaceAnalysis(
  List<CanonicalSurface> surfaces, {
  List<WalkPoint>? points,
  List<AnalysisReason>? reasons,
  List<AnalysisReason>? surfaceReasons,
  List<SurfaceAssignment>? assignments,
  List<OsmFeature?>? selections,
}) {
  final originals = points ?? straight(count: surfaces.length + 1);
  final feature = straightPath();
  final samples = [
    for (var i = 0; i < originals.length; i++)
      SampleAnalysis(
        original: originals[i],
        gps: GpsAssessment(GpsState.stable, [AnalysisReason.stable]),
        candidates: const [],
        selected: (selections == null ? feature : selections[i]) == null
            ? null
            : candidate(selections == null ? feature : selections[i]!),
        confidence: i.isEven
            ? MatchConfidence.strong
            : MatchConfidence.supported,
        reason: i.isEven
            ? AnalysisReason.matched
            : AnalysisReason.continuitySupported,
        surface: const SurfaceAssessment(
          CanonicalSurface.grass,
          SurfaceAssignment.direct,
          AnalysisReason.explicitSurface,
        ),
      ),
  ];
  return RouteAnalysis(
    samples: samples,
    edges: [
      for (var i = 0; i < surfaces.length; i++)
        EdgeAnalysis(
          from: samples[i],
          to: samples[i + 1],
          gps: const GpsEdgeAssessment(reason: AnalysisReason.stable, speed: 1),
          reason:
              reasons?[i] ??
              (surfaces[i] == CanonicalSurface.unknown
                  ? AnalysisReason.noCandidate
                  : AnalysisReason.matched),
          surface: SurfaceAssessment(
            surfaces[i],
            assignments?[i] ??
                (surfaces[i] == CanonicalSurface.unknown
                    ? SurfaceAssignment.unknown
                    : SurfaceAssignment.direct),
            surfaceReasons?[i] ??
                (surfaces[i] == CanonicalSurface.unknown
                    ? (reasons?[i] ?? AnalysisReason.noCandidate)
                    : AnalysisReason.explicitSurface),
          ),
        ),
    ],
  );
}

MatchCandidate candidate(OsmFeature feature) => MatchCandidate(
  feature: feature,
  distanceMeters: 1,
  directionDegrees: 0,
  proximityScore: 40,
  pedestrianScore: 20,
  directionScore: 20,
  gpsScore: 10,
  reason: AnalysisReason.eligible,
);

OsmEvidence mixedSurfaceEvidence() {
  final features = [
    way(
      1,
      [(-30, 0), (60, 0)],
      tags: {'highway': 'footway', 'surface': 'asphalt'},
    ),
    way(
      2,
      [(90, 0), (170, 0)],
      tags: {'highway': 'footway', 'surface': 'paving_stones'},
    ),
    way(
      3,
      [(200, 0), (330, 0)],
      tags: {'highway': 'footway', 'surface': 'grass'},
    ),
  ];
  return OsmEvidence(
    features: features,
    raw: {'elements': features.map((f) => f.raw).toList()},
    unparsedElements: 0,
  );
}
